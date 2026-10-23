// Modalidades de operação (Graneleiro, Grade baixa, Caçamba, Baú, Sider...).
//
// Cada modalidade funciona "por frete" (como o Graneleiro: peso, tonelada,
// adiantamento, saldo e comissão) ou "por viagem" (como o Baú: uma viagem por
// carreta engatada, sem dinheiro do frete; a comissão sai no acerto).
// Os campos de cada uma vêm do servidor, já com os ajustes do dono (nome,
// mostrar e obrigatório) e os campos novos criados pela Plataforma.

import 'formato.dart';
import 'modelos.dart';
import 'placa.dart';
import 'regras/resumo.dart';

enum TipoModalidade {
  frete,
  viagem;

  static TipoModalidade deTexto(Object? t) => t == 'viagem' ? TipoModalidade.viagem : TipoModalidade.frete;
}

/// Tipos de campo que o app sabe mostrar.
abstract final class TiposCampo {
  static const texto = 'texto';
  static const cidade = 'cidade';
  static const cidades = 'cidades';
  static const placa = 'placa';
  static const numero = 'numero';
  static const inteiro = 'inteiro';
  static const dinheiro = 'dinheiro';
  static const peso = 'peso';
  static const percentual = 'percentual';
  static const data = 'data';
  static const dataHora = 'data_hora';
  static const simNao = 'sim_nao';

  /// Os que a Plataforma pode usar num campo novo.
  static const paraCampoNovo = [texto, numero, inteiro, dinheiro, data, dataHora, simNao, cidade];

  static String nome(String tipo) => switch (tipo) {
        texto => 'Texto',
        cidade => 'Cidade',
        cidades => 'Lista de cidades',
        placa => 'Placa',
        numero => 'Número com vírgula',
        inteiro => 'Número inteiro',
        dinheiro => 'Dinheiro (R\$)',
        peso => 'Peso (kg)',
        percentual => 'Percentual (%)',
        data => 'Data',
        dataHora => 'Data e hora',
        simNao => 'Sim ou não',
        _ => tipo,
      };
}

/// Quando o motorista preenche o campo de uma viagem.
abstract final class EtapasViagem {
  static const engate = 'engate';
  static const entregas = 'entregas';
  static const desengate = 'desengate';
  static const todas = [engate, entregas, desengate];

  static String nome(String etapa) => switch (etapa) {
        engate => 'No engate (começo da viagem)',
        entregas => 'Nas entregas (durante a viagem)',
        desengate => 'No desengate (fim da viagem)',
        _ => etapa,
      };
}

class CampoModalidade {
  const CampoModalidade({
    required this.chave,
    required this.rotulo,
    required this.tipo,
    this.rotuloPadrao,
    this.obrigatorio = false,
    this.visivel = true,
    this.podeOcultar = true,
    this.extra = false,
    this.desativado = false,
    this.etapa,
  });

  /// Nome da coluna do banco (ou da chave em "extras", nos campos novos).
  final String chave;

  /// Nome que aparece para o motorista (já com o ajuste do dono).
  final String rotulo;

  /// Nome de fábrica (antes do ajuste do dono).
  final String? rotuloPadrao;
  final String tipo;
  final bool obrigatorio;
  final bool visivel;

  /// Falso: o dono só renomeia (o campo é necessário para as contas).
  final bool podeOcultar;

  /// Campo novo criado pela Plataforma (fica em "extras").
  final bool extra;
  final bool desativado;
  final String? etapa;

  factory CampoModalidade.deMapa(Map<String, Object?> m) => CampoModalidade(
        chave: lerTexto(m['chave']),
        rotulo: lerTexto(m['rotulo']),
        rotuloPadrao: lerTextoOuNulo(m['rotulo_padrao']),
        tipo: lerTexto(m['tipo'], TiposCampo.texto),
        obrigatorio: lerBool(m['obrigatorio']),
        visivel: lerBool(m['visivel'], true),
        podeOcultar: lerBool(m['pode_ocultar'], true),
        extra: lerBool(m['extra']),
        desativado: lerBool(m['desativado']),
        etapa: lerTextoOuNulo(m['etapa']),
      );

  Map<String, Object?> paraMapa() => {
        'chave': chave,
        'rotulo': rotulo,
        if (rotuloPadrao != null) 'rotulo_padrao': rotuloPadrao,
        'tipo': tipo,
        'obrigatorio': obrigatorio,
        'visivel': visivel,
        'pode_ocultar': podeOcultar,
        'extra': extra,
        'desativado': desativado,
        if (etapa != null) 'etapa': etapa,
      };
}

