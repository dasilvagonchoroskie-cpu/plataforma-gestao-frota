// Registros da plataforma. As contas de cada frete são as mesmas do Meu
// Frete; aqui o dinheiro fica em CENTAVOS (inteiro) e as contas devolvem
// centavos com casas (double), arredondados só na hora de mostrar.
//
// paraMapa / deMapa usam os nomes das colunas do banco (snake_case), que são
// os mesmos no celular, na sincronização e no painel.

double lerDouble(Object? v, [double padrao = 0]) {
  if (v == null) return padrao;
  if (v is num) return v.toDouble();
  return double.tryParse(v.toString()) ?? padrao;
}

int lerInt(Object? v, [int padrao = 0]) {
  if (v == null) return padrao;
  if (v is int) return v;
  if (v is num) return v.round();
  return num.tryParse(v.toString())?.round() ?? padrao;
}

String lerTexto(Object? v, [String padrao = '']) => v == null ? padrao : v.toString();

String? lerTextoOuNulo(Object? v) {
  if (v == null) return null;
  final t = v.toString();
  return t.isEmpty ? null : t;
}

bool lerBool(Object? v, [bool padrao = false]) {
  if (v == null) return padrao;
  if (v is bool) return v;
  if (v is num) return v != 0;
  final t = v.toString().toLowerCase();
  return t == 'true' || t == 't' || t == '1';
}

DateTime lerData(Object? v) {
  if (v is DateTime) return v;
  if (v is int) return DateTime.fromMillisecondsSinceEpoch(v, isUtc: true);
  return DateTime.parse(v.toString());
}

DateTime? lerDataOuNula(Object? v) => v == null || v.toString().isEmpty ? null : lerData(v);

List<String> lerLista(Object? v) {
  if (v == null) return const [];
  if (v is List) return v.map((e) => e.toString()).toList();
  final t = v.toString();
  if (t.isEmpty || t == '{}' || t == '[]') return const [];
  // "{a,b}" (Postgres) ou "a,b"
  return t.replaceAll(RegExp(r'[{}\[\]"]'), '').split(',').where((e) => e.isNotEmpty).toList();
}

String dataIso(DateTime d) => d.toUtc().toIso8601String();

class Frete {
  const Frete({
    required this.id,
    required this.motoristaId,
    required this.caminhaoId,
    required this.origem,
    required this.destino,
    this.embarcador = '',
    required this.dataCarga,
    this.pesoCargaKg = 0,
    this.valorToneladaCentavos = 0,
    this.adiantamentoCentavos = 0,
    this.saldoCentavos = 0,
    this.percentualComissao = 13,
    this.comissaoSobreBruto = false,
    this.pedagioCentavos = 0,
    this.pesoDescargaKg = 0,
    this.descontoQuebraCentavos = 0,
    this.empresaId,
    this.criadoNoAparelhoEm,
    this.atualizadoEm,
    this.apagadoEm,
    this.camposAjustados = const [],
  });

  final String id;
  final String? empresaId;
  final String motoristaId;
  final String caminhaoId;
  final String origem;
  final String destino;

  /// Quem contratou o frete (no Meu Frete era "empresa").
  final String embarcador;
  final DateTime dataCarga;
  final double pesoCargaKg;
  final int valorToneladaCentavos;
  final int adiantamentoCentavos;
  final int saldoCentavos;
  final double percentualComissao;
  final bool comissaoSobreBruto;
  final int pedagioCentavos;
  final double pesoDescargaKg;
  final int descontoQuebraCentavos;
  final DateTime? criadoNoAparelhoEm;
  final DateTime? atualizadoEm;
  final DateTime? apagadoEm;

  /// Campos corrigidos pelo gestor (o valor aqui já é o corrigido).
  final List<String> camposAjustados;

  bool get ajustado => camposAjustados.isNotEmpty;

  /// O que caiu na conta: adiantamento + saldo.
  int get freteRealCentavos => adiantamentoCentavos + saldoCentavos;

  /// Peso x valor da tonelada (carta frete).
  double get valorContratadoCentavos => (pesoCargaKg / 1000.0) * valorToneladaCentavos;

