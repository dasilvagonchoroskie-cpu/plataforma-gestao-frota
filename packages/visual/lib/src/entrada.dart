import 'package:flutter/services.dart';
import 'package:nucleo/nucleo.dart';

String _soDigitos(String s) => s.replaceAll(RegExp(r'[^0-9]'), '');

TextEditingValue _comCursorNoFim(String texto) => TextEditingValue(
      text: texto,
      selection: TextSelection.collapsed(offset: texto.length),
    );

/// Dinheiro digitado da direita para a esquerda, como em app de banco:
/// 1 -> 0,01 / 1550 -> 15,50 / 123456 -> 1.234,56
class FormatadorDinheiro extends TextInputFormatter {
  const FormatadorDinheiro();

  @override
  TextEditingValue formatEditUpdate(TextEditingValue antigo, TextEditingValue novo) {
    var digitos = _soDigitos(novo.text);
    if (digitos.length > 11) digitos = digitos.substring(0, 11);
    digitos = digitos.replaceFirst(RegExp(r'^0+'), '');
    if (digitos.isEmpty) return _comCursorNoFim('');
    return _comCursorNoFim(dinheiro(int.parse(digitos)));
  }
}

/// Número inteiro com ponto de milhar: 33040 -> 33.040
class FormatadorInteiro extends TextInputFormatter {
  const FormatadorInteiro({this.maxDigitos = 9});
  final int maxDigitos;

  @override
  TextEditingValue formatEditUpdate(TextEditingValue antigo, TextEditingValue novo) {
    var digitos = _soDigitos(novo.text);
    if (digitos.length > maxDigitos) digitos = digitos.substring(0, maxDigitos);
    digitos = digitos.replaceFirst(RegExp(r'^0+(?=\d)'), '');
    if (digitos.isEmpty) return _comCursorNoFim('');
    return _comCursorNoFim(semCasas(double.parse(digitos)));
  }
}

/// Número com vírgula decimal livre: 350,5 / 12,5. Ponto vira vírgula.
class FormatadorDecimal extends TextInputFormatter {
  const FormatadorDecimal({this.casas = 2, this.maxInteiros = 6});
  final int casas;
  final int maxInteiros;

  @override
  TextEditingValue formatEditUpdate(TextEditingValue antigo, TextEditingValue novo) {
    var t = novo.text.replaceAll('.', ',').replaceAll(RegExp(r'[^0-9,]'), '');
    final i = t.indexOf(',');
    String inteiro;
    String? fracao;
    if (i >= 0) {
      inteiro = t.substring(0, i);
      fracao = t.substring(i + 1).replaceAll(',', '');
      if (fracao.length > casas) fracao = fracao.substring(0, casas);
      if (inteiro.isEmpty) inteiro = '0';
    } else {
      inteiro = t;
    }
    if (inteiro.length > maxInteiros) inteiro = inteiro.substring(0, maxInteiros);
    if (inteiro.length > 1) inteiro = inteiro.replaceFirst(RegExp(r'^0+(?=\d)'), '');
    return _comCursorNoFim(fracao == null ? inteiro : '$inteiro,$fracao');
  }
}

/// Máscara do campo de placa: só letras e números, em maiúsculas, até 7.
class FormatadorPlaca extends TextInputFormatter {
  const FormatadorPlaca();

  @override
  TextEditingValue formatEditUpdate(TextEditingValue antigo, TextEditingValue novo) {
    var p = normalizarPlaca(novo.text);
    if (p.length > 7) p = p.substring(0, 7);
    return _comCursorNoFim(placaTexto(p));
  }
}

/// CPF com pontos e traço enquanto digita: 529.982.247-25
class FormatadorCpf extends TextInputFormatter {
  const FormatadorCpf();

  @override
  TextEditingValue formatEditUpdate(TextEditingValue antigo, TextEditingValue novo) =>
      _comCursorNoFim(cpfTexto(novo.text));
}

/// Código da empresa: 6 letras e números, em maiúsculas.
class FormatadorCodigo extends TextInputFormatter {
  const FormatadorCodigo();

  @override
  TextEditingValue formatEditUpdate(TextEditingValue antigo, TextEditingValue novo) {
    var t = novo.text.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');
    if (t.length > 6) t = t.substring(0, 6);
    return _comCursorNoFim(t);
  }
}
