plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")
}

android {
    namespace = "com.example.flutter_application_1"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.example.flutter_application_1"
        // Firestore requires minSdk 23+.
        minSdk = maxOf(flutter.minSdkVersion, 23)
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        ndk {
            abiFilters += listOf("armeabi-v7a", "arm64-v8a")
        }
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
        }
    }

    packaging {
        jniLibs {
            useLegacyPackaging = true
        }
    }
}

dependencies {
    implementation("com.alphacephei:vosk-android:0.3.75") {
        exclude(group = "net.java.dev.jna", module = "jna")
    }
    implementation("net.java.dev.jna:jna:5.13.0@aar")
}

val sttCacheDirs = listOf(
    layout.projectDirectory.dir("stt-cache"),
    layout.projectDirectory.dir("build/stt-cache"),
)
val assetsDir = layout.projectDirectory.dir("src/main/assets")

fun findSttZip(name: String): File? {
    return sttCacheDirs.map { it.file(name).asFile }.firstOrNull { it.isFile && it.length() > 1_000_000 }
}

fun unpackVoskZip(zip: File, dest: File) {
    val ready = dest.resolve("am").exists() ||
        dest.listFiles()?.any { it.isDirectory && it.resolve("am").exists() } == true
    if (ready) return
    dest.mkdirs()
    copy {
        from(zipTree(zip))
        into(dest)
        includeEmptyDirs = false
    }
}

tasks.register("prepareSttModels") {
    doLast {
        val enZip = findSttZip("vosk-en.zip")
        val tlZip = findSttZip("vosk-tl.zip")
        if (enZip == null || tlZip == null) {
            logger.warn(
                "Offline STT models missing. Expected vosk-en.zip and vosk-tl.zip in android/app/stt-cache.",
            )
            return@doLast
        }
        unpackVoskZip(enZip, assetsDir.dir("model-en").asFile)
        unpackVoskZip(tlZip, assetsDir.dir("model-tl").asFile)
    }
}

tasks.matching { it.name == "preBuild" }.configureEach {
    dependsOn("prepareSttModels")
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}
