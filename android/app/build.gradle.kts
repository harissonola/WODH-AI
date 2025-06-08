// Déclaration des plugins pour l'application
plugins {
    id("com.android.application")
    id("kotlin-android")
    // Le plugin Flutter doit être appliqué après les plugins Android et Kotlin
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")
}

// Dépendances du projet
dependencies {
    // Importation de la BOM Firebase
    implementation(platform("com.google.firebase:firebase-bom:33.14.0"))

    // TODO: Ajouter les dépendances Firebase nécessaires
    // Avec la BOM, ne pas spécifier de versions pour les dépendances Firebase
    implementation("com.google.firebase:firebase-analytics")

    // Ajouter les dépendances pour d'autres produits Firebase si besoin
    // https://firebase.google.com/docs/android/setup#available-libraries
}

// Configuration Android
android {
    namespace = "com.example.wodh_ai"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = "27.0.12077973"  // Correction NDK

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        applicationId = "com.example.wodh_ai"
        minSdk = 23  // Augmenté à 23 pour Firebase Auth
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

// Configuration Flutter
flutter {
    source = "../.."
}