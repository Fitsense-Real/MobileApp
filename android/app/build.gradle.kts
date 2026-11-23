import java.io.FileInputStream
import java.net.URI
import java.util.Base64
import java.util.Properties

plugins {
    id("com.android.application")
    // AGP 9 built-in Kotlin (android.builtInKotlin=true): no kotlin-android here.
    // The Flutter Gradle Plugin must be applied after the Android plugin.
    id("dev.flutter.flutter-gradle-plugin")
    // On the classpath always; applied below only when google-services.json exists.
    id("com.google.gms.google-services") apply false
}

// ---------------------------------------------------------------------------
// Release configuration for Google Play (docs/preparacion_google_play/).
//
// - Signing: android/key.properties (never versioned; see FIRMA_Y_AAB.md).
//   Without it, release builds fall back to the debug key, and the Play
//   bundle (bundleRelease) is refused.
// - Application ID: pe.fit.kora, approved by the owner and registered in the
//   Firebase project kora-fitpe. It is permanent once uploaded to Play. The
//   Gradle property kora.applicationId may override it for a local test build,
//   but the Play bundle only accepts the approved ID (and never com.example.*).
// - Firebase (push): android/app/google-services.json from FlutterFire for
//   kora-fitpe. The Google Services plugin is applied when the file exists, so
//   a checkout without it still builds and tests; the Play bundle requires it
//   and checks it belongs to the approved ID (docs/push/).
// - Backend: every release build needs --dart-define=API_BASE_URL with a
//   public https:// URL (CONFIGURACION_BACKEND_HTTPS.md).
// - Play bundle: account deletion enabled and public https pages for deletion
//   and privacy (ELIMINACION_CUENTA_FLUTTER.md).
// ---------------------------------------------------------------------------
val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties = Properties().apply {
    if (keystorePropertiesFile.exists()) FileInputStream(keystorePropertiesFile).use { load(it) }
}
val hasReleaseKey = keystorePropertiesFile.exists()
/** Android application ID approved for Kora (IDENTIFICADOR_APLICACION.md). */
val approvedApplicationId = "pe.fit.kora"
val koraApplicationId = (findProperty("kora.applicationId") as String?)?.trim()?.takeIf { it.isNotEmpty() } ?: approvedApplicationId
val googleServicesFile = file("google-services.json")
val hasGoogleServices = googleServicesFile.exists()
// Firebase configuration for push (kora-fitpe). Applied only when the file is
// present: CI and fresh checkouts without it keep building (push stays off).
if (hasGoogleServices) apply(plugin = "com.google.gms.google-services")

/** Values passed with --dart-define (Flutter hands them to Gradle base64-encoded). */
fun dartDefines(): Map<String, String> =
    (findProperty("dart-defines") as String?).orEmpty().split(",").filter { it.isNotBlank() }.mapNotNull {
        val decoded = String(Base64.getDecoder().decode(it))
        val i = decoded.indexOf('=')
        if (i <= 0) null else decoded.substring(0, i) to decoded.substring(i + 1)
    }.toMap()

fun isLocalHost(host: String): Boolean {
    val h = host.lowercase()
    if (h == "localhost" || h.endsWith(".localhost") || h.endsWith(".local") || h == "0.0.0.0" || h == "::1" || h == "[::1]") return true
    val ip = Regex("""^(\d+)\.(\d+)\.(\d+)\.(\d+)$""").matchEntire(h) ?: return false
    val a = ip.groupValues[1].toInt()
    val b = ip.groupValues[2].toInt()
    return a == 127 || a == 10 || (a == 192 && b == 168) || (a == 172 && b in 16..31) || (a == 169 && b == 254) || a == 0
}

/** Reserved test names: only with -Pkora.testBackendUrl=true, never for Play. */
fun isTestHost(host: String): Boolean = host.lowercase().let { it.endsWith(".invalid") || it.endsWith(".test") || it.endsWith(".example") }

