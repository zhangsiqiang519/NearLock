# Journal - zhangsiqiang (Part 1)

> AI development session journal
> Started: 2026-06-04

---



## Session 1: NearLock MVP 双端实现：Android BLE Beacon + macOS 扫描/RSSI/自动锁屏

**Date**: 2026-06-04
**Task**: NearLock MVP 双端实现：Android BLE Beacon + macOS 扫描/RSSI/自动锁屏
**Branch**: `main`

### Summary

完成 NearLock 双端 MVP。Android(Kotlin/Compose/BluetoothLeAdvertiser/前台服务/DataStore) 广播固定 Service UUID+deviceId；macOS(Swift/SwiftUI/MenuBarExtra/CoreBluetooth) 扫描解析、RSSI 滑动平均去抖、连续N秒低于阈值触发 pmset 息屏锁屏。macOS 经 Xcode 26.5 真实构建 BUILD SUCCEEDED；触发状态机与双端 deviceId 往返一致性经 swift 脚本验证通过。Android 因本机无 JDK/Gradle 未构建。

### Main Changes

(Add details)

### Git Commits

(No commits - planning session)

### Testing

- [OK] (Add test results)

### Status

[OK] **Completed**

### Next Steps

- None - task complete


## Session 2: NearLock code review 修复：P0 广播包字节预算 + 双端 deviceId 短 ID 统一

**Date**: 2026-06-04
**Task**: NearLock code review 修复：P0 广播包字节预算 + 双端 deviceId 短 ID 统一
**Branch**: `main`

### Summary

Code review 发现并修复 P0-1：Android 广播用 16B deviceId 致 ServiceData 34B 超 31B 预算，startAdvertising 必失败。改为 8 字节短 ID（UUID 高 64 位），双端统一 16 位小写 hex。撤回了 review 初版误报的 P0-2（withServices:nil 在 macOS 桌面 App 无后台扫描限制，原方案正确，改反而会弄坏）。同步更新 Android 单测、ble-protocol.md 文档、双端 UI 展示。验证：macOS clean build SUCCEEDED 无警告；脚本验证双端短 ID hex 一致(1234567890abcdef)且广播包 29≤31 字节；绑定-扫描-监控全链路 deviceId 同源自洽。

### Main Changes

(Add details)

### Git Commits

(No commits - planning session)

### Testing

- [OK] (Add test results)

### Status

[OK] **Completed**

### Next Steps

- None - task complete


## Session 3: macOS 新增保护总开关与手动立即锁屏

**Date**: 2026-06-04
**Task**: macOS 新增保护总开关与手动立即锁屏
**Branch**: `main`

### Summary

应用户'锁屏和不锁屏'需求。SettingsStore 加 protectionEnabled(默认true,UserDefaults持久化,向后兼容)；ProximityMonitor 增加保护开关短路闸(与 isPaused 并列)；MenuContentView 顶部加保护开关 Toggle + 立即锁屏按钮(直调 ScreenLocker 不受冷却限制)；statusText 与菜单栏图标加保护关闭分支(lock.slash,优先级最高)。macOS BUILD SUCCEEDED,已重启运行 PID 8960。README 同步。

### Main Changes

(Add details)

### Git Commits

(No commits - planning session)

### Testing

- [OK] (Add test results)

### Status

[OK] **Completed**

### Next Steps

- None - task complete


## Session 4: 修复立即锁屏失效 + 安卓权限引导与开机自启

**Date**: 2026-06-04
**Task**: 修复立即锁屏失效 + 安卓权限引导与开机自启
**Branch**: `main`

### Summary

锁屏修复:实测用户机 screenLock delay=300s 致纯息屏锁不住，ScreenLocker 改为 osascript 发 Ctrl+Cmd+Q 真正锁屏(lock()统一入口，失败降级 pmset 息屏)，自动+手动两处调用切换。安卓:新增 BeaconPreferences(autoStart/wasAdvertising)、BootReceiver 监听 BOOT_COMPLETED 按开关恢复广播、权限拒绝时 BeaconScreen 引导跳设置、开机自启开关 UI。双端构建通过(macOS BUILD SUCCEEDED / Android BUILD SUCCESSFUL 16MB APK)。Review:开机自启受国产 ROM 自启策略限制(已 UI 提示)；osascript 锁屏首次需辅助功能授权。

### Main Changes

(Add details)

### Git Commits

(No commits - planning session)

### Testing

- [OK] (Add test results)

### Status

[OK] **Completed**

### Next Steps

- None - task complete
