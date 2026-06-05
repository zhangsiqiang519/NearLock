import Foundation

/// 屏幕锁定执行器。
///
/// 锁屏策略（见 research/macos-lock-mechanism.md，本任务再次升级）：
/// - 首选 `lockViaLoginFramework()`：dlopen login.framework 调 SACLockScreenImmediate，
///   这是 macOS 锁屏的标准底层调用。**纯进程内调用，不发按键、不碰其他进程，
///   因此无需辅助功能(Accessibility)权限**——绕开了 ad-hoc 签名开发版 App
///   发送系统按键被 TCC 静默拦截的问题（实测 osascript 方案在 ad-hoc 签名下无效）。
/// - 降级 `lockViaOSAScript()`：osascript 发 Ctrl+Cmd+Q（需辅助功能权限，正式签名版可用）。
/// - 兜底 `sleepDisplay()`：pmset displaysleepnow 仅息屏。
/// 统一入口 `lock()` 依次尝试，返回首个成功者。
///
/// 不开启 App Sandbox（私有符号 dlopen 在沙箱下会被限制）。
enum ScreenLocker {

    /// 锁屏结果。
    enum Result {
        case success
        case failure(String)
    }

    /// 真正锁屏所用私有符号的函数类型（无参，返回 Int32）。
    private typealias LockScreenFunc = @convention(c) () -> Int32

    /// 统一锁屏入口：login.framework → osascript → 息屏，返回首个成功者。
    @discardableResult
    static func lock() -> Result {
        let viaFramework = lockViaLoginFramework()
        if case .success = viaFramework { return .success }

        let viaScript = lockViaOSAScript()
        if case .success = viaScript { return .success }

        // 都失败则息屏兜底
        let slept = sleepDisplay()
        if case .success = slept {
            return .failure("已息屏（未能真正锁屏：\(describe(viaFramework)) / \(describe(viaScript))）")
        }
        return viaFramework
    }

    /// 首选：dlopen login.framework 调 SACLockScreenImmediate 立即锁屏。
    ///
    /// 无需辅助功能权限，是当前最可靠的免授权锁屏方式。
    ///
    /// - Returns: 执行结果
    @discardableResult
    static func lockViaLoginFramework() -> Result {
        let path = "/System/Library/PrivateFrameworks/login.framework/login"
        guard let handle = dlopen(path, RTLD_NOW) else {
            return .failure("无法加载 login.framework：\(String(cString: dlerror()))")
        }
        defer { dlclose(handle) }

        guard let sym = dlsym(handle, "SACLockScreenImmediate") else {
            return .failure("未找到 SACLockScreenImmediate 符号")
        }
        let lockScreen = unsafeBitCast(sym, to: LockScreenFunc.self)
        let status = lockScreen()
        return status == 0
            ? .success
            : .failure("SACLockScreenImmediate 返回 \(status)")
    }

    /// 降级：osascript 发送 Ctrl+Cmd+Q（key code 12 = Q）。正式签名版本可用，
    /// ad-hoc 开发版可能被 TCC 拦截。
    ///
    /// - Returns: 执行结果
    @discardableResult
    static func lockViaOSAScript() -> Result {
        let script = "tell application \"System Events\" to key code 12 using {control down, command down}"
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        process.arguments = ["-e", script]
        do {
            try process.run()
            process.waitUntilExit()
            return process.terminationStatus == 0
                ? .success
                : .failure("osascript 退出码 \(process.terminationStatus)")
        } catch {
            return .failure("无法执行 osascript：\(error.localizedDescription)")
        }
    }

    /// 兜底：pmset displaysleepnow 息屏。
    ///
    /// - Returns: 执行结果
    @discardableResult
    static func sleepDisplay() -> Result {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/pmset")
        process.arguments = ["displaysleepnow"]
        do {
            try process.run()
            process.waitUntilExit()
            return process.terminationStatus == 0
                ? .success
                : .failure("pmset 退出码 \(process.terminationStatus)")
        } catch {
            return .failure("无法执行 pmset：\(error.localizedDescription)")
        }
    }

    private static func describe(_ result: Result) -> String {
        if case .failure(let msg) = result { return msg }
        return "ok"
    }
}
