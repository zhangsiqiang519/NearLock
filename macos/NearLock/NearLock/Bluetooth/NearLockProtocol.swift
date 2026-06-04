import Foundation
import CoreBluetooth

/// NearLock 双端共享的 BLE 协议常量与 deviceId 编解码。
///
/// 与 Android 端 `NearLockProtocol.kt` 保持一致：
/// - Service UUID 固定不变。
/// - deviceId 为 8 字节短 ID，放在广播包的 Service Data 字段，
///   双端统一用 16 位小写无分隔 hex 字符串表示与比对。
enum NearLockProtocol {

    /// NearLock 专用固定 Service UUID，双端硬编码。
    static let serviceUUIDString = "A1B2C3D4-0000-1000-8000-00805F9B34FB"

    static let serviceUUID = CBUUID(string: serviceUUIDString)

    /// deviceId 短 ID 的字节长度（与 Android 端一致）。
    static let deviceIdBytes = 8

    /// 将广播 Service Data 中的 8 字节短 ID 解码为 16 位小写 hex 字符串。
    ///
    /// 与 Android 端 `shortIdHex` 对应：同一短 ID 在两端得到完全相同的字符串，
    /// 用于设备绑定的识别与比对。
    ///
    /// - Parameter data: Service Data 字节（应为 8 字节）
    /// - Returns: 16 位小写 hex 字符串；长度不符时返回 nil
    static func decodeDeviceId(from data: Data) -> String? {
        guard data.count == deviceIdBytes else { return nil }
        return data.map { String(format: "%02x", $0) }.joined()
    }
}

