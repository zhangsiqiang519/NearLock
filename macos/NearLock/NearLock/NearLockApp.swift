import SwiftUI

/// NearLock macOS 应用入口。
///
/// 使用 MenuBarExtra 常驻菜单栏（无主窗口、无 Dock 图标，配合 Info.plist 的 LSUIElement）。
/// 在此组装所有依赖（设置、扫描器、事件日志、监控器）并注入环境。
@main
struct NearLockApp: App {

    @StateObject private var settings = SettingsStore()
    @StateObject private var scanner = BluetoothScanner()
    @StateObject private var eventLog = EventLog()
    @StateObject private var monitor: ProximityMonitor

    init() {
        let settings = SettingsStore()
        let scanner = BluetoothScanner()
        let eventLog = EventLog()
        _settings = StateObject(wrappedValue: settings)
        _scanner = StateObject(wrappedValue: scanner)
        _eventLog = StateObject(wrappedValue: eventLog)
        _monitor = StateObject(wrappedValue: ProximityMonitor(
            scanner: scanner,
            settings: settings,
            eventLog: eventLog
        ))
    }

    var body: some Scene {
        MenuBarExtra("NearLock", systemImage: menuBarIcon) {
            MenuContentView()
                .environmentObject(settings)
                .environmentObject(scanner)
                .environmentObject(eventLog)
                .environmentObject(monitor)
                .onAppear {
                    monitor.start()
                    eventLog.log("NearLock 已启动，开始扫描")
                }
        }
        .menuBarExtraStyle(.window)
    }

    /// 菜单栏图标随状态变化：绑定且保护中用实心锁，否则用空心锁。
    private var menuBarIcon: String {
        if settings.isPaused {
            return "lock.open"
        }
        return settings.boundDeviceId != nil ? "lock.fill" : "lock"
    }
}
