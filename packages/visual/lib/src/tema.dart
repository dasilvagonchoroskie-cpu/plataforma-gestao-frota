import 'package:flutter/material.dart';

/// Cores tiradas da estrada: o verde das placas de sinalizacao, o amarelo
/// da faixa, o cinza do asfalto e do concreto.
class Paleta {
  static const verdePlaca = Color(0xFF0B5D3B);
  static const verdePlacaNoite = Color(0xFF0F6E47);
  static const amareloFaixa = Color(0xFFF2B300);
  static const asfalto = Color(0xFF1E2427);
  static const concreto = Color(0xFFF1F2EE);
  static const vermelhoPlaca = Color(0xFF9E2A22);
}

/// Cores com significado (positivo, negativo, atencao) e da placa.
@immutable
class CoresApp extends ThemeExtension<CoresApp> {
  const CoresApp({
    required this.placa,
    required this.placaTexto,
    required this.positivo,
    required this.negativo,
    required this.atencao,
    required this.atencaoFundo,
    required this.textoFraco,
    required this.divisor,
    required this.campoFundo,
  });

  final Color placa;
  final Color placaTexto;
  final Color positivo;
  final Color negativo;
  final Color atencao;
  final Color atencaoFundo;
  final Color textoFraco;
  final Color divisor;
  final Color campoFundo;

  static const claro = CoresApp(
    placa: Paleta.verdePlaca,
    placaTexto: Colors.white,
    positivo: Color(0xFF0A7343),
    negativo: Color(0xFFB3261E),
    atencao: Color(0xFF7A5200),
    atencaoFundo: Color(0xFFFFF1C7),
    textoFraco: Color(0xFF5B6560),
    divisor: Color(0xFFDCDFD8),
    campoFundo: Colors.white,
  );

  static const escuro = CoresApp(
    placa: Paleta.verdePlacaNoite,
    placaTexto: Colors.white,
    positivo: Color(0xFF5CD69A),
    negativo: Color(0xFFFF8A80),
    atencao: Color(0xFFFFD25E),
    atencaoFundo: Color(0xFF3A2F0E),
    textoFraco: Color(0xFF9AA59F),
    divisor: Color(0xFF2B322F),
    campoFundo: Color(0xFF1B211E),
  );

  @override
  CoresApp copyWith({
    Color? placa,
    Color? placaTexto,
    Color? positivo,
    Color? negativo,
    Color? atencao,
    Color? atencaoFundo,
    Color? textoFraco,
    Color? divisor,
    Color? campoFundo,
  }) =>
      CoresApp(
        placa: placa ?? this.placa,
        placaTexto: placaTexto ?? this.placaTexto,
        positivo: positivo ?? this.positivo,
        negativo: negativo ?? this.negativo,
        atencao: atencao ?? this.atencao,
        atencaoFundo: atencaoFundo ?? this.atencaoFundo,
        textoFraco: textoFraco ?? this.textoFraco,
        divisor: divisor ?? this.divisor,
        campoFundo: campoFundo ?? this.campoFundo,
      );

  @override
  CoresApp lerp(ThemeExtension<CoresApp>? other, double t) {
    if (other is! CoresApp) return this;
    return CoresApp(
      placa: Color.lerp(placa, other.placa, t)!,
      placaTexto: Color.lerp(placaTexto, other.placaTexto, t)!,
      positivo: Color.lerp(positivo, other.positivo, t)!,
      negativo: Color.lerp(negativo, other.negativo, t)!,
      atencao: Color.lerp(atencao, other.atencao, t)!,
      atencaoFundo: Color.lerp(atencaoFundo, other.atencaoFundo, t)!,
      textoFraco: Color.lerp(textoFraco, other.textoFraco, t)!,
      divisor: Color.lerp(divisor, other.divisor, t)!,
      campoFundo: Color.lerp(campoFundo, other.campoFundo, t)!,
    );
  }
}

extension CoresDoContexto on BuildContext {
  CoresApp get cores => Theme.of(this).extension<CoresApp>() ?? CoresApp.claro;
  TextTheme get textos => Theme.of(this).textTheme;
}

