package com.nicolasfrouin.allforgames

import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {
    // The in-app update (lib/update/update_backend_io.dart): the installed version, the folder
    // the APK is downloaded to, and the system installer.
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "all_for_games/update")
            .setMethodCallHandler { call, result ->
                try {
                    when (call.method) {
                        "versionName" -> result.success(versionName())
                        "updateFolder" -> result.success(updateFolder().path)
                        "install" -> {
                            install(File(call.argument<String>("path")!!))
                            result.success(null)
                        }
                        else -> result.notImplemented()
                    }
                } catch (e: Exception) {
                    result.error("update", e.toString(), null)
                }
            }
    }

    private fun versionName(): String? {
        val info = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            packageManager.getPackageInfo(packageName, PackageManager.PackageInfoFlags.of(0))
        } else {
            @Suppress("DEPRECATION")
            packageManager.getPackageInfo(packageName, 0)
        }
        return info.versionName
    }

    // The folder of res/xml/update_paths.xml: the FileProvider shares nothing else.
    private fun updateFolder() = File(cacheDir, "updates").apply { mkdirs() }

    // The installer first asks the player to allow installs from this app (Install unknown
    // apps), then replaces the app: same package, same signing key.
    private fun install(apk: File) {
        val uri = FileProvider.getUriForFile(this, "$packageName.update", apk)
        val intent = Intent(Intent.ACTION_VIEW)
            .setDataAndType(uri, "application/vnd.android.package-archive")
            .addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_ACTIVITY_NEW_TASK)
        startActivity(intent)
    }
}
