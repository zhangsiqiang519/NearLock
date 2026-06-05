# NearLock

> 用 Android 手机作为 BLE 信标，离开 Mac 时自动锁屏。

![Platform](https://img.shields.io/badge/platform-macOS%2013%2B-lightgrey)
![Platform](https://img.shields.io/badge/platform-Android%208%2B-green)
![Release](https://img.shields.io/github/v/release/zhangsiqiang519/NearLock)

---

## 工作原理

手机持续广播低功耗蓝牙（BLE）信标，Mac 端扫描信号强度（RSSI）。当你带着手机离开工位，信号持续低于阈值超过设定时间后，Mac 自动锁屏。回来后手动解锁，无需任何额外操作。

```
Android (BLE 广播)  ──── RSSI ────▶  macOS (扫描 + 锁屏)
    手机放口袋              信号减弱              自动息屏
```

## 下载

前往 [Releases](https://github.com/zhangsiqiang519/NearLock/releases) 下载最新版本：

| 平台 | 文件 | 说明 |
|------|------|------|
| macOS | `NearLock-macOS.dmg` | 拖入 Applications 即用，macOS 13+ |
| Android | `NearLock-Android.apk` | 侧载安装，Android 8+ |

## 功能

- 📡 **BLE 自动检测** — 信号连续低于阈值后触发锁屏，含冷却保护避免反复触发
- 📏 **距离估算** — RSSI 实时换算为距离（基于实测数据校准），默认阈值约 5m
- ⏸ **暂停保护** — 支持 10 / 30 / 60 分钟定时暂停
- 🔒 **立即锁屏** — 手动一键锁屏
- 🚀 **开机自启** — macOS / Android 均支持
- 📋 **事件日志** — 记录绑定、锁屏、暂停等操作

## 快速上手

**1. Android 端**

安装 APK → 授予蓝牙权限 → 点击「开启广播」，前台通知常驻表示广播中。

**2. macOS 端**

安装 DMG → 菜单栏出现锁形图标 → 首次运行授予蓝牙权限 → 在「设备」区找到你的手机 → 点击「绑定」。

**3. 调整阈值**

点击菜单栏图标右上角齿轮 → 设置页拖动「RSSI 阈值」滑块，右侧实时显示对应距离。

> **锁屏生效前提**：系统设置 → 锁定屏幕 → 屏幕关闭后要求密码 → 选择「立即」

## 从源码构建

**macOS**（需要 Xcode 15+）

```bash
cd macos/NearLock
xcodebuild -scheme NearLock -configuration Debug build
```

**Android**（需要 JDK 17 + Android Studio）

```bash
cd android
./gradlew assembleDebug
# 产物：app/build/outputs/apk/debug/app-debug.apk
```

## 技术栈

**macOS** — Swift · SwiftUI · CoreBluetooth · MenuBarExtra · SMAppService

**Android** — Kotlin · Jetpack Compose · BluetoothLeAdvertiser · Foreground Service

## 已知限制

- BLE 广播需要 Android 真机，模拟器不支持
- RSSI 距离估算受环境干扰影响，室内误差约 ±30%
- macOS 执行的是息屏（`pmset displaysleepnow`），锁屏效果依赖系统密码设置

## 开发约定

代码注释、Commit Message 均使用中文，详见 [CONTRIBUTING.md](./CONTRIBUTING.md)。

## 致谢

本项目开发过程中使用 **claude-opus-4-8** 模型辅助编码，API 中转服务由 [Unity2.ai](https://unity2.ai/home) 提供，感谢其稳定的服务支持。

## 鸣谢

- [Anthropic](https://www.anthropic.com) — Claude claude-opus-4-8 模型
- [Unity2.ai](https://unity2.ai/home) — API 中转服务
- [Apple CoreBluetooth](https://developer.apple.com/documentation/corebluetooth) — macOS BLE 扫描
- [Android BluetoothLeAdvertiser](https://developer.android.com/reference/android/bluetooth/le/BluetoothLeAdvertiser) — Android BLE 广播

## License

MIT
