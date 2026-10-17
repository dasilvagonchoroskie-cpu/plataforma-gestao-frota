/// Placa guardada sem traço e em maiúsculas: "ABC1D23" ou "ABC1234".
String normalizarPlaca(String texto) => texto.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');

/// Placa brasileira: modelo antigo (ABC1234) ou Mercosul (ABC1D23).
bool placaValida(String texto) => RegExp(r'^[A-Z]{3}[0-9][A-Z0-9][0-9]{2}$').hasMatch(normalizarPlaca(texto));

/// Para mostrar: "ABC-1234" no modelo antigo, "ABC1D23" no Mercosul.
String placaTexto(String placa) {
  final p = normalizarPlaca(placa);
  if (p.length == 7 && RegExp(r'^[A-Z]{3}[0-9]{4}$').hasMatch(p)) {
    return '${p.substring(0, 3)}-${p.substring(3)}';
  }
  return p;
}
