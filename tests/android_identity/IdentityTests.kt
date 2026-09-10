package dev.kartpad.android

import java.io.File
import java.nio.file.Files
import java.util.zip.CRC32
import android.util.AtomicFile

fun main(args: Array<String>) {
    System.load(args[0])
    val fixtures = File(args[1])
    val root = Files.createTempDirectory("kartpad-identity-test-").toFile()
    fun path(profile: String) = File(root, "KartPad/${KartPadIdentityStorage.paths.getValue(profile)}")
    for (profile in KartPadIdentityStorage.paths.keys) {
        path(profile).parentFile.mkdirs()
        File(fixtures, if (profile == "mii") "mii.dat" else "save.dat").copyTo(path(profile))
    }
    fun record(profile: String) = KartPadIdentityStorage.records(root, profile == "mii").first { it.profile == profile }
    fun crc(bytes: ByteArray) {
        val crc = CRC32().apply { update(bytes, 0, 0x27ffc) }.value
        repeat(4) { bytes[0x27ffc + it] = (crc shr (24 - it * 8)).toByte() }
    }
    val original = path("original").readBytes()
    KartPadIdentityStorage.stage(root, record("original"), false, "Racer")
    check(path("original").readBytes().contentEquals(original))
    check(runCatching { KartPadIdentityStorage.stage(root, record("original"), false, "Other") }.isFailure)
    val latest = original.copyOf().apply { this[8 + 0x90] = 0x44; crc(this) }
    path("original").writeBytes(latest)
    // A newer appearance edit must survive a previously scheduled license rename.
    val latestMii = path("mii").readBytes().apply {
        this[4 + 0x20] = (this[4 + 0x20].toInt() xor 1).toByte()
        var crc = 0
        for (index in 0 until 0x1f1de) {
            crc = crc xor ((this[index].toInt() and 255) shl 8)
            repeat(8) { crc = if (crc and 0x8000 != 0) (crc shl 1) xor 0x1021 else crc shl 1 }
            crc = crc and 0xffff
        }
        this[0x1f1de] = (crc shr 8).toByte()
        this[0x1f1df] = crc.toByte()
    }
    path("mii").writeBytes(latestMii)
    AtomicFile.failSuffix = "/FaceLib/RFL_DB.dat"
    check(KartPadIdentityStorage.applyPending(root) != null)
    check(KartPadIdentityStorage.hasPending(root))
    check(record("original").name == "Racer")
    check(path("mii").readBytes().contentEquals(latestMii))
    AtomicFile.failSuffix = null
    check(KartPadIdentityStorage.applyPending(root) == null)
    check(record("original").name == "Racer")
    check(record("mii").name == "Racer")
    val renamedMii = path("mii").readBytes()
    for (i in latestMii.indices) if (i !in 6 until 26 && i !in 0x1f1de..0x1f1df)
        check(latestMii[i] == renamedMii[i])
    val renamed = path("original").readBytes()
    for (i in latest.indices) if (i !in (8 + 0x14) until (8 + 0x14 + 20) && i !in 0x27ffc..0x27fff)
        check(latest[i] == renamed[i])
    check(record("retro_rewind").name == "Player")
    check(path("retro_rewind").readBytes().contentEquals(original))
    check(path("retro_rewind_separate").readBytes().contentEquals(original))
    KartPadIdentityStorage.stage(root, record("mii"), false, "Both")
    AtomicFile.failSuffix = "/data/rksys.dat"
    check(KartPadIdentityStorage.applyPending(root) != null)
    check(KartPadIdentityStorage.hasPending(root))
    AtomicFile.failSuffix = null
    check(KartPadIdentityStorage.applyPending(root) == null)
    check(KartPadIdentityStorage.records(root, false).all { it.name == "Both" })
    check(record("mii").name == "Both")
    val beforeDelete = path("original").readBytes()
    val miiBeforeDelete = path("mii").readBytes()
    KartPadIdentityStorage.stage(root, record("original"), true, "")
    check(KartPadIdentityStorage.applyPending(root) == null)
    check(KartPadIdentityStorage.records(root, false).count { it.profile == "original" } == 1)
    val deleted = path("original").readBytes()
    check(path("mii").readBytes().contentEquals(miiBeforeDelete))
    check(beforeDelete.copyOfRange(8 + 0x8cc0, 8 + 2 * 0x8cc0)
        .contentEquals(deleted.copyOfRange(8 + 0x8cc0, 8 + 2 * 0x8cc0)))
    check(runCatching { KartPadIdentityStorage.stage(root, record("mii"), false, "01234567890") }.isFailure)
    check(!KartPadIdentityStorage.hasPending(root))
    check(File(root, "KartPad/IdentityBackups").listFiles()!!.size == 3)
    println("Android identity passed: JNI semantics, latest-progress preservation, license/Mii rename parity, profile and delete isolation, linked profiles, interrupted transaction recovery, backups, invalid names")
    root.deleteRecursively() // Only this test's newly-created synthetic directory.
}
