// Registro de paradas do motorista (opcional por empresa).
//
// Nenhum número da lei fica aqui: o limite sem descanso vem da empresa e os
// motivos que contam como descanso vêm do catálogo do servidor
// (motivos_parada). É um registro interno; não substitui o tacógrafo.

import 'formato.dart';
import 'modelos.dart';
import 'placa.dart';
import 'regras/periodo.dart';

/// Vai no pé de todo relatório de paradas (pedido do dono).
const avisoParadas = 'Registro interno feito pelo motorista; não substitui o tacógrafo.';

class MotivoParada {
  const MotivoParada({required this.codigo, required this.nome, this.contaComoDescanso = false, this.ativo = true});

  final String codigo;
  final String nome;

  /// Refeição, descanso e pernoite (definido no servidor, não no app).
  final bool contaComoDescanso;
  final bool ativo;

  factory MotivoParada.deMapa(Map<String, Object?> m) => MotivoParada(
        codigo: lerTexto(m['codigo']),
        nome: lerTexto(m['nome']),
        contaComoDescanso: lerBool(m['conta_como_descanso']),
        ativo: lerBool(m['ativo'], true),
      );

  Map<String, Object?> paraMapa() =>
      {'codigo': codigo, 'nome': nome, 'conta_como_descanso': contaComoDescanso, 'ativo': ativo};
}

/// O que a empresa escolheu sobre as paradas (vem da situação da conta).
class ConfiguracaoParadas {
  const ConfiguracaoParadas({this.ativas = false, this.limiteMinutos, this.motivos = const []});

  /// Desligado: nem o motorista nem o painel mostram a aba.
  final bool ativas;

  /// Tempo máximo sem descanso que a empresa definiu (sem ele, nada é destacado).
  final int? limiteMinutos;
  final List<MotivoParada> motivos;

  factory ConfiguracaoParadas.deMapa(Map<String, Object?>? empresa) {
    if (empresa == null) return const ConfiguracaoParadas();
    final limite = empresa['limite_sem_descanso_minutos'];
    return ConfiguracaoParadas(
      ativas: lerBool(empresa['paradas_ativas']),
      limiteMinutos: limite == null ? null : lerInt(limite),
      motivos: [
        for (final m in (empresa['motivos_parada'] as List? ?? const []))
          if (m is Map) MotivoParada.deMapa(m.cast<String, Object?>()),
      ],
    );
  }

  /// Os que o motorista pode escolher hoje.
  List<MotivoParada> get motivosAtivos => motivos.where((m) => m.ativo).toList();
}

/// Nome do motivo (com o catálogo; sem ele, o código mesmo).
String nomeDoMotivo(String codigo, List<MotivoParada> motivos) {
  for (final m in motivos) {
    if (m.codigo == codigo) return m.nome;
  }
  return codigo;
}

class Parada {
  const Parada({
    required this.id,
    required this.motoristaId,
    required this.motivo,
    required this.inicioEm,
    this.caminhaoId,
    this.descricao,
    this.fimEm,
    this.ajustado = false,
    this.empresaId,
    this.criadoNoAparelhoEm,
    this.atualizadoEm,
    this.apagadoEm,
  });

  final String id;
  final String? empresaId;
  final String motoristaId;
  final String? caminhaoId;
  final String motivo;

  /// Para o motivo "Outro".
  final String? descricao;
  final DateTime inicioEm;

  /// Sem fim, a parada está acontecendo agora.
  final DateTime? fimEm;

  /// O motorista informou o horário depois (esqueceu de registrar ou de retomar).
  final bool ajustado;
  final DateTime? criadoNoAparelhoEm;
  final DateTime? atualizadoEm;
  final DateTime? apagadoEm;

  bool get emAndamento => fimEm == null;

  /// Duração (aberta: até agora).
  Duration duracao(DateTime agora) => (fimEm ?? agora).difference(inicioEm);

  Parada copyWith({
    String? motivo,
    String? descricao,
    DateTime? inicioEm,
    DateTime? fimEm,
    bool reabrir = false,
    bool? ajustado,
    DateTime? apagadoEm,
  }) =>
      Parada(
        id: id,
        empresaId: empresaId,
        motoristaId: motoristaId,
        caminhaoId: caminhaoId,
        motivo: motivo ?? this.motivo,
        descricao: descricao ?? this.descricao,
        inicioEm: inicioEm ?? this.inicioEm,
        fimEm: reabrir ? null : (fimEm ?? this.fimEm),
        ajustado: ajustado ?? this.ajustado,
        criadoNoAparelhoEm: criadoNoAparelhoEm,
        atualizadoEm: atualizadoEm,
        apagadoEm: apagadoEm ?? this.apagadoEm,
      );

