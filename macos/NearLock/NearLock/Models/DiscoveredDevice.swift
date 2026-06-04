import Foundation

/// 扫描发现的 Android 信标设备。
///
/// deviceId 来自广播 Service Data，作为绑定与去重的唯一键。
/// rssi 随每次广播刷新，lastSeen 用于判断信号是否丢失。
struct DiscoveredDevice: Identifiable, Equatable {

    /// 设备唯一标识（解码自广播 Service Data），同时作为列表 id。
    let id: String

    /// 最新一次读到的 RSSI（dBm，负值，越大越近）。
    var rssi: Int

    /// 最近一次收到该设备广播的时间，用于信号丢失判定。
    var lastSeen: Date

    /// deviceId 的简短展示（前 8 位），用于 UI 紧凑显示。
    /// deviceId 的展示形式。id 本身已是 16 位 hex 短 ID，直接展示。
    var shortId: String {
        id
    }
}
