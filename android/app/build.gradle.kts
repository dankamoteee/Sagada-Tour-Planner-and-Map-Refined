plugins {
    id("com.android.application")
    id("com.google.gms.google-services") // Google Services plugin
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}

// ⭐️ 1. LOAD THE KEYSTORE PROPERTIES ⭐️
// This reads the file you just created to get the passwords
import java.util.Properties
import java.io.FileInputStream

val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

android {
    namespace = "com.example.sagadatourplannerandmap"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = "29.0.13846066"
    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        applicationId = "com.example.sagadatourplannerandmap"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    // ⭐️ 2. CONFIGURE SIGNING ⭐️
    signingConfigs {
        create("release") {
            keyAlias = keystoreProperties["keyAlias"] as String
            keyPassword = keystoreProperties["keyPassword"] as String
            storeFile = file(keystoreProperties["storeFile"] as String)
            storePassword = keystoreProperties["storePassword"] as String
        }
    }

    buildTypes {
        release {
            // ⭐️ 3. APPLY THE RELEASE SIGNING CONFIG ⭐️
            // This tells Gradle to use the "release" config we defined above
            signingConfig = signingConfigs.getByName("release")
            
            // Optional: Shrinking (set to true if you want to obfuscate code)
            isMinifyEnabled = false 
            isShrinkResources = false
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.0.4")
}