import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nucleo/nucleo.dart';
import 'package:uuid/uuid.dart';

import '../servidor/servidor.dart';
import 'armazenamento.dart';

final armazenamentoProvider = Provider<Armazenamento>((ref) => throw UnimplementedError('defina no main'));
final servidorProvider = Provider<Servidor>((ref) => throw UnimplementedError('defina no main'));
final relogioProvider = Provider<DateTime Function()>((ref) => DateTime.now);

const _uuid = Uuid();
String novoId() => _uuid.v4();

/// Tabelas que o motorista lança e manda para a nuvem.
abstract final class Tabelas {
  static const fretes = 'fretes';
  static const abastecimentos = 'abastecimentos';
  static const gastos = 'gastos_viagem';
  static const vales = 'vales';
  static const ajustesKm = 'ajustes_km';
  static const usos = 'uso_caminhao';
  static const caminhoes = 'caminhoes';
  static const categorias = 'categorias_gasto';
  static const ajustes = 'ajustes_gestor';

  static const lancamentos = [fretes, abastecimentos, gastos, vales, ajustesKm, usos];
  static const todas = [fretes, abastecimentos, gastos, vales, ajustesKm, usos, caminhoes, categorias, ajustes];
}

/// O que veio da última vez que o app conversou com a empresa.
class InfoMotorista {
  const InfoMotorista({
    this.motoristaId,
    this.nome = '',
    this.empresaNome = '',
    this.empresaStatus = '',
    this.motoristaAtivo = true,
    this.configuracao = const ConfiguracaoEmpresa(),
  });

  final String? motoristaId;
  final String nome;
  final String empresaNome;
  final String empresaStatus;
  final bool motoristaAtivo;
  final ConfiguracaoEmpresa configuracao;

  bool get suspensa => empresaStatus == 'suspensa';

  factory InfoMotorista.daSituacao(Map<String, Object?> s) {
    final perfil = (s['perfil'] as Map?)?.cast<String, Object?>() ?? const {};
    final empresa = (s['empresa'] as Map?)?.cast<String, Object?>();
    final motorista = (s['motorista'] as Map?)?.cast<String, Object?>();
    return InfoMotorista(
      motoristaId: motorista?['id'] as String?,
      nome: lerTexto(motorista?['nome'] ?? perfil['nome']),
      empresaNome: lerTexto(empresa?['nome']),
      empresaStatus: lerTexto(empresa?['status']),
      motoristaAtivo: motorista != null && lerBool(motorista['ativo'], true) && lerBool(perfil['ativo'], true),
      configuracao: ConfiguracaoEmpresa.deMapa(empresa),
    );
  }
}

/// Foto de tudo que está no celular, já com os ajustes do gestor aplicados.
class EstadoDados {
  const EstadoDados({
    this.info = const InfoMotorista(),
    this.fretes = const [],
    this.abastecimentos = const [],
    this.gastos = const [],
    this.vales = const [],
    this.ajustesKm = const [],
    this.usos = const [],
    this.caminhoes = const [],
    this.categorias = const [],
    this.ajustes = const [],
    this.pendentes = const {},
    this.recusados = const [],
  });

  final InfoMotorista info;

  /// Lançamentos que valem (sem os apagados), mais novos primeiro.
  final List<Frete> fretes;

  /// Abastecidas de todos os caminhões, inclusive os pontos de partida.
  final List<Abastecimento> abastecimentos;
  final List<Gasto> gastos;
  final List<Vale> vales;
  final List<AjusteKm> ajustesKm;
  final List<UsoCaminhao> usos;
  final List<Caminhao> caminhoes;
  final List<CategoriaGasto> categorias;
  final List<AjusteGestor> ajustes;

  /// "tabela:id" de cada registro que ainda não chegou na nuvem.
  final Set<String> pendentes;
  final List<ItemFila> recusados;

  int get quantidadePendente => pendentes.length;

  bool estaPendente(String tabela, String id) => pendentes.contains('$tabela:$id');

  Regras get regras => Regras.daEmpresa(info.configuracao);

  /// Caminhão em que o motorista está agora (última troca).
  String? get caminhaoAtualId => usos.isEmpty ? null : usos.first.caminhaoId;

  Caminhao? get caminhaoAtual => caminhaoPorId(caminhaoAtualId);

