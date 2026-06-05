# 修复立即锁屏失效并完善安卓权限与开机自启

## Goal

解决一个真实体验缺陷 + 补两个安卓侧实用能力：
1. **macOS 立即锁屏真正锁住**：当前只 `pmset` 息屏，依赖系统"立即要求密码"。
   实测用户机器 `screenLock delay = 300 秒`，息屏后 5 分钟内晃鼠标即回桌面，等于没锁。
   改为发送系统锁屏（Ctrl+Cmd+Q），直接锁到登录界面，不受宽限期影响。
2. **Android 权限引导**：蓝牙/通知权限未授予时，UI 明确提示并提供跳转系统设置入口。
3. **Android 开机自启**：监听 BOOT_COMPLETED，开机后自动恢复广播（可由用户开关控制）。

## Requirements

### macOS 立即锁屏修复

1. `ScreenLocker` 增加真正锁屏方法：用 `osascript` 触发系统锁屏快捷键 Ctrl+Cmd+Q。
2. 立即锁屏与自动锁屏都改为"先尝试系统锁屏，再息屏"，保证真正锁定。
3. 首次锁屏若因缺少辅助功能(Accessibility)权限失败，事件日志给出可读提示。

### Android 权限引导

4. 启动检查蓝牙广播权限(BLUETOOTH_ADVERTISE)、通知权限状态。
5. 权限缺失时，UI 显示提示卡片 + "去设置"按钮，跳转到应用详情页。
6. AdvertiseState 已有 PermissionDenied 分支，UI 据此渲染引导。

### Android 开机自启

7. 新增 `BootReceiver` 监听 `BOOT_COMPLETED`。
8. DataStore 持久化"开机自启"开关与"上次是否在广播"状态。
9. 开机后若开关开启且上次在广播，自动启动 AdvertiseService。
10. UI 增加"开机自启"开关。
11. Manifest 声明 RECEIVE_BOOT_COMPLETED 权限与 receiver。

## Acceptance Criteria

- [ ] macOS 点击"立即锁屏"直接锁到登录界面（需输密码解锁），不受 300 秒宽限影响
- [ ] 自动检测离开触发时也真正锁定
- [ ] 缺辅助功能权限时事件日志提示用户去授权
- [ ] Android 权限未授予时显示引导卡片与跳转设置按钮
- [ ] Android 开启"开机自启"后，重启手机自动恢复广播
- [ ] 关闭"开机自启"后重启不自动广播
- [ ] 双端构建通过（xcodebuild / gradlew assembleDebug）

## Definition of Done

- macOS BUILD SUCCEEDED；Android BUILD SUCCESSFUL 出 APK
- 锁屏行为在用户机器实测真正锁定（用户验证）
- README 同步辅助功能权限说明、开机自启说明

## Technical Approach

### macOS 锁屏（核心修复）

当前系统（Darwin 25）已移除 `CGSession`。可用方案对比：
- **osascript 模拟 Ctrl+Cmd+Q**（选用）：公开、稳定，直接锁到登录窗口。
  代价：触发辅助功能权限，首次需用户在"系统设置→隐私与安全性→辅助功能"授权。
- `pmset displaysleepnow`（保留作兜底）：仅息屏，受 screenLock delay 影响。

实现：
```swift
// ScreenLocker 新增
static func lockScreen() -> Result {
    let script = "tell application \"System Events\" to key code 12 using {control down, command down}"
    // key code 12 = Q
    ...运行 osascript...
}
```
立即锁屏与自动锁屏统一调用：先 `lockScreen()`（真正锁定），失败再 `lockNow()`（息屏兜底）。

### Android 权限引导

- MainActivity / BeaconScreen 在 `AdvertiseState.PermissionDenied` 或启动前检查时，
  渲染提示卡片 + Button 调 `Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS)` 跳转。

### Android 开机自启

- `BootReceiver : BroadcastReceiver`，`onReceive` 收到 BOOT_COMPLETED 后读 DataStore，
  若 autoStart 且 wasAdvertising，则 `AdvertiseService.start(context)`。
- DataStore 加 `autoStartEnabled`、`wasAdvertising` 两个布尔键。
- 广播启停时更新 wasAdvertising。
- Manifest：`<uses-permission RECEIVE_BOOT_COMPLETED />` +
  `<receiver BootReceiver exported=true intent-filter BOOT_COMPLETED />`。

## Decision (ADR-lite)

**Context**: 立即锁屏在用户机器无效（screenLock delay 300s）；用户要安卓权限引导与开机自启。
**Decision**:
1. 锁屏改用 osascript 系统锁屏快捷键（真正锁定），pmset 息屏降级为兜底。接受"首次需授权辅助功能"的代价，换取真正锁屏。
2. 开机自启用 BOOT_COMPLETED + DataStore 状态，由用户开关控制，默认关闭（尊重用户预期，避免静默自启）。
**Consequences**:
- 锁屏真正可用，不再依赖用户改系统宽限设置；但需引导一次辅助功能授权。
- 开机自启提升常驻体验；默认关闭避免意外。

## Out of Scope

- macOS 开机自启（本任务只做 Android 自启；macOS 自启另议）
- 私有 API 锁屏（SACLockScreenImmediate，签名风险，不用）
- 全局快捷键

## Technical Notes

- osascript 锁屏需辅助功能权限：`AXIsProcessTrusted()` 可检测，未授权时引导。
- Android BOOT_COMPLETED 需 RECEIVE_BOOT_COMPLETED 权限，且部分厂商 ROM(MIUI/EMUI)
  需用户在系统里额外允许"自启动"，README 需注明。
- 涉及文件：macOS `Lock/ScreenLocker.swift`、`Lock/ProximityMonitor.swift`、
  `Views/MenuContentView.swift`；Android `service/BootReceiver.kt`、`data/`、
  `ui/`、`AndroidManifest.xml`。
