import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}

val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

android {
    namespace = "com.opjh.fileviewer"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlin {
    compilerOptions {
        jvmTarget.set(org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17)
    }
}


    defaultConfig {
        applicationId = "com.opjh.fileviewer"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName

        // LO AAR가 strippedUI flavor를 쓰는 쪽으로 고정
        missingDimensionStrategy("default", "strippedUI")
    }

    signingConfigs {
        create("release") {
            val keyAliasValue = keystoreProperties["keyAlias"]?.toString()
            val keyPasswordValue = keystoreProperties["keyPassword"]?.toString()
            val storeFileValue = keystoreProperties["storeFile"]?.toString()
            val storePasswordValue = keystoreProperties["storePassword"]?.toString()

            if (keyAliasValue != null) keyAlias = keyAliasValue
            if (keyPasswordValue != null) keyPassword = keyPasswordValue
            if (storeFileValue != null) storeFile = file(storeFileValue)
            if (storePasswordValue != null) storePassword = storePasswordValue
        }
    }

    buildTypes {
        getByName("release") {
            signingConfig = signingConfigs.getByName("release")
        }
    }
    repositories {
    flatDir {
        dirs("libs")
    }
}
}

dependencies {
    implementation(files("libs/lo-strippedUI-debug.aar"))

    implementation("androidx.constraintlayout:constraintlayout:2.1.4")
    implementation("com.google.android.material:material:1.12.0")
}




flutter {
    source = "../.."
}

allprojects {
    repositories {
        flatDir {
            dirs("app/libs")
        }
    }
}

