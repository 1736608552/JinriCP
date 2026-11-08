package com.jinri.pureapp

import android.content.Context
import android.media.AudioManager
import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity: FlutterActivity() {
    private val CHANNEL = "com.jinri.pureapp/system_controls"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        val audioManager = getSystemService(Context.AUDIO_SERVICE) as AudioManager
        val methodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)

        methodChannel.setMethodCallHandler { call, result ->
            when (call.method) {
                // 🔒 屏幕常亮控制（彻底解决视频/直播播放过程中系统自动熄屏黑屏）
                "setKeepScreenOn" -> {
                    val keepOn = call.argument<Boolean>("keepOn") ?: true
                    if (keepOn) {
                        window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
                    } else {
                        window.clearFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
                    }
                    result.success(true)
                }

                // ☀️ 系统级屏幕背光亮度调节与还原（严格采用独立 LayoutParams 副本触发底层 SCREEN_BRIGHTNESS_CHANGED）
                "setBrightness" -> {
                    val brightness = call.argument<Double>("brightness") ?: 1.0
                    runOnUiThread {
                        try {
                            val newParams = WindowManager.LayoutParams()
                            newParams.copyFrom(window.attributes)
                            if (brightness < 0) {
                                newParams.screenBrightness = WindowManager.LayoutParams.BRIGHTNESS_OVERRIDE_NONE
                            } else {
                                newParams.screenBrightness = brightness.toFloat().coerceIn(0.01f, 1.0f)
                            }
                            window.attributes = newParams
                        } catch (e: Exception) {}
                    }
                    result.success(true)
                }
                "resetBrightness" -> {
                    runOnUiThread {
                        try {
                            val newParams = WindowManager.LayoutParams()
                            newParams.copyFrom(window.attributes)
                            newParams.screenBrightness = WindowManager.LayoutParams.BRIGHTNESS_OVERRIDE_NONE
                            window.attributes = newParams
                        } catch (e: Exception) {}
                    }
                    result.success(true)
                }
                "getBrightness" -> {
                    val layoutParams = window.attributes
                    if (layoutParams.screenBrightness >= 0) {
                        result.success(layoutParams.screenBrightness.toDouble())
                    } else {
                        try {
                            val sysBrightness = android.provider.Settings.System.getInt(
                                contentResolver,
                                android.provider.Settings.System.SCREEN_BRIGHTNESS
                            )
                            val ratio = (sysBrightness.toDouble() / 255.0).coerceIn(0.01, 1.0)
                            result.success(ratio)
                        } catch (e: Exception) {
                            result.success(0.5)
                        }
                    }
                }

                // 🔊 系统级全局媒体音量调节
                "setVolume" -> {
                    val volumeRatio = call.argument<Double>("volume") ?: 1.0
                    val maxVolume = audioManager.getStreamMaxVolume(AudioManager.STREAM_MUSIC)
                    val targetVolume = (volumeRatio * maxVolume).toInt().coerceIn(0, maxVolume)
                    audioManager.setStreamVolume(AudioManager.STREAM_MUSIC, targetVolume, 0)
                    result.success(true)
                }
                "getVolume" -> {
                    val currentVolume = audioManager.getStreamVolume(AudioManager.STREAM_MUSIC)
                    val maxVolume = audioManager.getStreamMaxVolume(AudioManager.STREAM_MUSIC)
                    val ratio = if (maxVolume > 0) currentVolume.toDouble() / maxVolume.toDouble() else 1.0
                    result.success(ratio)
                }

                // ℹ️ 获取当前安装的真实版本信息
                "getAppVersion" -> {
                    try {
                        val pInfo = if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.TIRAMISU) {
                            packageManager.getPackageInfo(packageName, android.content.pm.PackageManager.PackageInfoFlags.of(0))
                        } else {
                            packageManager.getPackageInfo(packageName, 0)
                        }
                        val vCode = if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.P) {
                            pInfo.longVersionCode
                        } else {
                            pInfo.versionCode.toLong()
                        }
                        result.success(mapOf(
                            "versionName" to (pInfo.versionName ?: "1.0.0"),
                            "versionCode" to vCode
                        ))
                    } catch (e: Exception) {
                        result.error("VERSION_ERROR", e.message, null)
                    }
                }

                // 📦 在线更新：获取安全下载目录
                "getDownloadDir" -> {
                    val dir = getExternalFilesDir(android.os.Environment.DIRECTORY_DOWNLOADS)?.absolutePath
                        ?: cacheDir.absolutePath
                    result.success(dir)
                }

                // 🚀 在线更新：安装 APK（基于 FileProvider 完美兼容 Android 7.0~14+）
                "installApk" -> {
                    val filePath = call.argument<String>("filePath")
                    if (filePath != null) {
                        try {
                            val file = java.io.File(filePath)
                            if (file.exists()) {
                                val intent = android.content.Intent(android.content.Intent.ACTION_VIEW)
                                intent.flags = android.content.Intent.FLAG_ACTIVITY_NEW_TASK
                                if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.N) {
                                    intent.flags = intent.flags or android.content.Intent.FLAG_GRANT_READ_URI_PERMISSION
                                    val contentUri = androidx.core.content.FileProvider.getUriForFile(
                                        this,
                                        "${applicationContext.packageName}.fileprovider",
                                        file
                                    )
                                    intent.setDataAndType(contentUri, "application/vnd.android.package-archive")
                                } else {
                                    intent.setDataAndType(android.net.Uri.fromFile(file), "application/vnd.android.package-archive")
                                }
                                startActivity(intent)
                                result.success(true)
                            } else {
                                result.error("FILE_NOT_FOUND", "APK 文件不存在: $filePath", null)
                            }
                        } catch (e: Exception) {
                            result.error("INSTALL_ERROR", e.message, null)
                        }
                    } else {
                        result.error("INVALID_PATH", "filePath is null", null)
                    }
                }

                // 🌐 系统浏览器打开链接
                "openUrl" -> {
                    val url = call.argument<String>("url")
                    if (url != null) {
                        try {
                            val intent = android.content.Intent(android.content.Intent.ACTION_VIEW, android.net.Uri.parse(url))
                            intent.flags = android.content.Intent.FLAG_ACTIVITY_NEW_TASK
                            startActivity(intent)
                            result.success(true)
                        } catch (e: Exception) {
                            result.error("OPEN_URL_ERROR", e.message, null)
                        }
                    } else {
                        result.error("INVALID_URL", "url is null", null)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    override fun onPause() {
        super.onPause()
        // ☀️ 爱奇艺级原生兜底：切后台/离开应用时，彻底清空窗口亮度覆盖，100% 自动还原系统默认背光
        try {
            val newParams = WindowManager.LayoutParams()
            newParams.copyFrom(window.attributes)
            if (newParams.screenBrightness >= 0) {
                newParams.screenBrightness = WindowManager.LayoutParams.BRIGHTNESS_OVERRIDE_NONE
                window.attributes = newParams
            }
        } catch (e: Exception) {}
    }
}
