# BLE 协议设计：双端广播/扫描契约

## 决策摘要

- 固定 Service UUID：`A1B2C3D4-0000-1000-8000-00805F9B34FB`，双端硬编码常量。
- deviceId 放在广播包 **Service Data** 字段，**8 字节短 ID**（取 UUID 高 64 位）。
- macOS 仅被动扫描（scan-only），不建立 GATT 连接。
- 扫描开 `allowDuplicates`，持续刷新 RSSI。
- 双端统一用 **16 位小写 hex** 字符串表示短 ID，用于展示与绑定比对。

## 为什么用 Service Data 携带 deviceId

Android `BluetoothLeAdvertiser` 的广播包（31 字节 legacy）空间有限。可选载体：

| 载体 | 容量 | 取舍 |
|------|------|------|
| Service UUID | 固定 16B | 用于设备发现过滤，所有 NearLock 设备相同，不能区分个体 |
| Service Data | UUID + payload | **选用**：同一 UUID 下携带 deviceId payload，macOS 易解析 |
| Manufacturer Data | 2B 厂商 ID + payload | 需要厂商 ID，对自用工具无意义，且与系统约定冲突风险 |
| Device Name | 受限 | 占空间大，部分系统不在广播中带 name |

deviceId 用 8 字节短 ID（UUID 高 64 位）。广播包 31 字节预算核算：
- flags：3 字节
- Service Data：`长度1 + 类型1 + 128bit UUID 16 + payload 8` = 26 字节
- 合计 29 字节 ≤ 31，可放入。

**为何不用完整 16 字节 UUID**：若 payload 用 16 字节，Service Data 达 `2+16+16=34`，
单项即超 31 字节预算，`startAdvertising` 会以 `ADVERTISE_FAILED_DATA_TOO_LARGE` 失败。
8 字节（64 bit）随机空间对"单用户绑定一台手机"场景碰撞概率可忽略。

实现采用：`AdvertiseData` 只放 `addServiceData(ParcelUuid, 8B)` +
`setIncludeDeviceName(false)` + `setIncludeTxPowerLevel(false)`，扫描端用 ServiceData
的 key UUID 做匹配。

## macOS 扫描要点

```swift
centralManager.scanForPeripherals(
    withServices: [CBUUID(string: NearLockProtocol.serviceUUID)],
    options: [CBCentralManagerScanOptionAllowDuplicatesKey: true]
)
```

- `didDiscover peripheral, advertisementData, rssi`：
  - RSSI 直接取 `rssi.intValue`（NSNumber）。
  - deviceId 从 `advertisementData[CBAdvertisementDataServiceDataKey]`
    （`[CBUUID: Data]`）取出对应 UUID 的 Data，转成 hex / UUID 字符串。
- 注意：`withServices` 过滤要求广播里有该 Service UUID。若 Android 端为省字节
  只放 ServiceData，需在扫描时传 `withServices: nil` 后自行在回调里按 ServiceData
  的 key 过滤。MVP 采用 `withServices: nil` + 回调内过滤，兼容性最好。

## deviceId 编解码

- Android：`UUID.randomUUID()` 取高 64 位 → `ByteBuffer.putLong(msb)` 得 8 字节大端。
- Android：`shortIdHex()` 将 8 字节转 16 位小写 hex 字符串用于展示。
- macOS：`Data` 8 字节 → 逐字节 `%02x` 拼成同样的 16 位小写 hex。
- 绑定：macOS 持久化绑定的短 ID hex 字符串；扫描回调里 `shortIdHex == boundId` 才更新 RSSI。
- 双端对同一 8 字节得到完全相同的 hex（已用脚本验证），是绑定识别的基础。

## 边界与失败处理

- 收不到广播：macOS 维护"最后一次见到绑定设备的时间"，超过 ~3 秒未刷新视为信号丢失，
  按"低于阈值"喂给触发状态机（人走出范围时广播直接消失，不是 RSSI 缓慢下降）。
- 蓝牙关闭/无权限：`centralManagerDidUpdateState` 非 `.poweredOn` 时停止扫描并在 UI 提示。
