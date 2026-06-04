package com.nearlock.beacon.ble

import android.Manifest
import android.annotation.SuppressLint
import android.bluetooth.BluetoothAdapter
import android.bluetooth.BluetoothManager
import android.bluetooth.le.AdvertiseCallback
import android.bluetooth.le.AdvertiseData
import android.bluetooth.le.AdvertiseSettings
import android.bluetooth.le.BluetoothLeAdvertiser
import android.content.Context
import android.content.pm.PackageManager
import android.os.Build
import androidx.core.content.ContextCompat
import java.util.UUID

/**
 * 封装 BluetoothLeAdvertiser，负责开始/停止广播并上报状态。
 *
 * 广播内容遵循 [NearLockProtocol]：固定 Service UUID + 16 字节 deviceId 放入 Service Data。
 * 设置为不可连接（setConnectable(false)），macOS 端仅被动扫描读取 RSSI，不建立连接。
 */
class BleAdvertiser(private val context: Context) {

    private val bluetoothAdapter: BluetoothAdapter? by lazy {
        val manager = context.getSystemService(Context.BLUETOOTH_SERVICE) as? BluetoothManager
        manager?.adapter
    }

    private var advertiser: BluetoothLeAdvertiser? = null
    private var activeCallback: AdvertiseCallback? = null

    /**
     * 开始广播指定 deviceId。
     *
     * @param deviceId 本机唯一标识
     * @param onStateChange 状态回调（成功/失败/不支持等）
     */
    @SuppressLint("MissingPermission")
    fun start(deviceId: UUID, onStateChange: (AdvertiseState) -> Unit) {
        if (!hasAdvertisePermission()) {
            onStateChange(AdvertiseState.PermissionDenied)
            return
        }

        val adapter = bluetoothAdapter
        if (adapter == null || !adapter.isEnabled) {
            onStateChange(AdvertiseState.BluetoothOff)
            return
        }

        if (!adapter.isMultipleAdvertisementSupported) {
            onStateChange(AdvertiseState.Unsupported)
            return
        }

        val leAdvertiser = adapter.bluetoothLeAdvertiser
        if (leAdvertiser == null) {
            onStateChange(AdvertiseState.Unsupported)
            return
        }

        // 已在广播则先停止，避免重复回调
        stop()

        val settings = AdvertiseSettings.Builder()
            .setAdvertiseMode(AdvertiseSettings.ADVERTISE_MODE_LOW_LATENCY)
            .setTxPowerLevel(AdvertiseSettings.ADVERTISE_TX_POWER_HIGH)
            .setConnectable(false)
            .setTimeout(0)
            .build()

        // 仅放 ServiceData（含 deviceId），不单独放 ServiceUuid 以控制在 31 字节预算内
        val data = AdvertiseData.Builder()
            .setIncludeDeviceName(false)
            .setIncludeTxPowerLevel(false)
            .addServiceData(
                NearLockProtocol.SERVICE_PARCEL_UUID,
                NearLockProtocol.encodeDeviceId(deviceId)
            )
            .build()

        val callback = object : AdvertiseCallback() {
            override fun onStartSuccess(settingsInEffect: AdvertiseSettings) {
                onStateChange(AdvertiseState.Advertising(deviceId))
            }

            override fun onStartFailure(errorCode: Int) {
                onStateChange(AdvertiseState.Error(describeError(errorCode)))
            }
        }

        activeCallback = callback
        advertiser = leAdvertiser
        leAdvertiser.startAdvertising(settings, data, callback)
    }

    /**
     * 停止广播。幂等：未广播时调用无副作用。
     */
    @SuppressLint("MissingPermission")
    fun stop() {
        val current = activeCallback
        val adv = advertiser
        if (current != null && adv != null && hasAdvertisePermission()) {
            adv.stopAdvertising(current)
        }
        activeCallback = null
        advertiser = null
    }

    /**
     * 检查是否具备广播所需权限。
     *
     * Android 12+ 需 BLUETOOTH_ADVERTISE；低版本 BLUETOOTH/ADMIN 为安装期权限，恒为 true。
     */
    fun hasAdvertisePermission(): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            ContextCompat.checkSelfPermission(
                context,
                Manifest.permission.BLUETOOTH_ADVERTISE
            ) == PackageManager.PERMISSION_GRANTED
        } else {
            true
        }
    }

    private fun describeError(errorCode: Int): String = when (errorCode) {
        AdvertiseCallback.ADVERTISE_FAILED_DATA_TOO_LARGE -> "广播数据超出长度限制"
        AdvertiseCallback.ADVERTISE_FAILED_TOO_MANY_ADVERTISERS -> "广播器数量已达上限"
        AdvertiseCallback.ADVERTISE_FAILED_ALREADY_STARTED -> "广播已在运行"
        AdvertiseCallback.ADVERTISE_FAILED_INTERNAL_ERROR -> "蓝牙内部错误"
        AdvertiseCallback.ADVERTISE_FAILED_FEATURE_UNSUPPORTED -> "设备不支持广播"
        else -> "未知广播错误（代码 $errorCode）"
    }
}