  /// Sobre o que a comissão é calculada.
  double get baseComissaoCentavos {
    if (comissaoSobreBruto) {
      final peso = pesoDescargaKg > 0 ? pesoDescargaKg : pesoCargaKg;
      return (peso / 1000.0) * valorToneladaCentavos;
    }
    return freteRealCentavos.toDouble();
  }

  /// A parte do motorista neste frete.
  double get minhaParteCentavos => baseComissaoCentavos * (percentualComissao / 100.0);

  /// Quilos que faltaram na descarga (null se não teve quebra).
  double? get quebraKg {
    if (pesoDescargaKg <= 0 || pesoCargaKg <= 0) return null;
    final q = pesoCargaKg - pesoDescargaKg;
    return q > 0 ? q : null;
  }

  /// Quanto a quebra vale pelo preço da tonelada.
  double get valorQuebraIntegralCentavos {
    final q = quebraKg;
    return q == null ? 0 : (q / 1000.0) * valorToneladaCentavos;
  }

  int get freteSemQuebraCentavos => adiantamentoCentavos + saldoCentavos + descontoQuebraCentavos;

  /// Ainda falta cair o saldo.
  bool get aguardandoSaldo => saldoCentavos <= 0;

  /// Diferença entre o que entrou e o contratado (negativo = desconto).
  double get diferencaDoContratadoCentavos => freteRealCentavos - valorContratadoCentavos;

  String get rota => '$origem para $destino';

  Frete copyWith({
    String? caminhaoId,
    String? origem,
    String? destino,
    String? embarcador,
    DateTime? dataCarga,
    double? pesoCargaKg,
    int? valorToneladaCentavos,
    int? adiantamentoCentavos,
    int? saldoCentavos,
    double? percentualComissao,
    bool? comissaoSobreBruto,
    int? pedagioCentavos,
    double? pesoDescargaKg,
    int? descontoQuebraCentavos,
    DateTime? apagadoEm,
    List<String>? camposAjustados,
  }) =>
      Frete(
        id: id,
        empresaId: empresaId,
        motoristaId: motoristaId,
        caminhaoId: caminhaoId ?? this.caminhaoId,
        origem: origem ?? this.origem,
        destino: destino ?? this.destino,
        embarcador: embarcador ?? this.embarcador,
        dataCarga: dataCarga ?? this.dataCarga,
        pesoCargaKg: pesoCargaKg ?? this.pesoCargaKg,
        valorToneladaCentavos: valorToneladaCentavos ?? this.valorToneladaCentavos,
        adiantamentoCentavos: adiantamentoCentavos ?? this.adiantamentoCentavos,
        saldoCentavos: saldoCentavos ?? this.saldoCentavos,
        percentualComissao: percentualComissao ?? this.percentualComissao,
        comissaoSobreBruto: comissaoSobreBruto ?? this.comissaoSobreBruto,
        pedagioCentavos: pedagioCentavos ?? this.pedagioCentavos,
        pesoDescargaKg: pesoDescargaKg ?? this.pesoDescargaKg,
        descontoQuebraCentavos: descontoQuebraCentavos ?? this.descontoQuebraCentavos,
        criadoNoAparelhoEm: criadoNoAparelhoEm,
        atualizadoEm: atualizadoEm,
        apagadoEm: apagadoEm ?? this.apagadoEm,
        camposAjustados: camposAjustados ?? this.camposAjustados,
      );

  Map<String, Object?> paraMapa() => {
        'id': id,
        if (empresaId != null) 'empresa_id': empresaId,
        'motorista_id': motoristaId,
        'caminhao_id': caminhaoId,
        'origem': origem,
        'destino': destino,
        'embarcador': embarcador,
        'data_carga': dataIso(dataCarga),
        'peso_carga_kg': pesoCargaKg,
        'valor_tonelada_centavos': valorToneladaCentavos,
        'adiantamento_centavos': adiantamentoCentavos,
        'saldo_centavos': saldoCentavos,
        'percentual_comissao': percentualComissao,
        'comissao_sobre_bruto': comissaoSobreBruto,
        'pedagio_centavos': pedagioCentavos,
        'peso_descarga_kg': pesoDescargaKg,
        'desconto_quebra_centavos': descontoQuebraCentavos,
        if (criadoNoAparelhoEm != null) 'criado_no_aparelho_em': dataIso(criadoNoAparelhoEm!),
        if (apagadoEm != null) 'apagado_em': dataIso(apagadoEm!),
      };

