package com.example.arslan_medical_store

import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.PowerManager
import android.provider.Settings
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterFragmentActivity() {
    private val CHANNEL = "com.bismillahstore/settings_channel"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "getDeviceInfo" -> {
                    val info = mapOf(
                        "manufacturer" to Build.MANUFACTURER,
                        "model" to Build.MODEL,
                        "sdkInt" to Build.VERSION.SDK_INT,
                        "isSamsung" to Build.MANUFACTURER.equals("samsung", ignoreCase = true)
                    )
                    result.success(info)
                }
                "isIgnoringBatteryOptimizations" -> {
                    try {
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                            val powerManager = getSystemService(Context.POWER_SERVICE) as PowerManager
                            result.success(powerManager.isIgnoringBatteryOptimizations(packageName))
                        } else {
                            result.success(true)
                        }
                    } catch (e: Exception) {
                        result.success(false)
                    }
                }
                "openNotificationSettings" -> {
                    try {
                        val intent = Intent()
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                            intent.action = Settings.ACTION_APP_NOTIFICATION_SETTINGS
                            intent.putExtra(Settings.EXTRA_APP_PACKAGE, packageName)
                        } else {
                            intent.action = Settings.ACTION_APPLICATION_DETAILS_SETTINGS
                            intent.data = Uri.parse("package:$packageName")
                        }
                        intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        startActivity(intent)
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("INTENT_ERROR", e.message, null)
                    }
                }
                "openBatteryOptimizationSettings" -> {
                    val isSamsung = Build.MANUFACTURER.equals("samsung", ignoreCase = true)
                    var launched = false
                    var target = "dialog"

                    // Try direct package battery optimization request dialog if not already ignoring
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                        try {
                            val powerManager = getSystemService(Context.POWER_SERVICE) as PowerManager
                            if (!powerManager.isIgnoringBatteryOptimizations(packageName)) {
                                val requestIntent = Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS).apply {
                                    data = Uri.parse("package:$packageName")
                                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                                }
                                if (requestIntent.resolveActivity(packageManager) != null) {
                                    startActivity(requestIntent)
                                    launched = true
                                    target = "request_dialog"
                                }
                            }
                        } catch (_: Exception) {}
                    }

                    // Fallback to app details settings so user can tap Battery -> Unrestricted
                    if (!launched) {
                        try {
                            val appIntent = Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
                                data = Uri.parse("package:$packageName")
                                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                            }
                            if (appIntent.resolveActivity(packageManager) != null) {
                                startActivity(appIntent)
                                launched = true
                                target = "app_details"
                            }
                        } catch (e: Exception) {
                            result.error("INTENT_ERROR", "Could not open settings: ${e.message}", null)
                            return@setMethodCallHandler
                        }
                    }

                    result.success(mapOf(
                        "launched" to launched,
                        "target" to target,
                        "isSamsung" to isSamsung
                    ))
                }
                "openExactAlarmSettings" -> {
                    try {
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                            val intent = Intent(Settings.ACTION_REQUEST_SCHEDULE_EXACT_ALARM).apply {
                                data = Uri.parse("package:$packageName")
                                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                            }
                            if (intent.resolveActivity(packageManager) != null) {
                                startActivity(intent)
                                result.success(true)
                            } else {
                                // Fallback to general application details
                                val appIntent = Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
                                    data = Uri.parse("package:$packageName")
                                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                                }
                                startActivity(appIntent)
                                result.success(true)
                            }
                        } else {
                            result.success(true)
                        }
                    } catch (e: Exception) {
                        result.error("INTENT_ERROR", e.message, null)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }
}
