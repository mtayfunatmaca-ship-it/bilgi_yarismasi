// android/app/build.gradle.kts

import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    id("com.google.gms.google-services")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}

val keyProperties = Properties().apply {
    val keyPropertiesFile = rootProject.file("key.properties")
    if (keyPropertiesFile.exists()) {
        load(FileInputStream(keyPropertiesFile))
    }
}

android {
    namespace = "com.tayfunatmaca.bilgiyarismasi"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        // --- Java 8 Desugaring için ZORUNLU AYARLAR ---
        sourceCompatibility = JavaVersion.VERSION_1_8
        targetCompatibility = JavaVersion.VERSION_1_8
        isCoreLibraryDesugaringEnabled = true // Core Desugaring'i etkinleştir
    }

    kotlinOptions {
        // --- KRİTİK ÇÖZÜM: Kotlin'i Java 8'e eşitle ---
        jvmTarget = JavaVersion.VERSION_1_8.toString()
        // --- BİTTİ ---
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
            signingConfig = signingConfigs.getByName("release")
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    // Implementasyonu manuel Kotlin sürümüne değiştirildi (örn: 1.8.0)
    // Bu, 'kotlinVersion' değişkeni hatasını çözmelidir.
    implementation("org.jetbrains.kotlin:kotlin-stdlib-jdk8:1.8.0") 
    
    // Core Library Desugaring bağımlılığını ekler
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}