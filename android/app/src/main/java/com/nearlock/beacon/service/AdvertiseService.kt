package com.nearlock.beacon.service

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.IBinder
import androidx.core.app.NotificationCompat
import com.nearlock.beacon.R
import com.nearlock.beacon.ble.AdvertiseController
import com.nearlock.beacon.ble.AdvertiseState
import com.nearlock.beacon.ble.BleAdvertiser
import com.nearlock.beacon.data.DeviceIdStore
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.launch

/**
 * 前台服务：在后台持续保持 BLE 广播。
 *
 * 关键约束（见 research/android-advertise-permissions.md）：
 * - startForeground 必须在 onStartCommand 中尽快调用（Android 12+ 有 5 秒限制）。
 * - 通知渠道需在 startForeground 前创建。
 * - Android 14+ 需传 foregroundServiceType，且与 Manifest 的 connectedDevice 匹配。
 */
class AdvertiseService : Service() {

    private val advertiser by lazy { BleAdvertiser(applicationContext) }
    private val deviceIdStore by lazy { DeviceIdStore(applicationContext) }
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Main)

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_STOP -> {
                stopAdvertisingAndSelf()
                return START_NOT_STICKY
            }
            else -> startAdvertising()
        }
        return START_STICKY
    }

    private fun startAdvertising() {
        // 先进入前台，满足系统时限要求
        startForegroundCompat()

        scope.launch {
            val deviceId = deviceIdStore.getOrCreateDeviceId()
            advertiser.start(deviceId) { state ->
                AdvertiseController.update(state)
                // 广播失败时退出前台服务，避免无意义占用通知栏
                if (state is AdvertiseState.Error ||
                    state is AdvertiseState.Unsupported ||
                    state is AdvertiseState.PermissionDenied ||
                    state is AdvertiseState.BluetoothOff
                ) {
                    stopAdvertisingAndSelf()
                }
            }
        }
    }

    private fun stopAdvertisingAndSelf() {
        advertiser.stop()
        AdvertiseController.update(AdvertiseState.Idle)
        stopForeground(STOP_FOREGROUND_REMOVE)
        stopSelf()
    }

    private fun startForegroundCompat() {
        createChannel()
        val notification = buildNotification()
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            startForeground(
                NOTIFICATION_ID,
                notification,
                ServiceInfo.FOREGROUND_SERVICE_TYPE_CONNECTED_DEVICE
            )
        } else {
            startForeground(NOTIFICATION_ID, notification)
        }
    }

    private fun buildNotification(): Notification {
        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle(getString(R.string.notification_title))
            .setContentText(getString(R.string.notification_text))
            .setSmallIcon(R.drawable.ic_launcher_foreground)
            .setOngoing(true)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .build()
    }

    private fun createChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            if (manager.getNotificationChannel(CHANNEL_ID) == null) {
                val channel = NotificationChannel(
                    CHANNEL_ID,
                    getString(R.string.notification_channel_name),
                    NotificationManager.IMPORTANCE_LOW
                ).apply {
                    description = getString(R.string.notification_channel_desc)
                }
                manager.createNotificationChannel(channel)
            }
        }
    }

    override fun onDestroy() {
        advertiser.stop()
        scope.cancel()
        super.onDestroy()
    }

    override fun onBind(intent: Intent?): IBinder? = null

    companion object {
        private const val CHANNEL_ID = "nearlock_advertise"
        private const val NOTIFICATION_ID = 1001
        const val ACTION_STOP = "com.nearlock.beacon.action.STOP"

        /** 启动广播服务。 */
        fun start(context: Context) {
            val intent = Intent(context, AdvertiseService::class.java)
            context.startForegroundService(intent)
        }

        /** 停止广播服务。 */
        fun stop(context: Context) {
            val intent = Intent(context, AdvertiseService::class.java).apply {
                action = ACTION_STOP
            }
            context.startService(intent)
        }
    }
}