  factory Frete.deMapa(Map<String, Object?> m) => Frete(
        id: lerTexto(m['id']),
        empresaId: lerTextoOuNulo(m['empresa_id']),
        motoristaId: lerTexto(m['motorista_id']),
        caminhaoId: lerTexto(m['caminhao_id']),
        origem: lerTexto(m['origem']),
        destino: lerTexto(m['destino']),
        embarcador: lerTexto(m['embarcador']),
        dataCarga: lerData(m['data_carga']),
        pesoCargaKg: lerDouble(m['peso_carga_kg']),
        valorToneladaCentavos: lerInt(m['valor_tonelada_centavos']),
        adiantamentoCentavos: lerInt(m['adiantamento_centavos']),
        saldoCentavos: lerInt(m['saldo_centavos']),
        percentualComissao: lerDouble(m['percentual_comissao'], 13),
        comissaoSobreBruto: lerBool(m['comissao_sobre_bruto']),
        pedagioCentavos: lerInt(m['pedagio_centavos']),
        pesoDescargaKg: lerDouble(m['peso_descarga_kg']),
        descontoQuebraCentavos: lerInt(m['desconto_quebra_centavos']),
        criadoNoAparelhoEm: lerDataOuNula(m['criado_no_aparelho_em']),
        atualizadoEm: lerDataOuNula(m['atualizado_em']),
        apagadoEm: lerDataOuNula(m['apagado_em']),
        camposAjustados: lerLista(m['campos_ajustados']),
      );
}

class Abastecimento {
  const Abastecimento({
    required this.id,
    required this.motoristaId,
    required this.caminhaoId,
    required this.data,
    this.freteId,
    this.cidade = '',
    this.posto = '',
    this.litros = 0,
    this.valorCentavos = 0,
    required this.kmOdometro,
    this.tanqueCheio = true,
    this.pontoDePartida = false,
    this.empresaId,
    this.criadoNoAparelhoEm,
    this.atualizadoEm,
    this.apagadoEm,
    this.camposAjustados = const [],
  });

  final String id;
  final String? empresaId;
  final String motoristaId;
  final String caminhaoId;
  final String? freteId;
  final DateTime data;
  final String cidade;
  final String posto;
  final double litros;
  final int valorCentavos;
  final double kmOdometro;
  final bool tanqueCheio;

  /// Km anotado do painel no começo, só para a média começar certa.
  final bool pontoDePartida;
  final DateTime? criadoNoAparelhoEm;
  final DateTime? atualizadoEm;
  final DateTime? apagadoEm;
  final List<String> camposAjustados;

  bool get ajustado => camposAjustados.isNotEmpty;

  /// Atalhos com os nomes do Meu Frete.
  double get km => kmOdometro;

  double get precoLitroCentavos => litros > 0 ? valorCentavos / litros : 0;

  Abastecimento copyWith({
    String? caminhaoId,
    String? freteId,
    bool limparFrete = false,
    DateTime? data,
    String? cidade,
    String? posto,
    double? litros,
    int? valorCentavos,
    double? kmOdometro,
    bool? tanqueCheio,
    DateTime? apagadoEm,
  }) =>
      Abastecimento(
        id: id,
        empresaId: empresaId,
        motoristaId: motoristaId,
        caminhaoId: caminhaoId ?? this.caminhaoId,
        freteId: limparFrete ? null : (freteId ?? this.freteId),
        data: data ?? this.data,
        cidade: cidade ?? this.cidade,
        posto: posto ?? this.posto,
        litros: litros ?? this.litros,
        valorCentavos: valorCentavos ?? this.valorCentavos,
        kmOdometro: kmOdometro ?? this.kmOdometro,
        tanqueCheio: tanqueCheio ?? this.tanqueCheio,
        pontoDePartida: pontoDePartida,
        criadoNoAparelhoEm: criadoNoAparelhoEm,
        atualizadoEm: atualizadoEm,
        apagadoEm: apagadoEm ?? this.apagadoEm,
        camposAjustados: camposAjustados,
      );

