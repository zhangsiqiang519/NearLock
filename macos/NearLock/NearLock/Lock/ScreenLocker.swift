import Foundation

/// 屏幕锁定执行器。
///
/// MVP 方案（见 research/macos-lock-mechanism.md）：执行 `pmset displaysleepnow` 息屏，
/// 配合系统"屏幕关闭后立即要求密码"设置达到锁屏效果。
/// 不使用私有 API，不依赖特殊权限（但需 App 未开启 Sandbox 以允许 Process 执行）。
enum ScreenLocker {

    /// 锁屏结果。
    enum Result {
        case success
        case failure(String)
    }

    /// 执行息屏。
    ///
    /// - Returns: 执行结果（成功或带错误信息的失败）
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
