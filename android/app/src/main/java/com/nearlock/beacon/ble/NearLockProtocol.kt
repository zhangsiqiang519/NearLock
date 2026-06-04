package com.nearlock.beacon.ble

import android.os.ParcelUuid
import java.nio.ByteBuffer
import java.util.UUID

/**
 * NearLock 双端共享的 BLE 协议常量与 deviceId 编解码。
 *
 * 这是 Android（广播端）与 macOS（扫描端）之间的契约，两端必须保持一致：
 * - Service UUID 固定不变，用于 macOS 识别 NearLock 信标。
 * - deviceId 以 8 字节放入广播包的 Service Data 字段。
 *
 * 为什么是 8 字节而非完整 16 字节 UUID：
 * BLE legacy 广播总预算仅 31 字节。flags(3) + ServiceData(长度1+类型1+UUID16+payload)。
 * 若 payload 用 16 字节，ServiceData 达 34 字节，单项即超预算，startAdvertising 会以
 * ADVERTISE_FAILED_DATA_TOO_LARGE 失败。取 UUID 高 8 字节作短 ID，payload 降到 8 字节，
 * ServiceData = 2+16+8 = 26，加 flags 共 29 字节，可放入预算内。
 * 8 字节（64 bit）随机空间对单用户绑定一台手机的场景，碰撞概率可忽略。
 */
object NearLockProtocol {

    /** NearLock 专用固定 Service UUID，双端硬编码。 */
    const val SERVICE_UUID_STRING: String = "A1B2C3D4-0000-1000-8000-00805F9B34FB"

    val SERVICE_UUID: UUID = UUID.fromString(SERVICE_UUID_STRING)

    val SERVICE_PARCEL_UUID: ParcelUuid = ParcelUuid(SERVICE_UUID)

    /** deviceId 短 ID 的字节长度。 */
    const val DEVICE_ID_BYTES: Int = 8

    /**
     * 将 deviceId（UUID）编码为 8 字节大端短 ID，用于 Service Data。
     *
     * 取 UUID 的高 64 位（mostSignificantBits）作为短 ID。
     *
     * @param deviceId 设备唯一标识
     * @return 8 字节数组
     */
    fun encodeDeviceId(deviceId: UUID): ByteArray {
        return ByteBuffer.allocate(DEVICE_ID_BYTES)
            .putLong(deviceId.mostSignificantBits)
            .array()
    }

    /**
     * 将 8 字节短 ID 解码为十六进制字符串，作为双端统一的 deviceId 展示与比对形式。
     *
     * 与 macOS 端解析逻辑对应：两端都用小写无分隔的 16 位 hex 表示同一短 ID。
     *
     * @param bytes 8 字节数组
     * @return 16 位小写 hex 字符串
     * @throws IllegalArgumentException 字节长度不为 8 时抛出
     */
    fun shortIdHex(bytes: ByteArray): String {
        require(bytes.size == DEVICE_ID_BYTES) {
            "deviceId 字节长度必须为 $DEVICE_ID_BYTES，实际为 ${bytes.size}"
        }
        return bytes.joinToString("") { "%02x".format(it) }
    }

    /**
     * 从 deviceId（UUID）直接得到其短 ID 的 hex 字符串展示。
     *
     * @param deviceId 设备唯一标识
     * @return 16 位小写 hex 字符串
     */
    fun shortIdHex(deviceId: UUID): String = shortIdHex(encodeDeviceId(deviceId))
}

