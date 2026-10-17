plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "br.com.fortalezadigitalsecurity.gestaofrota.motorista"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "br.com.fortalezadigitalsecurity.gestaofrota.motorista"
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

    // Chave de TESTE (piloto): fica no repositório para todo APK da esteira
    // sair com a mesma assinatura e o motorista conseguir atualizar sem
    // desinstalar. Antes da Play Store troca pela chave de envio de verdade.
    signingConfigs {
        create("teste") {
            storeFile = file("chave-teste.jks")
            storePassword = "REMOVIDO"
            keyAlias = "teste"
            keyPassword = "REMOVIDO"
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("teste")
            // Sem o "encolhedor" R8: ele renomeia métodos que os plugins
            // (shared_preferences, path_provider) chamam por JNI, e o app
            // travava na abertura (NoSuchMethodError) só na versão de entrega.
            isMinifyEnabled = false
            isShrinkResources = false
        }
        debug {
            signingConfig = signingConfigs.getByName("teste")
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
