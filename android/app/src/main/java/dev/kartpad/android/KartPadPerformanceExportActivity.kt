package dev.kartpad.android

import android.content.Intent
import android.net.Uri
import android.os.Bundle
import android.util.Log
import android.view.Gravity
import android.widget.Button
import android.widget.LinearLayout
import android.widget.TextView
import java.io.File
import java.security.MessageDigest
import java.util.UUID
import java.util.concurrent.Executors

/** Owns the document picker outside SDL; a complete private snapshot precedes every export. */
internal class KartPadPerformanceExportActivity : ControllerMenuActivity() {
    private lateinit var report: File
    private lateinit var detail: TextView
    private lateinit var save: Button
    private var pickerOpen = false
    private var destination: Uri? = null
    private var busy = false

    override fun onCreate(state: Bundle?) {
        super.onCreate(state)
        val supplied = state?.getString("session") ?: intent.getStringExtra("session")
        val session = runCatching { UUID.fromString(supplied).toString() }
            .getOrElse { UUID.randomUUID().toString() }
        report = File(filesDir, "KartPad/PerformanceExports/$session.txt")
        pickerOpen = state?.getBoolean("pickerOpen") ?: false
        destination = state?.getString("destination")?.let(Uri::parse)
        val padding = (24 * resources.displayMetrics.density).toInt()
        val layout = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER
            setPadding(padding, padding, padding, padding)
        }
        detail = TextView(this).apply {
            text = "Preparing performance report…"
            textSize = 18f
            gravity = Gravity.CENTER
        }
        save = Button(this).apply {
            text = "Save report…"
            isEnabled = false
            setOnClickListener { if (!busy && !pickerOpen) openPicker() }
        }
        val close = Button(this).apply {
            text = "Back to game"
            setOnClickListener { if (!busy) finish() }
        }
        layout.addView(detail)
        layout.addView(save)
        layout.addView(close)
        setContentView(layout)
        prepareSnapshot(openWhenReady = state == null)
    }

    override fun onSaveInstanceState(out: Bundle) {
        out.putString("session", report.nameWithoutExtension)
        out.putBoolean("pickerOpen", pickerOpen)
        out.putString("destination", destination?.toString())
        super.onSaveInstanceState(out)
    }

    private fun prepareSnapshot(openWhenReady: Boolean) {
        busy = true
        val app = applicationContext
        val scale = intent.getFloatExtra("scale", 1f)
        val minimum = intent.getFloatExtra("minimum", 1f)
        val width = intent.getIntExtra("width", 0)
        val height = intent.getIntExtra("height", 0)
        executor.execute {
            val result = runCatching {
                if (!report.isFile || report.length() == 0L) {
                    check(report.parentFile!!.isDirectory || report.parentFile!!.mkdirs()) {
                        "Cannot create local report folder"
                    }
                    val partial = File.createTempFile("report-", ".partial", report.parentFile)
                    try {
                        partial.bufferedWriter(Charsets.UTF_8).use {
                            KartPadPerformanceReport.write(app, it, scale, minimum, width, height)
                        }
                        check(partial.length() > 0) { "Local report is empty" }
                        check(partial.renameTo(report)) { "Cannot preserve local report" }
                    } finally { partial.delete() }
                }
                report.length()
            }
            runOnUiThread {
                if (isFinishing || isDestroyed) return@runOnUiThread
                busy = false
                result.onSuccess { bytes ->
                    detail.text = "Report ready ($bytes bytes)."
                    save.isEnabled = !pickerOpen
                    when {
                        destination != null -> copyReport(destination!!)
                        openWhenReady && !pickerOpen -> openPicker()
                    }
                }.onFailure { error ->
                    showError("Could not prepare report", error)
                    save.text = "Retry preparation"
                    save.isEnabled = true
                    save.setOnClickListener { if (!busy) prepareSnapshot(true) }
                }
            }
        }
    }

    private fun openPicker() {
        save.setOnClickListener { if (!busy && !pickerOpen) openPicker() }
        save.text = "Save report…"
        pickerOpen = true
        save.isEnabled = false
        try {
            startActivityForResult(Intent(Intent.ACTION_CREATE_DOCUMENT).apply {
                addCategory(Intent.CATEGORY_OPENABLE)
                type = "text/plain"
                putExtra(Intent.EXTRA_TITLE, "MarioKart-Performance-${System.currentTimeMillis()}.txt")
                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_GRANT_WRITE_URI_PERMISSION)
            }, PICK_DOCUMENT)
        } catch (error: Exception) {
            pickerOpen = false
            save.isEnabled = true
            showError("Cannot open file picker", error)
        }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode != PICK_DOCUMENT) return
        pickerOpen = false
        if (resultCode != RESULT_OK || data?.data == null) {
            detail.text = "Export cancelled. The prepared report is still available."
            save.isEnabled = true
            return
        }
        val uri = data.data!!
        if (data.flags and Intent.FLAG_GRANT_PERSISTABLE_URI_PERMISSION != 0) {
            runCatching {
                contentResolver.takePersistableUriPermission(uri, data.flags and
                    (Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_GRANT_WRITE_URI_PERMISSION))
            }
        }
        destination = uri
        copyReport(uri)
    }

    private fun copyReport(uri: Uri) {
        busy = true
        save.isEnabled = false
        detail.text = "Saving and verifying report…"
        val resolver = applicationContext.contentResolver
        executor.execute {
            val result = runCatching {
                val bytes = report.readBytes()
                check(bytes.isNotEmpty()) { "Local report is empty" }
                // Some document providers support 'w' but reject 'wt'.
                val output = try { resolver.openOutputStream(uri, "wt") }
                    catch (_: IllegalArgumentException) { resolver.openOutputStream(uri, "w") }
                    ?: error("Cannot open destination for writing")
                output.use { it.write(bytes); it.flush() }
                val expected = MessageDigest.getInstance("SHA-256").digest(bytes)
                val actual = MessageDigest.getInstance("SHA-256")
                var count = 0L
                val input = resolver.openInputStream(uri) ?: error("Cannot reopen report to verify it")
                input.use {
                    val buffer = ByteArray(8192)
                    while (true) {
                        val n = it.read(buffer)
                        if (n < 0) break
                        if (n == 0) continue
                        count += n
                        check(count <= bytes.size.toLong()) { "Destination contains unexpected extra data" }
                        actual.update(buffer, 0, n)
                    }
                }
                check(count == bytes.size.toLong() && expected.contentEquals(actual.digest())) {
                    "Saved file is empty, incomplete or different from the report"
                }
                bytes.size
            }
            runOnUiThread {
                if (isFinishing || isDestroyed) return@runOnUiThread
                busy = false
                destination = null
                save.isEnabled = true
                result.onSuccess { bytes ->
                    detail.text = "Performance report saved and verified ($bytes bytes)."
                    save.text = "Save another copy…"
                }.onFailure { error ->
                    showError("Export could not be verified. Local copy retained; try Downloads", error)
                    save.text = "Retry export…"
                }
            }
        }
    }

    private fun showError(message: String, error: Throwable) {
        Log.e("KartPadReport", message, error)
        detail.text = "$message.\n${error.javaClass.simpleName}: ${error.message.orEmpty().take(240)}"
    }

    companion object {
        private const val PICK_DOCUMENT = 4305
        // Serializes re-created Activity instances; the complete snapshot is shared on disk.
        private val executor = Executors.newSingleThreadExecutor()
    }
}
