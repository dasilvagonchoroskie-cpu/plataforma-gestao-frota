import '../modelos.dart';

/// Resultado da conta de média de uma abastecida.
class PreviaMedia {
  const PreviaMedia({
    this.kmRodados,
    this.media,
    this.litrosContados = 0,
    this.kmReferencia,
    this.abastecidasContadas = 0,
    this.motivo = '',
  });

  const PreviaMedia.sem(String motivo) : this(motivo: motivo);

  final double? kmRodados;
  final double? media;
  final double litrosContados;
  final double? kmReferencia;
  final int abastecidasContadas;

  /// Quando não dá para calcular, o porquê (para mostrar ao motorista).
  final String motivo;
}

/// Média de tanque cheio a tanque cheio: km rodados desde o último tanque
/// cheio, dividido por todos os litros que entraram nesse meio tempo
/// (incluindo esta abastecida). Mesma regra do Meu Frete.
///
/// A média é sempre de UM caminhão, porque o odômetro é do caminhão: quando
/// [caminhaoId] é informado, só as abastecidas dele entram na conta.
PreviaMedia calcularMedia(
  List<Abastecimento> jaSalvas, {
  required double km,
  required double litros,
  required bool tanqueCheio,
  String? caminhaoId,
  String idIgnorar = '',
}) {
  if (!tanqueCheio) {
    return const PreviaMedia.sem('O tanque não foi completado. A média sai na próxima vez que você encher.');
  }
  if (km <= 0) return const PreviaMedia.sem('Digite o km da abastecida.');

  final anteriores = jaSalvas
      .where((a) =>
          a.id != idIgnorar && a.apagadoEm == null && a.km < km && (caminhaoId == null || a.caminhaoId == caminhaoId))
      .toList()
    ..sort((a, b) => a.km.compareTo(b.km));

  Abastecimento? referencia;
  for (final a in anteriores.reversed) {
    if (a.tanqueCheio) {
      referencia = a;
      break;
    }
  }
  if (referencia == null) {
    return const PreviaMedia.sem('Esta é a primeira com tanque cheio. A média começa a valer na próxima.');
  }

  final kmRodados = km - referencia.km;
  if (kmRodados <= 0) return const PreviaMedia.sem('O km precisa ser maior que o da abastecida anterior.');

  final kmRef = referencia.km;
  final noMeio = anteriores.where((a) => a.km > kmRef).toList();
  final litrosTotal = noMeio.fold<double>(0, (s, a) => s + a.litros) + litros;
  if (litrosTotal <= 0) return const PreviaMedia.sem('Digite os litros.');

  return PreviaMedia(
    kmRodados: kmRodados,
    media: kmRodados / litrosTotal,
    litrosContados: litrosTotal,
    kmReferencia: kmRef,
    abastecidasContadas: noMeio.length + 1,
  );
}

/// Média de uma abastecida já salva (só com as do mesmo caminhão).
PreviaMedia mediaDaLinha(List<Abastecimento> todas, Abastecimento item) => calcularMedia(
      todas,
      km: item.km,
      litros: item.litros,
      tanqueCheio: item.tanqueCheio,
      caminhaoId: item.caminhaoId,
      idIgnorar: item.id,
    );

/// Média real de um conjunto de abastecidas: soma dos km de cada trecho
/// cheio-a-cheio dividida pela soma dos litros desses trechos. Com vários
/// caminhões, cada trecho é calculado no próprio caminhão.
class MediaPeriodo {
  const MediaPeriodo(this.km, this.litros);
  final double km;
  final double litros;
  double? get media => litros > 0 ? km / litros : null;
}

MediaPeriodo mediaDoPeriodo(List<Abastecimento> doPeriodo, List<Abastecimento> todas) {
  var km = 0.0;
  var litros = 0.0;
  for (final a in doPeriodo.where((a) => !a.pontoDePartida)) {
    final m = mediaDaLinha(todas, a);
    final rodados = m.kmRodados;
    if (rodados != null && rodados > 0 && m.litrosContados > 0) {
      km += rodados;
      litros += m.litrosContados;
    }
  }
  return MediaPeriodo(km, litros);
}

/// Média separada por caminhão (id do caminhão -> média).
Map<String, MediaPeriodo> mediaPorCaminhao(List<Abastecimento> doPeriodo, List<Abastecimento> todas) {
  final ids = doPeriodo.map((a) => a.caminhaoId).toSet();
  return {
    for (final id in ids)
      id: mediaDoPeriodo(doPeriodo.where((a) => a.caminhaoId == id).toList(), todas),
  };
}
