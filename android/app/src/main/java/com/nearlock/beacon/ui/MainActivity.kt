package com.nearlock.beacon.ui

import android.Manifest
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.provider.Settings
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
                    val autoStart by viewModel.autoStartEnabled.collectAsState()
                    BeaconScreen(
                        state = state,
                        deviceId = deviceId,
                        autoStartEnabled = autoStart,
                        onStart = viewModel::startAdvertising,
                        onStop = viewModel::stopAdvertising,
                        onAutoStartChange = viewModel::setAutoStart,
                        onOpenSettings = ::openAppSettings
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

    /** 跳转到本应用的系统设置详情页，便于用户手动授予权限。 */
    private fun openAppSettings() {
        val intent = Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
            data = Uri.fromParts("package", packageName, null)
        }
        startActivity(intent)
    }
}
