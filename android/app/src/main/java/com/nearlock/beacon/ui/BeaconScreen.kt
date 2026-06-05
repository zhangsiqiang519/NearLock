package com.nearlock.beacon.ui

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.lazy.grid.GridCells
import androidx.compose.foundation.lazy.grid.LazyVerticalGrid
import androidx.compose.foundation.lazy.grid.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Settings
import androidx.compose.material3.Button
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Surface
import androidx.compose.material3.Switch
import androidx.compose.material3.Text
import androidx.compose.material3.rememberModalBottomSheetState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import com.nearlock.beacon.ble.AdvertiseState

/**
 * Beacon 主屏幕：顶部 App 标识 + 状态卡片 + 设备 ID，
 * 右上角齿轮按钮弹出设置底部弹窗（开启/停止广播、开机自启）。
 */
@OptIn(ExperimentalMaterial3Api::class)
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
    var showSheet by remember { mutableStateOf(false) }
    val sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true)

    Column(
        modifier = Modifier
            .fillMaxSize()
            .padding(20.dp),
        verticalArrangement = Arrangement.spacedBy(16.dp)
    ) {
        // 顶部：App 标识 + 设置按钮
        Row(
            modifier = Modifier.fillMaxWidth(),
            verticalAlignment = Alignment.CenterVertically
        ) {
            Column(Modifier.weight(1f)) {
                Text(
                    text = "NearLock Beacon",
                    style = MaterialTheme.typography.headlineMedium,
                    fontWeight = FontWeight.Bold
                )
                Text(
                    text = "让这台 Android 手机持续广播短 ID，供 Mac 端识别离座距离。",
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant
                )
            }
            IconButton(onClick = { showSheet = true }) {
                Icon(Icons.Default.Settings, contentDescription = "设置")
            }
        }

        StatusCard(state)
        DeviceIdCard(deviceId)
    }

    // 设置底部弹窗：广播操作 + 开机自启
    if (showSheet) {
        ModalBottomSheet(
            onDismissRequest = { showSheet = false },
            sheetState = sheetState
        ) {
            Column(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(horizontal = 20.dp)
                    .padding(bottom = 32.dp),
                verticalArrangement = Arrangement.spacedBy(12.dp)
            ) {
                Text(
                    text = "设置",
                    style = MaterialTheme.typography.titleLarge,
                    fontWeight = FontWeight.Bold
                )

                // 广播操作按钮
                when {
                    state is AdvertiseState.PermissionDenied -> {
                        Button(
                            onClick = { onOpenSettings(); showSheet = false },
                            modifier = Modifier.fillMaxWidth()
                        ) { Text("去设置授予蓝牙权限") }
                    }
                    state is AdvertiseState.Advertising -> {
                        OutlinedButton(
                            onClick = { onStop(); showSheet = false },
                            modifier = Modifier.fillMaxWidth()
                        ) { Text("停止广播") }
                    }
                    else -> {
                        Button(
                            onClick = { onStart(); showSheet = false },
                            modifier = Modifier.fillMaxWidth()
                        ) { Text("开启广播") }
                    }
                }

                AutoStartRow(enabled = autoStartEnabled, onChange = onAutoStartChange)
            }
        }
    }
}

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
        modifier = Modifier
            .fillMaxWidth()
            .height(160.dp),
        shape = RoundedCornerShape(16.dp),
        colors = CardDefaults.cardColors(containerColor = tint.copy(alpha = 0.14f))
    ) {
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(20.dp),
            verticalArrangement = Arrangement.SpaceBetween
        ) {
            Text(
                text = label,
                style = MaterialTheme.typography.headlineSmall,
                color = tint,
                fontWeight = FontWeight.Bold
            )
            if (detail != null) {
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
        shape = RoundedCornerShape(16.dp)
    ) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(16.dp),
            verticalArrangement = Arrangement.spacedBy(12.dp)
        ) {
            Text(
                text = "本机短 ID",
                style = MaterialTheme.typography.labelMedium,
                color = MaterialTheme.colorScheme.onSurfaceVariant
            )
            Text(
                text = deviceId ?: "生成中…",
                style = MaterialTheme.typography.bodyLarge,
                fontFamily = FontFamily.Monospace,
                fontWeight = FontWeight.Bold
            )
            // 4 宫格：每 4 位一格，与 macOS 端扫描列表对照
            if (deviceId != null) {
                val chunks = deviceId.chunked(4)
                LazyVerticalGrid(
                    columns = GridCells.Fixed(4),
                    modifier = Modifier
                        .fillMaxWidth()
                        .height(52.dp),
                    contentPadding = PaddingValues(0.dp),
                    horizontalArrangement = Arrangement.spacedBy(6.dp),
                    verticalArrangement = Arrangement.spacedBy(6.dp),
                    userScrollEnabled = false
                ) {
                    items(chunks) { chunk ->
                        Surface(
                            shape = RoundedCornerShape(8.dp),
                            color = MaterialTheme.colorScheme.primaryContainer,
                            modifier = Modifier.height(40.dp)
                        ) {
                            Row(
                                modifier = Modifier.fillMaxSize(),
                                horizontalArrangement = Arrangement.Center,
                                verticalAlignment = Alignment.CenterVertically
                            ) {
                                Text(
                                    text = chunk,
                                    style = MaterialTheme.typography.labelSmall,
                                    fontFamily = FontFamily.Monospace,
                                    fontWeight = FontWeight.Bold,
                                    color = MaterialTheme.colorScheme.onPrimaryContainer
                                )
                            }
                        }
                    }
                }
            }
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