const fonteTexto = 'Barlow';
const fonteNumero = 'BarlowSemiCondensed';

/// Estilo para valores em dinheiro: numeros alinhados (tabulares).
TextStyle estiloNumero(double tamanho, {FontWeight peso = FontWeight.w600, Color? cor}) => TextStyle(
      fontFamily: fonteNumero,
      fontSize: tamanho,
      fontWeight: peso,
      color: cor,
      height: 1.1,
      fontFeatures: const [FontFeature.tabularFigures()],
    );

ThemeData _base(Brightness brilho) {
  final escuro = brilho == Brightness.dark;
  final cores = escuro ? CoresApp.escuro : CoresApp.claro;
  final fundo = escuro ? const Color(0xFF111513) : Paleta.concreto;
  final superficie = escuro ? const Color(0xFF181D1B) : Colors.white;
  final texto = escuro ? const Color(0xFFE6EAE7) : Paleta.asfalto;
  final primaria = escuro ? const Color(0xFF5CD69A) : Paleta.verdePlaca;

  final esquema = ColorScheme(
    brightness: brilho,
    primary: primaria,
    onPrimary: escuro ? const Color(0xFF00391F) : Colors.white,
    primaryContainer: escuro ? const Color(0xFF0F6E47) : const Color(0xFFD3EBDD),
    onPrimaryContainer: escuro ? Colors.white : const Color(0xFF06331F),
    secondary: escuro ? const Color(0xFFFFD25E) : const Color(0xFF7A5200),
    onSecondary: escuro ? const Color(0xFF2A1F00) : Colors.white,
    secondaryContainer: cores.atencaoFundo,
    onSecondaryContainer: cores.atencao,
    error: cores.negativo,
    onError: Colors.white,
    surface: superficie,
    onSurface: texto,
    onSurfaceVariant: cores.textoFraco,
    surfaceContainerLowest: superficie,
    surfaceContainerLow: superficie,
    surfaceContainer: escuro ? const Color(0xFF1D2320) : const Color(0xFFF7F8F5),
    surfaceContainerHigh: escuro ? const Color(0xFF222926) : const Color(0xFFEDEFEA),
    surfaceContainerHighest: escuro ? const Color(0xFF29302D) : const Color(0xFFE6E9E3),
    outline: escuro ? const Color(0xFF4A534F) : const Color(0xFFB9BEB6),
    outlineVariant: cores.divisor,
  );

  final base = ThemeData(
    useMaterial3: true,
    brightness: brilho,
    colorScheme: esquema,
    fontFamily: fonteTexto,
    scaffoldBackgroundColor: fundo,
    extensions: [cores],
  );

  final t = base.textTheme;
  final textTheme = t.copyWith(
    headlineMedium: t.headlineMedium?.copyWith(fontFamily: fonteNumero, fontWeight: FontWeight.w700, color: texto),
    headlineSmall: t.headlineSmall?.copyWith(fontFamily: fonteNumero, fontWeight: FontWeight.w700, color: texto),
    titleLarge: t.titleLarge?.copyWith(fontWeight: FontWeight.w600, fontSize: 22, color: texto),
    titleMedium: t.titleMedium?.copyWith(fontWeight: FontWeight.w600, fontSize: 17, color: texto),
    titleSmall: t.titleSmall?.copyWith(fontWeight: FontWeight.w600, fontSize: 15, color: texto),
    bodyLarge: t.bodyLarge?.copyWith(fontSize: 17, height: 1.35, color: texto),
    bodyMedium: t.bodyMedium?.copyWith(fontSize: 15, height: 1.35, color: texto),
    bodySmall: t.bodySmall?.copyWith(fontSize: 13.5, height: 1.3, color: cores.textoFraco),
    labelLarge: t.labelLarge?.copyWith(fontSize: 16, fontWeight: FontWeight.w600),
    labelMedium: t.labelMedium?.copyWith(fontSize: 13.5, fontWeight: FontWeight.w500),
  );

  final borda = OutlineInputBorder(
    borderRadius: BorderRadius.circular(10),
    borderSide: BorderSide(color: esquema.outline),
  );

  return base.copyWith(
    textTheme: textTheme,
    appBarTheme: AppBarThemeData(
      backgroundColor: fundo,
      foregroundColor: texto,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 1,
      centerTitle: false,
      titleTextStyle: TextStyle(fontFamily: fonteTexto, fontSize: 22, fontWeight: FontWeight.w600, color: texto),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: superficie,
      surfaceTintColor: Colors.transparent,
      indicatorColor: esquema.primaryContainer,
      height: 70,
      labelTextStyle: WidgetStateProperty.resolveWith(
        (s) => TextStyle(
          fontFamily: fonteTexto,
          fontSize: 13.5,
          fontWeight: s.contains(WidgetState.selected) ? FontWeight.w600 : FontWeight.w500,
          color: s.contains(WidgetState.selected) ? texto : cores.textoFraco,
        ),
      ),
      iconTheme: WidgetStateProperty.resolveWith(
        (s) => IconThemeData(
          color: s.contains(WidgetState.selected) ? esquema.onPrimaryContainer : cores.textoFraco,
        ),
      ),
    ),
    inputDecorationTheme: InputDecorationThemeData(
      filled: true,
      fillColor: cores.campoFundo,
      border: borda,
      enabledBorder: borda,
      focusedBorder: borda.copyWith(borderSide: BorderSide(color: esquema.primary, width: 2)),
      errorBorder: borda.copyWith(borderSide: BorderSide(color: cores.negativo)),
      focusedErrorBorder: borda.copyWith(borderSide: BorderSide(color: cores.negativo, width: 2)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
      labelStyle: TextStyle(color: cores.textoFraco, fontSize: 16),
      floatingLabelStyle: TextStyle(color: esquema.primary, fontSize: 16),
      helperStyle: TextStyle(color: cores.textoFraco, fontSize: 13),
      hintStyle: TextStyle(color: cores.textoFraco.withValues(alpha: 0.7)),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(64, 54),
        textStyle: const TextStyle(fontFamily: fonteTexto, fontSize: 17, fontWeight: FontWeight.w600),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(64, 52),
        textStyle: const TextStyle(fontFamily: fonteTexto, fontSize: 16, fontWeight: FontWeight.w600),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        side: BorderSide(color: esquema.outline),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        minimumSize: const Size(48, 48),
        textStyle: const TextStyle(fontFamily: fonteTexto, fontSize: 16, fontWeight: FontWeight.w600),
      ),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: escuro ? Paleta.verdePlacaNoite : Paleta.verdePlaca,
      foregroundColor: Colors.white,
      extendedTextStyle: const TextStyle(fontFamily: fonteTexto, fontSize: 16.5, fontWeight: FontWeight.w600),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: ButtonStyle(
        minimumSize: const WidgetStatePropertyAll(Size(48, 48)),
        textStyle: const WidgetStatePropertyAll(
          TextStyle(fontFamily: fonteTexto, fontSize: 15, fontWeight: FontWeight.w600),
        ),
      ),
    ),
    chipTheme: ChipThemeData(
      selectedColor: esquema.primaryContainer,
      labelStyle: TextStyle(fontFamily: fonteTexto, fontSize: 15, fontWeight: FontWeight.w500, color: texto),
      side: BorderSide(color: esquema.outline),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
    ),
    dividerTheme: DividerThemeData(color: cores.divisor, thickness: 1, space: 1),
    listTileTheme: ListTileThemeData(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20),
      iconColor: cores.textoFraco,
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: superficie,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: superficie,
      surfaceTintColor: Colors.transparent,
      showDragHandle: true,
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: escuro ? const Color(0xFFE6EAE7) : Paleta.asfalto,
      contentTextStyle: TextStyle(
        fontFamily: fonteTexto,
        fontSize: 15.5,
        color: escuro ? Paleta.asfalto : Colors.white,
      ),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? Colors.white : null),
      trackColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected) ? (escuro ? Paleta.verdePlacaNoite : Paleta.verdePlaca) : null,
      ),
    ),
  );
}

final temaClaro = _base(Brightness.light);
final temaEscuro = _base(Brightness.dark);