  Map<String, Object?> paraMapa() => {
        'id': id,
        if (empresaId != null) 'empresa_id': empresaId,
        'motorista_id': motoristaId,
        if (caminhaoId != null && caminhaoId!.isNotEmpty) 'caminhao_id': caminhaoId,
        'motivo': motivo,
        if (descricao != null && descricao!.trim().isNotEmpty) 'descricao': descricao!.trim(),
        'inicio_em': dataIso(inicioEm),
        if (fimEm != null) 'fim_em': dataIso(fimEm!),
        'ajustado': ajustado,
        if (criadoNoAparelhoEm != null) 'criado_no_aparelho_em': dataIso(criadoNoAparelhoEm!),
        if (apagadoEm != null) 'apagado_em': dataIso(apagadoEm!),
      };

  factory Parada.deMapa(Map<String, Object?> m) => Parada(
        id: lerTexto(m['id']),
        empresaId: lerTextoOuNulo(m['empresa_id']),
        motoristaId: lerTexto(m['motorista_id']),
        caminhaoId: lerTextoOuNulo(m['caminhao_id']),
        motivo: lerTexto(m['motivo']),
        descricao: lerTextoOuNulo(m['descricao']),
        inicioEm: lerData(m['inicio_em']),
        fimEm: lerDataOuNula(m['fim_em']),
        ajustado: lerBool(m['ajustado']),
        criadoNoAparelhoEm: lerDataOuNula(m['criado_no_aparelho_em']),
        atualizadoEm: lerDataOuNula(m['atualizado_em']),
        apagadoEm: lerDataOuNula(m['apagado_em']),
      );
}

/// "45 min", "1h05", "26h10".
String duracaoTexto(Duration d) {
  final total = d.inMinutes;
  if (total < 0) return '0 min';
  if (total < 60) return '$total min';
  final h = total ~/ 60;
  final m = total % 60;
  return '${h}h${m.toString().padLeft(2, '0')}';
}

/// "5h30" a partir de minutos (o limite da empresa).
String limiteTexto(int minutos) => duracaoTexto(Duration(minutes: minutos));

/// Tempo entre o fim de um descanso e o começo do seguinte (ou até agora).
class IntervaloSemDescanso {
  const IntervaloSemDescanso({required this.inicio, required this.fim, this.limiteMinutos, this.ateAgora = false});

  final DateTime inicio;
  final DateTime fim;
  final int? limiteMinutos;

  /// Ainda sem descanso desde o último (o fim é "agora").
  final bool ateAgora;

  Duration get duracao => fim.difference(inicio);
  bool get acimaDoLimite => limiteMinutos != null && duracao.inMinutes > limiteMinutos!;
}

class ResumoParadas {
  const ResumoParadas({
    required this.paradas,
    required this.tempoParado,
    required this.tempoDescanso,
    required this.intervalos,
    required this.temDescanso,
    this.limiteMinutos,
  });

  /// Paradas que tocam o período, da mais antiga para a mais nova.
  final List<Parada> paradas;
  final Duration tempoParado;
  final Duration tempoDescanso;

  /// Intervalos sem descanso que tocam o período.
  final List<IntervaloSemDescanso> intervalos;
  final int? limiteMinutos;

  /// Algum descanso (refeição, descanso, pernoite) registrado no período.
  final bool temDescanso;

  IntervaloSemDescanso? get maior {
    IntervaloSemDescanso? r;
    for (final i in intervalos) {
      if (r == null || i.duracao > r.duracao) r = i;
    }
    return r;
  }

  List<IntervaloSemDescanso> get acimaDoLimite => intervalos.where((i) => i.acimaDoLimite).toList();
}

