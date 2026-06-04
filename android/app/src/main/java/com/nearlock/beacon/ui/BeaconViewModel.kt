package com.nearlock.beacon.ui

import android.app.Application
import androidx.lifecycle.AndroidViewModel
import androidx.lifecycle.viewModelScope
import com.nearlock.beacon.ble.AdvertiseController
import com.nearlock.beacon.ble.AdvertiseState
import com.nearlock.beacon.ble.NearLockProtocol
import com.nearlock.beacon.data.DeviceIdStore
import com.nearlock.beacon.service.AdvertiseService
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.stateIn
import kotlinx.coroutines.launch

/**
 * 主界面 ViewModel：暴露广播状态与 deviceId，转发启停广播操作到前台服务。
 */
class BeaconViewModel(application: Application) : AndroidViewModel(application) {

    private val deviceIdStore = DeviceIdStore(application)

    /** 广播状态，直接复用服务更新的共享状态。 */
    val advertiseState: StateFlow<AdvertiseState> = AdvertiseController.state
        .stateIn(viewModelScope, SharingStarted.Eagerly, AdvertiseState.Idle)

    private val _deviceId = MutableStateFlow<String?>(null)

    /** 本机 deviceId 的短 ID 展示（与 macOS 端绑定列表显示一致的 16 位 hex）。 */
    val deviceId: StateFlow<String?> = _deviceId.asStateFlow()

    init {
        viewModelScope.launch {
            val uuid = deviceIdStore.getOrCreateDeviceId()
            _deviceId.value = NearLockProtocol.shortIdHex(uuid)
        }
    }

    /** 开启广播（启动前台服务）。 */
    fun startAdvertising() {
        AdvertiseService.start(getApplication())
    }

    /** 停止广播（停止前台服务）。 */
    fun stopAdvertising() {
        AdvertiseService.stop(getApplication())
    }
}
