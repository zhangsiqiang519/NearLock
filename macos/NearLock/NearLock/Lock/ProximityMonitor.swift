import Foundation
import Combine

/// 接近度监控器：驱动整个"离座检测 → 锁屏"闭环。
///
/// 职责：
/// - 周期性读取绑定设备的 RSSI（或判定信号丢失），喂给 ProximityEvaluator 去抖。
/// - 满足"连续 N 秒低于阈值"且未处于暂停期时，执行锁屏并记录日志。
/// - 锁屏后进入冷却，避免息屏瞬间重复触发。
@MainActor
final class ProximityMonitor: ObservableObject {

    /// 当前平滑后的 RSSI（用于 UI 展示，nil 表示无数据）。
    @Published private(set) var smoothedRSSI: Int?

    /// 当前已持续低于阈值的秒数（用于 UI 进度展示）。
    @Published private(set) var belowSeconds: Int = 0

    private let scanner: BluetoothScanner
    private let settings: SettingsStore
    private let eventLog: EventLog

    private var evaluator = ProximityEvaluator()
    private var timer: Timer?

    /// 信号丢失判定阈值：超过此秒数未收到绑定设备广播视为离场。
    private let signalLostThreshold: TimeInterval = 3.0

    /// 锁屏后的冷却时间，避免重复触发。
    private let cooldown: TimeInterval = 30.0
    private var lastLockTime: Date?

    init(scanner: BluetoothScanner, settings: SettingsStore, eventLog: EventLog) {
        self.scanner = scanner
        self.settings = settings
        self.eventLog = eventLog
    }

    /// 启动监控循环（每秒 tick 一次）。
    func start() {
        guard timer == nil else { return }
        let timer = Timer(timeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.tick() }
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    /// 停止监控循环。
    func stop() {
        timer?.invalidate()
        timer = nil
        evaluator.reset()
        smoothedRSSI = nil
        belowSeconds = 0
    }

    /// 绑定设备变更时重置去抖状态。
    func resetForRebind() {
        evaluator.reset()
        smoothedRSSI = nil
        belowSeconds = 0
        lastLockTime = nil
    }

    private func tick() {
        guard let boundId = settings.boundDeviceId else {
            // 未绑定：清理状态，不监控
            smoothedRSSI = nil
            belowSeconds = 0
            return
        }

        let now = Date()

        // 判定信号是否丢失（一段时间未刷新或从未发现）
        if let lastSeen = scanner.lastSeen(for: boundId),
           now.timeIntervalSince(lastSeen) < signalLostThreshold,
           let rssi = scanner.rssi(for: boundId) {
            evaluator.addSample(rssi, threshold: settings.rssiThreshold, now: now)
        } else {
            evaluator.markSignalLost(now: now)
        }

        smoothedRSSI = evaluator.smoothedRSSI
        belowSeconds = Int(evaluator.belowDuration(now: now))

        // 保护总开关关闭时不触发（无限期手动停用，与定时暂停并列的另一道闸）
        if !settings.protectionEnabled { return }

        // 暂停保护期内不触发
        if settings.isPaused { return }

        // 冷却期内不触发
        if let lastLock = lastLockTime, now.timeIntervalSince(lastLock) < cooldown {
            return
        }

        if evaluator.shouldTrigger(triggerSeconds: settings.triggerSeconds, now: now) {
            triggerLock()
        }
    }

    private func triggerLock() {
        lastLockTime = Date()
        let result = ScreenLocker.lock()
        switch result {
        case .success:
            eventLog.log("检测到离开，已自动息屏锁屏")
        case .failure(let reason):
            eventLog.log("锁屏失败：\(reason)")
        }
        evaluator.reset()
    }
}
