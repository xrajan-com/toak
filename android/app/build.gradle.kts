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

val appMinSdk = 23

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

    // Ensure google-services generated resources are merged (Flutter plugin can override sourceSets).
    sourceSets {
        getByName("debug").res.srcDir("$buildDir/generated/res/google-services/debug")
        getByName("release").res.srcDir("$buildDir/generated/res/google-services/release")
    }
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
