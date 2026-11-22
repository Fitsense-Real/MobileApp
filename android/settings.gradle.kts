pluginManagement {
    val flutterSdkPath = run {
        val properties = java.util.Properties()
        file("local.properties").inputStream().use { properties.load(it) }
        val flutterSdkPath = properties.getProperty("flutter.sdk")
        require(flutterSdkPath != null) { "flutter.sdk not set in local.properties" }
        flutterSdkPath
    }

    includeBuild("$flutterSdkPath/packages/flutter_tools/gradle")

    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }
}

plugins {
    id("dev.flutter.flutter-plugin-loader") version "1.0.0"
    id("com.android.application") version "9.3.1" apply false
    // One Kotlin Gradle Plugin version (2.4.20) for the Flutter plugins that still
    // apply kotlin-android themselves (as in the Flutter 3.50.1 template).
    id("org.jetbrains.kotlin.android") version "2.4.20" apply false
    // Firebase configuration (google-services.json of kora-fitpe) for push.
    id("com.google.gms.google-services") version "4.6.0" apply false
}

include(":app")