  Caminhao? caminhaoPorId(String? id) {
    if (id == null) return null;
    for (final c in caminhoes) {
      if (c.id == id) return c;
    }
    return null;
  }

  String placaDe(String caminhaoId) => caminhaoPorId(caminhaoId)?.placa ?? '';

  Map<String, String> get placasPorCaminhao => {for (final c in caminhoes) c.id: c.placa};

  List<Caminhao> get caminhoesAtivos =>
      caminhoes.where((c) => c.ativo).toList()..sort((a, b) => a.placa.compareTo(b.placa));

  List<CategoriaGasto> get categoriasAtivas =>
      categorias.where((c) => c.ativa).toList()..sort((a, b) => a.nome.compareTo(b.nome));

  String nomeCategoria(String id) {
    for (final c in categorias) {
      if (c.id == id) return c.nome;
    }
    return 'Sem categoria';
  }

  /// Abastecidas de verdade de um caminhão (sem o ponto de partida).
  List<Abastecimento> abastecidasDo(String? caminhaoId) =>
      abastecimentos.where((a) => !a.pontoDePartida && a.caminhaoId == caminhaoId).toList();

  Abastecimento? pontoDePartidaDo(String? caminhaoId) {
    for (final a in abastecimentos) {
      if (a.pontoDePartida && a.caminhaoId == caminhaoId) return a;
    }
    return null;
  }

  Frete? freteComId(String? id) {
    if (id == null) return null;
    for (final f in fretes) {
      if (f.id == id) return f;
    }
    return null;
  }

  List<AjusteGestor> ajustesDe(String registroId) =>
      ajustes.where((a) => a.registroId == registroId && !a.apagado).toList()
        ..sort((a, b) => b.criadoEm.compareTo(a.criadoEm));

  /// Cidades já usadas (sugestão nos formulários).
  List<String> get cidadesUsadas {
    final s = <String>{
      for (final f in fretes) ...[f.origem.trim(), f.destino.trim()],
      for (final a in abastecimentos) a.cidade.trim(),
    }..remove('');
    return s.toList()..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
  }

  List<String> get embarcadoresUsados {
    final s = <String>{for (final f in fretes) f.embarcador.trim()}..remove('');
    return s.toList()..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
  }

  List<String> get postosUsados {
    final s = <String>{for (final a in abastecimentos) a.posto.trim()}..remove('');
    return s.toList()..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
  }

  DadosRelatorio dadosDoPeriodo(Periodo periodo, {ConteudoRelatorio conteudo = ConteudoRelatorio.tudo}) => montarDados(
        fretes: fretes,
        abastecimentos: abastecimentos,
        vales: vales,
        gastos: gastos,
        ajustes: ajustesKm,
        periodo: periodo,
        regras: regras,
        conteudo: conteudo,
        motorista: info.nome,
        placa: _placaDoPeriodo(periodo),
        empresa: info.empresaNome,
        placasPorCaminhao: placasPorCaminhao,
      );

  DadosRelatorio dadosDaViagem(Frete frete) => montarDadosDaViagem(
        frete: frete,
        fretes: fretes,
        abastecimentos: abastecimentos,
        vales: vales,
        gastos: gastos,
        ajustes: ajustesKm,
        regras: regras,
        motorista: info.nome,
        placa: placaDe(frete.caminhaoId),
        empresa: info.empresaNome,
        placasPorCaminhao: placasPorCaminhao,
      );

  /// Placa no cabeçalho: a do caminhão usado no período, ou "Vários".
  String _placaDoPeriodo(Periodo p) {
    final ids = {
      ...fretes.where((f) => p.contem(f.dataCarga)).map((f) => f.caminhaoId),
      ...abastecimentos.where((a) => !a.pontoDePartida && p.contem(a.data)).map((a) => a.caminhaoId),
      ...gastos.where((g) => p.contem(g.data)).map((g) => g.caminhaoId),
    };
    if (ids.isEmpty) return caminhaoAtual?.placa ?? '';
    if (ids.length == 1) return placaDe(ids.first);
    return 'Vários';
  }
}

/// Os dados do motorista no celular. Grava primeiro aqui e põe na fila; a
/// sincronização leva para a nuvem quando tiver internet.
class Dados extends AsyncNotifier<EstadoDados> {
  Armazenamento get _a => ref.read(armazenamentoProvider);
  DateTime _agora() => ref.read(relogioProvider)();

