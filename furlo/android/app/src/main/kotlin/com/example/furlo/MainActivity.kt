package com.example.furlo

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.util.TimeZone

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "furlo/device_timezone")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "getLocalTimeZone" -> result.success(TimeZone.getDefault().id)
                    else -> result.notImplemented()
                }
            }
    }
}
