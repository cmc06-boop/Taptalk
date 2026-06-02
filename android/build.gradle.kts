import com.android.build.gradle.LibraryExtension
import org.jetbrains.kotlin.gradle.dsl.JvmTarget
import org.jetbrains.kotlin.gradle.tasks.KotlinCompile

allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val newBuildDir: Directory =
    rootProject.layout.buildDirectory
        .dir("../../build")
        .get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}
subprojects {
    project.evaluationDependsOn(":app")
}

// cloud_functions is Kotlin-only; with AGP 9+ the plugin skips kotlin-android
// and built-in Kotlin may not expose classes to GeneratedPluginRegistrant (Java).
subprojects {
    if (name == "cloud_functions") {
        if (!plugins.hasPlugin("org.jetbrains.kotlin.android")) {
            plugins.apply("org.jetbrains.kotlin.android")
        }
        tasks.withType<KotlinCompile>().configureEach {
            compilerOptions.jvmTarget.set(JvmTarget.JVM_17)
        }
    }
}

// telephony 0.2.0 is unmaintained; patch for AGP 9+ (namespace + JVM 17).
subprojects {
    if (name == "telephony") {
        if (!plugins.hasPlugin("org.jetbrains.kotlin.android")) {
            plugins.apply("org.jetbrains.kotlin.android")
        }
        afterEvaluate {
            extensions.findByType(LibraryExtension::class.java)?.apply {
                namespace = "com.shounakmulay.telephony"
                compileSdk = 36
                compileOptions {
                    sourceCompatibility = JavaVersion.VERSION_17
                    targetCompatibility = JavaVersion.VERSION_17
                }
            }
        }
        tasks.withType<KotlinCompile>().configureEach {
            compilerOptions.jvmTarget.set(JvmTarget.JVM_17)
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