  @override
  Future<EstadoDados> build() => _carregar();

  Future<EstadoDados> _carregar() async {
    final a = ref.read(armazenamentoProvider);
    final brutos = <String, List<Map<String, Object?>>>{
      for (final t in Tabelas.todas) t: await a.registros(t),
    };
    final ajustes = [for (final m in brutos[Tabelas.ajustes]!) AjusteGestor.deMapa(m)];
    List<Map<String, Object?>> vivos(String t) =>
        [for (final m in brutos[t]!) if (m['apagado_em'] == null) aplicarAjustes(m, ajustes)];

    final categorias = [for (final m in brutos[Tabelas.categorias]!) CategoriaGasto.deMapa(m)];
    final nomes = {for (final c in categorias) c.id: c.nome};
    final info = await _lerInfo(a);
    final fila = await a.fila();

    return EstadoDados(
      info: info,
      fretes: [for (final m in vivos(Tabelas.fretes)) Frete.deMapa(m)]..sort((x, y) => y.dataCarga.compareTo(x.dataCarga)),
      abastecimentos: [for (final m in vivos(Tabelas.abastecimentos)) Abastecimento.deMapa(m)]
        ..sort((x, y) => y.data.compareTo(x.data) != 0 ? y.data.compareTo(x.data) : y.km.compareTo(x.km)),
      gastos: [
        for (final m in vivos(Tabelas.gastos))
          Gasto.deMapa(m, categoriaNome: nomes[m['categoria_id']] ?? 'Sem categoria'),
      ]..sort((x, y) => y.data.compareTo(x.data)),
      vales: [for (final m in vivos(Tabelas.vales)) Vale.deMapa(m)]..sort((x, y) => y.data.compareTo(x.data)),
      ajustesKm: [for (final m in vivos(Tabelas.ajustesKm)) AjusteKm.deMapa(m)]
        ..sort((x, y) => y.quando.compareTo(x.quando)),
      usos: [for (final m in vivos(Tabelas.usos)) UsoCaminhao.deMapa(m)]..sort((x, y) => y.inicioEm.compareTo(x.inicioEm)),
      caminhoes: [for (final m in brutos[Tabelas.caminhoes]!) Caminhao.deMapa(m)],
      categorias: categorias,
      ajustes: ajustes,
      pendentes: {for (final i in fila) if (i.situacao == 'pendente') i.chave},
      recusados: [for (final i in fila) if (i.situacao == 'recusado') i],
    );
  }

  static Future<InfoMotorista> _lerInfo(Armazenamento a) async {
    final t = await a.lerEstado('situacao');
    if (t == null) return const InfoMotorista();
    return InfoMotorista.daSituacao((jsonDecode(t) as Map).cast<String, Object?>());
  }

  Future<void> recarregar() async => state = AsyncData(await _carregar());

  EstadoDados get _atual => state.requireValue;
  String get _motoristaId => _atual.info.motoristaId ?? '';

  Future<void> _gravar(String tabela, Map<String, Object?> mapa) async {
    await _a.gravarRegistros(tabela, [mapa]);
    await _a.enfileirar(tabela, mapa['id'].toString(), mapa);
    await recarregar();
  }

  Future<void> _apagar(String tabela, Map<String, Object?> mapa) =>
      _gravar(tabela, {...mapa, 'apagado_em': dataIso(_agora())});

  /// O gestor já corrigiu: o motorista não muda mais (fala com o patrão).
  bool podeAlterar(String registroId) => _atual.ajustesDe(registroId).isEmpty;

  Future<void> salvarFrete(Frete f) => _gravar(Tabelas.fretes, f.paraMapa());
  Future<void> apagarFrete(Frete f) => _apagar(Tabelas.fretes, f.paraMapa());
  Future<void> salvarAbastecimento(Abastecimento a) => _gravar(Tabelas.abastecimentos, a.paraMapa());
  Future<void> apagarAbastecimento(Abastecimento a) => _apagar(Tabelas.abastecimentos, a.paraMapa());
  Future<void> salvarGasto(Gasto g) => _gravar(Tabelas.gastos, g.paraMapa());
  Future<void> apagarGasto(Gasto g) => _apagar(Tabelas.gastos, g.paraMapa());
  Future<void> salvarVale(Vale v) => _gravar(Tabelas.vales, v.paraMapa());
  Future<void> apagarVale(Vale v) => _apagar(Tabelas.vales, v.paraMapa());

