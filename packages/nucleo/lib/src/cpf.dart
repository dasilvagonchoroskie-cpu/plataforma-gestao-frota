/// Só os números do CPF.
String soDigitos(String texto) => texto.replaceAll(RegExp(r'[^0-9]'), '');

/// Confere os dois dígitos verificadores (mesma conta do servidor).
bool cpfValido(String texto) {
  final d = soDigitos(texto);
  if (d.length != 11 || RegExp(r'^(\d)\1{10}$').hasMatch(d)) return false;
  int digito(int ate) {
    var soma = 0;
    for (var i = 0; i < ate; i++) {
      soma += int.parse(d[i]) * (ate + 1 - i);
    }
    final r = (soma * 10) % 11;
    return r == 10 ? 0 : r;
  }

  return digito(9) == int.parse(d[9]) && digito(10) == int.parse(d[10]);
}

/// "52998224725" -> "529.982.247-25" (vai formando enquanto digita).
String cpfTexto(String texto) {
  final d = soDigitos(texto);
  final b = StringBuffer();
  for (var i = 0; i < d.length && i < 11; i++) {
    if (i == 3 || i == 6) b.write('.');
    if (i == 9) b.write('-');
    b.write(d[i]);
  }
  return b.toString();
}

/// "***.982.247-**": para mostrar sem expor o CPF inteiro.
String cpfMascarado(String texto) {
  final t = cpfTexto(texto);
  if (t.length != 14) return t;
  return '***${t.substring(3, 12)}**';
}
