# Regras do encolhedor R8 (versão de entrega).
# Classes chamadas pelo código nativo (JNI) ou por nome não podem ser
# renomeadas nem removidas: sem isto o app fecha na abertura.
-keep class com.github.dart_lang.jni.** { *; }
-keep class com.github.dart_lang.jni_flutter.** { *; }
-keep class dev.flutter.pigeon.** { *; }
-keep class io.flutter.plugins.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class androidx.datastore.** { *; }
# Biblioteca do Kotlin inteira: o pacote jni procura classes dela pelo nome
# (kotlin/Result, kotlin/Unit, kotlin/coroutines/...) e o shared_preferences as
# usa nas assinaturas chamadas por JNI. Se forem renomeadas, o app fecha na
# abertura (NoSuchMethodError / ClassNotFoundException).
-keep class kotlin.** { *; }
# Referências opcionais do Flutter que não existem neste app.
-dontwarn com.google.android.play.core.**
