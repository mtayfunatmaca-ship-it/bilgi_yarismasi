// --- 1. DEĞİŞİKLİK: Eksik import'lar eklendi ---
// BU İKİ SATIR DOĞRU VE KALMALI
import java.util.Properties
import java.io.FileInputStream
// --- DEĞİŞİKLİK BİTTİ ---

plugins {
    id("com.android.application")
    id("com.google.gms.google-services")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Bu blok, "key.properties" dosyasını okur
val keyProperties = Properties().apply {
    val keyPropertiesFile = rootProject.file("key.properties") // Proje kök dizinine bakar
    if (keyPropertiesFile.exists()) {
        load(FileInputStream(keyPropertiesFile))
    }
}

android {
    namespace = "com.tayfunatmaca.bilgiyarismasi"
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
        applicationId = "com.tayfunatmaca.bilgiyarismasi"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("release") {
            // --- Burası key.properties'ten değerleri güvenle yükler ---
            val storeFilePath = keyProperties["storeFile"] as? String
            if (!storeFilePath.isNullOrBlank()) {
                storeFile = file(storeFilePath.replace("\\", "/"))
            }

            keyAlias = keyProperties["keyAlias"] as? String ?: ""
            keyPassword = keyProperties["keyPassword"] as? String ?: ""
            storePassword = keyProperties["storePassword"] as? String ?: ""
        }
    }

    buildTypes {
        getByName("release") {
            signingConfig = signingConfigs.getByName("release")
            isMinifyEnabled = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
        getByName("debug") {
            // Debug'da da aynı anahtar kullanılacak
            signingConfig = signingConfigs.getByName("release")
        }
    }
}

flutter {
    source = "../.."
}