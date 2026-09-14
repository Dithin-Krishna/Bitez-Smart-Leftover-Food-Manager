plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.bitez_app"
    compileSdk = 36
    ndkVersion = flutter.ndkVersion

    compileOptions {
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "com.example.bitez_app"
        minSdk = flutter.minSdkVersion
        targetSdk = 36
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}

flutter {
    source = "../.."
}

val reversePortForward = tasks.register("reversePortForward") {
    doLast {
        try {
            ProcessBuilder("adb", "reverse", "tcp:3000", "tcp:3000").start()
            println("🔗 [Bitez] Reversed port: adb reverse tcp:3000 tcp:3000")
        } catch (_: Exception) {
            // Ignore if device not connected or adb not found
        }
    }
}

tasks.configureEach {
    if (name.contains("Debug", ignoreCase = true) &&
        (name.startsWith("assemble") || name.startsWith("install") || name.startsWith("flutterBuild"))) {
        dependsOn(reversePortForward)
    }
}

