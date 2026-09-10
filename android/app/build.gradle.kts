import org.jetbrains.kotlin.gradle.dsl.JvmTarget

plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
}

android {
    namespace = "dev.kartpad.android" // JNI ABI: do not rename without rebuilding native code.
    compileSdk = 36
    buildToolsVersion = "36.0.0"
    defaultConfig {
        applicationId = "com.ast.kartpadandroid"
        minSdk = 29 // Must match the native ELF-TLS library set.
        // API 35 allows opting out of forced edge-to-edge on AAOS, including API 36 hosts.
        targetSdk = 35
        versionCode = 19
        versionName = "1.0"
        manifestPlaceholders["kartpadProfileable"] = "false"
        buildConfigField("boolean", "GAME_RUNTIME", "true")
        buildConfigField("boolean", "DISC_IMAGE_IMPORT", "true")
        ndk { abiFilters += "arm64-v8a" }
    }
    flavorDimensions += "platform"
    productFlavors {
        create("normal") {
            dimension = "platform"
            manifestPlaceholders["kartpadOrientation"] = "sensorLandscape"
        }
        create("automotive") {
            dimension = "platform"
            manifestPlaceholders["kartpadOrientation"] = "unspecified"
        }
    }
    buildTypes {
        getByName("release") {
            isMinifyEnabled = false // Preserve JNI names and SDL entry points.
        }
    }
    buildFeatures { buildConfig = true }
    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }
    packaging {
        jniLibs {
            useLegacyPackaging = false
            keepDebugSymbols += "**/*.so" // Already stripped, audited release binaries.
        }
    }
    lint {
        disable += setOf("AndroidGradlePluginVersion", "ChromeOsAbiSupport", "DiscouragedApi")
    }
}

kotlin { compilerOptions { jvmTarget.set(JvmTarget.JVM_17) } }

dependencies {
    implementation("androidx.work:work-runtime-ktx:2.11.1")
    testImplementation("junit:junit:4.13.2")
}

// Fail clearly if a transfer or antivirus has removed the actual game runtime.
val verifyNativeRuntime by tasks.registering {
    val binaries = listOf("libmain.so", "libSDL3.so", "libkartpad_discio.so", "libc++_shared.so")
    inputs.files(binaries.map { file("src/main/jniLibs/arm64-v8a/$it") })
    doLast {
        binaries.forEach { name ->
            check(file("src/main/jniLibs/arm64-v8a/$name").isFile) {
                "Missing $name. Extract the complete KartPad-AAOS-1.0 ZIP again."
            }
        }
    }
}
tasks.named("preBuild") { dependsOn(verifyNativeRuntime) }
