# Regras do encolhedor R8 (versão de entrega).
# Classes chamadas pelo código nativo (JNI) ou por nome não podem ser
# renomeadas nem removidas: sem isto o app fecha na abertura.
-keep class com.github.dart_lang.jni.** { *; }
-keep class com.github.dart_lang.jni_flutter.** { *; }
-keep class dev.flutter.pigeon.** { *; }
-keep class io.flutter.plugins.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class androidx.datastore.** { *; }
# Tipos do Kotlin que aparecem nas assinaturas chamadas por JNI
# (shared_preferences_android: getAll(String, List, Continuation) etc.).
# Se forem renomeados, o método não é achado e o app fecha na abertura.
-keep class kotlin.Unit { *; }
-keep class kotlin.coroutines.** { *; }
-keep class kotlin.enums.** { *; }
-keep class kotlin.jvm.internal.DefaultConstructorMarker { *; }
# Referências opcionais do Flutter que não existem neste app.
-dontwarn com.google.android.play.core.**