  /// Km inicial do caminhão: salva o ponto de partida e, se o km mudou,
  /// o registro da mudança (com motivo), como no Meu Frete.
  Future<void> salvarPontoDePartida({
    required String caminhaoId,
    required double km,
    DateTime? data,
    String cidade = '',
    String motivo = '',
  }) async {
    final atual = _atual.pontoDePartidaDo(caminhaoId);
    final agora = _agora();
    if (atual != null && atual.km != km) {
      final ajuste = AjusteKm(
        id: novoId(),
        motoristaId: _motoristaId,
        caminhaoId: caminhaoId,
        quando: agora,
        kmAnterior: atual.km,
        kmNovo: km,
        motivo: motivo.trim().isEmpty ? 'Sem motivo informado' : motivo.trim(),
      );
      await _a.gravarRegistros(Tabelas.ajustesKm, [ajuste.paraMapa()]);
      await _a.enfileirar(Tabelas.ajustesKm, ajuste.id, ajuste.paraMapa());
    }
    final ponto = atual?.copyWith(kmOdometro: km, data: data, cidade: cidade) ??
        Abastecimento(
          id: novoId(),
          motoristaId: _motoristaId,
          caminhaoId: caminhaoId,
          data: data ?? inicioDoDia(agora),
          cidade: cidade,
          kmOdometro: km,
          tanqueCheio: true,
          pontoDePartida: true,
          criadoNoAparelhoEm: agora,
        );
    await _gravar(Tabelas.abastecimentos, ponto.paraMapa());
  }

  /// Passa a lançar no caminhão escolhido. Nada do que já foi lançado muda.
  Future<void> trocarCaminhao(String caminhaoId) async {
    if (_atual.caminhaoAtualId == caminhaoId) return;
    // A troca nova é sempre depois da última, mesmo com o relógio do celular
    // atrasado (senão ela entraria no meio do histórico).
    var inicio = _agora();
    final ultima = _atual.usos.isEmpty ? null : _atual.usos.first.inicioEm;
    if (ultima != null && !inicio.isAfter(ultima)) inicio = ultima.add(const Duration(seconds: 1));
    final uso = UsoCaminhao(id: novoId(), motoristaId: _motoristaId, caminhaoId: caminhaoId, inicioEm: inicio);
    await _gravar(Tabelas.usos, uso.paraMapa());
  }

  /// "Não achei meu caminhão": cadastra a placa (o gestor confere depois) e
  /// já passa a usar.
  Future<String> cadastrarCaminhao(String placa, {String numeroFrota = ''}) async {
    final p = normalizarPlaca(placa);
    for (final c in _atual.caminhoes) {
      if (c.placa == p) {
        await trocarCaminhao(c.id);
        return c.id;
      }
    }
    final c = Caminhao(
      id: novoId(),
      placa: p,
      numeroFrota: numeroFrota.trim().isEmpty ? null : numeroFrota.trim(),
      confirmado: false,
    );
    await _a.gravarRegistros(Tabelas.caminhoes, [c.paraMapa()]);
    await _a.enfileirar(Tabelas.caminhoes, c.id, c.paraMapa());
    await trocarCaminhao(c.id);
    return c.id;
  }

  /// O motorista viu o aviso de um envio recusado.
  Future<void> dispensarRecusado(ItemFila item) async {
    await _a.removerDaFila(item.tabela, item.registroId);
    await recarregar();
  }

  /// Novo frete já com a comissão que a empresa usa.
  Frete novoFrete() {
    final c = _atual.info.configuracao;
    return Frete(
      id: novoId(),
      motoristaId: _motoristaId,
      caminhaoId: _atual.caminhaoAtualId ?? '',
      origem: '',
      destino: '',
      dataCarga: inicioDoDia(_agora()),
      percentualComissao: c.percentualComissaoPadrao,
      comissaoSobreBruto: c.comissaoSobreBrutoPadrao,
      criadoNoAparelhoEm: _agora(),
    );
  }
}

final dadosProvider = AsyncNotifierProvider<Dados, EstadoDados>(Dados.new);
