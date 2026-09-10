package dev.kartpad.android

import android.content.Context
import android.os.Build
import java.io.File
import java.io.RandomAccessFile
import java.io.Writer

/** Exports only performance-tagged lines, never the full console/save contents. */
internal object KartPadPerformanceReport {
    fun write(context: Context, output: Writer, scale: Float, minimum: Float, width: Int, height: Int) {
        output.append("Mario Kart performance report\n")
        output.append("Exported UTC: ${java.time.Instant.now()}\n")
        output.append("App: ${BuildConfig.VERSION_NAME} (${BuildConfig.VERSION_CODE})\n")
        output.append("Device: ${Build.MANUFACTURER} ${Build.MODEL}; API ${Build.VERSION.SDK_INT}\n")
        output.append("Requested scale sent to runtime: $scale; native minimum: $minimum\n")
        output.append("Window decor: ${width}x${height} (not internal framebuffer size)\n")
        output.append("Timings below precede export; CPU occupancy is not GPU execution time.\n")
        val root = File(context.filesDir, "KartPad/Logs")
        val log = root.walkTopDown().maxDepth(3)
            .filter { it.isFile && it.name == "console.log" }
            .maxByOrNull { it.lastModified() }
        if (log == null) {
            output.append("No native console log found. No FPS measurement available.\n")
            return
        }
        output.append("Newest log modified UTC: ${java.time.Instant.ofEpochMilli(log.lastModified())}\n")
        output.append("Only newest available log tail is included; it may be from a previous session.\n\n")
        val tags = listOf("[KartPadPerf]", "[KartPadCPU]", "[KartPadGPU]", "[KartPadPhase]")
        var count = 0
        RandomAccessFile(log, "r").use { input ->
            val end = input.length()
            val start = (end - 2L * 1024 * 1024).coerceAtLeast(0)
            input.seek(start)
            if (start > 0) input.readLine()
            while (input.filePointer < end) {
                val line = input.readLine() ?: break
                if (tags.any { line.contains(it) }) {
                    output.append(line).append("\n")
                    count++
                }
            }
        }
        if (count == 0) output.append("No performance samples in log tail. Run a race for 60 seconds before export.\n")
    }
}
