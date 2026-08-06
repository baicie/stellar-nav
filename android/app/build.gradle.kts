plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val releaseSigningPropertyNames =
    listOf(
        "ASTRONAV_UPLOAD_STORE_FILE",
        "ASTRONAV_UPLOAD_STORE_PASSWORD",
        "ASTRONAV_UPLOAD_KEY_ALIAS",
        "ASTRONAV_UPLOAD_KEY_PASSWORD",
    )
val releaseSigningProperties =
    releaseSigningPropertyNames.associateWith { providers.gradleProperty(it).orNull }
val configuredReleaseSigningProperties =
    releaseSigningProperties.values.count { !it.isNullOrBlank() }
if (configuredReleaseSigningProperties !in setOf(0, releaseSigningPropertyNames.size)) {
    throw GradleException("Android release signing properties are only partially configured.")
}
val hasReleaseSigning = configuredReleaseSigningProperties == releaseSigningPropertyNames.size

android {
    namespace = "com.baicie.astro_nav"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "com.baicie.astro_nav"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (hasReleaseSigning) {
            create("release") {
                storeFile = file(releaseSigningProperties.getValue("ASTRONAV_UPLOAD_STORE_FILE")!!)
                storePassword =
                    releaseSigningProperties.getValue("ASTRONAV_UPLOAD_STORE_PASSWORD")
                keyAlias = releaseSigningProperties.getValue("ASTRONAV_UPLOAD_KEY_ALIAS")
                keyPassword = releaseSigningProperties.getValue("ASTRONAV_UPLOAD_KEY_PASSWORD")
            }
        }
    }

    buildTypes {
        getByName("release") {
            signingConfig =
                if (hasReleaseSigning) {
                    signingConfigs.getByName("release")
                } else {
                    null
                }
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}

tasks.configureEach {
    if (name in setOf("assembleRelease", "bundleRelease", "packageRelease")) {
        doFirst {
            if (!hasReleaseSigning) {
                throw GradleException(
                    "Android release builds require ASTRONAV_UPLOAD_* signing properties.",
                )
            }
        }
    }
}
