plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "app.habit_adventure"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "app.habit_adventure"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        // Uses the version code from pubspec.yaml. When using split APKs, 1000 * ABI_VERSION
        // is added automatically by Flutter. (https://developer.android.com/studio/build/configure-apk-splits#configure-APK-versions)
        // You can force using the value of versionCode by specifying the `-P force-version-code-ignoring-abi=true`
        // flag during build.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    // A fixed key for personal sideloaded builds, kept in this private
    // repository, so every build installs over the last one and the data on
    // the device is kept (DESIGN §9.2). See DECISIONS.md D-34.
    signingConfigs {
        getByName("debug") {
            storeFile = file("personal-debug.p12")
            storePassword = "habitadventure"
            keyAlias = "personal"
            keyPassword = "habitadventure"
            storeType = "pkcs12"
        }
    }

    buildTypes {
        release {
            // The same fixed personal key as the debug build, so a release
            // build installs over a debug build (and back) and the data on
            // the device is kept. See DECISIONS.md D-34 and D-75.
            signingConfig = signingConfigs.getByName("debug")
            // The speed of a release build comes from the compiled Dart
            // code. Shrinking the small Android side as well would save
            // little and cannot be tried on a device from CI, so it is off.
            isMinifyEnabled = false
            isShrinkResources = false
            // The release build is for the phone: arm64 only. Without this
            // it would also carry the database library for two processors
            // the rest of the app is not built for.
            ndk {
                abiFilters.add("arm64-v8a")
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

dependencies {
    // FileProvider, for Settings > Share…. Already on the classpath through
    // the Flutter embedding; named here so the build does not rely on that.
    implementation("androidx.core:core:1.13.1")
    // @RequiresApi, for the Health Connect call that exists from Android 14.
    implementation("androidx.annotation:annotation:1.9.1")
}

