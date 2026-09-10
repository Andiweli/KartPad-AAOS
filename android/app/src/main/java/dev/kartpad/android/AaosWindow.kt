package dev.kartpad.android

import android.app.Activity
import android.content.Context
import android.content.pm.ActivityInfo
import android.content.pm.PackageManager
import android.os.Build
import android.util.Log
import android.view.View
import android.view.ViewGroup
import android.view.WindowInsets
import android.view.WindowManager
import android.widget.FrameLayout
import kotlin.math.max

/** AST AAOS integration, 2026-09-07. No fixed vehicle resolution or inset constants. */
internal object AaosWindow {
    fun isAutomotive(context: Context): Boolean =
        context.packageManager.hasSystemFeature(PackageManager.FEATURE_AUTOMOTIVE)

    @Suppress("DEPRECATION")
    fun configure(activity: Activity) {
        activity.requestedOrientation = ActivityInfo.SCREEN_ORIENTATION_UNSPECIFIED
        activity.window.apply {
            clearFlags(WindowManager.LayoutParams.FLAG_FULLSCREEN or
                WindowManager.LayoutParams.FLAG_LAYOUT_NO_LIMITS or
                WindowManager.LayoutParams.FLAG_TRANSLUCENT_STATUS or
                WindowManager.LayoutParams.FLAG_TRANSLUCENT_NAVIGATION)
            addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
            attributes = attributes.apply {
                layoutInDisplayCutoutMode = WindowManager.LayoutParams.LAYOUT_IN_DISPLAY_CUTOUT_MODE_NEVER
            }
            decorView.systemUiVisibility = View.SYSTEM_UI_FLAG_VISIBLE
            if (Build.VERSION.SDK_INT >= 30) {
                setDecorFitsSystemWindows(true)
                insetsController?.show(WindowInsets.Type.systemBars())
            }
        }
    }

    fun install(activity: Activity) {
        if (activity.isFinishing || activity.isDestroyed) return
        val content = activity.findViewById<ViewGroup>(android.R.id.content) ?: return
        if (content.childCount == 1 && content.getChildAt(0) is SafeFrame) {
            content.requestApplyInsets()
            return
        }
        if (content.childCount == 0) return
        val safeFrame = SafeFrame(activity)
        // Move the entire SDL layout, including SurfaceView and controls together.
        // SurfaceHolder delivers the real resulting size to SDL/Aurora/Vulkan.
        while (content.childCount > 0) {
            val child = content.getChildAt(0)
            val originalParams = child.layoutParams
            content.removeViewAt(0)
            safeFrame.addView(child, if (originalParams is FrameLayout.LayoutParams) {
                originalParams
            } else FrameLayout.LayoutParams(originalParams.width, originalParams.height))
        }
        content.addView(safeFrame, ViewGroup.LayoutParams(
            ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.MATCH_PARENT))
        safeFrame.bind(activity, content)
    }

    private class SafeFrame(context: Context) : FrameLayout(context) {
        @Suppress("DEPRECATION")
        fun bind(activity: Activity, content: ViewGroup) {
            fun update(insets: WindowInsets) {
                val root = activity.window.decorView
                if (root.width <= 0 || content.width <= 0 || content.height <= 0) return
                val safe = if (Build.VERSION.SDK_INT >= 30) {
                    insets.getInsetsIgnoringVisibility(
                        WindowInsets.Type.systemBars() or WindowInsets.Type.displayCutout() or
                            WindowInsets.Type.systemGestures() or WindowInsets.Type.mandatorySystemGestures() or
                            WindowInsets.Type.tappableElement())
                } else {
                    val cutout = insets.displayCutout
                    var l = max(insets.systemWindowInsetLeft, insets.stableInsetLeft)
                    var t = max(insets.systemWindowInsetTop, insets.stableInsetTop)
                    var r = max(insets.systemWindowInsetRight, insets.stableInsetRight)
                    var b = max(insets.systemWindowInsetBottom, insets.stableInsetBottom)
                    l = max(l, cutout?.safeInsetLeft ?: 0)
                    t = max(t, cutout?.safeInsetTop ?: 0)
                    r = max(r, cutout?.safeInsetRight ?: 0)
                    b = max(b, cutout?.safeInsetBottom ?: 0)
                    if (Build.VERSION.SDK_INT >= 29) {
                        for (extra in arrayOf(insets.systemGestureInsets,
                            insets.mandatorySystemGestureInsets, insets.tappableElementInsets)) {
                            l = max(l, extra.left); t = max(t, extra.top)
                            r = max(r, extra.right); b = max(b, extra.bottom)
                        }
                    }
                    // android.graphics.Insets exists only from API 29; use an array below on API 28.
                    return updateLegacy(root, content, l, t, r, b)
                }
                applyMargins(root, content, safe.left, safe.top, safe.right, safe.bottom)
            }

            fun requestUpdate() {
                activity.window.decorView.rootWindowInsets?.let(::update)
            }
            // Listener runs after WMS fitting; subtract existing fit instead of adding it twice.
            content.setOnApplyWindowInsetsListener { _, insets ->
                content.post { requestUpdate() }
                if (Build.VERSION.SDK_INT >= 30) WindowInsets.CONSUMED else
                    insets.consumeSystemWindowInsets().consumeStableInsets().consumeDisplayCutout()
            }
            content.addOnLayoutChangeListener { _, _, _, _, _, _, _, _, _ -> requestUpdate() }
            activity.window.decorView.addOnLayoutChangeListener { _, _, _, _, _, _, _, _, _ ->
                content.post { requestUpdate() }
            }
            content.requestApplyInsets()
            content.post { requestUpdate() }
        }

        private fun updateLegacy(root: View, content: ViewGroup, l: Int, t: Int, r: Int, b: Int) =
            applyMargins(root, content, l, t, r, b)

        private var previous = intArrayOf(-1, -1, -1, -1)

        private fun applyMargins(root: View, content: ViewGroup, l: Int, t: Int, r: Int, b: Int) {
            val rootPosition = IntArray(2).also { root.getLocationInWindow(it) }
            val position = IntArray(2).also { content.getLocationInWindow(it) }
            val remaining = SafeAreaMath.remaining(root.width, root.height,
                position[0] - rootPosition[0], position[1] - rootPosition[1],
                content.width, content.height, l, t, r, b)
            if (previous.contentEquals(remaining)) return
            previous = remaining
            val params = layoutParams as ViewGroup.MarginLayoutParams
            params.setMargins(remaining[0], remaining[1], remaining[2], remaining[3])
            layoutParams = params
            if (BuildConfig.DEBUG) Log.d("KartPadAAOS", "Available content=${content.width}x${content.height}, " +
                "remaining insets=${remaining.joinToString()}")
        }
    }
}
