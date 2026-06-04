package com.nearlock.beacon.data

import android.content.Context
import androidx.datastore.core.DataStore
import androidx.datastore.preferences.core.Preferences
import androidx.datastore.preferences.core.booleanPreferencesKey
import androidx.datastore.preferences.core.edit
import androidx.datastore.preferences.core.stringPreferencesKey
import androidx.datastore.preferences.preferencesDataStore
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.flow.map
import java.util.UUID

private val Context.dataStore: DataStore<Preferences> by preferencesDataStore(name = "nearlock_prefs")

/**
 * 设备身份持久化：首次启动生成 deviceId 并存入 DataStore，后续复用同一 ID。
 *
 * deviceId 是 macOS 端绑定与识别本机信标的唯一依据，因此必须稳定不变。
 */
class DeviceIdStore(private val context: Context) {

    private val deviceIdKey = stringPreferencesKey("device_id")

    /**
     * 获取本机 deviceId，不存在则生成并持久化。
     *
     * @return 稳定的设备唯一标识
     */
    suspend fun getOrCreateDeviceId(): UUID {
        val prefs = context.dataStore.data.first()
        val existing = prefs[deviceIdKey]
        if (existing != null) {
            return UUID.fromString(existing)
        }
        val created = UUID.randomUUID()
        context.dataStore.edit { it[deviceIdKey] = created.toString() }
        return created
    }
}

/**
 * 广播运行偏好持久化：开机自启开关 + 上次是否在广播。
 *
 * 用于 BootReceiver 在开机后判断是否需要自动恢复广播：
 * 仅当"开机自启开启"且"上次确实在广播"时才自动启动，避免静默自启超出用户预期。
 */
class BeaconPreferences(private val context: Context) {

    private val autoStartKey = booleanPreferencesKey("auto_start_enabled")
    private val wasAdvertisingKey = booleanPreferencesKey("was_advertising")

    /** 开机自启开关（默认关闭，尊重用户预期）。 */
    val autoStartEnabled: Flow<Boolean> =
        context.dataStore.data.map { it[autoStartKey] ?: false }

    /** 设置开机自启开关。 */
    suspend fun setAutoStart(enabled: Boolean) {
        context.dataStore.edit { it[autoStartKey] = enabled }
    }

    /** 记录"当前是否在广播"，供开机后恢复判断。 */
    suspend fun setWasAdvertising(value: Boolean) {
        context.dataStore.edit { it[wasAdvertisingKey] = value }
    }

    /** 同步读取一次：开机自启是否开启。 */
    suspend fun isAutoStartEnabled(): Boolean =
        context.dataStore.data.first()[autoStartKey] ?: false

    /** 同步读取一次：上次是否在广播。 */
    suspend fun wasAdvertising(): Boolean =
        context.dataStore.data.first()[wasAdvertisingKey] ?: false
}
