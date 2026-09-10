package dev.kartpad.android

import android.content.Context
import android.os.Handler
import android.os.Looper
import androidx.lifecycle.MutableLiveData
import androidx.work.Data
import androidx.work.workDataOf
import java.util.UUID
import java.util.concurrent.Executors
import java.util.concurrent.atomic.AtomicBoolean
import kotlinx.coroutines.runBlocking

internal data class InstallInfo(
    val state: State,
    val progress: Data = Data.EMPTY,
    val outputData: Data = Data.EMPTY,
) {
    enum class State(val isFinished: Boolean) {
        ENQUEUED(false), BLOCKED(false), RUNNING(false),
        SUCCEEDED(true), CANCELLED(true), FAILED(true)
    }
}

/** One visible installation at a time; no WorkManager scheduling or service. */
internal object RetroRewindInstallWork {
    const val UNIQUE_NAME = "kartpad-retro-rewind-install"
    const val TAG = "kartpad-retro-rewind-install"
    const val KEY_TOKEN = "install_token"
    const val KEY_PHASE = "phase"
    const val KEY_COMPLETED_BYTES = "completed_bytes"
    const val KEY_TOTAL_BYTES = "total_bytes"
    const val KEY_ERROR = "error"
    const val KEY_LATEST_VERSION = "latest_version"
    const val KEY_DEBUG_FIXTURE = "debug_fixture"
    const val KEY_DEBUG_FIXTURE_STEPS = "debug_fixture_steps"
    const val KEY_DEBUG_FIXTURE_DELAY_MILLIS = "debug_fixture_delay_millis"
    const val KEY_DEBUG_RESUME_PROCESS_DEATH = "debug_resume_process_death"
    const val DEBUG_RESUME_PARTIAL = ".kartpad-worker-resume-fixture.part"


    val liveData = MutableLiveData<List<InstallInfo>>(emptyList())
    private val main = Handler(Looper.getMainLooper())
    private val executor = Executors.newSingleThreadExecutor()
    private var cancellation: AtomicBoolean? = null

    fun enqueue(context: Context) {
        start(context, workDataOf(KEY_TOKEN to UUID.randomUUID().toString()))
    }

    private fun start(context: Context, input: Data) {
        check(Looper.myLooper() == Looper.getMainLooper())
        if (cancellation != null) return
        val stop = AtomicBoolean(false)
        cancellation = stop
        liveData.value = listOf(InstallInfo(InstallInfo.State.RUNNING))
        val app = context.applicationContext
        executor.execute {
            val result = try {
                runBlocking {
                    RetroRewindInstallWorker(app, input, { stop.get() }) { data ->
                        main.post {
                            if (cancellation === stop && !stop.get()) {
                                liveData.value = listOf(InstallInfo(InstallInfo.State.RUNNING, data))
                            }
                        }
                    }.doWork()
                }
            } catch (_: Exception) {
                RetroRewindInstallWorker.Result.failure(workDataOf(KEY_ERROR to "unexpected"))
            }
            main.post {
                if (cancellation === stop) {
                    cancellation = null
                    val state = when {
                        result.successful -> InstallInfo.State.SUCCEEDED
                        stop.get() -> InstallInfo.State.CANCELLED
                        else -> InstallInfo.State.FAILED
                    }
                    liveData.value = listOf(InstallInfo(state, outputData = result.data))
                }
            }
        }
    }

    @Suppress("UNUSED_PARAMETER")
    fun cancel(context: Context) {
        cancellation?.set(true)
    }

    fun enqueueDebugFixture(
        context: Context,
        steps: Int = 3,
        delayMillis: Long = 250,
        resumeProcessDeath: Boolean = false,
    ): UUID {
        check(BuildConfig.DEBUG && !BuildConfig.GAME_RUNTIME)
        check(steps in 1..120 && delayMillis in 1..5_000)
        val id = UUID.randomUUID()
        start(context, workDataOf(
            KEY_TOKEN to id.toString(), KEY_DEBUG_FIXTURE to true,
            KEY_DEBUG_FIXTURE_STEPS to steps,
            KEY_DEBUG_FIXTURE_DELAY_MILLIS to delayMillis,
            KEY_DEBUG_RESUME_PROCESS_DEATH to resumeProcessDeath,
        ))
        return id
    }
}