gradle.taskGraph.whenReady {
    val names = allTasks.map { it.name }
    val release = names.any { it == "assembleRelease" || it == "bundleRelease" }
    val playBundle = names.contains("bundleRelease")
    if (!release) return@whenReady
    val problems = mutableListOf<String>()
    val defines = dartDefines()
    val testUrlAllowed = (findProperty("kora.testBackendUrl") as String?) == "true"
    // Android lint (lintVital*Release, never skipped) crashes on JDK 17 while
    // analysing firebase_core (List.removeLast is JDK 21 API). Fail early with a clear message instead.
    if (!JavaVersion.current().isCompatibleWith(JavaVersion.VERSION_21)) problems += "Las compilaciones release necesitan JDK 21 (el de Android Studio); Gradle usa JDK ${JavaVersion.current()}. Configuralo con: flutter config --jdk-dir=<ruta del JDK 21>."
    val url = defines["API_BASE_URL"].orEmpty().trim()
    val uri = runCatching { URI(url) }.getOrNull()
    when {
        url.isEmpty() -> problems += "Falta --dart-define=API_BASE_URL=https://... (URL HTTPS del backend de produccion)."
        uri == null || uri.host.isNullOrEmpty() -> problems += "API_BASE_URL no es una URL valida: $url"
        uri.scheme != "https" -> problems += "API_BASE_URL debe usar https:// en release: $url"
        isLocalHost(uri.host) -> problems += "API_BASE_URL no puede ser una direccion local o del emulador en release: ${uri.host}"
        isTestHost(uri.host) && !testUrlAllowed -> problems += "API_BASE_URL usa un dominio reservado de prueba (${uri.host}); solo se admite con -Pkora.testBackendUrl=true y nunca para Play."
    }
    if (playBundle) {
        if (!hasReleaseKey) problems += "Falta android/key.properties: el AAB para Google Play no se firma con la clave debug."
        if (koraApplicationId.startsWith("com.example")) problems += "applicationId de ejemplo ($koraApplicationId): quita kora.applicationId; el aprobado ($approvedApplicationId) es el valor por defecto."
        else if (koraApplicationId != approvedApplicationId) problems += "applicationId ($koraApplicationId) distinto del aprobado para Kora ($approvedApplicationId); en Play es permanente."
        // Push notifications: the Play build must carry the Firebase config of the approved app.
        if (!hasGoogleServices) problems += "Falta android/app/google-services.json (Firebase kora-fitpe, generado con FlutterFire): sin ese archivo no hay notificaciones push."
        else if (!Regex("\"package_name\"\\s*:\\s*\"${Regex.escape(koraApplicationId)}\"").containsMatchIn(googleServicesFile.readText())) problems += "android/app/google-services.json no contiene la app Android $koraApplicationId (proyecto Firebase equivocado o desactualizado)."
        // Google Play: account deletion inside the app, a public web page to
        // request it, and a privacy policy (ELIMINACION_CUENTA_FLUTTER.md).
        if (defines["ACCOUNT_DELETION_ENABLED"] != "true") problems += "La eliminacion de cuenta esta desactivada: Play exige poder borrar la cuenta desde la app (ACCOUNT_DELETION_ENABLED=true cuando DELETE /users/me este en servicio)."
        for (key in listOf("ACCOUNT_DELETION_WEB_URL", "PRIVACY_POLICY_URL")) {
            val link = defines[key].orEmpty().trim()
            if (!link.startsWith("https://")) problems += "Falta --dart-define=$key=https://... (pagina publica exigida por Google Play)."
        }
        if (testUrlAllowed) logger.warn("AVISO: AAB con URL de prueba (kora.testBackendUrl=true). Es solo para verificar el empaquetado: NO es publicable.")
    }
    if (problems.isNotEmpty()) {
        throw GradleException(
            "Compilacion release bloqueada (docs/preparacion_google_play/):\n - " + problems.joinToString("\n - ")
        )
    }
}

android {
    namespace = "pe.fit.kora"
    // compileSdk 37: flutter_local_notifications 23 compiles against API 37 and
    // its AAR metadata requires the app to do the same. Compile-time only: the
    // runtime behaviour is set by targetSdk, which stays at 36.
    compileSdk = 37
    // flutter_local_notifications, flutter_secure_storage and path_provider_android
    // require NDK 28.2 with Flutter 3.50 (backward compatible; Flutter's default).
    ndkVersion = "28.2.13676358"

    compileOptions {
        // Required by flutter_local_notifications for scheduled notifications.
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    defaultConfig {
        // Pending the owner's approval: set kora.applicationId (IDENTIFICADOR_APLICACION.md).
        applicationId = koraApplicationId
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        // Google Play requires targetSdk 36 (Android 16) for new apps and updates since
        // 31/08/2026. Set explicitly so a Flutter default change can never lower it.
        targetSdk = 36
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (hasReleaseKey) {
            create("release") {
                keyAlias = keystoreProperties.getProperty("keyAlias")
                keyPassword = keystoreProperties.getProperty("keyPassword")
                storeFile = keystoreProperties.getProperty("storeFile")?.let { file(it) }
                storePassword = keystoreProperties.getProperty("storePassword")
            }
        }
    }

    buildTypes {
        release {
            // Own upload key from android/key.properties. The debug key is only a
            // fallback for local evaluation APKs; bundleRelease refuses it.
            signingConfig = if (hasReleaseKey) signingConfigs.getByName("release") else signingConfigs.getByName("debug")
        }
    }
}

// kotlinOptions {} was removed in Kotlin 2.4; same JVM target as Java (11).
kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_11
    }
}

flutter {
    source = "../.."
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}
