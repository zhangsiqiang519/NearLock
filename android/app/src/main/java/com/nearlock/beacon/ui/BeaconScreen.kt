package com.nearlock.beacon.ui

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Button
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Switch
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.State
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import com.nearlock.beacon.ble.AdvertiseState

/**
 * Beacon 主屏幕：展示广播状态、deviceId，并提供开启/停止广播按钮。
 *
 * @param state 当前广播状态
 * @param deviceId 本机设备标识
 * @param onStart 开启广播回调
 * @param onStop 停止广播回调
 */
@Composable
fun BeaconScreen(
    state: AdvertiseState,
    deviceId: String?,
    autoStartEnabled: Boolean,
    onStart: () -> Unit,
    onStop: () -> Unit,
    onAutoStartChange: (Boolean) -> Unit,
    onOpenSettings: () -> Unit
) {
    Column(
        modifier = Modifier
            .fillMaxSize()
            .padding(24.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.Center
    ) {
        Text(
            text = "NearLock Beacon",
            style = MaterialTheme.typography.headlineMedium,
            fontWeight = FontWeight.Bold
        )
        Spacer(Modifier.height(8.dp))
        Text(
            text = "把这台手机作为信标，离开电脑时自动锁屏",
            style = MaterialTheme.typography.bodyMedium,
            color = MaterialTheme.colorScheme.onSurfaceVariant
        )

        Spacer(Modifier.height(32.dp))

        StatusCard(state)

        Spacer(Modifier.height(16.dp))

        DeviceIdCard(deviceId)

        Spacer(Modifier.height(24.dp))

        val isAdvertising = state is AdvertiseState.Advertising
        when {
            // 权限缺失：引导用户去系统设置授权
            state is AdvertiseState.PermissionDenied -> {
                Button(
                    onClick = onOpenSettings,
                    modifier = Modifier.fillMaxWidth()
                ) {
                    Text("去设置授予蓝牙权限")
                }
            }
            isAdvertising -> {
                OutlinedButton(
                    onClick = onStop,
                    modifier = Modifier.fillMaxWidth()
                ) {
                    Text("停止广播")
                }
            }
            else -> {
                Button(
                    onClick = onStart,
                    modifier = Modifier.fillMaxWidth()
                ) {
                    Text("开启广播")
                }
            }
        }

        Spacer(Modifier.height(16.dp))

        AutoStartRow(enabled = autoStartEnabled, onChange = onAutoStartChange)
    }
}

/**
 * 开机自启开关行。
 */
@Composable
private fun AutoStartRow(enabled: Boolean, onChange: (Boolean) -> Unit) {
    Card(
        modifier = Modifier.fillMaxWidth(),
        shape = RoundedCornerShape(12.dp)
    ) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(16.dp),
            verticalAlignment = Alignment.CenterVertically
        ) {
            Column(Modifier.weight(1f)) {
                Text(
                    text = "开机自启",
                    style = MaterialTheme.typography.titleSmall,
                    fontWeight = FontWeight.SemiBold
                )
                Text(
                    text = "重启后自动恢复广播（部分机型需在系统设置允许自启动）",
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant
                )
            }
            Switch(checked = enabled, onCheckedChange = onChange)
        }
    }
}

@Composable
private fun StatusCard(state: AdvertiseState) {
    val (label, detail, tint) = state.describe()
    Card(
        modifier = Modifier.fillMaxWidth(),
        shape = RoundedCornerShape(12.dp),
        colors = CardDefaults.cardColors(containerColor = tint.copy(alpha = 0.12f))
    ) {
        Column(Modifier.padding(16.dp)) {
            Text(
                text = label,
                style = MaterialTheme.typography.titleMedium,
                color = tint,
                fontWeight = FontWeight.SemiBold
            )
            if (detail != null) {
                Spacer(Modifier.height(4.dp))
                Text(
                    text = detail,
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant
                )
            }
        }
    }
}

@Composable
private fun DeviceIdCard(deviceId: String?) {
    Card(
        modifier = Modifier.fillMaxWidth(),
        shape = RoundedCornerShape(12.dp)
    ) {
        Column(Modifier.padding(16.dp)) {
            Text(
                text = "设备 ID",
                style = MaterialTheme.typography.labelMedium,
                color = MaterialTheme.colorScheme.onSurfaceVariant
            )
            Spacer(Modifier.height(4.dp))
            Text(
                text = deviceId ?: "生成中…",
                style = MaterialTheme.typography.bodyMedium,
                fontFamily = FontFamily.Monospace
            )
        }
    }
}

/**
 * 将广播状态映射为 (标题, 详情, 颜色) 三元组用于展示。
 */
private fun AdvertiseState.describe(): Triple<String, String?, Color> = when (this) {
    is AdvertiseState.Idle ->
        Triple("已停止", "点击下方按钮开始广播", Color(0xFF6B7280))
    is AdvertiseState.Advertising ->
        Triple("广播中", "Mac 现在可以发现这台手机", Color(0xFF16A34A))
    is AdvertiseState.Unsupported ->
        Triple("设备不支持", "此设备不支持 BLE 广播，无法作为信标", Color(0xFFDC2626))
    is AdvertiseState.PermissionDenied ->
        Triple("缺少权限", "请在系统设置中授予蓝牙权限后重试", Color(0xFFDC2626))
    is AdvertiseState.BluetoothOff ->
        Triple("蓝牙未开启", "请先打开系统蓝牙", Color(0xFFD97706))
    is AdvertiseState.Error ->
        Triple("启动失败", message, Color(0xFFDC2626))
}
