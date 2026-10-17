// Formatação no padrão brasileiro: 1.234,56 / dd/mm/aaaa.
// Feita à mão (sem depender de dados de localidade carregados), igual ao
// Meu Frete. Dinheiro sempre chega aqui em CENTAVOS.

const _meses = [
  'janeiro', 'fevereiro', 'março', 'abril', 'maio', 'junho', 'julho',
  'agosto', 'setembro', 'outubro', 'novembro', 'dezembro',
];
const _mesesCurtos = [
  'jan', 'fev', 'mar', 'abr', 'mai', 'jun',
  'jul', 'ago', 'set', 'out', 'nov', 'dez',
];
const _diasSemana = ['seg', 'ter', 'qua', 'qui', 'sex', 'sáb', 'dom'];

/// Sinal de menos tipográfico (mais legível que o hífen nas contas).
const menos = '−';

String _agrupar(String inteiro) {
  final b = StringBuffer();
  final n = inteiro.length;
  for (var i = 0; i < n; i++) {
    b.write(inteiro[i]);
    final faltam = n - i - 1;
    if (faltam > 0 && faltam % 3 == 0) b.write('.');
  }
  return b.toString();
}

/// Número com [casas] decimais: 1234.5 -> "1.234,50".
String numeroBr(num valor, int casas) {
  var v = valor.toDouble();
  if (v.isNaN || v.isInfinite) v = 0;
  final negativo = v < 0;
  final texto = v.abs().toStringAsFixed(casas);
  final partes = texto.split('.');
  var r = _agrupar(partes[0]);
  if (casas > 0) r = '$r,${partes[1]}';
  final ehZero = r.replaceAll(RegExp(r'[0.,]'), '').isEmpty;
  if (negativo && !ehZero) r = '-$r';
  return r;
}

/// Centavos para "1.234,56".
String dinheiro(num centavos) => numeroBr(centavos / 100.0, 2);

/// Centavos para "R$ 1.234,56" ou "−R$ 1.234,56".
String reais(num centavos) {
  final texto = numeroBr((centavos / 100.0).abs(), 2);
  final ehZero = texto == '0,00';
  return (centavos < 0 && !ehZero) ? '${menos}R\$ $texto' : 'R\$ $texto';
}

String umaCasa(num v) => numeroBr(v, 1);
String semCasas(num v) => numeroBr(v, 0);

/// Quilos para toneladas com 3 casas: 33040 -> "33,040".
String toneladas(num kg) => numeroBr(kg / 1000.0, 3);

/// 13 -> "13", 12.5 -> "12,5".
String percentualTexto(num p) {
  if (p == p.roundToDouble()) return p.round().toString();
  return umaCasa(p);
}

String _dois(int n) => n.toString().padLeft(2, '0');

/// 12/10/2026 (no horário do celular).
String dataTexto(DateTime d) {
  final l = d.toLocal();
  return '${_dois(l.day)}/${_dois(l.month)}/${l.year}';
}

/// 12/10/2026 às 14:05
String dataHoraTexto(DateTime d) {
  final l = d.toLocal();
  return '${dataTexto(l)} às ${_dois(l.hour)}:${_dois(l.minute)}';
}

/// "12 out"
String diaMes(DateTime d) {
  final l = d.toLocal();
  return '${l.day} ${_mesesCurtos[l.month - 1]}';
}

/// "qui"
String diaSemana(DateTime d) => _diasSemana[d.toLocal().weekday - 1];

/// "outubro de 2026"
String mesAno(DateTime d) => '${_meses[d.month - 1]} de ${d.year}';

/// "Outubro de 2026"
String mesAnoTitulo(DateTime d) {
  final t = mesAno(d);
  return t[0].toUpperCase() + t.substring(1);
}

/// "1 frete" / "3 fretes"
String plural(int n, String um, String varios) => n == 1 ? '1 $um' : '$n $varios';

/// Início do dia (meia-noite, horário local).
DateTime inicioDoDia(DateTime d) {
  final l = d.toLocal();
  return DateTime(l.year, l.month, l.day);
}

/// Último milissegundo do dia (horário local).
DateTime fimDoDia(DateTime d) {
  final l = d.toLocal();
  return DateTime(l.year, l.month, l.day, 23, 59, 59, 999);
}

/// Lê o que foi digitado num campo de número.
/// Aceita "1.234,56", "33.040", "350,5", "13", "12.5" e "R$ 10,00".
double lerNumero(String texto) {
  var t = texto.trim().replaceAll('R\$', '').replaceAll(' ', '').replaceAll(' ', '');
  if (t.isEmpty) return 0;
  if (t.contains(',')) {
    t = t.replaceAll('.', '').replaceAll(',', '.');
  } else if (t.contains('.')) {
    final partes = t.split('.');
    final ehMilhar = partes.length > 1 && partes.skip(1).every((p) => p.length == 3);
    if (ehMilhar) {
      t = partes.join();
    } else if (partes.length > 2) {
      t = '${partes.sublist(0, partes.length - 1).join()}.${partes.last}';
    }
  }
  return double.tryParse(t) ?? 0;
}

/// Lê um valor em reais digitado e devolve centavos: "1.234,56" -> 123456.
int lerCentavos(String texto) => (lerNumero(texto) * 100).round();

/// Texto para um campo de dinheiro já preenchido (centavos).
String textoDinheiro(int centavos) => centavos > 0 ? dinheiro(centavos) : '';

/// Texto para campo inteiro (kg, km).
String textoInteiro(num v) => v > 0 ? semCasas(v) : '';

/// Texto para campo decimal livre: 350.5 -> "350,5", 13.0 -> "13".
String textoDecimal(num v, {int casas = 2}) {
  if (v <= 0) return '';
  var t = v.toStringAsFixed(casas);
  if (t.contains('.')) {
    t = t.replaceFirst(RegExp(r'0+$'), '');
    t = t.replaceFirst(RegExp(r'\.$'), '');
  }
  return t.replaceAll('.', ',');
}

/// Tira os acentos (nomes de arquivo).
String semAcento(String s) {
  const de = 'áàâãäéèêëíìîïóòôõöúùûüçÁÀÂÃÄÉÈÊËÍÌÎÏÓÒÔÕÖÚÙÛÜÇ';
  const para = 'aaaaaeeeeiiiiooooouuuucAAAAAEEEEIIIIOOOOOUUUUC';
  final b = StringBuffer();
  for (final r in s.runes) {
    final c = String.fromCharCode(r);
    final i = de.indexOf(c);
    b.write(i >= 0 ? para[i] : c);
  }
  return b.toString();
}