  Map<String, Object?> paraMapa() => {
        'id': id,
        if (empresaId != null) 'empresa_id': empresaId,
        'motorista_id': motoristaId,
        'caminhao_id': caminhaoId,
        if (freteId != null) 'frete_id': freteId,
        'data': dataIso(data),
        'cidade': cidade,
        'posto': posto,
        'litros': litros,
        'valor_centavos': valorCentavos,
        'km_odometro': kmOdometro,
        'tanque_cheio': tanqueCheio,
        'ponto_de_partida': pontoDePartida,
        if (criadoNoAparelhoEm != null) 'criado_no_aparelho_em': dataIso(criadoNoAparelhoEm!),
        if (apagadoEm != null) 'apagado_em': dataIso(apagadoEm!),
      };

  factory Abastecimento.deMapa(Map<String, Object?> m) => Abastecimento(
        id: lerTexto(m['id']),
        empresaId: lerTextoOuNulo(m['empresa_id']),
        motoristaId: lerTexto(m['motorista_id']),
        caminhaoId: lerTexto(m['caminhao_id']),
        freteId: lerTextoOuNulo(m['frete_id']),
        data: lerData(m['data']),
        cidade: lerTexto(m['cidade']),
        posto: lerTexto(m['posto']),
        litros: lerDouble(m['litros']),
        valorCentavos: lerInt(m['valor_centavos']),
        kmOdometro: lerDouble(m['km_odometro']),
        tanqueCheio: lerBool(m['tanque_cheio'], true),
        pontoDePartida: lerBool(m['ponto_de_partida']),
        criadoNoAparelhoEm: lerDataOuNula(m['criado_no_aparelho_em']),
        atualizadoEm: lerDataOuNula(m['atualizado_em']),
        apagadoEm: lerDataOuNula(m['apagado_em']),
        camposAjustados: lerLista(m['campos_ajustados']),
      );
}

/// Registro de cada mudança do km inicial (sai no pé do relatório).
class AjusteKm {
  const AjusteKm({
    required this.id,
    required this.motoristaId,
    required this.caminhaoId,
    required this.quando,
    required this.kmAnterior,
    required this.kmNovo,
    required this.motivo,
    this.empresaId,
  });

  final String id;
  final String? empresaId;
  final String motoristaId;
  final String caminhaoId;
  final DateTime quando;
  final double kmAnterior;
  final double kmNovo;
  final String motivo;

  Map<String, Object?> paraMapa() => {
        'id': id,
        if (empresaId != null) 'empresa_id': empresaId,
        'motorista_id': motoristaId,
        'caminhao_id': caminhaoId,
        'quando': dataIso(quando),
        'km_anterior': kmAnterior,
        'km_novo': kmNovo,
        'motivo': motivo,
      };

  factory AjusteKm.deMapa(Map<String, Object?> m) => AjusteKm(
        id: lerTexto(m['id']),
        empresaId: lerTextoOuNulo(m['empresa_id']),
        motoristaId: lerTexto(m['motorista_id']),
        caminhaoId: lerTexto(m['caminhao_id']),
        quando: lerData(m['quando']),
        kmAnterior: lerDouble(m['km_anterior']),
        kmNovo: lerDouble(m['km_novo']),
        motivo: lerTexto(m['motivo']),
      );
}

class Gasto {
  const Gasto({
    required this.id,
    required this.motoristaId,
    required this.caminhaoId,
    required this.data,
    required this.categoriaId,
    required this.valorCentavos,
    this.categoriaNome = '',
    this.freteId,
    this.observacao,
    this.empresaId,
    this.criadoNoAparelhoEm,
    this.atualizadoEm,
    this.apagadoEm,
    this.camposAjustados = const [],
  });

  final String id;
  final String? empresaId;
  final String motoristaId;
  final String caminhaoId;
  final String? freteId;
  final DateTime data;
  final String categoriaId;

