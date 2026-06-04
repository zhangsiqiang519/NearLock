import Foundation
import Combine

/// 用户设置持久化（UserDefaults）。
///
/// 持久化项：RSSI 阈值、触发时间、绑定的 deviceId、暂停截止时间戳。
/// 全部用 @Published 暴露，SwiftUI 视图可直接绑定，didSet 同步写入 UserDefaults。
@MainActor
final class SettingsStore: ObservableObject {

    private let defaults = UserDefaults.standard

    private enum Keys {
        static let rssiThreshold = "rssiThreshold"
        static let triggerSeconds = "triggerSeconds"
        static let boundDeviceId = "boundDeviceId"
        static let pauseUntil = "pauseUntil"
    }

    /// RSSI 阈值（dBm），低于此值视为远离。默认 -85。
    @Published var rssiThreshold: Int {
        didSet { defaults.set(rssiThreshold, forKey: Keys.rssiThreshold) }
    }

    /// 触发时间（秒），连续低于阈值达到此时长才锁屏。默认 15。
    @Published var triggerSeconds: Int {
        didSet { defaults.set(triggerSeconds, forKey: Keys.triggerSeconds) }
    }

    /// 已绑定的设备 deviceId（nil 表示未绑定）。
    @Published var boundDeviceId: String? {
        didSet { defaults.set(boundDeviceId, forKey: Keys.boundDeviceId) }
    }

    /// 暂停保护的截止时间（nil 表示未暂停）。
    @Published var pauseUntil: Date? {
        didSet {
            if let pauseUntil {
                defaults.set(pauseUntil.timeIntervalSince1970, forKey: Keys.pauseUntil)
            } else {
                defaults.removeObject(forKey: Keys.pauseUntil)
            }
        }
    }

    init() {
        // 读取持久化值，缺省时用默认值
        let storedThreshold = defaults.object(forKey: Keys.rssiThreshold) as? Int
        self.rssiThreshold = storedThreshold ?? -85

        let storedTrigger = defaults.object(forKey: Keys.triggerSeconds) as? Int
        self.triggerSeconds = storedTrigger ?? 15

        self.boundDeviceId = defaults.string(forKey: Keys.boundDeviceId)

        if let ts = defaults.object(forKey: Keys.pauseUntil) as? Double {
            let date = Date(timeIntervalSince1970: ts)
            // 过期的暂停时间忽略
            self.pauseUntil = date > Date() ? date : nil
        } else {
            self.pauseUntil = nil
        }
    }

    /// 当前是否处于暂停保护期。
    var isPaused: Bool {
        guard let pauseUntil else { return false }
        return pauseUntil > Date()
    }

    /// 暂停保护指定分钟数。
    ///
    /// - Parameter minutes: 暂停时长（分钟）
    func pause(minutes: Int) {
        pauseUntil = Date().addingTimeInterval(TimeInterval(minutes * 60))
    }

    /// 立即恢复保护（取消暂停）。
    func resume() {
        pauseUntil = nil
    }

    /// 绑定设备。
    func bind(deviceId: String) {
        boundDeviceId = deviceId
    }

    /// 解绑当前设备。
    func unbind() {
        boundDeviceId = nil
    }
}
