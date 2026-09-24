package com.example.kinvo

import android.app.Activity
import android.app.KeyguardManager
import android.content.Context
import android.os.Build
import android.view.WindowManager
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * What a call needs from the window it is drawn in: to be visible on a locked
 * phone, and to stay lit while someone is watching it.
 *
 * Written here rather than declared in the manifest ON PURPOSE. Putting
 * `showWhenLocked` on the activity would let every screen in Kinvo appear over
 * a lock screen, which on a dating app means somebody's chats are one
 * notification tap from anyone holding the phone. Set from Dart while a call
 * is on screen, and cleared the moment it goes, only the call is ever shown
 * that way.
 *
 * Nothing here exists on iOS: CallKit draws the call over the lock screen
 * itself, and idle timing is the system's.
 */
class CallWindowBridge(
    private val context: Context,
) : MethodChannel.MethodCallHandler {

    companion object {
        const val CHANNEL = "kinvo/call_window"
    }

    private var activity: Activity? = null

    fun attach(activity: Activity) {
        this.activity = activity
    }

    fun detach() {
        // The activity is going; the flags go with it.
        apply(showOverLockScreen = false, keepAwake = false)
        activity = null
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "set" -> {
                apply(
                    showOverLockScreen = call.argument<Boolean>("showOverLockScreen") ?: false,
                    keepAwake = call.argument<Boolean>("keepAwake") ?: false,
                )
                result.success(null)
            }

            else -> result.notImplemented()
        }
    }

    private fun apply(showOverLockScreen: Boolean, keepAwake: Boolean) {
        val activity = activity ?: return

        activity.runOnUiThread {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
                activity.setShowWhenLocked(showOverLockScreen)
                activity.setTurnScreenOn(showOverLockScreen)

                if (showOverLockScreen) {
                    // Asks for the keyguard to be taken away. On a phone with
                    // no PIN it simply goes; on one with a PIN the call is
                    // shown over it and the rest of Kinvo stays locked, which
                    // is the behaviour to want either way.
                    val keyguard =
                        activity.getSystemService(Context.KEYGUARD_SERVICE) as? KeyguardManager
                    keyguard?.requestDismissKeyguard(activity, null)
                }
            } else {
                @Suppress("DEPRECATION")
                val lockFlags = WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
                    WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON or
                    WindowManager.LayoutParams.FLAG_DISMISS_KEYGUARD

                if (showOverLockScreen) {
                    activity.window.addFlags(lockFlags)
                } else {
                    activity.window.clearFlags(lockFlags)
                }
            }

            // Separate from the lock screen: a video call is watched, and a
            // phone that dims halfway through one is a phone that has stopped
            // being a video call.
            if (keepAwake) {
                activity.window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
            } else {
                activity.window.clearFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
            }
        }
    }
}