  /// Nome da categoria (só para mostrar; não vai para o banco).
  final String categoriaNome;
  final int valorCentavos;
  final String? observacao;
  final DateTime? criadoNoAparelhoEm;
  final DateTime? atualizadoEm;
  final DateTime? apagadoEm;
  final List<String> camposAjustados;

  bool get ajustado => camposAjustados.isNotEmpty;

  /// Atalho com o nome do Meu Frete.
  String get categoria => categoriaNome;

  Gasto comCategoria(String nome) => Gasto(
        id: id,
        empresaId: empresaId,
        motoristaId: motoristaId,
        caminhaoId: caminhaoId,
        freteId: freteId,
        data: data,
        categoriaId: categoriaId,
        categoriaNome: nome,
        valorCentavos: valorCentavos,
        observacao: observacao,
        criadoNoAparelhoEm: criadoNoAparelhoEm,
        atualizadoEm: atualizadoEm,
        apagadoEm: apagadoEm,
        camposAjustados: camposAjustados,
      );

  Gasto copyWith({
    String? caminhaoId,
    DateTime? data,
    String? categoriaId,
    String? categoriaNome,
    int? valorCentavos,
    String? observacao,
    DateTime? apagadoEm,
  }) =>
      Gasto(
        id: id,
        empresaId: empresaId,
        motoristaId: motoristaId,
        caminhaoId: caminhaoId ?? this.caminhaoId,
        freteId: freteId,
        data: data ?? this.data,
        categoriaId: categoriaId ?? this.categoriaId,
        categoriaNome: categoriaNome ?? this.categoriaNome,
        valorCentavos: valorCentavos ?? this.valorCentavos,
        observacao: observacao ?? this.observacao,
        criadoNoAparelhoEm: criadoNoAparelhoEm,
        atualizadoEm: atualizadoEm,
        apagadoEm: apagadoEm ?? this.apagadoEm,
        camposAjustados: camposAjustados,
      );

  Map<String, Object?> paraMapa() => {
        'id': id,
        if (empresaId != null) 'empresa_id': empresaId,
        'motorista_id': motoristaId,
        'caminhao_id': caminhaoId,
        if (freteId != null) 'frete_id': freteId,
        'data': dataIso(data),
        'categoria_id': categoriaId,
        'valor_centavos': valorCentavos,
        if (observacao != null && observacao!.isNotEmpty) 'observacao': observacao,
        if (criadoNoAparelhoEm != null) 'criado_no_aparelho_em': dataIso(criadoNoAparelhoEm!),
        if (apagadoEm != null) 'apagado_em': dataIso(apagadoEm!),
      };

  factory Gasto.deMapa(Map<String, Object?> m, {String categoriaNome = ''}) => Gasto(
        id: lerTexto(m['id']),
        empresaId: lerTextoOuNulo(m['empresa_id']),
        motoristaId: lerTexto(m['motorista_id']),
        caminhaoId: lerTexto(m['caminhao_id']),
        freteId: lerTextoOuNulo(m['frete_id']),
        data: lerData(m['data']),
        categoriaId: lerTexto(m['categoria_id']),
        categoriaNome: categoriaNome,
        valorCentavos: lerInt(m['valor_centavos']),
        observacao: lerTextoOuNulo(m['observacao']),
        criadoNoAparelhoEm: lerDataOuNula(m['criado_no_aparelho_em']),
        atualizadoEm: lerDataOuNula(m['atualizado_em']),
        apagadoEm: lerDataOuNula(m['apagado_em']),
        camposAjustados: lerLista(m['campos_ajustados']),
      );
}

/// Dinheiro que o motorista pegou adiantado.
class Vale {
  const Vale({
    required this.id,
    required this.motoristaId,
    required this.data,
    required this.valorCentavos,
    this.observacao,
    this.empresaId,
    this.criadoNoAparelhoEm,
    this.atualizadoEm,
    this.apagadoEm,
    this.camposAjustados = const [],
  });

