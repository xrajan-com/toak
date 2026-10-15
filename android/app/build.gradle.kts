import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
    // START: FlutterFire Configuration
    // Apply after Flutter plugin so generated res stay in the merged source sets.
    id("com.google.gms.google-services")
    // Required by firebase_crashlytics: without it the app stops at launch
    // with "The Crashlytics build ID is missing". Also uploads R8 mappings.
    id("com.google.firebase.crashlytics")
    // END: FlutterFire Configuration
}

val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}
val releaseSigningKeys = listOf("keyAlias", "keyPassword", "storeFile", "storePassword")
val hasReleaseSigning = releaseSigningKeys.all {
    keystoreProperties.getProperty(it)?.isNotBlank() == true
}

val appMinSdk = 24

android {
    namespace = "com.tenofakind.poker"
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
        applicationId = "com.tenofakind.poker"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = appMinSdk
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (hasReleaseSigning) {
            create("release") {
                keyAlias = keystoreProperties.getProperty("keyAlias")
                keyPassword = keystoreProperties.getProperty("keyPassword")
                storeFile = file(keystoreProperties.getProperty("storeFile"))
                storePassword = keystoreProperties.getProperty("storePassword")
            }
        }
    }

    buildTypes {
        release {
            if (hasReleaseSigning) {
                signingConfig = signingConfigs.getByName("release")
            }
        }
    }

    // google-services 4.4 registers its generated resources through the
    // variant API, so the old res.srcDir workaround for 4.3.10 is gone (it
    // would now add a second, stale copy of the same values).
}

dependencies {
    implementation("androidx.activity:activity-ktx:1.9.3")
    implementation("androidx.core:core-ktx:1.13.1")
    implementation("androidx.fragment:fragment-ktx:1.8.9")
}

// Ensure merge tasks wait for google-services resource generation.
afterEvaluate {
    listOf("Debug", "Release").forEach { variant ->
        tasks.matching { it.name in setOf(
            "map${variant}SourceSetPaths",
            "generate${variant}Resources",
            "merge${variant}Resources",
        ) }.configureEach {
            dependsOn("process${variant}GoogleServices")
        }
    }
}

flutter {
    source = "../.."
}
