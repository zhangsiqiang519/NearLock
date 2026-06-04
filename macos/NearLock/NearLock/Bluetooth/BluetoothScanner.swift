import Foundation
import CoreBluetooth
import Combine

/// CoreBluetooth 扫描器：发现 NearLock 信标、解析 deviceId、持续读取 RSSI。
///
/// 设计要点（见 research/ble-protocol.md）：
/// - 仅被动扫描（scan-only），不建立 GATT 连接，RSSI 直接取自 didDiscover 回调。
/// - 开启 allowDuplicates 以重复接收同一设备广播、持续刷新 RSSI。
/// - 用 withServices: nil + 回调内按 Service Data key 过滤，兼容 Android 仅放 ServiceData 的广播。
@MainActor
final class BluetoothScanner: NSObject, ObservableObject {

    /// 当前发现的所有 NearLock 设备（按 deviceId 去重）。
    @Published private(set) var devices: [String: DiscoveredDevice] = [:]

    /// 蓝牙是否就绪（poweredOn）。
    @Published private(set) var isReady = false

    /// 是否正在扫描。
    @Published private(set) var isScanning = false

    /// 发现/更新设备时的回调（deviceId, rssi），供监控逻辑订阅。
    var onDeviceUpdate: ((String, Int) -> Void)?

    private var centralManager: CBCentralManager!

    override init() {
        super.init()
        centralManager = CBCentralManager(delegate: self, queue: .main)
    }

    /// 开始扫描（蓝牙就绪时生效）。
    func startScanning() {
        guard centralManager.state == .poweredOn else { return }
        guard !isScanning else { return }
        centralManager.scanForPeripherals(
            withServices: nil,
            options: [CBCentralManagerScanOptionAllowDuplicatesKey: true]
        )
        isScanning = true
    }

    /// 停止扫描。
    func stopScanning() {
        guard isScanning else { return }
        centralManager.stopScan()
        isScanning = false
    }

    /// 移除超过指定时间未刷新的设备（清理离场设备）。
    ///
    /// - Parameter staleAfter: 超时秒数
    func pruneStaleDevices(staleAfter: TimeInterval) {
        let now = Date()
        devices = devices.filter { now.timeIntervalSince($0.value.lastSeen) < staleAfter }
    }

    /// 读取指定设备的当前 RSSI（不存在返回 nil）。
    func rssi(for deviceId: String) -> Int? {
        devices[deviceId]?.rssi
    }

    /// 指定设备最近一次被发现的时间（不存在返回 nil）。
    func lastSeen(for deviceId: String) -> Date? {
        devices[deviceId]?.lastSeen
    }
}

extension BluetoothScanner: CBCentralManagerDelegate {

    nonisolated func centralManagerDidUpdateState(_ central: CBCentralManager) {
        Task { @MainActor in
            isReady = (central.state == .poweredOn)
            if central.state == .poweredOn {
                startScanning()
            } else {
                isScanning = false
                devices.removeAll()
            }
        }
    }

    nonisolated func centralManager(
        _ central: CBCentralManager,
        didDiscover peripheral: CBPeripheral,
        advertisementData: [String: Any],
        rssi RSSI: NSNumber
    ) {
        // 从广播 Service Data 中按固定 Service UUID 取出 deviceId 字节
        guard let serviceData = advertisementData[CBAdvertisementDataServiceDataKey]
            as? [CBUUID: Data] else { return }
        guard let payload = serviceData[NearLockProtocol.serviceUUID] else { return }
        guard let deviceId = NearLockProtocol.decodeDeviceId(from: payload) else { return }

        let rssiValue = RSSI.intValue
        // 忽略明显无效的 RSSI（CoreBluetooth 在不可用时返回 127）
        guard rssiValue != 127 else { return }

        Task { @MainActor in
            devices[deviceId] = DiscoveredDevice(
                id: deviceId,
                rssi: rssiValue,
                lastSeen: Date()
            )
            onDeviceUpdate?(deviceId, rssiValue)
        }
    }
}
