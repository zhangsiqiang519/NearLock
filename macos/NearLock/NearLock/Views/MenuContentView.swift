import SwiftUI
import ServiceManagement

/// 菜单栏弹出面板（单窗口内页面切换，避免 .sheet 抢焦点导致面板关闭）。
///
/// 主页：header + 设备区
/// 设置页：控制区、阈值、暂停、事件日志、开机自启、退出
struct MenuContentView: View {

    @EnvironmentObject var settings: SettingsStore
    @EnvironmentObject var scanner: BluetoothScanner
    @EnvironmentObject var eventLog: EventLog
    @EnvironmentObject var monitor: ProximityMonitor

    @State private var showSettings = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Divider().padding(.horizontal, 14)
            if showSettings {
                settingsPage
            } else {
                devicePage
            }
        }
        .frame(width: 320)
    }

    // MARK: - Header（两页通用）

    private var header: some View {
        HStack(spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.accentColor.gradient)
                    .frame(width: 38, height: 38)
                Image(systemName: "lock.shield.fill")
                    .font(.system(size: 18))
                    .foregroundStyle(.white)
            }
            VStack(alignment: .leading, spacing: 1) {
                Text("NearLock").font(.headline)
                Text(statusText).font(.caption).foregroundStyle(statusColor)
            }
            Spacer()
            Image(systemName: menuBarIcon)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(statusColor)
                .frame(width: 28, height: 28)
                .background(statusColor.opacity(0.1), in: RoundedRectangle(cornerRadius: 7))
            // 设置 / 返回 按钮
            Button {
                showSettings.toggle()
            } label: {
                Image(systemName: showSettings ? "chevron.left" : "gearshape")
                    .font(.system(size: 14, weight: .medium))
                    .frame(width: 28, height: 28)
            }
            .buttonStyle(.borderless)
            .background(Color.secondary.opacity(0.1), in: RoundedRectangle(cornerRadius: 7))
            .help(showSettings ? "返回" : "设置")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
    }

    // MARK: - 主页：设备区

    private var devicePage: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("设备").font(.caption.weight(.medium)).foregroundStyle(.secondary)
                Spacer()
                Text(settings.boundDeviceId == nil ? "扫描中" : "已绑定")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(settings.boundDeviceId == nil ? .orange : .green)
            }
            if !scanner.isReady {
                Label("蓝牙未开启或无权限", systemImage: "exclamationmark.triangle")
                    .font(.callout).foregroundStyle(.orange)
                    .padding(10).frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.orange.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
            } else if let boundId = settings.boundDeviceId {
                boundDeviceSection(boundId: boundId)
            } else {
                discoverySection
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    // MARK: - 设置页

    private var settingsPage: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                // 控制区
                block {
                    VStack(alignment: .leading, spacing: 10) {
                        row("控制区", "保护策略")
                        Toggle(isOn: Binding(
                            get: { settings.protectionEnabled },
                            set: { v in
                                settings.protectionEnabled = v
                                eventLog.log(v ? "已启用自动锁屏保护" : "已关闭自动锁屏保护")
                            }
                        )) {
                            VStack(alignment: .leading, spacing: 1) {
                                Text("自动锁屏保护").font(.subheadline.bold())
                                Text(settings.protectionEnabled ? "BLE 离开阈值触发后自动锁屏" : "关闭时不会自动锁屏")
                                    .font(.caption2).foregroundStyle(.secondary)
                            }
                        }
                        .toggleStyle(.switch)
                        Button {
                            switch ScreenLocker.lock() {
                            case .success: eventLog.log("手动立即锁屏")
                            case .failure(let r): eventLog.log("手动锁屏失败：\(r)")
                            }
                        } label: {
                            Label("立即锁屏", systemImage: "lock.fill").frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent).controlSize(.large)
                    }
                }
                Divider().padding(.horizontal, 14)

                // 阈值设置
                block {
                    VStack(alignment: .leading, spacing: 10) {
                        row("阈值设置", "实时生效")
                        sliderRow(
                            label: "RSSI 阈值",
                            valueText: "\(settings.rssiThreshold) dBm  ≈ \(MenuContentView.rssiToMeters(settings.rssiThreshold))",
                            value: Binding(get: { Double(settings.rssiThreshold) }, set: { settings.rssiThreshold = Int($0) }),
                            range: -100...(-40)
                        )
                        sliderRow(
                            label: "触发时间",
                            valueText: "\(settings.triggerSeconds) 秒",
                            value: Binding(get: { Double(settings.triggerSeconds) }, set: { settings.triggerSeconds = Int($0) }),
                            range: 5...120
                        )
                    }
                }
                Divider().padding(.horizontal, 14)

                // 暂停保护
                block {
                    VStack(alignment: .leading, spacing: 8) {
                        row("暂停保护", settings.isPaused ? pauseUntilText : "")
                        if settings.isPaused {
                            Button("立即恢复保护") { settings.resume(); eventLog.log("已恢复保护") }
                                .buttonStyle(.bordered).controlSize(.small)
                        } else {
                            HStack(spacing: 8) {
                                ForEach([10, 30, 60], id: \.self) { min in
                                    Button("\(min) 分钟") {
                                        settings.pause(minutes: min)
                                        eventLog.log("已暂停保护 \(min) 分钟")
                                    }
                                    .buttonStyle(.bordered).controlSize(.small)
                                }
                            }
                        }
                    }
                }
                Divider().padding(.horizontal, 14)

                // 事件日志
                block { EventLogView() }
                Divider().padding(.horizontal, 14)

                // 开机自启
                block {
                    Toggle(isOn: Binding(
                        get: { SMAppService.mainApp.status == .enabled },
                        set: { _ in
                            do {
                                if SMAppService.mainApp.status == .enabled {
                                    try SMAppService.mainApp.unregister()
                                } else {
                                    try SMAppService.mainApp.register()
                                }
                            } catch {}
                        }
                    )) {
                        VStack(alignment: .leading, spacing: 1) {
                            Text("开机自启").font(.subheadline.bold())
                            Text("登录后自动启动 NearLock").font(.caption2).foregroundStyle(.secondary)
                        }
                    }
                    .toggleStyle(.switch)
                }
                Divider().padding(.horizontal, 14)

                // 退出
                HStack {
                    Spacer()
                    Button("退出 NearLock") { NSApplication.shared.terminate(nil) }
                        .buttonStyle(.borderless).foregroundStyle(.red)
                }
                .padding(14)
            }
        }
    }

    // MARK: - 状态派生

    private var statusText: String {
        if !settings.protectionEnabled { return "保护已关闭" }
        if settings.isPaused { return "已暂停" }
        if settings.boundDeviceId == nil { return "未绑定设备" }
        return scanner.isScanning ? "保护中" : "等待蓝牙"
    }

    private var statusColor: Color {
        if !settings.protectionEnabled { return .secondary }
        if settings.isPaused { return .orange }
        if settings.boundDeviceId == nil { return .red }
        return .green
    }

    private var menuBarIcon: String {
        if !settings.protectionEnabled { return "lock.slash" }
        if settings.isPaused { return "lock.open" }
        return settings.boundDeviceId != nil ? "lock.fill" : "lock"
    }

    private var pauseUntilText: String {
        guard let until = settings.pauseUntil else { return "" }
        let f = DateFormatter(); f.dateFormat = "HH:mm"
        return "至 \(f.string(from: until))"
    }

    // MARK: - 设置页小组件

    @ViewBuilder
    private func block<C: View>(@ViewBuilder _ content: () -> C) -> some View {
        content().padding(14)
    }

    private func row(_ left: String, _ right: String) -> some View {
        HStack {
            Text(left).font(.system(.caption, design: .monospaced)).foregroundStyle(.secondary)
            Spacer()
            Text(right).font(.system(.caption, design: .monospaced)).foregroundStyle(.secondary)
        }
    }

    private func sliderRow(label: String, valueText: String, value: Binding<Double>, range: ClosedRange<Double>) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack {
                Text(label).font(.caption)
                Spacer()
                Text(valueText).font(.caption.monospacedDigit()).foregroundStyle(.secondary)
            }
            Slider(value: value, in: range, step: 1)
        }
    }

    /// RSSI (dBm) → 估算距离，用实测值校准（-53 dBm @ 40cm → TxPower ≈ -61, n=2.0）。
    static func rssiToMeters(_ rssi: Int) -> String {
        let d = pow(10.0, (-61.0 - Double(rssi)) / 20.0)
        if d < 1 { return String(format: "%.0f cm", d * 100) }
        return String(format: "%.1f m", d)
    }
}

