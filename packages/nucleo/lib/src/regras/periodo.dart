import '../formato.dart';

/// Intervalo de datas, com as duas pontas incluídas (horário do celular).
class Periodo {
  const Periodo(this.inicio, this.fim);
  final DateTime inicio;
  final DateTime fim;

  bool contem(DateTime d) => !d.isBefore(inicio) && !d.isAfter(fim);

  String get texto => '${dataTexto(inicio)} a ${dataTexto(fim)}';

  @override
  bool operator ==(Object other) => other is Periodo && other.inicio == inicio && other.fim == fim;

  @override
  int get hashCode => Object.hash(inicio, fim);
}

enum TipoPeriodo {
  mesAtual('Este mês'),
  mesPassado('Mês passado'),
  seteDias('7 dias'),
  quinzeDias('15 dias'),
  trintaDias('30 dias'),
  escolher('Escolher datas');

  const TipoPeriodo(this.rotulo);
  final String rotulo;
}

/// Mesma regra do Meu Frete (PeriodoRelatorio.kt).
Periodo? calcularPeriodo(TipoPeriodo tipo, {DateTime? inicio, DateTime? fim, DateTime? agora}) {
  final hoje = (agora ?? DateTime.now()).toLocal();
  switch (tipo) {
    case TipoPeriodo.escolher:
      if (inicio == null || fim == null) return null;
      final a = inicioDoDia(inicio);
      final b = fimDoDia(fim);
      if (b.isBefore(a)) return null;
      return Periodo(a, b);
    case TipoPeriodo.seteDias:
    case TipoPeriodo.quinzeDias:
    case TipoPeriodo.trintaDias:
      final voltar = tipo == TipoPeriodo.seteDias ? 6 : (tipo == TipoPeriodo.quinzeDias ? 14 : 29);
      final comeco = DateTime(hoje.year, hoje.month, hoje.day - voltar);
      return Periodo(inicioDoDia(comeco), fimDoDia(hoje));
    case TipoPeriodo.mesAtual:
      final primeiro = DateTime(hoje.year, hoje.month, 1);
      final ultimo = DateTime(hoje.year, hoje.month + 1, 0);
      return Periodo(inicioDoDia(primeiro), fimDoDia(ultimo));
    case TipoPeriodo.mesPassado:
      final primeiro = DateTime(hoje.year, hoje.month - 1, 1);
      final ultimo = DateTime(hoje.year, hoje.month, 0);
      return Periodo(inicioDoDia(primeiro), fimDoDia(ultimo));
  }
}

/// Janela de uma viagem: da carga até o dia em que a carga seguinte foi
/// pega (esse dia incluído). Se já havia carga antes, começa no dia seguinte
/// ao desta carga, porque o próprio dia ficou na conta da viagem anterior.
Periodo janelaDaViagem(DateTime dataCarga, List<DateTime> datasDeTodasAsCargas, {DateTime? agora}) {
  DateTime? anterior;
  DateTime? proxima;
  for (final d in datasDeTodasAsCargas) {
    if (d.isBefore(dataCarga) && (anterior == null || d.isAfter(anterior))) anterior = d;
    if (d.isAfter(dataCarga) && (proxima == null || d.isBefore(proxima))) proxima = d;
  }
  final carga = dataCarga.toLocal();
  final comeco = anterior != null ? DateTime(carga.year, carga.month, carga.day + 1) : carga;
  final fim = proxima != null ? fimDoDia(proxima) : fimDoDia(agora ?? DateTime.now());
  return Periodo(inicioDoDia(comeco), fim);
}
