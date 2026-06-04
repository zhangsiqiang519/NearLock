# Android 端（NearLock Beacon App）

Kotlin / Jetpack Compose 实现的 Android 蓝牙信标应用。

## 技术栈

- Kotlin
- Jetpack Compose（界面）
- BluetoothLeAdvertiser（BLE 广播）
- Foreground Service（保持广播常驻）
- DataStore（配置持久化）

## 职责

1. 首次启动请求蓝牙相关权限
2. 生成唯一 deviceId（见 `../shared/service-uuid.md`）
3. 点击按钮开启 / 停止 BLE 广播
4. 使用固定 Service UUID 广播
5. 前台服务保持广播
6. 显示当前广播状态

## 待实现

Gradle 工程将在 Android BLE Beacon 阶段创建（第一个实现阶段）。
