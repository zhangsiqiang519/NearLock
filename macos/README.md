# macOS 端（NearLock 菜单栏 App）

Swift / SwiftUI 实现的 macOS 菜单栏应用。

## 技术栈

- Swift
- SwiftUI + MenuBarExtra（菜单栏常驻）
- CoreBluetooth（BLE 扫描、读取 RSSI）
- UserDefaults（配置持久化）

## 职责

1. 菜单栏常驻入口
2. 扫描 NearLock Beacon（固定 Service UUID，见 `../shared/service-uuid.md`）
3. 显示发现的 Android 设备并支持绑定一个设备
4. 显示当前 RSSI
5. 设置 RSSI 阈值（默认 -85 dBm）与触发时间（默认 15 秒）
6. RSSI 连续低于阈值达触发时间后自动锁屏
7. 暂停保护 10 / 30 / 60 分钟
8. 显示最近事件日志

## 待实现

工程文件（`.xcodeproj` / SwiftUI 源码）将在 macOS 扫描阶段创建。
