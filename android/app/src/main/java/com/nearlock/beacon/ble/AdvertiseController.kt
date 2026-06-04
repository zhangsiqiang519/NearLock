package com.nearlock.beacon.ble

import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow

/**
 * 进程内共享的广播状态持有器。
 *
 * 前台服务 [com.nearlock.beacon.service.AdvertiseService] 实际持有 BLE 资源并更新此状态，
 * UI 层（ViewModel / Compose）观察此 StateFlow 展示广播状态。
 * 用单例桥接是因为前台服务与 Activity 生命周期独立，需要一个稳定的共享通道。
 */
object AdvertiseController {

    private val _state = MutableStateFlow<AdvertiseState>(AdvertiseState.Idle)

    /** 当前广播状态，UI 观察此 Flow。 */
    val state: StateFlow<AdvertiseState> = _state.asStateFlow()

    /** 由服务更新状态。 */
    fun update(newState: AdvertiseState) {
        _state.value = newState
    }

    /** 是否正在广播。 */
    fun isAdvertising(): Boolean = _state.value is AdvertiseState.Advertising
}
