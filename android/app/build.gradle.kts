import java.io.FileInputStream
import java.util.Properties
import org.gradle.api.GradleException

plugins {
    id("com.android.application")
    id("com.google.gms.google-services")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    FileInputStream(keystorePropertiesFile).use { keystoreProperties.load(it) }
}

fun releaseSigningValue(environmentName: String, propertyName: String): String? =
    System.getenv(environmentName)?.takeIf { it.isNotBlank() }
        ?: keystoreProperties.getProperty(propertyName)?.takeIf { it.isNotBlank() }

val releaseStoreFile = releaseSigningValue("BTW_UPLOAD_KEYSTORE", "storeFile")
val releaseStorePassword = releaseSigningValue("BTW_UPLOAD_STORE_PASSWORD", "storePassword")
val releaseKeyAlias = releaseSigningValue("BTW_UPLOAD_KEY_ALIAS", "keyAlias")
val releaseKeyPassword = releaseSigningValue("BTW_UPLOAD_KEY_PASSWORD", "keyPassword")

// Never produce a Play bundle with the development/debug signing key.
if (gradle.startParameter.taskNames.any { it.contains("Release", ignoreCase = true) }) {
    val missing = listOf(
        "storeFile" to releaseStoreFile,
        "storePassword" to releaseStorePassword,
        "keyAlias" to releaseKeyAlias,
        "keyPassword" to releaseKeyPassword,
    ).filter { it.second.isNullOrBlank() }.map { it.first }
    if (missing.isNotEmpty()) {
        throw GradleException("Release signing is not configured: missing ${missing.joinToString()}. Use scripts/build_android_release.sh or android/key.properties.")
    }
    if (!file(releaseStoreFile!!).isFile) {
        throw GradleException("Release signing keystore file does not exist.")
    }
}

android {
    namespace = "com.dashay.bitetheway"
    compileSdk = 36
    ndkVersion = flutter.ndkVersion

    compileOptions {
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "com.dashay.bitetheway"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("release") {
            keyAlias = releaseKeyAlias
            keyPassword = releaseKeyPassword
            storeFile = releaseStoreFile?.let { file(it) }
            storePassword = releaseStorePassword
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("release")
        }
    }
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.5")
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}
