package com.nearlock.beacon.ui

import android.Manifest
import android.os.Build
import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.result.contract.ActivityResultContracts
import androidx.activity.viewModels
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import androidx.compose.foundation.layout.fillMaxSize

/**
 * 应用入口：首次启动申请蓝牙相关权限，挂载 Compose 界面。
 *
 * 权限策略（见 research/android-advertise-permissions.md）：
 * - Android 12+：运行时申请 BLUETOOTH_ADVERTISE、BLUETOOTH_CONNECT。
 * - Android 13+：额外申请 POST_NOTIFICATIONS（前台服务通知需展示）。
 */
class MainActivity : ComponentActivity() {

    private val viewModel: BeaconViewModel by viewModels()

    private val permissionLauncher = registerForActivityResult(
        ActivityResultContracts.RequestMultiplePermissions()
    ) { /* 结果反映在 advertiseState：无权限时开启广播会回 PermissionDenied */ }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        requestRequiredPermissions()

        setContent {
            MaterialTheme {
                Surface(modifier = Modifier.fillMaxSize()) {
                    val state by viewModel.advertiseState.collectAsState()
                    val deviceId by viewModel.deviceId.collectAsState()
                    BeaconScreen(
                        state = state,
                        deviceId = deviceId,
                        onStart = viewModel::startAdvertising,
                        onStop = viewModel::stopAdvertising
                    )
                }
            }
        }
    }

    private fun requestRequiredPermissions() {
        val permissions = mutableListOf<String>()
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            permissions += Manifest.permission.BLUETOOTH_ADVERTISE
            permissions += Manifest.permission.BLUETOOTH_CONNECT
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            permissions += Manifest.permission.POST_NOTIFICATIONS
        }
        if (permissions.isNotEmpty()) {
            permissionLauncher.launch(permissions.toTypedArray())
        }
    }
}
