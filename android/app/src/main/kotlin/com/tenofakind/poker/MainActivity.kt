package com.tenofakind.poker

import android.content.pm.ActivityInfo
import android.os.Bundle
import android.view.WindowManager
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterFragmentActivity() {
    private val deviceControlChannel = "com.tenofakind.poker/device_control"

    override fun onCreate(savedInstanceState: Bundle?) {
        // The manifest declares sensorLandscape so the launch window is
        // already landscape before this runs. Without it the orientation is
        // only applied once this method executes, so cold-starting a phone
        // held in portrait shows a portrait splash that snaps round when
        // Flutter comes up.
        //
        // Phones keep that. Tablets hand orientation straight back to the
        // system, since they retain their normal choices outside the poker
        // table — applyGameSystemUi() re-applies landscape when the table
        // itself opens.
        requestedOrientation = if (resources.configuration.smallestScreenWidthDp < 600) {
            ActivityInfo.SCREEN_ORIENTATION_SENSOR_LANDSCAPE
        } else {
            ActivityInfo.SCREEN_ORIENTATION_UNSPECIFIED
        }
        super.onCreate(savedInstanceState)
        window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            deviceControlChannel,
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "useSensorLandscape" -> {
                    requestedOrientation = ActivityInfo.SCREEN_ORIENTATION_SENSOR_LANDSCAPE
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }
}