  final String id;
  final String? empresaId;
  final String motoristaId;
  final DateTime data;
  final int valorCentavos;
  final String? observacao;
  final DateTime? criadoNoAparelhoEm;
  final DateTime? atualizadoEm;
  final DateTime? apagadoEm;
  final List<String> camposAjustados;

  bool get ajustado => camposAjustados.isNotEmpty;

  Vale copyWith({DateTime? data, int? valorCentavos, String? observacao, DateTime? apagadoEm}) => Vale(
        id: id,
        empresaId: empresaId,
        motoristaId: motoristaId,
        data: data ?? this.data,
        valorCentavos: valorCentavos ?? this.valorCentavos,
        observacao: observacao ?? this.observacao,
        criadoNoAparelhoEm: criadoNoAparelhoEm,
        atualizadoEm: atualizadoEm,
        apagadoEm: apagadoEm ?? this.apagadoEm,
        camposAjustados: camposAjustados,
      );

  Map<String, Object?> paraMapa() => {
        'id': id,
        if (empresaId != null) 'empresa_id': empresaId,
        'motorista_id': motoristaId,
        'data': dataIso(data),
        'valor_centavos': valorCentavos,
        if (observacao != null && observacao!.isNotEmpty) 'observacao': observacao,
        if (criadoNoAparelhoEm != null) 'criado_no_aparelho_em': dataIso(criadoNoAparelhoEm!),
        if (apagadoEm != null) 'apagado_em': dataIso(apagadoEm!),
      };

  factory Vale.deMapa(Map<String, Object?> m) => Vale(
        id: lerTexto(m['id']),
        empresaId: lerTextoOuNulo(m['empresa_id']),
        motoristaId: lerTexto(m['motorista_id']),
        data: lerData(m['data']),
        valorCentavos: lerInt(m['valor_centavos']),
        observacao: lerTextoOuNulo(m['observacao']),
        criadoNoAparelhoEm: lerDataOuNula(m['criado_no_aparelho_em']),
        atualizadoEm: lerDataOuNula(m['atualizado_em']),
        apagadoEm: lerDataOuNula(m['apagado_em']),
        camposAjustados: lerLista(m['campos_ajustados']),
      );
}

class Caminhao {
  const Caminhao({
    required this.id,
    required this.placa,
    this.numeroFrota,
    this.modelo = '',
    this.ano,
    this.ativo = true,
    this.confirmado = true,
    this.empresaId,
  });

  final String id;
  final String? empresaId;

  /// Sem traço e em maiúsculas.
  final String placa;
  final String? numeroFrota;
  final String modelo;
  final int? ano;
  final bool ativo;

  /// Falso quando o motorista cadastrou e o gestor ainda não conferiu.
  final bool confirmado;

  Map<String, Object?> paraMapa() => {
        'id': id,
        if (empresaId != null) 'empresa_id': empresaId,
        'placa': placa,
        if (numeroFrota != null) 'numero_frota': numeroFrota,
        'modelo': modelo,
        if (ano != null) 'ano': ano,
        'ativo': ativo,
        'confirmado': confirmado,
      };

  factory Caminhao.deMapa(Map<String, Object?> m) => Caminhao(
        id: lerTexto(m['id']),
        empresaId: lerTextoOuNulo(m['empresa_id']),
        placa: lerTexto(m['placa']),
        numeroFrota: lerTextoOuNulo(m['numero_frota']),
        modelo: lerTexto(m['modelo']),
        ano: m['ano'] == null ? null : lerInt(m['ano']),
        ativo: lerBool(m['ativo'], true),
        confirmado: lerBool(m['confirmado'], true),
      );
}

class CategoriaGasto {
  const CategoriaGasto({required this.id, required this.nome, this.ativa = true});

  final String id;
  final String nome;
  final bool ativa;

  Map<String, Object?> paraMapa() => {'id': id, 'nome': nome, 'ativa': ativa};

  factory CategoriaGasto.deMapa(Map<String, Object?> m) =>
      CategoriaGasto(id: lerTexto(m['id']), nome: lerTexto(m['nome']), ativa: lerBool(m['ativa'], true));
}

/// Período em que um motorista esteve num caminhão.
class UsoCaminhao {
  const UsoCaminhao({
    required this.id,
    required this.motoristaId,
    required this.caminhaoId,
    required this.inicioEm,
    this.fimEm,
  });