// MARK: - 设备发现

extension MenuContentView {

    var discoverySection: some View {
        VStack(alignment: .leading, spacing: 6) {
            let sorted = scanner.devices.values.sorted { $0.rssi > $1.rssi }
            if sorted.isEmpty {
                Text("正在扫描 NearLock 信标…")
                    .font(.caption).foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 4)
            } else {
                ForEach(sorted) { device in
                    HStack(spacing: 8) {
                        Text(device.shortId)
                            .font(.system(.callout, design: .monospaced, weight: .medium))
                        Spacer()
                        Text("\(device.rssi) dBm")
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(device.rssi < settings.rssiThreshold ? .orange : .green)
                        Button("绑定") {
                            settings.bind(deviceId: device.id)
                            monitor.resetForRebind()
                            eventLog.log("已绑定设备 \(device.shortId)")
                        }
                        .buttonStyle(.borderedProminent).controlSize(.mini)
                    }
                    .padding(.horizontal, 10).padding(.vertical, 7)
                    .background(Color.secondary.opacity(0.06), in: RoundedRectangle(cornerRadius: 9))
                }
            }
        }
    }

    func boundDeviceSection(boundId: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            // 可视化卡片
            ZStack(alignment: .bottom) {
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color.accentColor.opacity(0.12).gradient)
                    .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Color.accentColor.opacity(0.18), lineWidth: 1))
                    .frame(height: 110)
                ZStack {
                    Circle().stroke(Color.accentColor.opacity(0.25), lineWidth: 1).frame(width: 72, height: 72)
                    Circle().stroke(Color.accentColor.opacity(0.15), lineWidth: 1).frame(width: 50, height: 50)
                    Circle().fill(Color.accentColor.opacity(0.15)).frame(width: 38, height: 38)
                        .overlay(Image(systemName: "lock.shield.fill").font(.system(size: 16)).foregroundStyle(Color.accentColor))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center).padding(.bottom, 28)
                HStack(spacing: 6) {
                    metricBadge("RSSI", monitor.smoothedRSSI.map { "\($0) dBm · \(MenuContentView.rssiToMeters($0))" } ?? "--")
                    metricBadge("TRIGGER", "\(settings.triggerSeconds)s")
                }
                .padding(.horizontal, 10).padding(.bottom, 8)
            }
            .frame(height: 110)

            // 设备 ID + 解绑
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(boundId).font(.system(.callout, design: .monospaced, weight: .semibold))
                    if let rssi = monitor.smoothedRSSI {
                        Text("实时 RSSI  \(rssi) dBm").font(.caption)
                            .foregroundStyle(rssi < settings.rssiThreshold ? .orange : .green)
                    }
                }
                Spacer()
                Button("解绑") {
                    settings.unbind(); monitor.resetForRebind(); eventLog.log("已解绑设备")
                }
                .buttonStyle(.borderless).foregroundStyle(.red).controlSize(.small)
            }

            // 离开计时进度条
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("离开计时").font(.caption).foregroundStyle(.secondary)
                    Spacer()
                    Text("\(monitor.belowSeconds) / \(settings.triggerSeconds) 秒")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(monitor.belowSeconds > 0 ? .orange : .secondary)
                }
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color.secondary.opacity(0.15))
                        let pct = settings.triggerSeconds > 0
                            ? min(1.0, Double(monitor.belowSeconds) / Double(settings.triggerSeconds)) : 0
                        Capsule().fill(pct > 0.7 ? Color.red : Color.accentColor)
                            .frame(width: geo.size.width * pct)
                    }
                }
                .frame(height: 6)
            }
        }
    }

    private func metricBadge(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(label).font(.system(size: 9, weight: .medium)).foregroundStyle(.secondary)
            Text(value).font(.system(size: 12, design: .monospaced).weight(.semibold))
        }
        .padding(.horizontal, 8).padding(.vertical, 5)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
    }
}

// MARK: - 事件日志

struct EventLogView: View {

    @EnvironmentObject var eventLog: EventLog

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("事件日志").font(.system(.caption, design: .monospaced)).foregroundStyle(.secondary)
                Spacer()
                Text("最近 8 条").font(.system(.caption, design: .monospaced)).foregroundStyle(.secondary)
            }
            if eventLog.entries.isEmpty {
                Text("暂无事件").font(.caption).foregroundStyle(.secondary)
            } else {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(eventLog.entries.prefix(8)) { entry in
                        HStack(alignment: .top, spacing: 8) {
                            Text(entry.timeText)
                                .font(.caption2.monospacedDigit()).foregroundStyle(.secondary)
                                .frame(width: 38, alignment: .leading)
                            Text(entry.message).font(.caption2)
                            Spacer()
                        }
                        if entry.id != eventLog.entries.prefix(8).last?.id { Divider() }
                    }
                }
            }
        }
    }
}
