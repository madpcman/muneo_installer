import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
val keystorePropertiesExampleFile = rootProject.file("key.properties.example")
val activeKeystorePropertiesFile = when {
    keystorePropertiesFile.exists() -> keystorePropertiesFile
    keystorePropertiesExampleFile.exists() -> keystorePropertiesExampleFile
    else -> null
}
if (activeKeystorePropertiesFile != null) {
    activeKeystorePropertiesFile.inputStream().use { keystoreProperties.load(it) }
}

android {
    namespace = "kr.co.grib.claix"
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
        applicationId = "kr.co.grib.claix"
        minSdk = flutter.minSdkVersion
        targetSdk = 35
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    sourceSets {
        getByName("main") {
            // Package JNI libs from app-local directory.
            jniLibs.srcDirs("src/main/jniLibs")
        }
    }

    signingConfigs {
        create("release") {
            val storeFilePath = keystoreProperties.getProperty("storeFile")
                ?: throw GradleException("Missing Android release signing config: add storeFile to android/key.properties or android/key.properties.example")
            val storePasswordValue = keystoreProperties.getProperty("storePassword")
                ?: throw GradleException("Missing Android release signing config: add storePassword to android/key.properties or android/key.properties.example")
            val keyAliasValue = keystoreProperties.getProperty("keyAlias")
                ?: throw GradleException("Missing Android release signing config: add keyAlias to android/key.properties or android/key.properties.example")
            val keyPasswordValue = keystoreProperties.getProperty("keyPassword")
                ?: throw GradleException("Missing Android release signing config: add keyPassword to android/key.properties or android/key.properties.example")

            val invalidPlaceholderValues = setOf(
                "YOUR_STORE_PASSWORD",
                "YOUR_KEY_ALIAS",
                "YOUR_KEY_PASSWORD",
            )
            if (storePasswordValue in invalidPlaceholderValues ||
                keyAliasValue in invalidPlaceholderValues ||
                keyPasswordValue in invalidPlaceholderValues
            ) {
                throw GradleException("Android release signing config still contains placeholder values. Update android/key.properties or android/key.properties.example")
            }

            storeFile = rootProject.file(storeFilePath)
            if (!storeFile!!.exists()) {
                throw GradleException("Android release keystore file not found: $storeFilePath")
            }
            storePassword = storePasswordValue
            keyAlias = keyAliasValue
            keyPassword = keyPasswordValue
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("release")
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    // CardView dependency (Kotlin DSL)
    implementation("androidx.cardview:cardview:1.0.0")
    implementation("com.caverock:androidsvg:1.4")
}

val syncTurboJpegJniLibs by tasks.registering(Copy::class) {
    val turboJpegRoot = file("../../third_party/libjpeg-turbo/android")
    from(turboJpegRoot) {
        include("**/*.so")
    }
    into(file("src/main/jniLibs"))
    includeEmptyDirs = false
}

tasks.named("preBuild") {
    dependsOn(syncTurboJpegJniLibs)
}

