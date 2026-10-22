plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "br.com.fortalezadigitalsecurity.gestaofrota.gestor"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "br.com.fortalezadigitalsecurity.gestaofrota.gestor"
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

    // Assinatura: a esteira deriva a chave da CHAVE_MESTRA (segredo do GitHub,
    // ferramentas/chaves/derivar.py) e passa o arquivo e a senha por variáveis
    // de ambiente; nada de chave ou senha fica no repositório. Sem elas (no
    // computador de quem desenvolve), a versão sai com a chave de depuração.
    val arquivoChave = System.getenv("FROTA_CHAVE_ARQUIVO")
    signingConfigs {
        if (arquivoChave != null) {
            create("frota") {
                storeFile = file(arquivoChave)
                storeType = "pkcs12"
                storePassword = System.getenv("FROTA_CHAVE_SENHA")
                keyAlias = "frota"
                keyPassword = System.getenv("FROTA_CHAVE_SENHA")
            }
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.findByName("frota") ?: signingConfigs.getByName("debug")
            // Encolhedor R8 ligado, com as regras de proguard-rules.pro para as
            // classes que o código nativo chama pelo nome. A esteira abre o APK
            // num emulador a cada versão para garantir que nada quebrou.
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro")
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
