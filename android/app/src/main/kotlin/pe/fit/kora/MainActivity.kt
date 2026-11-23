package pe.fit.kora

import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // Perfil → Avisos en el teléfono: after the notification permission was
        // denied, Android only lets the user turn it on from the system settings.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "pe.fit.kora/settings").setMethodCallHandler { call, result ->
            if (call.method != "openNotificationSettings") return@setMethodCallHandler result.notImplemented()
            val intent = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS).putExtra(Settings.EXTRA_APP_PACKAGE, packageName)
            } else {
                Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS, Uri.fromParts("package", packageName, null))
            }
            try {
                startActivity(intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
                result.success(true)
            } catch (e: Exception) {
                result.success(false)
            }
        }
    }
}
