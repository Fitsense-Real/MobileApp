import java.io.FileInputStream
import java.net.URI
import java.util.Base64
import java.util.Properties

plugins {
    id("com.android.application")
    // AGP 9 built-in Kotlin (android.builtInKotlin=true): no kotlin-android here.
    // The Flutter Gradle Plugin must be applied after the Android plugin.
    id("dev.flutter.flutter-gradle-plugin")
}

// ---------------------------------------------------------------------------
// Release configuration for Google Play (docs/preparacion_google_play/).
//
// - Signing: android/key.properties (never versioned; see FIRMA_Y_AAB.md).
//   Without it, release builds fall back to the debug key, and the Play
//   bundle (bundleRelease) is refused.
// - Application ID: Gradle property kora.applicationId (pending the owner's
//   approval; IDENTIFICADOR_APLICACION.md). The Play bundle refuses
//   com.example.*.
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
val exampleApplicationId = "com.example.fitsense_mobile"
val koraApplicationId = (findProperty("kora.applicationId") as String?)?.trim()?.takeIf { it.isNotEmpty() } ?: exampleApplicationId

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
        if (koraApplicationId.startsWith("com.example")) problems += "applicationId de ejemplo ($koraApplicationId): define kora.applicationId con el identificador aprobado."
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
    namespace = "com.example.fitsense_mobile"
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
