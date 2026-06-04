# NearLock 双端离座自动锁屏工具

## Goal

解决用户离开工位忘记锁屏的安全隐患。Android 手机作为 BLE Beacon 持续广播一个固定
Service UUID，macOS 端扫描该 UUID、绑定用户手机并持续读取 RSSI 信号强度；当 RSSI
连续 N 秒低于用户设定阈值（说明用户带手机离开 Mac），macOS 自动息屏并立即要求密码，
从而实现"人走屏锁"。

## Requirements

### macOS 菜单栏 App（Swift / SwiftUI / MenuBarExtra / CoreBluetooth / UserDefaults）

1. 菜单栏常驻（MenuBarExtra，无主窗口 Dock 图标）
2. 扫描 NearLock Beacon（CBCentralManager 扫描固定 Service UUID）
3. 显示发现的 Android 设备列表（deviceId + 实时 RSSI）
4. 支持绑定一个 Android 设备（持久化绑定的 deviceId）
5. 显示当前绑定设备的实时 RSSI
6. 设置 RSSI 阈值，默认 -85 dBm（可调范围 -100 ~ -40）
7. 设置触发时间，默认 15 秒（可调范围 5 ~ 120 秒）
8. 手机远离后自动息屏 + 立即要求密码（详见技术决策）
9. 支持暂停保护 10 / 30 / 60 分钟（暂停期间不触发锁屏）
10. 显示最近事件日志（扫描启停、绑定、触发锁屏、暂停等，内存环形缓冲）

### Android Beacon App（Kotlin / Jetpack Compose / BluetoothLeAdvertiser / 前台服务 / DataStore）

1. 首次启动请求蓝牙相关权限（Android 12+ 运行时 BLUETOOTH_ADVERTISE/CONNECT）
2. 生成唯一 deviceId（首次启动生成并持久化到 DataStore）
3. 点击按钮开启 BLE 广播
4. 使用固定 Service UUID（与 macOS 端约定一致）
5. 前台服务保持广播（带常驻通知，进入后台/锁屏后不中断）
6. 显示当前广播状态（广播中 / 已停止 / 不支持 / 权限缺失）
7. 支持停止广播

## Acceptance Criteria

- [ ] Android App 可在 Android Studio 构建出 APK 并安装运行
- [ ] Android 首启正确申请权限，拒绝时给出可读提示，不崩溃
- [ ] Android 点击开启后通过 `BluetoothLeAdvertiser` 广播固定 Service UUID + deviceId，前台通知常驻
- [ ] macOS App 可在 Xcode 构建运行，菜单栏出现 NearLock 图标
- [ ] macOS 扫描能发现正在广播的 Android 设备，列表展示 deviceId 与实时刷新的 RSSI
- [ ] 绑定设备后，菜单栏显示该设备实时 RSSI 数值
- [ ] 当绑定设备 RSSI 连续 ≥ N 秒低于阈值时，触发息屏 + 立即要密码
- [ ] 手机靠近（RSSI 回升过阈值）后，触发计时器重置，不会误锁
- [ ] 暂停保护期间不触发锁屏，到期后自动恢复
- [ ] 阈值、触发时间、绑定设备、暂停状态在 App 重启后保持（UserDefaults / DataStore）

## Definition of Done

- 两端工程均能在各自 IDE（Xcode / Android Studio）独立构建
- 纯逻辑单元可测部分有单元测试（RSSI 去抖判定、触发状态机、deviceId 编解码）
- 关键 BLE 路径有联调步骤文档（需两台真实设备，CI/模拟器无法覆盖，需显式说明）
- README 说明构建、运行、配对联调步骤
- Info.plist / AndroidManifest 权限声明完整且有 usage description

## Technical Approach

### BLE 协议约定（双端共享契约）

- **固定 Service UUID**：`A1B2C3D4-0000-1000-8000-00805F9B34FB`（NearLock 专用，双端硬编码常量）
- **deviceId 传输**：Android 在广播包的 **Service Data** 字段携带 16 字节 deviceId
  （UUID 去横线的字节数组）。macOS 从 `CBAdvertisementDataServiceDataKey` 解析，
  无需建立 GATT 连接。
- **不建立连接**：macOS 仅做被动扫描（scan-only），RSSI 直接取自 `didDiscover` 回调，
  避免连接开销与配对弹窗。
