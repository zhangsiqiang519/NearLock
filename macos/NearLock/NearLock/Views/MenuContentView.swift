import SwiftUI

/// 菜单栏弹出内容：状态总览、设备列表/绑定、阈值与时间设置、暂停、事件日志。
struct MenuContentView: View {

    @EnvironmentObject var settings: SettingsStore
    @EnvironmentObject var scanner: BluetoothScanner
    @EnvironmentObject var eventLog: EventLog
    @EnvironmentObject var monitor: ProximityMonitor

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header

            Divider()

            if !scanner.isReady {
                bluetoothOffNotice
            } else if let boundId = settings.boundDeviceId {
                boundDeviceSection(boundId: boundId)
            } else {
                discoverySection
            }

            Divider()

            settingsSection

            Divider()

            pauseSection

            Divider()

            EventLogView()

            Divider()

            HStack {
                Spacer()
                Button("退出 NearLock") {
                    NSApplication.shared.terminate(nil)
                }
                .buttonStyle(.borderless)
                .foregroundStyle(.secondary)
            }
        }
        .padding(16)
        .frame(width: 320)
    }

    private var header: some View {
        HStack {
            Image(systemName: "lock.shield")
                .font(.title2)
                .foregroundStyle(.tint)
            VStack(alignment: .leading, spacing: 2) {
                Text("NearLock")
                    .font(.headline)
                Text(statusText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
    }

    private var statusText: String {
        if settings.isPaused {
            return "已暂停保护"
        }
        if settings.boundDeviceId == nil {
            return "未绑定设备"
        }
        return scanner.isScanning ? "保护中" : "等待蓝牙"
    }

    private var bluetoothOffNotice: some View {
        Label("蓝牙未开启或无权限，请在系统设置中检查", systemImage: "exclamationmark.triangle")
            .font(.callout)
            .foregroundStyle(.orange)
    }
}

// MARK: - 设备发现与绑定

extension MenuContentView {

    /// 未绑定时：展示扫描到的设备列表，点击绑定。
    var discoverySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("发现的设备")
                .font(.subheadline.bold())

            let sorted = scanner.devices.values.sorted { $0.rssi > $1.rssi }
            if sorted.isEmpty {
                Text("正在扫描 NearLock 信标…")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(sorted) { device in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(device.shortId)
                                .font(.system(.body, design: .monospaced))
                            Text("\(device.rssi) dBm")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button("绑定") {
                            settings.bind(deviceId: device.id)
                            monitor.resetForRebind()
                            eventLog.log("已绑定设备 \(device.shortId)")
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                    }
                }
            }
        }
    }

    /// 已绑定时：展示绑定设备的实时 RSSI、触发进度与解绑。
    func boundDeviceSection(boundId: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("已绑定设备")
                    .font(.subheadline.bold())
                Spacer()
                Button("解绑") {
                    settings.unbind()
                    monitor.resetForRebind()
                    eventLog.log("已解绑设备")
                }
                .buttonStyle(.borderless)
                .controlSize(.small)
                .foregroundStyle(.red)
            }

            Text(boundId)
                .font(.system(.body, design: .monospaced))

            HStack(spacing: 16) {
                rssiBadge
                triggerProgress
            }
        }
    }

    private var rssiBadge: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("当前 RSSI")
                .font(.caption2)
                .foregroundStyle(.secondary)
            if let rssi = monitor.smoothedRSSI {
                Text("\(rssi) dBm")
                    .font(.title3.monospacedDigit())
                    .foregroundStyle(rssi < settings.rssiThreshold ? .orange : .green)
            } else {
                Text("--")
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var triggerProgress: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("离开计时")
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text("\(monitor.belowSeconds) / \(settings.triggerSeconds) 秒")
                .font(.title3.monospacedDigit())
                .foregroundStyle(monitor.belowSeconds > 0 ? .orange : .secondary)
        }
    }
}

// MARK: - 设置与暂停

extension MenuContentView {

    /// RSSI 阈值与触发时间设置。
    var settingsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("保护设置")
                .font(.subheadline.bold())

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("RSSI 阈值")
                        .font(.caption)
                    Spacer()
                    Text("\(settings.rssiThreshold) dBm")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
                Slider(
                    value: Binding(
                        get: { Double(settings.rssiThreshold) },
                        set: { settings.rssiThreshold = Int($0) }
                    ),
                    in: -100...(-40),
                    step: 1
                )
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("触发时间")
                        .font(.caption)
                    Spacer()
                    Text("\(settings.triggerSeconds) 秒")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
                Slider(
                    value: Binding(
                        get: { Double(settings.triggerSeconds) },
                        set: { settings.triggerSeconds = Int($0) }
                    ),
                    in: 5...120,
                    step: 1
                )
            }
        }
    }

    /// 暂停保护区：10/30/60 分钟暂停，或恢复。
    var pauseSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("暂停保护")
                    .font(.subheadline.bold())
                Spacer()
                if settings.isPaused, let until = settings.pauseUntil {
                    Text("至 \(timeString(until))")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.orange)
                }
            }

            if settings.isPaused {
                Button("立即恢复保护") {
                    settings.resume()
                    eventLog.log("已恢复保护")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            } else {
                HStack(spacing: 8) {
                    ForEach([10, 30, 60], id: \.self) { minutes in
                        Button("\(minutes) 分钟") {
                            settings.pause(minutes: minutes)
                            eventLog.log("已暂停保护 \(minutes) 分钟")
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                }
            }
        }
    }

    private func timeString(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }
}

// MARK: - 事件日志

/// 事件日志列表视图（展示最近若干条）。
struct EventLogView: View {

    @EnvironmentObject var eventLog: EventLog

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("最近事件")
                .font(.subheadline.bold())

            if eventLog.entries.isEmpty {
                Text("暂无事件")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(eventLog.entries.prefix(8)) { entry in
                            HStack(alignment: .top, spacing: 6) {
                                Text(entry.timeText)
                                    .font(.caption2.monospacedDigit())
                                    .foregroundStyle(.secondary)
                                Text(entry.message)
                                    .font(.caption2)
                                Spacer()
                            }
                        }
                    }
                }
                .frame(maxHeight: 120)
            }
        }
    }
}

