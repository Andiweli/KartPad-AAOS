package android.util

import java.io.File
import java.io.FileOutputStream
import java.nio.file.Files
import java.nio.file.StandardCopyOption

/** Host test stand-in for Android's AtomicFile; permits a bounded publication fault. */
class AtomicFile(private val file: File) {
    private val temporary = File(file.path + ".new")
    fun startWrite(): FileOutputStream = FileOutputStream(temporary)
    fun finishWrite(stream: FileOutputStream) {
        stream.fd.sync()
        stream.close()
        if (failSuffix != null && file.path.endsWith(failSuffix!!)) throw java.io.IOException("injected")
        Files.move(temporary.toPath(), file.toPath(), StandardCopyOption.ATOMIC_MOVE, StandardCopyOption.REPLACE_EXISTING)
    }
    fun failWrite(stream: FileOutputStream) { stream.close(); temporary.delete() }
    companion object { var failSuffix: String? = null }
}
