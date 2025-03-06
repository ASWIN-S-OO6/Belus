package com.nth.beluslauncher

import android.app.usage.UsageStatsManager
import android.content.Context
import android.content.Intent
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

class SystemMethodChannel(private val context: Context) : MethodChannel.MethodCallHandler {
    companion object {
        const val CHANNEL = "com.nth.beluslauncher/system"
    }

    fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler(this)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        try {
            when (call.method) {
                "goHome" -> {
                    val intent = Intent(Intent.ACTION_MAIN)
                    intent.addCategory(Intent.CATEGORY_HOME)
                    intent.flags = Intent.FLAG_ACTIVITY_NEW_TASK
                    context.startActivity(intent)
                    result.success(true)
                }
                "getForegroundApp" -> {
                    val packageName = getForegroundPackageName()
                    result.success(packageName)
                }
                "getCurrentVideoInfo" -> {
                    val videoInfo = YouTubeAccessibilityService.currentVideoInfo
                    result.success(videoInfo ?: "") // Ensure non-null response
                }
                else -> result.notImplemented()
            }
        } catch (e: Exception) {
            println("MethodChannel error: ${e.message}")
            result.error("METHOD_ERROR", e.message, null)
        }
    }

    private fun getForegroundPackageName(): String? {
        try {
            val usageStatsManager = context.getSystemService(Context.USAGE_STATS_SERVICE) as UsageStatsManager
            val time = System.currentTimeMillis()
            val usageStats = usageStatsManager.queryUsageStats(UsageStatsManager.INTERVAL_DAILY, time - 1000 * 60 * 60, time)
            return usageStats.maxByOrNull { it.lastTimeUsed }?.packageName
        } catch (e: Exception) {
            println("Error getting foreground app: ${e.message}")
            return null
        }
    }
}