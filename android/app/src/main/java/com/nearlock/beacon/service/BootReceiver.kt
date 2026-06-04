package com.nearlock.beacon.service

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import com.nearlock.beacon.ble.BleAdvertiser
import com.nearlock.beacon.data.BeaconPreferences
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.launch

/**
 * 开机自启接收器：设备启动完成后，按用户偏好自动恢复 BLE 广播。
 *
 * 仅当满足全部条件时才自动启动广播服务：
 * - 用户开启了"开机自启"开关；
 * - 上次确实在广播（避免用户主动停止后还自动恢复）；
 * - 当前具备广播权限（Android 12+ 重启后权限仍在，但仍做一次校验）。
 *
 * 这样可避免静默自启超出用户预期。
 */
class BootReceiver : BroadcastReceiver() {

    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != Intent.ACTION_BOOT_COMPLETED) return

        val appContext = context.applicationContext
        val preferences = BeaconPreferences(appContext)
        // goAsync 让 BroadcastReceiver 在协程读取 DataStore 期间保持存活
        val pendingResult = goAsync()
        val scope = CoroutineScope(SupervisorJob() + Dispatchers.Default)
        scope.launch {
            try {
                val shouldStart = preferences.isAutoStartEnabled() &&
                    preferences.wasAdvertising() &&
                    BleAdvertiser(appContext).hasAdvertisePermission()
                if (shouldStart) {
                    AdvertiseService.start(appContext)
                }
            } finally {
                pendingResult.finish()
            }
        }
    }
}
