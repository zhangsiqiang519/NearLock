import Foundation

/// 接近度判定的纯逻辑核心（无副作用，便于单元测试）。
///
/// 负责：RSSI 滑动平均去抖 + "连续低于阈值时长"累计。
/// 不直接触发锁屏，只回答"是否应该锁屏"，由 ProximityMonitor 驱动并执行。
struct ProximityEvaluator {

    /// 滑动平均窗口大小。
    let windowSize: Int

    private var samples: [Int] = []

    /// 平滑 RSSI 持续低于阈值的起始时间（nil 表示当前不低于阈值）。
    private(set) var belowSince: Date?

    init(windowSize: Int = 3) {
        self.windowSize = max(1, windowSize)
    }

    /// 当前滑动平均 RSSI（无样本时返回 nil）。
    var smoothedRSSI: Int? {
        guard !samples.isEmpty else { return nil }
        return samples.reduce(0, +) / samples.count
    }

    /// 喂入一个新 RSSI 样本并更新去抖状态。
    ///
    /// - Parameters:
    ///   - rssi: 最新 RSSI
    ///   - threshold: 阈值
    ///   - now: 当前时间（测试可注入）
    mutating func addSample(_ rssi: Int, threshold: Int, now: Date = Date()) {
        samples.append(rssi)
        if samples.count > windowSize {
            samples.removeFirst(samples.count - windowSize)
        }
        updateBelowState(threshold: threshold, now: now)
    }

    /// 标记信号丢失（一段时间收不到广播），等同于"低于阈值"。
    /// 保留旧样本，避免信号短暂回来后需重新积累才能恢复平滑值。
    ///
    /// - Parameter now: 当前时间
    mutating func markSignalLost(now: Date = Date()) {
        if belowSince == nil {
            belowSince = now
        }
    }

    /// 判断是否已满足触发条件（连续低于阈值时长 ≥ triggerSeconds）。
    ///
    /// - Parameters:
    ///   - triggerSeconds: 触发所需的持续秒数
    ///   - now: 当前时间
    /// - Returns: 是否应触发锁屏
    func shouldTrigger(triggerSeconds: Int, now: Date = Date()) -> Bool {
        guard let belowSince else { return false }
        return now.timeIntervalSince(belowSince) >= TimeInterval(triggerSeconds)
    }

    /// 当前已持续低于阈值的秒数（未低于时为 0）。
    func belowDuration(now: Date = Date()) -> TimeInterval {
        guard let belowSince else { return 0 }
        return now.timeIntervalSince(belowSince)
    }

    /// 重置状态（如绑定变更、恢复保护后）。
    mutating func reset() {
        samples.removeAll()
        belowSince = nil
    }

    private mutating func updateBelowState(threshold: Int, now: Date) {
        guard let smoothed = smoothedRSSI else { return }
        if smoothed < threshold {
            if belowSince == nil { belowSince = now }
        } else {
            belowSince = nil
        }
    }
}
