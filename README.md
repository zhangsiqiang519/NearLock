# NearLock

NearLock 是一个 macOS + Android 组合工具，用于解决「人离开工位却忘记锁屏」的问题。

Android 手机作为蓝牙信标（Beacon）持续广播，macOS 端扫描该信标并读取信号强度（RSSI）。当你带着手机离开 Mac、信号持续减弱到设定阈值以下时，macOS 自动锁屏，避免工位无人值守时屏幕长时间敞开。

## 工作原理

```
┌─────────────────┐         BLE 广播          ┌──────────────────┐
│  Android Beacon │  ───── Service UUID ────▶ │  macOS 菜单栏 App │
│   (Kotlin)      │                           │     (Swift)      │
└─────────────────┘                           └──────────────────┘
        │                                              │
   固定 UUID 广播                              扫描 / 读取 RSSI
   前台服务常驻                                RSSI 连续 N 秒 < 阈值
                                                      │
                                                      ▼
                                               自动锁屏 / 息屏
```

1. Android 端安装 NearLock Beacon App，通过 `BluetoothLeAdvertiser` 广播一个固定的 Service UUID。
2. macOS 端通过 `CoreBluetooth` 扫描该 UUID，绑定用户的 Android 手机，并持续读取 RSSI 信号强度。
3. 当 RSSI **连续 N 秒**低于用户设置的阈值时，判定为「用户带着手机离开了 Mac」，macOS 自动执行锁屏。

## 技术栈

### macOS 端

| 技术 | 用途 |
| --- | --- |
| Swift | 开发语言 |
| SwiftUI | 界面 |
| MenuBarExtra | 菜单栏常驻入口 |
| CoreBluetooth | BLE 扫描与 RSSI 读取 |
| UserDefaults | 配置持久化 |

### Android 端

| 技术 | 用途 |
| --- | --- |
| Kotlin | 开发语言 |
| Jetpack Compose | 界面 |
| BluetoothLeAdvertiser | BLE 广播 |
| Foreground Service | 保持广播常驻 |
| DataStore | 配置持久化 |

## 目录结构

```
NearLock/
├── macos/              # macOS 菜单栏 App（Swift / SwiftUI）
├── android/            # Android Beacon App（Kotlin / Compose）
├── shared/             # 双端共享约定（固定 Service UUID 等）
├── docs/               # 项目文档
├── .trellis/           # Trellis 工作流与编码规范
├── CONTRIBUTING.md     # 开发规则（提交规范、语言规范）
└── README.md
```

## MVP 功能

### macOS 端

1. 菜单栏常驻
2. 扫描 NearLock Beacon
3. 显示发现的 Android 设备
4. 支持绑定一个 Android 设备
5. 显示当前 RSSI
6. 设置 RSSI 阈值，默认 `-85 dBm`
7. 设置触发时间，默认 `15 秒`
8. 手机远离后自动锁屏
9. 支持暂停保护 10 / 30 / 60 分钟
10. 显示最近事件日志

### Android 端

1. 首次启动请求蓝牙相关权限
2. 生成唯一 `deviceId`
3. 点击按钮开启 BLE 广播
4. 使用固定 Service UUID
5. 前台服务保持广播
6. 显示当前广播状态
7. 支持停止广播

## 开发约定

- 所有沟通、文档、代码注释、Git Commit Message 均使用**中文**。
- **每次逻辑改动完成后都要进行一次代码提交**，保持提交历史清晰、每个 commit 自洽。

详见 [CONTRIBUTING.md](./CONTRIBUTING.md)。

## 开发路线

- [ ] 搭建项目结构（当前）
- [ ] Android BLE Beacon 广播
- [ ] macOS 扫描与 RSSI 显示
- [ ] macOS 自动锁屏逻辑
