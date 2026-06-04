import Foundation

/// 屏幕锁定执行器。
///
/// 锁屏策略（见 research/macos-lock-mechanism.md，本任务从纯息屏升级）：
/// - 首选 `lockScreen()`：用 osascript 发送系统锁屏快捷键 Ctrl+Cmd+Q，直接锁到登录界面，
///   不受"屏幕关闭后多久要求密码"宽限期影响（实测用户机器宽限期为 300 秒，纯息屏锁不住）。
///   代价：首次需用户授予辅助功能(Accessibility)权限。
/// - 兜底 `lockNow()`：`pmset displaysleepnow` 仅息屏，作为锁屏快捷键不可用时的退路。
/// 统一入口 `lock()` 先尝试真正锁屏，失败再息屏。
///
/// 不使用私有 API；需 App 未开启 Sandbox 以允许 Process 执行外部命令。
enum ScreenLocker {

    /// 锁屏结果。
    enum Result {
        case success
        case failure(String)
    }

    /// 统一锁屏入口：先尝试系统锁屏（真正锁定），失败则降级为息屏。
    ///
    /// - Returns: 锁屏成功（系统锁屏或息屏任一成功）或均失败
    @discardableResult
    static func lock() -> Result {
        let locked = lockScreen()
        if case .success = locked {
            return .success
        }
        // 系统锁屏失败（多为未授辅助功能权限），降级息屏兜底
        let slept = lockNow()
        if case .success = slept {
            return .failure("已息屏（未能真正锁屏，可能缺少辅助功能权限）")
        }
        return locked
    }

    /// 真正锁屏：osascript 发送 Ctrl+Cmd+Q（key code 12 = Q）锁到登录界面。
    ///
    /// - Returns: 执行结果
    @discardableResult
    static func lockScreen() -> Result {
        let script = "tell application \"System Events\" to key code 12 using {control down, command down}"
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        process.arguments = ["-e", script]
        let errPipe = Pipe()
        process.standardError = errPipe
        do {
            try process.run()
            process.waitUntilExit()
            if process.terminationStatus == 0 {
                return .success
            }
            let errData = errPipe.fileHandleForReading.readDataToEndOfFile()
            let errText = String(data: errData, encoding: .utf8) ?? ""
            return .failure("锁屏失败（退出码 \(process.terminationStatus)）：\(errText)")
        } catch {
            return .failure("无法执行 osascript：\(error.localizedDescription)")
        }
    }

    /// 息屏：执行 `pmset displaysleepnow`（兜底用）。
    ///
    /// - Returns: 执行结果
    @discardableResult
    static func lockNow() -> Result {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/pmset")
        process.arguments = ["displaysleepnow"]
        do {
            try process.run()
            process.waitUntilExit()
            if process.terminationStatus == 0 {
                return .success
            }
            return .failure("pmset 退出码 \(process.terminationStatus)")
        } catch {
            return .failure("无法执行 pmset：\(error.localizedDescription)")
        }
    }
}
