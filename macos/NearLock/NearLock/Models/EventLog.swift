import Foundation

/// 事件日志条目，记录 NearLock 的关键行为供菜单栏展示。
struct EventLogEntry: Identifiable {
    let id = UUID()
    let timestamp: Date
    let message: String

    /// 格式化为 HH:mm:ss 用于 UI 展示。
    var timeText: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter.string(from: timestamp)
    }
}

/// 内存环形事件日志（最多保留 maxEntries 条）。
///
/// 仅用于 UI 展示最近事件，不持久化（重启清空）。
@MainActor
final class EventLog: ObservableObject {

    @Published private(set) var entries: [EventLogEntry] = []

    private let maxEntries: Int

    init(maxEntries: Int = 50) {
        self.maxEntries = maxEntries
    }

    /// 追加一条日志，超出上限时丢弃最旧条目。
    ///
    /// - Parameter message: 事件描述
    func log(_ message: String) {
        entries.insert(EventLogEntry(timestamp: Date(), message: message), at: 0)
        if entries.count > maxEntries {
            entries.removeLast(entries.count - maxEntries)
        }
    }
}