class Modalidade {
  const Modalidade({
    required this.codigo,
    required this.nome,
    this.tipo = TipoModalidade.frete,
    this.ativa = true,
    this.campos = const [],
    this.ajustes = const {},
    this.motoristas = 0,
  });

  final String codigo;
  final String nome;
  final TipoModalidade tipo;

  /// Ligada na empresa.
  final bool ativa;
  final List<CampoModalidade> campos;

  /// O que o dono mudou em cada campo: {"chave": {"rotulo", "visivel", "obrigatorio"}}.
  final Map<String, Map<String, Object?>> ajustes;

  /// Quantos motoristas ativos usam (só na tela do gestor).
  final int motoristas;

  /// Quando o app ainda não sabe a modalidade (celular sem a informação nova):
  /// funciona como sempre funcionou.
  static const graneleiro = Modalidade(codigo: 'graneleiro', nome: 'Graneleiro');

  bool get porViagem => tipo == TipoModalidade.viagem;

  CampoModalidade? campo(String chave) {
    for (final c in campos) {
      if (c.chave == chave) return c;
    }
    return null;
  }

  /// Nome do campo; sem a configuração, o nome que o app já usava.
  String rotulo(String chave, String padrao) {
    final r = campo(chave)?.rotulo.trim() ?? '';
    return r.isEmpty ? padrao : r;
  }

  bool visivel(String chave) => campo(chave)?.visivel ?? true;

  bool obrigatorio(String chave, {bool padrao = false}) => campo(chave)?.obrigatorio ?? padrao;

  /// Campos novos da Plataforma que aparecem no formulário.
  List<CampoModalidade> extras({String? etapa}) => [
        for (final c in campos)
          if (c.extra && c.visivel && !c.desativado && (etapa == null || c.etapa == etapa)) c,
      ];

  /// Nome de cada campo novo (para mostrar e imprimir os valores já salvos).
  Map<String, String> get rotulosExtras => {for (final c in campos) if (c.extra) c.chave: c.rotulo};

  factory Modalidade.deMapa(Map<String, Object?> m) {
    final ajustes = <String, Map<String, Object?>>{};
    final a = m['ajustes'];
    if (a is Map) {
      for (final e in a.entries) {
        if (e.value is Map) ajustes[e.key.toString()] = (e.value as Map).cast<String, Object?>();
      }
    }
    return Modalidade(
      codigo: lerTexto(m['codigo']),
      nome: lerTexto(m['nome']),
      tipo: TipoModalidade.deTexto(m['tipo']),
      ativa: lerBool(m['ativa'], true),
      campos: [
        for (final c in (m['campos'] as List? ?? const []))
          if (c is Map) CampoModalidade.deMapa(c.cast<String, Object?>()),
      ],
      ajustes: ajustes,
      motoristas: lerInt(m['motoristas']),
    );
  }

  Map<String, Object?> paraMapa() => {
        'codigo': codigo,
        'nome': nome,
        'tipo': tipo.name,
        'ativa': ativa,
        'campos': [for (final c in campos) c.paraMapa()],
        if (ajustes.isNotEmpty) 'ajustes': ajustes,
        if (motoristas > 0) 'motoristas': motoristas,
      };
}

/// Modalidades ligadas na empresa (vêm na situação da conta).
List<Modalidade> modalidadesDaEmpresa(Map<String, Object?>? empresa) => [
      for (final m in (empresa?['modalidades'] as List? ?? const []))
        if (m is Map) Modalidade.deMapa(m.cast<String, Object?>()),
    ];

/// A modalidade com este código, ou null.
Modalidade? modalidadePorCodigo(List<Modalidade> lista, String? codigo) {
  if (codigo == null) return null;
  for (final m in lista) {
    if (m.codigo == codigo) return m;
  }
  return null;
}

/// Gera o código de uma modalidade ou campo a partir do nome: "Porta-contêiner" -> "porta_conteiner".
String codigoDoNome(String nome) {
  var c = semAcento(nome.trim().toLowerCase()).replaceAll(RegExp(r'[^a-z0-9]+'), '_');
  c = c.replaceAll(RegExp(r'^_+|_+$'), '');
  if (c.isEmpty || !RegExp(r'^[a-z]').hasMatch(c)) c = 'm_$c';
  return c.length > 29 ? c.substring(0, 29).replaceAll(RegExp(r'_+$'), '') : c;
}

