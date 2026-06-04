# NearLock 双端共享约定

macOS 端与 Android 端必须保持一致的常量与协议约定都记录在此。任何一端改动都要同步更新另一端代码与本文件。

## 固定 Service UUID

Android 端通过 `BluetoothLeAdvertiser` 广播、macOS 端通过 `CoreBluetooth` 扫描时，使用同一个固定的 Service UUID 作为 NearLock 信标的识别标志。

```
Service UUID: 0000FEAA-0000-1000-8000-00805F9B34FB
```

> 说明：上面是占位 UUID（沿用 Eddystone 的 0xFEAA 便于调试），正式开发时可替换为项目自有的随机 UUID，替换后两端必须同时更新。

### 各端取值位置

| 端 | 文件 | 常量名 |
| --- | --- | --- |
| macOS | `macos/`（待实现） | `nearLockServiceUUID` |
| Android | `android/`（待实现） | `NEARLOCK_SERVICE_UUID` |

## deviceId 约定

- Android 端首次启动生成唯一 `deviceId`，通过 DataStore 持久化。
- `deviceId` 随广播数据一并发出，供 macOS 端识别并绑定特定设备。
- 格式：UUID v4 字符串。

## RSSI 与触发逻辑默认值

| 参数 | 默认值 | 说明 |
| --- | --- | --- |
| RSSI 阈值 | `-85 dBm` | 低于该值视为「远离」 |
| 触发时间 | `15 秒` | RSSI 连续低于阈值达到该时长才触发锁屏 |
