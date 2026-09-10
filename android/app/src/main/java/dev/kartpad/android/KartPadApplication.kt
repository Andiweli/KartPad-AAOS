package dev.kartpad.android

import android.app.Activity
import android.app.Application
import android.os.Bundle

/** Applies the same AAOS window policy to the game, chooser and data import. */
class KartPadApplication : Application(), Application.ActivityLifecycleCallbacks {
    override fun onCreate() {
        super.onCreate()
        registerActivityLifecycleCallbacks(this)
    }

    override fun onActivityCreated(activity: Activity, state: Bundle?) {
        if (AaosWindow.isAutomotive(activity)) {
            AaosWindow.configure(activity)
            // onActivityCreated can run from super.onCreate, before SDL installs mLayout.
            activity.window.decorView.post { AaosWindow.install(activity) }
        }
    }

    override fun onActivityResumed(activity: Activity) {
        if (AaosWindow.isAutomotive(activity)) {
            AaosWindow.configure(activity)
            activity.window.decorView.post { AaosWindow.install(activity) }
        }
    }
    override fun onActivityStarted(activity: Activity) = Unit
    override fun onActivityPaused(activity: Activity) = Unit
    override fun onActivityStopped(activity: Activity) = Unit
    override fun onActivitySaveInstanceState(activity: Activity, state: Bundle) = Unit
    override fun onActivityDestroyed(activity: Activity) = Unit
}
