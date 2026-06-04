package com.nearlock.beacon.ble

import org.junit.Assert.assertArrayEquals
import org.junit.Assert.assertEquals
import org.junit.Test
import java.util.UUID

/**
 * NearLockProtocol 的 deviceId 编解码测试。
 *
 * 该编解码是双端契约的核心：Android 取 UUID 高 64 位编码为 8 字节短 ID，
 * 双端统一用 16 位小写 hex 表示，必须与 macOS 端 decodeDeviceId 输出完全一致。
 */
class NearLockProtocolTest {

    @Test
    fun `编码长度固定为8字节`() {
        val encoded = NearLockProtocol.encodeDeviceId(UUID.randomUUID())
        assertEquals(8, encoded.size)
    }

    @Test
    fun `编码采用大端字节序取UUID高64位`() {
        // mostSignificantBits = 0x0102030405060708
        val uuid = UUID(0x0102030405060708L, 0x090A0B0C0D0E0F10L)
        val encoded = NearLockProtocol.encodeDeviceId(uuid)
        val expected = byteArrayOf(0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08)
        assertArrayEquals(expected, encoded)
    }

    @Test
    fun `短ID hex 为16位小写无分隔`() {
        val uuid = UUID(0x1234567890ABCDEFL, 0L)
        val hex = NearLockProtocol.shortIdHex(uuid)
        assertEquals("1234567890abcdef", hex)
    }

    @Test
    fun `字节数组与UUID两种shortIdHex入参结果一致`() {
        val uuid = UUID.randomUUID()
        val fromUuid = NearLockProtocol.shortIdHex(uuid)
        val fromBytes = NearLockProtocol.shortIdHex(NearLockProtocol.encodeDeviceId(uuid))
        assertEquals(fromUuid, fromBytes)
    }

    @Test(expected = IllegalArgumentException::class)
    fun `shortIdHex 非8字节抛出异常`() {
        NearLockProtocol.shortIdHex(byteArrayOf(1, 2, 3))
    }

    @Test
    fun `固定ServiceUUID常量与字符串一致`() {
        assertEquals(
            UUID.fromString(NearLockProtocol.SERVICE_UUID_STRING),
            NearLockProtocol.SERVICE_UUID
        )
    }
}