/// Junta as paradas de um motorista no período: tempo parado, tempo de
/// descanso e os intervalos sem descanso (do fim de um descanso ao começo do
/// seguinte; se o período chega até agora, também desde o último descanso).
/// Só refeição, descanso e pernoite contam, e quem diz isso é o catálogo.
ResumoParadas resumirParadas({
  required List<Parada> paradas,
  required List<MotivoParada> motivos,
  required Periodo periodo,
  required int? limiteMinutos,
  required DateTime agora,
}) {
  final descanso = {for (final m in motivos) if (m.contaComoDescanso) m.codigo};
  final vivas = paradas.where((p) => p.apagadoEm == null).toList()..sort((a, b) => a.inicioEm.compareTo(b.inicioEm));
  bool toca(DateTime a, DateTime b) => !a.isAfter(periodo.fim) && !b.isBefore(periodo.inicio);

  final doPeriodo = [for (final p in vivas) if (toca(p.inicioEm, p.fimEm ?? agora)) p];
  var parado = Duration.zero;
  var descansado = Duration.zero;
  for (final p in doPeriodo) {
    final d = p.duracao(agora);
    parado += d;
    if (descanso.contains(p.motivo)) descansado += d;
  }

  final descansos = [for (final p in vivas) if (descanso.contains(p.motivo)) p];
  final intervalos = <IntervaloSemDescanso>[];
  for (var i = 0; i + 1 < descansos.length; i++) {
    final fim = descansos[i].fimEm;
    if (fim == null) continue;
    final proximo = descansos[i + 1].inicioEm;
    if (!proximo.isAfter(fim)) continue;
    if (toca(fim, proximo)) {
      intervalos.add(IntervaloSemDescanso(inicio: fim, fim: proximo, limiteMinutos: limiteMinutos));
    }
  }
  // Desde o último descanso até agora (quando o período chega até hoje).
  if (descansos.isNotEmpty && periodo.contem(agora)) {
    final ultimo = descansos.last;
    if (ultimo.fimEm != null && agora.isAfter(ultimo.fimEm!)) {
      intervalos.add(IntervaloSemDescanso(inicio: ultimo.fimEm!, fim: agora, limiteMinutos: limiteMinutos, ateAgora: true));
    }
  }

  return ResumoParadas(
    paradas: doPeriodo,
    tempoParado: parado,
    tempoDescanso: descansado,
    intervalos: intervalos,
    limiteMinutos: limiteMinutos,
    temDescanso: doPeriodo.any((p) => descanso.contains(p.motivo)),
  );
}

/// Desde quando o motorista está sem descanso (fim do último descanso), ou
/// nulo se está descansando agora ou nunca registrou descanso.
DateTime? semDescansoDesde(List<Parada> paradas, List<MotivoParada> motivos) {
  final descanso = {for (final m in motivos) if (m.contaComoDescanso) m.codigo};
  Parada? ultimo;
  for (final p in paradas) {
    if (p.apagadoEm != null || !descanso.contains(p.motivo)) continue;
    if (ultimo == null || p.inicioEm.isAfter(ultimo.inicioEm)) ultimo = p;
  }
  return ultimo?.fimEm;
}

/// A parada em andamento (a mais recente sem fim), se houver.
Parada? paradaAberta(List<Parada> paradas) {
  Parada? r;
  for (final p in paradas) {
    if (p.apagadoEm != null || p.fimEm != null) continue;
    if (r == null || p.inicioEm.isAfter(r.inicioEm)) r = p;
  }
  return r;
}

/// "de 10/10 08:00 a 10/10 14:10".
String textoDoIntervalo(IntervaloSemDescanso i) =>
    'de ${diaMes(i.inicio)} ${horaTexto(i.inicio)} a ${i.ateAgora ? 'agora' : '${diaMes(i.fim)} ${horaTexto(i.fim)}'}';

/// "08:05" no horário do celular.
String horaTexto(DateTime d) {
  final l = d.toLocal();
  return '${l.hour.toString().padLeft(2, '0')}:${l.minute.toString().padLeft(2, '0')}';
}

/// Tudo o que o relatório de paradas precisa (PDF e planilha).
class DadosParadas {
  const DadosParadas({
    required this.periodo,
    required this.resumo,
    required this.motivos,
    this.empresa = '',
    this.motorista = '',
    this.placasPorCaminhao = const {},
  });

  final Periodo periodo;
  final ResumoParadas resumo;
  final List<MotivoParada> motivos;
  final String empresa;
  final String motorista;
  final Map<String, String> placasPorCaminhao;

  String placaDe(String? caminhaoId) {
    final p = caminhaoId == null ? null : placasPorCaminhao[caminhaoId];
    return p == null || p.isEmpty ? '' : placaTexto(p);
  }
}

String nomeDoArquivoParadas(DadosParadas d, {String extensao = 'pdf'}) {
  final i = dataTexto(d.periodo.inicio).replaceAll('/', '-');
  final f = dataTexto(d.periodo.fim).replaceAll('/', '-');
  final quem = d.motorista.isEmpty
      ? ''
      : '${semAcento(d.motorista.split(' ').first).replaceAll(RegExp(r'[^A-Za-z0-9]'), '')}_';
  return 'Frota_${quem}paradas_${i}_a_$f.$extensao';
}
