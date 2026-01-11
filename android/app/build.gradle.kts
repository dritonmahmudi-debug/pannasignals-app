import java.io.FileInputStream
import java.util.Properties

// Read android/key.properties (not checked into version control)
val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties = Properties()
if (keystorePropertiesFile.exists()) {
    FileInputStream(keystorePropertiesFile).use { keystoreProperties.load(it) }
}
plugins {
    id("com.android.application")
    id("kotlin-android")

    // 👇 Firebase / Google services plugin
    id("com.google.gms.google-services")
    // Firebase Crashlytics plugin for crash mapping uploads
    id("com.google.firebase.crashlytics")
    
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.pannasignals.app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        // Application ID (matches Firebase config)
        applicationId = "com.pannasignals.app"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = 1 // Set to a valid integer. Update as needed for releases.
        versionName = flutter.versionName
    }

    signingConfigs {
        create("release") {
            if (keystoreProperties.isNotEmpty()) {
                keyAlias = keystoreProperties["keyAlias"] as String? ?: ""
                keyPassword = keystoreProperties["keyPassword"] as String? ?: ""
                storeFile = file(keystoreProperties["storeFile"] as String? ?: "keystore.jks")
                storePassword = keystoreProperties["storePassword"] as String? ?: ""
            }
        }
    }

    buildTypes {
        release {
            // Use a release signing config if available, otherwise keep debug for local testing.
            try {
                signingConfig = signingConfigs.getByName("release")
            } catch (e: Exception) {
                signingConfig = signingConfigs.getByName("debug")
            }
        }
    }
}

flutter {
    source = "../.."
}

// imports were moved to the file top; duplicates removed