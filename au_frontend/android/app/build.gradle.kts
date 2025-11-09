plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.au_frontend"
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
        applicationId = "com.example.au_frontend"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("debug")
        }
    }

    // ✅ Add this block to rename your APK
    applicationVariants.all {
                outputs.all {
                    val appName = "Adamas_Attendance"
                    val variantName = name // e.g. "release"
                    val version = versionName

                    // Cast to ApkVariantOutput to access outputFileName
                    val outputImpl = this as com.android.build.gradle.internal.api.ApkVariantOutputImpl
                    outputImpl.outputFileName = "${appName}_${variantName}_v${version}.apk"

                    println("✅ APK renamed to: ${outputImpl.outputFileName}")
                }
            }

}

flutter {
    source = "../.."
}
