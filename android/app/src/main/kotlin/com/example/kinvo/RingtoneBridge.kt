package com.example.kinvo

import android.app.Activity
import android.content.Context
import android.content.Intent
import android.media.AudioAttributes
import android.media.AudioManager
import android.media.MediaPlayer
import android.media.RingtoneManager
import android.net.Uri
import android.os.Build
import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.PluginRegistry

/**
 * The ringtone a call rings with, and the picker that chooses it.
 *
 * Written here rather than taken from a package because what it does is short
 * and specific: open Android's own ringtone chooser, remember what came back,
 * and play it on a loop when a call arrives. A package would be a dependency
 * to keep up to date for forty lines of platform code.
 *
 * iOS has no equivalent. Apple only plays sounds bundled inside the app, so
 * the Dart side treats "no picker" as an answer rather than an error.
 */
class RingtoneBridge(
    private val context: Context,
) : MethodChannel.MethodCallHandler, PluginRegistry.ActivityResultListener {

    companion object {
        const val CHANNEL = "kinvo/ringtone"
        private const val PICK_REQUEST = 4671
    }

    private var activity: Activity? = null
    private var pendingPick: MethodChannel.Result? = null
    private var player: MediaPlayer? = null

    fun attach(activity: Activity) {
        this.activity = activity
    }

    fun detach() {
        activity = null
        stop()
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "pick" -> pick(call.argument<String>("current"), result)
            "titleOf" -> result.success(titleOf(call.argument<String>("uri")))
            "defaultTitle" -> result.success(titleOf(defaultRingtone().toString()))
            "play" -> {
                play(call.argument<String>("uri"), call.argument<Boolean>("vibrate") ?: true)
                result.success(null)
            }
            "stop" -> {
                stop()
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }

    /**
     * Opens Android's ringtone chooser.
     *
     * Only one pick can be in flight: a second would leave the first result
     * waiting forever, and a Dart future that never completes is a screen that
     * never stops spinning.
     */
    private fun pick(current: String?, result: MethodChannel.Result) {
        val activity = this.activity
        if (activity == null) {
            result.error("no_activity", "The app is not on screen.", null)
            return
        }

        if (pendingPick != null) {
            result.error("busy", "A ringtone is already being chosen.", null)
            return
        }

        val intent = Intent(RingtoneManager.ACTION_RINGTONE_PICKER).apply {
            putExtra(RingtoneManager.EXTRA_RINGTONE_TYPE, RingtoneManager.TYPE_RINGTONE)
            putExtra(RingtoneManager.EXTRA_RINGTONE_TITLE, "Call ringtone")
            putExtra(RingtoneManager.EXTRA_RINGTONE_SHOW_SILENT, false)
            putExtra(
                RingtoneManager.EXTRA_RINGTONE_EXISTING_URI,
                current?.let(Uri::parse) ?: defaultRingtone(),
            )
        }

        pendingPick = result
        activity.startActivityForResult(intent, PICK_REQUEST)
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?): Boolean {
        if (requestCode != PICK_REQUEST) return false

        val result = pendingPick ?: return true
        pendingPick = null

        if (resultCode != Activity.RESULT_OK) {
            // Backed out. Null means "kept what you had", which is different
            // from an error and the Dart side treats it that way.
            result.success(null)
            return true
        }

        val uri = data?.getParcelableExtra<Uri>(RingtoneManager.EXTRA_RINGTONE_PICKED_URI)
        if (uri == null) {
            result.success(null)
            return true
        }

        result.success(mapOf("uri" to uri.toString(), "title" to titleOf(uri.toString())))
        return true
    }

    /** The name to show for a chosen ringtone, or null if it has gone away. */
    private fun titleOf(uri: String?): String? {
        if (uri.isNullOrEmpty()) return null
        return try {
            RingtoneManager.getRingtone(context, Uri.parse(uri))?.getTitle(context)
        } catch (error: Exception) {
            // A ringtone on a removed SD card, or one whose permission has
            // lapsed. The setting still shows, with the system default.
            null
        }
    }

    private fun defaultRingtone(): Uri =
        RingtoneManager.getActualDefaultRingtoneUri(context, RingtoneManager.TYPE_RINGTONE)
            ?: RingtoneManager.getDefaultUri(RingtoneManager.TYPE_RINGTONE)

    /**
     * Rings, on a loop, on the RING stream — so the phone's silent and vibrate
     * modes decide whether anything is heard, exactly as for a real call. An
     * app that rings through a silent phone is an app people uninstall.
     */
    private fun play(uri: String?, vibrate: Boolean) {
        stop()

        val audio = context.getSystemService(Context.AUDIO_SERVICE) as? AudioManager
        val mode = audio?.ringerMode ?: AudioManager.RINGER_MODE_NORMAL

        if (vibrate && mode != AudioManager.RINGER_MODE_SILENT) {
            vibrate()
        }

        if (mode != AudioManager.RINGER_MODE_NORMAL) return

        val sound = if (uri.isNullOrEmpty()) defaultRingtone() else Uri.parse(uri)

        player = MediaPlayer().apply {
            try {
                setAudioAttributes(
                    AudioAttributes.Builder()
                        .setUsage(AudioAttributes.USAGE_NOTIFICATION_RINGTONE)
                        .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                        .build(),
                )
                setDataSource(context, sound)
                isLooping = true
                prepare()
                start()
            } catch (error: Exception) {
                // A ringtone that cannot be played must not stop the call from
                // arriving: the screen still appears, silently.
                release()
                player = null
            }
        }
    }

    private fun vibrate() {
        val pattern = longArrayOf(0, 900, 700)

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            val manager =
                context.getSystemService(Context.VIBRATOR_MANAGER_SERVICE) as? VibratorManager
            manager?.defaultVibrator?.vibrate(
                VibrationEffect.createWaveform(pattern, 0),
            )
            return
        }

        @Suppress("DEPRECATION")
        val vibrator = context.getSystemService(Context.VIBRATOR_SERVICE) as? Vibrator
        @Suppress("DEPRECATION")
        vibrator?.vibrate(pattern, 0)
    }

    private fun stop() {
        player?.let { active ->
            try {
                if (active.isPlaying) active.stop()
            } catch (error: IllegalStateException) {
                // Already stopped; releasing below is what matters.
            }
            active.release()
        }
        player = null

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            val manager =
                context.getSystemService(Context.VIBRATOR_MANAGER_SERVICE) as? VibratorManager
            manager?.defaultVibrator?.cancel()
        } else {
            @Suppress("DEPRECATION")
            (context.getSystemService(Context.VIBRATOR_SERVICE) as? Vibrator)?.cancel()
        }
    }
}