/// Mostra o valor de um campo novo ("sim"/"não", datas, dinheiro...).
String textoDoExtra(CampoModalidade? campo, Object? valor) {
  if (valor == null || (valor is String && valor.trim().isEmpty)) return '';
  final tipo = campo?.tipo ?? TiposCampo.texto;
  switch (tipo) {
    case TiposCampo.simNao:
      return lerBool(valor) ? 'sim' : 'não';
    case TiposCampo.dinheiro:
      return reais(lerInt(valor));
    case TiposCampo.data:
      final d = DateTime.tryParse(valor.toString());
      return d == null ? valor.toString() : dataTexto(d);
    case TiposCampo.dataHora:
      final d = DateTime.tryParse(valor.toString());
      return d == null ? valor.toString() : dataHoraTexto(d);
    case TiposCampo.numero:
      return numeroBr(lerDouble(valor), 2).replaceFirst(RegExp(r',00$'), '');
    case TiposCampo.inteiro:
      return semCasas(lerDouble(valor));
    default:
      return valor.toString();
  }
}

/// Campo novo sem valor (o formulário guarda "" quando o motorista apaga).
bool extraVazio(Object? v) => v == null || (v is String && v.trim().isEmpty);

/// Erros dos campos novos obrigatórios que ficaram vazios: {"chave": "mensagem"}.
Map<String, String> errosDosExtras(List<CampoModalidade> campos, Map<String, Object?> valores) => {
      for (final c in campos)
        if (c.obrigatorio && c.visivel && !c.desativado && extraVazio(valores[c.chave]))
          c.chave: 'Preencha ${c.rotulo.toLowerCase()}.',
    };

/// "Rótulo: valor" de cada campo novo preenchido, na ordem da modalidade.
List<String> linhasDosExtras(Map<String, Object?> extras, Modalidade? modalidade) {
  final r = <String>[];
  final vistos = <String>{};
  for (final c in modalidade?.campos ?? const <CampoModalidade>[]) {
    if (!c.extra || !extras.containsKey(c.chave)) continue;
    vistos.add(c.chave);
    final t = textoDoExtra(c, extras[c.chave]);
    if (t.trim().isNotEmpty) r.add('${c.rotulo}: $t');
  }
  for (final e in extras.entries) {
    if (vistos.contains(e.key)) continue;
    final t = textoDoExtra(null, e.value);
    if (t.trim().isNotEmpty) r.add('${e.key}: $t');
  }
  return r;
}

Map<String, Object?> lerMapa(Object? v) {
  if (v is Map) return v.cast<String, Object?>();
  return const {};
}

/// Viagem do Baú e do Sider: uma carreta engatada, de onde engatou até onde
/// levou, com as entregas. Sem desengate, está em andamento.
class Viagem {
  const Viagem({
    required this.id,
    required this.motoristaId,
    required this.caminhaoId,
    required this.placaCarreta,
    required this.engateEm,
    this.modalidade = 'bau',
    this.engateLocal = '',
    this.desengateLocal = '',
    this.desengateEm,
    this.entregasQuantidade = 0,
    this.entregasCidades = const [],
    this.observacao,
    this.extras = const {},
    this.empresaId,
    this.criadoNoAparelhoEm,
    this.atualizadoEm,
    this.apagadoEm,
  });

  final String id;
  final String? empresaId;
  final String motoristaId;

  /// O cavalo (caminhão do motorista).
  final String caminhaoId;
  final String modalidade;
  final String placaCarreta;
  final String engateLocal;
  final DateTime engateEm;
  final String desengateLocal;
  final DateTime? desengateEm;
  final int entregasQuantidade;
  final List<String> entregasCidades;
  final String? observacao;
  final Map<String, Object?> extras;
  final DateTime? criadoNoAparelhoEm;
  final DateTime? atualizadoEm;
  final DateTime? apagadoEm;

  bool get emAndamento => desengateEm == null;

  String get rota => '${engateLocal.trim().isEmpty ? 'Engate' : engateLocal.trim()} para '
      '${desengateLocal.trim().isEmpty ? (emAndamento ? 'em andamento' : 'desengate') : desengateLocal.trim()}';

  /// Duração (só com o desengate).
  Duration? get duracao => desengateEm?.difference(engateEm);

