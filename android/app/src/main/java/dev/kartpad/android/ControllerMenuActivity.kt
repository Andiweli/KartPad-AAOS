package dev.kartpad.android

import android.app.Activity
import android.view.InputDevice
import android.view.KeyEvent
import android.view.MotionEvent
import android.view.View
import android.os.SystemClock

/** Gamepads also operate the Android chooser/import UI. Gameplay stays on native SDL. */
open class ControllerMenuActivity : Activity() {
    private var lastDirection = 0
    private var lastMove = 0L

    override fun dispatchKeyEvent(event: KeyEvent): Boolean {
        val mapped = when (event.keyCode) {
            KeyEvent.KEYCODE_BUTTON_A -> KeyEvent.KEYCODE_DPAD_CENTER
            KeyEvent.KEYCODE_BUTTON_B -> KeyEvent.KEYCODE_BACK
            else -> return super.dispatchKeyEvent(event)
        }
        return super.dispatchKeyEvent(KeyEvent(event.downTime, event.eventTime,
            event.action, mapped, event.repeatCount, event.metaState, event.deviceId,
            event.scanCode, event.flags, event.source))
    }

    override fun onGenericMotionEvent(event: MotionEvent): Boolean {
        if (!event.isFromSource(InputDevice.SOURCE_JOYSTICK) ||
            event.actionMasked != MotionEvent.ACTION_MOVE) return super.onGenericMotionEvent(event)
        val hatX = event.getAxisValue(MotionEvent.AXIS_HAT_X)
        val hatY = event.getAxisValue(MotionEvent.AXIS_HAT_Y)
        val x = if (kotlin.math.abs(hatX) > 0.5f) hatX else event.getAxisValue(MotionEvent.AXIS_X)
        val y = if (kotlin.math.abs(hatY) > 0.5f) hatY else event.getAxisValue(MotionEvent.AXIS_Y)
        val direction = when {
            x < -0.55f -> View.FOCUS_LEFT
            x > 0.55f -> View.FOCUS_RIGHT
            y < -0.55f -> View.FOCUS_UP
            y > 0.55f -> View.FOCUS_DOWN
            else -> 0
        }
        val now = SystemClock.uptimeMillis()
        if (direction != 0 && (direction != lastDirection || now - lastMove >= 220)) {
            val focused = currentFocus
            val next = focused?.focusSearch(direction)
            if (next != null) next.requestFocus() else if (focused == null)
                window.decorView.requestFocus(View.FOCUS_FORWARD)
            lastMove = now
        }
        lastDirection = direction
        return true
    }

    override fun onPause() {
        lastDirection = 0
        lastMove = 0
        super.onPause()
    }
}
