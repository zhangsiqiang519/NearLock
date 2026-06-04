package com.nearlock.beacon.data

import android.content.Context
import androidx.datastore.core.DataStore
import androidx.datastore.preferences.core.Preferences
import androidx.datastore.preferences.core.edit
import androidx.datastore.preferences.core.stringPreferencesKey
import androidx.datastore.preferences.preferencesDataStore
import kotlinx.coroutines.flow.first
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