  Viagem copyWith({
    String? caminhaoId,
    String? placaCarreta,
    String? engateLocal,
    DateTime? engateEm,
    String? desengateLocal,
    DateTime? desengateEm,
    bool reabrir = false,
    int? entregasQuantidade,
    List<String>? entregasCidades,
    String? observacao,
    Map<String, Object?>? extras,
    DateTime? apagadoEm,
  }) =>
      Viagem(
        id: id,
        empresaId: empresaId,
        motoristaId: motoristaId,
        caminhaoId: caminhaoId ?? this.caminhaoId,
        modalidade: modalidade,
        placaCarreta: placaCarreta ?? this.placaCarreta,
        engateLocal: engateLocal ?? this.engateLocal,
        engateEm: engateEm ?? this.engateEm,
        desengateLocal: desengateLocal ?? this.desengateLocal,
        desengateEm: reabrir ? null : (desengateEm ?? this.desengateEm),
        entregasQuantidade: entregasQuantidade ?? this.entregasQuantidade,
        entregasCidades: entregasCidades ?? this.entregasCidades,
        observacao: observacao ?? this.observacao,
        extras: extras ?? this.extras,
        criadoNoAparelhoEm: criadoNoAparelhoEm,
        atualizadoEm: atualizadoEm,
        apagadoEm: apagadoEm ?? this.apagadoEm,
      );

  Map<String, Object?> paraMapa() => {
        'id': id,
        if (empresaId != null) 'empresa_id': empresaId,
        'motorista_id': motoristaId,
        'caminhao_id': caminhaoId,
        'modalidade': modalidade,
        'placa_carreta': normalizarPlaca(placaCarreta),
        'engate_local': engateLocal,
        'engate_em': dataIso(engateEm),
        'desengate_local': desengateLocal,
        if (desengateEm != null) 'desengate_em': dataIso(desengateEm!),
        'entregas_quantidade': entregasQuantidade,
        'entregas_cidades': entregasCidades,
        'observacao': observacao ?? '',
        'extras': extras,
        if (criadoNoAparelhoEm != null) 'criado_no_aparelho_em': dataIso(criadoNoAparelhoEm!),
        if (apagadoEm != null) 'apagado_em': dataIso(apagadoEm!),
      };

  factory Viagem.deMapa(Map<String, Object?> m) => Viagem(
        id: lerTexto(m['id']),
        empresaId: lerTextoOuNulo(m['empresa_id']),
        motoristaId: lerTexto(m['motorista_id']),
        caminhaoId: lerTexto(m['caminhao_id']),
        modalidade: lerTexto(m['modalidade'], 'bau'),
        placaCarreta: lerTexto(m['placa_carreta']),
        engateLocal: lerTexto(m['engate_local']),
        engateEm: lerData(m['engate_em']),
        desengateLocal: lerTexto(m['desengate_local']),
        desengateEm: lerDataOuNula(m['desengate_em']),
        entregasQuantidade: lerInt(m['entregas_quantidade']),
        entregasCidades: lerLista(m['entregas_cidades']),
        observacao: lerTextoOuNulo(m['observacao']),
        extras: lerMapa(m['extras']),
        criadoNoAparelhoEm: lerDataOuNula(m['criado_no_aparelho_em']),
        atualizadoEm: lerDataOuNula(m['atualizado_em']),
        apagadoEm: lerDataOuNula(m['apagado_em']),
      );
}

class DescontoAcerto {
  const DescontoAcerto({required this.descricao, required this.valorCentavos});
  final String descricao;
  final int valorCentavos;

  Map<String, Object?> paraMapa() => {'descricao': descricao, 'valor_centavos': valorCentavos};

  factory DescontoAcerto.deMapa(Map<String, Object?> m) =>
      DescontoAcerto(descricao: lerTexto(m['descricao']), valorCentavos: lerInt(m['valor_centavos']));
}

/// Data sem hora ("2026-10-01"), no dia local.
DateTime lerDia(Object? v) {
  final t = v.toString();
  final d = DateTime.tryParse(t.length >= 10 ? t.substring(0, 10) : t);
  if (d == null) return lerData(v).toLocal();
  return DateTime(d.year, d.month, d.day);
}

String diaIso(DateTime d) {
  final l = DateTime(d.year, d.month, d.day);
  return '${l.year.toString().padLeft(4, '0')}-${l.month.toString().padLeft(2, '0')}-${l.day.toString().padLeft(2, '0')}';
}

/// Acerto fechado pelo gestor (Baú e Sider). Os totais de vales, diesel e
/// gastos foram somados pelo servidor no fechamento.
class Acerto {
  const Acerto({
    required this.id,
    required this.motoristaId,
    required this.periodoInicio,
    required this.periodoFim,
    required this.comissaoCentavos,
    this.descontos = const [],
    this.totalDescontosCentavos = 0,
    this.valesCentavos = 0,
    this.dieselCentavos = 0,
    this.gastosCentavos = 0,
    this.descontaVales = true,
    this.descontaGastos = false,
    this.paraReceberCentavos = 0,
    this.quantidadeViagens = 0,
    this.observacao,
    this.fechadoEm,
    this.autorId,
  });

