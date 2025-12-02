import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Load keystore properties if present (do not commit key.properties)
val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

// Check if keystore file actually exists
val keystoreFile = if (keystorePropertiesFile.exists()) {
    val path = keystoreProperties["storeFile"] as? String
    if (path != null) rootProject.file("app/$path") else null
} else null
val useReleaseSigningConfig = keystoreFile?.exists() == true

android {
    signingConfigs {
        if (useReleaseSigningConfig) {
            create("release") {
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
                storeFile = keystoreFile
                storePassword = keystoreProperties["storePassword"] as String
            }
        }
    }

    namespace = "com.mcb.lxdklp.mcb"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.mcb.lxdklp.mcb"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            // Disable minification by default (adjust as needed)
            isMinifyEnabled = false
            // Disable resource shrinking when code shrinking is not enabled
            isShrinkResources = false
            // Use release signing config when keystore exists, otherwise fallback to debug
            signingConfig = if (useReleaseSigningConfig) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
        }
    }
}

flutter {
    source = "../.."
}