  final String id;
  final String motoristaId;
  final String caminhaoId;
  final DateTime inicioEm;
  final DateTime? fimEm;

  bool get aberto => fimEm == null;

  Map<String, Object?> paraMapa() => {
        'id': id,
        'motorista_id': motoristaId,
        'caminhao_id': caminhaoId,
        'inicio_em': dataIso(inicioEm),
        if (fimEm != null) 'fim_em': dataIso(fimEm!),
      };

  factory UsoCaminhao.deMapa(Map<String, Object?> m) => UsoCaminhao(
        id: lerTexto(m['id']),
        motoristaId: lerTexto(m['motorista_id']),
        caminhaoId: lerTexto(m['caminhao_id']),
        inicioEm: lerData(m['inicio_em']),
        fimEm: lerDataOuNula(m['fim_em']),
      );
}

/// Correção do gestor num campo de um lançamento.
class AjusteGestor {
  const AjusteGestor({
    required this.id,
    required this.tabelaAlvo,
    required this.registroId,
    required this.campo,
    required this.valorNovo,
    this.valorAntigo,
    required this.motivo,
    required this.criadoEm,
    this.autorId,
    this.apagado = false,
  });

  final String id;
  final String tabelaAlvo;
  final String registroId;
  final String campo;
  final Object? valorAntigo;
  final Object? valorNovo;
  final String motivo;
  final DateTime criadoEm;
  final String? autorId;
  final bool apagado;

  factory AjusteGestor.deMapa(Map<String, Object?> m) => AjusteGestor(
        id: lerTexto(m['id']),
        tabelaAlvo: lerTexto(m['tabela_alvo']),
        registroId: lerTexto(m['registro_id']),
        campo: lerTexto(m['campo']),
        valorAntigo: m['valor_antigo'],
        valorNovo: m['valor_novo'],
        motivo: lerTexto(m['motivo']),
        criadoEm: lerData(m['criado_em']),
        autorId: lerTextoOuNulo(m['autor_id']),
        apagado: lerBool(m['apagado']) || m['apagado_em'] != null,
      );

  Map<String, Object?> paraMapa() => {
        'id': id,
        'tabela_alvo': tabelaAlvo,
        'registro_id': registroId,
        'campo': campo,
        'valor_antigo': valorAntigo,
        'valor_novo': valorNovo,
        'motivo': motivo,
        'criado_em': dataIso(criadoEm),
        if (autorId != null) 'autor_id': autorId,
        'apagado': apagado,
      };
}

/// Como a empresa acerta com o motorista (as perguntas do Meu Frete).
class ConfiguracaoEmpresa {
  const ConfiguracaoEmpresa({
    this.percentualComissaoPadrao = 13,
    this.comissaoSobreBrutoPadrao = false,
    this.gastosDescontamDoLiquido = false,
    this.valeDescontaDoLiquido = true,
  });

  final double percentualComissaoPadrao;
  final bool comissaoSobreBrutoPadrao;
  final bool gastosDescontamDoLiquido;
  final bool valeDescontaDoLiquido;

  factory ConfiguracaoEmpresa.deMapa(Map<String, Object?>? m) {
    if (m == null) return const ConfiguracaoEmpresa();
    return ConfiguracaoEmpresa(
      percentualComissaoPadrao: lerDouble(m['percentual_comissao_padrao'], 13),
      comissaoSobreBrutoPadrao: lerBool(m['comissao_sobre_bruto_padrao']),
      gastosDescontamDoLiquido: lerBool(m['gastos_descontam_do_liquido']),
      valeDescontaDoLiquido: lerBool(m['vale_desconta_do_liquido'], true),
    );
  }

  Map<String, Object?> paraMapa() => {
        'percentual_comissao_padrao': percentualComissaoPadrao,
        'comissao_sobre_bruto_padrao': comissaoSobreBrutoPadrao,
        'gastos_descontam_do_liquido': gastosDescontamDoLiquido,
        'vale_desconta_do_liquido': valeDescontaDoLiquido,
      };
}