  final String id;
  final String motoristaId;
  final DateTime periodoInicio;
  final DateTime periodoFim;
  final int comissaoCentavos;
  final List<DescontoAcerto> descontos;
  final int totalDescontosCentavos;
  final int valesCentavos;
  final int dieselCentavos;
  final int gastosCentavos;
  final bool descontaVales;
  final bool descontaGastos;
  final int paraReceberCentavos;
  final int quantidadeViagens;
  final String? observacao;
  final DateTime? fechadoEm;
  final String? autorId;

  String get periodoTexto => '${dataTexto(periodoInicio)} a ${dataTexto(periodoFim)}';

  bool cobre(DateTime d) {
    final l = d.toLocal();
    final dia = DateTime(l.year, l.month, l.day);
    return !dia.isBefore(periodoInicio) && !dia.isAfter(periodoFim);
  }

  factory Acerto.deMapa(Map<String, Object?> m) => Acerto(
        id: lerTexto(m['id']),
        motoristaId: lerTexto(m['motorista_id']),
        periodoInicio: lerDia(m['periodo_inicio']),
        periodoFim: lerDia(m['periodo_fim']),
        comissaoCentavos: lerInt(m['comissao_centavos']),
        descontos: [
          for (final d in (m['descontos'] as List? ?? const []))
            if (d is Map) DescontoAcerto.deMapa(d.cast<String, Object?>()),
        ],
        totalDescontosCentavos: lerInt(m['total_descontos_centavos']),
        valesCentavos: lerInt(m['vales_centavos']),
        dieselCentavos: lerInt(m['diesel_centavos']),
        gastosCentavos: lerInt(m['gastos_centavos']),
        descontaVales: lerBool(m['desconta_vales'], true),
        descontaGastos: lerBool(m['desconta_gastos']),
        paraReceberCentavos: lerInt(m['para_receber_centavos']),
        quantidadeViagens: lerInt(m['quantidade_viagens']),
        observacao: lerTextoOuNulo(m['observacao']),
        fechadoEm: lerDataOuNula(m['fechado_em']),
        autorId: lerTextoOuNulo(m['autor_id']),
      );

  Map<String, Object?> paraMapa() => {
        'id': id,
        'motorista_id': motoristaId,
        'periodo_inicio': diaIso(periodoInicio),
        'periodo_fim': diaIso(periodoFim),
        'comissao_centavos': comissaoCentavos,
        'descontos': [for (final d in descontos) d.paraMapa()],
        'total_descontos_centavos': totalDescontosCentavos,
        'vales_centavos': valesCentavos,
        'diesel_centavos': dieselCentavos,
        'gastos_centavos': gastosCentavos,
        'desconta_vales': descontaVales,
        'desconta_gastos': descontaGastos,
        'para_receber_centavos': paraReceberCentavos,
        'quantidade_viagens': quantidadeViagens,
        if (observacao != null) 'observacao': observacao,
        if (fechadoEm != null) 'fechado_em': dataIso(fechadoEm!),
        if (autorId != null) 'autor_id': autorId,
      };
}

/// A mesma conta do servidor (fechar_acerto): comissão menos descontos menos
/// vales (se a regra manda) menos diesel e gastos (se a regra manda).
int calcularParaReceber({
  required int comissaoCentavos,
  required List<DescontoAcerto> descontos,
  required int valesCentavos,
  required int dieselCentavos,
  required int gastosCentavos,
  required Regras regras,
}) {
  var r = comissaoCentavos - descontos.fold<int>(0, (s, d) => s + d.valorCentavos);
  if (regras.valeDescontaDoLiquido) r -= valesCentavos;
  if (regras.gastosDescontamDoLiquido) r -= dieselCentavos + gastosCentavos;
  return r;
}

/// "Comissão R$ X menos descontos R$ Y menos vales R$ Z..." (a conta escrita).
String contaDoAcerto(Acerto a) {
  final b = StringBuffer('Comissão ${reais(a.comissaoCentavos)}');
  if (a.totalDescontosCentavos > 0) b.write('  menos descontos ${reais(a.totalDescontosCentavos)}');
  if (a.descontaVales && a.valesCentavos > 0) b.write('  menos vales ${reais(a.valesCentavos)}');
  if (a.descontaGastos && a.dieselCentavos + a.gastosCentavos > 0) {
    b.write('  menos diesel e gastos ${reais(a.dieselCentavos + a.gastosCentavos)}');
  }
  return b.toString();
}
