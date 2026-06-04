package com.nearlock.beacon.ble

import java.util.UUID

/**
 * BLE 广播状态，驱动 UI 显示与服务行为。
 */
sealed interface AdvertiseState {

    /** 未广播（初始或已手动停止）。 */
    data object Idle : AdvertiseState

    /** 正在广播，携带当前 deviceId 供 UI 展示。 */
    data class Advertising(val deviceId: UUID) : AdvertiseState

    /** 设备不支持 BLE 广播（硬件或系统限制）。 */
    data object Unsupported : AdvertiseState

    /** 缺少必要权限。 */
    data object PermissionDenied : AdvertiseState

    /** 蓝牙未开启。 */
    data object BluetoothOff : AdvertiseState

    /** 启动失败，携带可读错误信息。 */
    data class Error(val message: String) : AdvertiseState
}
