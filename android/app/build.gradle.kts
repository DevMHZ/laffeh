import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Load Google Maps key from android/local.properties first, then fall back to root .env.
val mapsKey: String = run {
    val localProps = Properties()
    val lp = rootProject.file("local.properties")
    if (lp.exists()) {
        FileInputStream(lp).use { localProps.load(it) }
    }
    var key = localProps.getProperty("GOOGLE_MAPS_API_KEY") ?: ""

    if (key.isBlank()) {
        val envFile = rootProject.file("../.env")
        if (envFile.exists()) {
            envFile.readLines().forEach { line ->
                val trimmed = line.trim()
                if (trimmed.startsWith("GOOGLE_MAPS_API_KEY=")) {
                    key = trimmed.substringAfter("=").trim()
                }
            }
        }
    }
    if (key.isBlank()) "YOUR_GOOGLE_MAPS_API_KEY_HERE" else key
}

android {
    namespace = "com.example.laffeh"
    compileSdk = flutter.compileSdkVersion
    // Pinned to satisfy geolocator / google_maps_flutter / permission_handler /
    // flutter_plugin_android_lifecycle / geocoding (all require 27.0.12077973).
    ndkVersion = "27.0.12077973"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        applicationId = "com.example.laffeh"
        // google_maps_flutter requires minSdk 21+
        minSdk = 21
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName

        manifestPlaceholders["GOOGLE_MAPS_API_KEY"] = mapsKey
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."
}