- **持续 RSSI**：macOS 扫描开启 `CBCentralManagerScanOptionAllowDuplicatesKey = true`，
  以便重复收到同一设备的广播、持续刷新 RSSI。

### macOS 触发逻辑

- RSSI 原始值抖动大，采用**滑动平均**（窗口 ~5 个样本）平滑。
- 状态机：`平滑 RSSI < 阈值` → 启动"远离计时器"；`平滑 RSSI ≥ 阈值` → 重置计时器。
  计时器累计 ≥ N 秒 → 触发锁屏。
- **丢失广播**视为远离信号（一段时间收不到绑定设备的广播，按低于阈值处理）。
- **锁屏方式（已决策）**：息屏 + 立即要求密码。
  - 息屏：执行 `pmset displaysleepnow`（或等价的 IOKit 调用）。
  - 立即要密码：依赖系统"进入睡眠或开始屏幕保护程序后立即要求密码"设置；
    App 在事件日志与首次引导中提示用户开启该系统设置。
  - 备选实现：`Quartz` 的 `CGSession` 不作为 MVP 默认，仅在 research 文档记录。

### Android 广播逻辑

- `BluetoothLeAdvertiser.startAdvertising`，`AdvertiseSettings` 用低延迟/可连接=false。
- `AdvertiseData` 加入 `ParcelUuid(固定 UUID)` + `addServiceData(uuid, deviceIdBytes)`。
- 广播置于**前台服务**中，带常驻通知，确保锁屏/后台不被系统杀死。
- deviceId：首启用 `UUID.randomUUID()` 生成，存 DataStore，后续复用。

### 暂停保护

- macOS 端记录 `pauseUntil` 时间戳（UserDefaults）。当前时间 < pauseUntil 时，
  状态机短路，不触发锁屏，菜单栏显示剩余暂停时间。

## Decision (ADR-lite)

**Context**: 需要确定流程模式、锁屏机制、工程脚手架三个关键方向。

**Decision**（用户已确认，全部取推荐项）：
1. **流程**：Trellis 结构化 —— 建任务 → PRD 锁定架构 → 按 Android→macOS→锁屏 顺序实现，全程 .trellis 跟踪并做质检。
2. **锁屏机制**：息屏（`pmset displaysleepnow`）+ 依赖系统"立即要密码"。最稳，不依赖私有 API 或特殊权限。
3. **工程格式**：完整可构建工程 —— macOS 用 Xcode 工程（.xcodeproj），Android 用 Gradle 工程（含 wrapper），开箱即可在 IDE 构建。

**Consequences**:
- 优点：方案稳健、无私有 API 依赖、开箱可构建、流程可追溯。
- 代价：BLE 端到端验证需两台真实设备，本环境无法自动化跑通，需人工联调。
- 风险：`pmset` 息屏的"锁屏强度"取决于用户系统设置（是否开启立即要密码），需引导用户配置。

## Out of Scope

- iOS 端 Beacon（仅 Android 作为 Beacon）
- 多设备同时绑定（MVP 仅绑定一台）
- 自动重连 / 配对加密 / GATT 服务（MVP 仅广播+扫描，不建连）
- 靠近自动解锁（macOS 不支持第三方编程解锁，安全模型限制，明确不做）
- 云同步 / 账户体系 / 多 Mac 协同
- App 上架签名公证流程（仅保证本地可构建运行）

## Technical Notes

- macOS CoreBluetooth 扫描需 `NSBluetoothAlwaysUsageDescription`（Info.plist）。
- macOS App 需 Bluetooth entitlement（沙箱开启时 `com.apple.security.device.bluetooth`）。
- Android 12+ (API 31+) 蓝牙广播需运行时权限 `BLUETOOTH_ADVERTISE`；低版本用
  `BLUETOOTH` + `BLUETOOTH_ADMIN`。前台服务（含蓝牙）在 Android 14 需
  `FOREGROUND_SERVICE_CONNECTED_DEVICE` 与对应 `foregroundServiceType`。
- 详细技术调研与取舍见 `research/` 下文档。

## Research References

- [`research/ble-protocol.md`](research/ble-protocol.md) — 双端 BLE 广播/扫描协议与 deviceId 编码取舍
- [`research/macos-lock-mechanism.md`](research/macos-lock-mechanism.md) — macOS 息屏/锁屏各方案对比与选型
- [`research/android-advertise-permissions.md`](research/android-advertise-permissions.md) — Android 各版本广播权限与前台服务要求
