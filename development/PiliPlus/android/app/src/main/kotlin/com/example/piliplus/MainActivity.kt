package com.example.piliplus

import android.content.res.Configuration
import android.os.Build
import android.os.Bundle
import android.graphics.Color
import android.view.View
import android.view.ViewGroup
import android.view.WindowInsets
import android.view.WindowInsetsController
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.view.WindowManager.LayoutParams
import com.ryanheise.audioservice.AudioServiceActivity

class MainActivity : AudioServiceActivity() {
    private var wasImeVisible = false
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "influence/updates").setMethodCallHandler { call, result ->
            if (call.method == "install") {
                val version = call.argument<Number>("versionCode")?.toLong()
                val hash = call.argument<String>("sha256")
                if (version == null || hash == null || !hash.matches(Regex("[a-fA-F0-9]{64}"))) {
                    result.error("invalid_update", "更新参数无效", null)
                } else {
                    org.influence.updates.AndroidUpdatesProvider.installVerified(version, hash) { error ->
                        if (error == null) result.success(null) else result.error("invalid_update", error, null)
                    }
                }
            } else result.notImplemented()
        }
        if (packageName == "local.muhuo.piliplus.phone") {
            flutterEngine.plugins.remove(com.github.rmtmckenzie.native_device_orientation.NativeDeviceOrientationPlugin::class.java)
        }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "bili/window").setMethodCallHandler { call, result ->
            if (call.method == "apply") { applyCanvasWindow(); result.success(null) }
            else result.notImplemented()
        }
    }

    @Suppress("DEPRECATION")
    private fun applyCanvasWindow() {
        window.statusBarColor = Color.TRANSPARENT
        window.navigationBarColor = Color.TRANSPARENT
        if (Build.VERSION.SDK_INT >= 28) window.navigationBarDividerColor = Color.TRANSPARENT
        if (Build.VERSION.SDK_INT >= 29) {
            window.isStatusBarContrastEnforced = false
            window.isNavigationBarContrastEnforced = false
        }
        if (Build.VERSION.SDK_INT >= 30) {
            window.setDecorFitsSystemWindows(false)
            window.insetsController?.apply {
                systemBarsBehavior = WindowInsetsController.BEHAVIOR_SHOW_TRANSIENT_BARS_BY_SWIPE
                hide(WindowInsets.Type.systemBars())
            }
        } else {
            window.decorView.systemUiVisibility = View.SYSTEM_UI_FLAG_LAYOUT_STABLE or View.SYSTEM_UI_FLAG_LAYOUT_FULLSCREEN or
                View.SYSTEM_UI_FLAG_LAYOUT_HIDE_NAVIGATION or View.SYSTEM_UI_FLAG_FULLSCREEN or
                View.SYSTEM_UI_FLAG_HIDE_NAVIGATION or View.SYSTEM_UI_FLAG_IMMERSIVE_STICKY
        }
        val screen = window.decorView.display
        val mode = screen?.mode
        // Ask for a high UI cadence. User refresh limits, battery and thermal policy
        // still decide the actual mode; do not latch an idle 60 Hz reading on resume.
        val rate = screen?.supportedModes?.filter {
            it.physicalWidth == mode?.physicalWidth && it.physicalHeight == mode?.physicalHeight
        }?.maxOfOrNull { it.refreshRate } ?: 0f
        window.attributes = window.attributes.apply { preferredRefreshRate = rate }
        if (Build.VERSION.SDK_INT >= 35) {
            fun request(view: View) {
                view.setRequestedFrameRate(View.REQUESTED_FRAME_RATE_CATEGORY_HIGH)
                if (view is ViewGroup) for (i in 0 until view.childCount) request(view.getChildAt(i))
            }
            request(window.decorView)
        }
    }

    override fun onWindowFocusChanged(hasFocus: Boolean) {
        super.onWindowFocusChanged(hasFocus)
        if (hasFocus) window.decorView.post { applyCanvasWindow() }
    }

    override fun onResume() {
        super.onResume()
        window.decorView.post { applyCanvasWindow() }
    }
    override fun onConfigurationChanged(newConfig: Configuration) {
        super.onConfigurationChanged(newConfig)
        if (AndroidHelper.isFoldable) {
            AndroidHelper.ToDart.onConfigurationChanged?.run()
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        window.decorView.post { applyCanvasWindow() }
        window.decorView.viewTreeObserver.addOnGlobalLayoutListener {
            if (Build.VERSION.SDK_INT >= 30) {
                val visible = window.decorView.rootWindowInsets?.isVisible(WindowInsets.Type.ime()) == true
                if (wasImeVisible && !visible) window.decorView.postDelayed({ applyCanvasWindow() }, 1100)
                wasImeVisible = visible
            }
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            window.attributes.layoutInDisplayCutoutMode =
                LayoutParams.LAYOUT_IN_DISPLAY_CUTOUT_MODE_SHORT_EDGES
        }
    }

    override fun onUserLeaveHint() {
        super.onUserLeaveHint()
        AndroidHelper.ToDart.onUserLeaveHint?.run()
    }

    override fun onPictureInPictureModeChanged(isInPictureInPictureMode: Boolean, newConfig: Configuration?) {
        super.onPictureInPictureModeChanged(isInPictureInPictureMode, newConfig)
        AndroidHelper.isPipMode = isInPictureInPictureMode
    }
}
