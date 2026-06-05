# Android 广播权限与前台服务要求

## 权限矩阵（按 API 版本）

| 能力 | API ≤ 30 | API 31 (Android 12) | API 33+ | API 34 (Android 14) |
|------|----------|---------------------|---------|---------------------|
| BLE 广播 | `BLUETOOTH` + `BLUETOOTH_ADMIN`（普通权限，安装即授予） | `BLUETOOTH_ADVERTISE`（运行时申请） | 同 31 | 同 31 |
| 蓝牙连接（如需读 adapter） | 隐含 | `BLUETOOTH_CONNECT`（运行时） | 同 | 同 |
| 前台服务 | `FOREGROUND_SERVICE` | 同 | 同 | + `FOREGROUND_SERVICE_CONNECTED_DEVICE` |

注意：BLE **广播（advertise）** 不需要定位权限（`ACCESS_FINE_LOCATION`），
那是 **扫描（scan）** 才在部分版本需要。本 App 只广播，无需定位权限。

## Manifest 声明

```xml
<uses-permission android:name="android.permission.BLUETOOTH"
    android:maxSdkVersion="30" />
<uses-permission android:name="android.permission.BLUETOOTH_ADMIN"
    android:maxSdkVersion="30" />
<uses-permission android:name="android.permission.BLUETOOTH_ADVERTISE" />
<uses-permission android:name="android.permission.BLUETOOTH_CONNECT" />
<uses-permission android:name="android.permission.FOREGROUND_SERVICE" />
<uses-permission android:name="android.permission.FOREGROUND_SERVICE_CONNECTED_DEVICE" />
<uses-permission android:name="android.permission.POST_NOTIFICATIONS" />

<uses-feature android:name="android.hardware.bluetooth_le" android:required="true" />
```

前台服务声明：

```xml
<service
    android:name=".service.AdvertiseService"
    android:foregroundServiceType="connectedDevice"
    android:exported="false" />
```

## 运行时权限申请

API 31+ 需在首启申请：`BLUETOOTH_ADVERTISE`、`BLUETOOTH_CONNECT`。
API 33+ 通知需 `POST_NOTIFICATIONS`（前台服务通知要显示）。
用 `rememberLauncherForActivityResult(RequestMultiplePermissions)` 一次性申请。

## 前台服务保活要点

- `startForeground(id, notification)` 必须在 `onStartCommand` 中尽快调用，
  Android 12+ 有 5 秒限制，否则 ANR/崩溃。
- 通知渠道（NotificationChannel）需在启动服务前创建。
- Android 14：`startForeground` 第三参数需传 `foregroundServiceType`，
  且 Manifest 的 type 要匹配（`connectedDevice`）。

## BluetoothLeAdvertiser 关键代码骨架

```kotlin
val settings = AdvertiseSettings.Builder()
    .setAdvertiseMode(AdvertiseSettings.ADVERTISE_MODE_LOW_LATENCY)
    .setConnectable(false)
    .setTimeout(0)
    .build()

val data = AdvertiseData.Builder()
    .setIncludeDeviceName(false)
    .addServiceData(ParcelUuid(SERVICE_UUID), deviceIdBytes) // 16B
    .build()

advertiser.startAdvertising(settings, data, advertiseCallback)
```

## 设备能力检查

- `bluetoothAdapter.isMultipleAdvertisementSupported`：部分老设备不支持广播，
  UI 状态需展示"设备不支持 BLE 广播"。
- `bluetoothAdapter.bluetoothLeAdvertiser` 为 null 时同上。
