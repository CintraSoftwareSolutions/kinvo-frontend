package com.example.kinvo

import android.app.NotificationChannel
import android.app.NotificationManager
import android.os.Build
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var ringtones: RingtoneBridge? = null
    private var callWindow: CallWindowBridge? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        createNotificationChannel()
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        val bridge = RingtoneBridge(applicationContext)
        bridge.attach(this)
        ringtones = bridge

        // Registered on the ACTIVITY, not the plugin registry, because the
        // ringtone chooser is an activity result and only an activity receives
        // one.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, RingtoneBridge.CHANNEL)
            .setMethodCallHandler(bridge)

        // Also the activity's, for the same reason: the window a call is
        // shown in belongs to it.
        val window = CallWindowBridge(applicationContext)
        window.attach(this)
        callWindow = window

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CallWindowBridge.CHANNEL)
            .setMethodCallHandler(window)
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: android.content.Intent?) {
        if (ringtones?.onActivityResult(requestCode, resultCode, data) == true) return
        super.onActivityResult(requestCode, resultCode, data)
    }

    override fun onDestroy() {
        // Releases the ringtone player: a call screen killed mid-ring would
        // otherwise leave the phone ringing with nothing on screen.
        ringtones?.detach()
        ringtones = null
        callWindow?.detach()
        callWindow = null
        super.onDestroy()
    }

    /**
     * Push notifications arrive on this channel, named in the manifest. Without
     * it Android files them under a "Miscellaneous" channel. Creating a channel
     * that already exists changes nothing, so this is safe on every launch.
     */
    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return

        val channel = NotificationChannel(
            getString(R.string.notification_channel_id),
            getString(R.string.notification_channel_name),
            NotificationManager.IMPORTANCE_HIGH,
        ).apply {
            description = getString(R.string.notification_channel_description)
        }
        getSystemService(NotificationManager::class.java)
            ?.createNotificationChannel(channel)
    }
}
