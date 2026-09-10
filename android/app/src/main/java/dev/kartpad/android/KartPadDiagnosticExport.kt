package dev.kartpad.android

import android.content.Context
import android.net.Uri
import java.io.File
import java.io.RandomAccessFile
import java.util.zip.ZipEntry
import java.util.zip.ZipOutputStream

/** Explicit local export, available even when the game cannot finish booting. */
internal object KartPadDiagnosticExport {
    private const val MAX_FILE_BYTES = 4L * 1024 * 1024
    private const val MAX_FILES = 12

    fun write(context: Context, destination: Uri) {
        val root = File(context.filesDir, "KartPad/Logs").canonicalFile
        // Only bounded tails of runtime text logs, never game data, NAND or config.
        val files = if (root.isDirectory) root.walkTopDown().maxDepth(3)
            .filter { it.isFile && it.extension in setOf("log", "txt") }
            .filter { it.canonicalPath.startsWith(root.path + File.separator) }
            .sortedByDescending { it.lastModified() }.take(MAX_FILES).toList() else emptyList()
        val output = context.contentResolver.openOutputStream(destination, "w")
            ?: error("The chosen destination could not be opened.")
        ZipOutputStream(output.buffered()).use { zip ->
            zip.putNextEntry(ZipEntry("README.txt"))
            zip.write(buildString {
                appendLine("Private KartPad runtime diagnostics; review before sharing.")
                appendLine("Version: ${BuildConfig.VERSION_NAME} (${BuildConfig.VERSION_CODE})")
                appendLine("Device: ${android.os.Build.MANUFACTURER} ${android.os.Build.MODEL}")
                appendLine("API: ${android.os.Build.VERSION.SDK_INT}")
                appendLine("Retro Rewind: ${RetroRewindRelease.VERSION}")
                appendLine("Native KartPadPerf/CPU/GPU metrics and android-health.log use elapsed_ms since boot.")
                appendLine("Health samples run every 10 seconds while the game activity is resumed.")
                appendLine("An in-game pause menu may still render; these samples do not identify race state.")
                appendLine("Health history is bounded to 1 MiB; null means unavailable, not zero.")
                appendLine("Thermal status and headroom are OS signals, not proof of a single bottleneck.")
                appendLine("Each log contains at most its last $MAX_FILE_BYTES bytes.")
                appendLine("Log files: ${files.size}")
            }.toByteArray())
            zip.closeEntry()
            val buffer = ByteArray(32 * 1024)
            for (file in files) {
                zip.putNextEntry(ZipEntry("Logs/" + file.relativeTo(root).invariantSeparatorsPath))
                RandomAccessFile(file, "r").use { input ->
                    val size = input.length()
                    input.seek(maxOf(0, size - MAX_FILE_BYTES))
                    var remaining = minOf(size, MAX_FILE_BYTES)
                    while (remaining > 0) {
                        val count = input.read(buffer, 0, minOf(buffer.size.toLong(), remaining).toInt())
                        if (count < 0) break
                        zip.write(buffer, 0, count)
                        remaining -= count
                    }
                }
                zip.closeEntry()
            }
        }
    }
}
