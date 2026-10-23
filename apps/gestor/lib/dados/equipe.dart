import 'package:nucleo/nucleo.dart';

import '../servidor/servidor.dart';
import 'modelos.dart';

/// Os lançamentos de um recorte (um motorista, um caminhão, um embarcador ou
/// a frota toda), de todo o tempo. O período é aplicado depois (montarDados).
class Lancamentos {
  const Lancamentos({
    this.fretes = const [],
    this.abastecimentos = const [],
    this.gastos = const [],
    this.vales = const [],
    this.ajustesKm = const [],
    this.viagens = const [],
  });

  final List<Frete> fretes;
  final List<Abastecimento> abastecimentos;
  final List<Gasto> gastos;
  final List<Vale> vales;
  final List<AjusteKm> ajustesKm;

  /// Viagens do Baú e do Sider.
  final List<Viagem> viagens;
}

enum TipoAlerta { pedidos, caminhaoNaoConfirmado, doisMotoristas, semEnvio, suspensa }

class Alerta {
  const Alerta(this.tipo, this.titulo, this.texto, {this.motoristaId, this.caminhaoId});
  final TipoAlerta tipo;
  final String titulo;
  final String texto;
  final String? motoristaId;
  final String? caminhaoId;
}

/// Uma linha da lista de motoristas do painel.
class LinhaMotorista {
  const LinhaMotorista({
    required this.motorista,
    required this.resultado,
    this.caminhao,
    this.ultimoEnvio,
    this.porViagem = false,
    this.viagens = 0,
    this.entregas = 0,
    this.ultimoAcerto,
  });

  final Motorista motorista;
  final ResultadoResumo resultado;
  final Caminhao? caminhao;
  final DateTime? ultimoEnvio;

  /// Baú e Sider: viagens e entregas do período e o último acerto fechado.
  final bool porViagem;
  final int viagens;
  final int entregas;
  final Acerto? ultimoAcerto;
}

/// Tudo da empresa que o painel mostra, carregado de uma vez. As contas
/// usam o pacote nucleo, igual ao app do motorista.
class Equipe {
  Equipe({
    required this.empresa,
    required this.eu,
    required this.perfis,
    required this.motoristas,
    required this.caminhoes,
    required this.categorias,
    required this.fretes,
    required this.abastecimentos,
    required this.gastos,
    required this.vales,
    required this.ajustesKm,
    required this.usos,
    required this.ajustes,
    required this.pedidos,
    required this.dispositivos,
    required this.acessos,
    this.convites = const [],
    this.viagens = const [],
    this.acertos = const [],
    this.modalidades = const [],
    required this.brutos,
    required this.carregadoEm,
  });

  final Empresa empresa;
  final Perfil eu;
  final List<Perfil> perfis;
  final List<Motorista> motoristas;
  final List<Caminhao> caminhoes;
  final List<CategoriaGasto> categorias;
  final List<Frete> fretes;
  final List<Abastecimento> abastecimentos;
  final List<Gasto> gastos;
  final List<Vale> vales;
  final List<AjusteKm> ajustesKm;
  final List<UsoCaminhao> usos;
  final List<AjusteGestor> ajustes;
  final List<PedidoEntrada> pedidos;
  final List<Dispositivo> dispositivos;
  final List<AcessoAutorizado> acessos;

  /// Códigos individuais gerados para motoristas (mais novos primeiro).
  final List<Convite> convites;

  /// Viagens do Baú e do Sider (mais novas primeiro).
  final List<Viagem> viagens;

  /// Acertos fechados (mais novos primeiro).
  final List<Acerto> acertos;

  /// Todas as modalidades do catálogo, com a situação na empresa (ativa),
  /// os campos já ajustados e os ajustes do dono.
  final List<Modalidade> modalidades;

  /// Linha como veio do banco (valores efetivos), por tabela e id. A tela de
  /// correção lê daqui o valor atual de cada campo.
  final Map<String, Map<String, Map<String, Object?>>> brutos;
  final DateTime carregadoEm;

  /// Quando o motorista pediu para excluir a conta (nulo = não pediu).
  DateTime? exclusaoPedida(Motorista m) {
    for (final p in perfis) {
      if (p.id == m.perfilId) return p.exclusaoPedidaEm;
    }
    return null;
  }

  factory Equipe.montar({
    required Map<String, Object?> situacao,
    required Map<String, List<Map<String, Object?>>> tabelas,
    required List<Map<String, Object?>> pedidos,
    required DateTime agora,
    List<Map<String, Object?>>? modalidades,
  }) {
    List<Map<String, Object?>> t(String nome) => tabelas[nome] ?? const [];
    bool vivo(Map<String, Object?> m) => m['apagado_em'] == null;

    final empresaSituacao = (situacao['empresa'] as Map?)?.cast<String, Object?>() ?? const {};
    final linhaEmpresa = t(Fontes.empresa).isEmpty ? const <String, Object?>{} : t(Fontes.empresa).first;
    final empresa = Empresa.deMapa({...empresaSituacao, ...linhaEmpresa});
    final eu = Perfil.deMapa((situacao['perfil'] as Map?)?.cast<String, Object?>() ?? const {});

    final categorias = [
      for (final m in t(Fontes.categorias))
        if (vivo(m)) CategoriaGasto.deMapa(m),
    ]..sort((a, b) => a.nome.compareTo(b.nome));
    final nomeCategoria = {for (final c in categorias) c.id: c.nome};

    Map<String, Map<String, Object?>> porId(List<Map<String, Object?>> l) => {for (final m in l) '${m['id']}': m};

    return Equipe(
      empresa: empresa,
      eu: eu,
      perfis: [for (final m in t(Fontes.perfis)) Perfil.deMapa(m)],
      motoristas: [
        for (final m in t(Fontes.motoristas))
          if (vivo(m)) Motorista.deMapa(m),
      ]..sort((a, b) => a.nome.toLowerCase().compareTo(b.nome.toLowerCase())),
      caminhoes: [
        for (final m in t(Fontes.caminhoes))
          if (vivo(m)) Caminhao.deMapa(m),
      ]..sort((a, b) => a.placa.compareTo(b.placa)),
      categorias: categorias,
      fretes: [for (final m in t(Fontes.fretes)) Frete.deMapa(m)]..sort((a, b) => b.dataCarga.compareTo(a.dataCarga)),
      abastecimentos: [for (final m in t(Fontes.abastecimentos)) Abastecimento.deMapa(m)]
        ..sort((a, b) => b.data.compareTo(a.data)),
      gastos: [
        for (final m in t(Fontes.gastos))
          Gasto.deMapa(m, categoriaNome: nomeCategoria['${m['categoria_id']}'] ?? 'Outros'),
      ]..sort((a, b) => b.data.compareTo(a.data)),
      vales: [for (final m in t(Fontes.vales)) Vale.deMapa(m)]..sort((a, b) => b.data.compareTo(a.data)),
      ajustesKm: [
        for (final m in t(Fontes.ajustesKm))
          if (vivo(m)) AjusteKm.deMapa(m),
      ],
      usos: [
        for (final m in t(Fontes.usos))
          if (vivo(m)) UsoCaminhao.deMapa(m),
      ]..sort((a, b) => b.inicioEm.compareTo(a.inicioEm)),
      ajustes: [for (final m in t(Fontes.ajustes)) AjusteGestor.deMapa(m)]
        ..sort((a, b) => b.criadoEm.compareTo(a.criadoEm)),
      pedidos: [for (final m in pedidos) PedidoEntrada.deMapa(m)],
      dispositivos: [
        for (final m in t(Fontes.dispositivos))
          if (vivo(m)) Dispositivo.deMapa(m),
      ],
      acessos: [
        for (final m in t(Fontes.acessos))
          if (vivo(m)) AcessoAutorizado.deMapa(m),
      ]..sort((a, b) => a.email.compareTo(b.email)),
      convites: [
        for (final m in t(Fontes.convites))
          if (vivo(m)) Convite.deMapa(m),
      ]..sort((a, b) => b.expiraEm.compareTo(a.expiraEm)),
      viagens: [
        for (final m in t(Fontes.viagens))
          if (vivo(m)) Viagem.deMapa(m),
      ]..sort((a, b) => b.engateEm.compareTo(a.engateEm)),
      acertos: [
        for (final m in t(Fontes.acertos))
          if (vivo(m)) Acerto.deMapa(m),
      ]..sort((a, b) => b.periodoFim.compareTo(a.periodoFim)),
      // Sem a lista completa (só o dono e o gestor leem), as ligadas que vêm na situação.
      modalidades: modalidades != null
          ? [for (final m in modalidades) Modalidade.deMapa(m)]
          : modalidadesDaEmpresa(empresaSituacao),
      brutos: {
        'fretes': porId(t(Fontes.fretes)),
        'abastecimentos': porId(t(Fontes.abastecimentos)),
        'gastos_viagem': porId(t(Fontes.gastos)),
        'vales': porId(t(Fontes.vales)),
      },
      carregadoEm: agora,
    );
  }

  // ------------------------------------------------------------- atalhos

  bool get souDono => eu.dono;
  Regras get regras => Regras.daEmpresa(empresa.configuracao);

  // ---------------------------------------------------------- modalidades

  /// As modalidades ligadas na empresa.
  List<Modalidade> get modalidadesAtivas => modalidades.where((m) => m.ativa).toList();

  /// A empresa trabalha com mais de uma modalidade (aí o painel pergunta e mostra).
  bool get variasModalidades => modalidadesAtivas.length > 1;

  /// Alguma modalidade por viagem ligada (Baú, Sider...).
  bool get temViagens => modalidadesAtivas.any((m) => m.porViagem) || viagens.isNotEmpty;

  Modalidade? modalidade(String? codigo) => modalidadePorCodigo(modalidades, codigo);

  /// Como o motorista trabalha. Sem modalidade (ainda não escolheu) e com uma
  /// só ligada, é ela; sem informação nenhuma, Graneleiro.
  Modalidade modalidadeDe(Motorista m) {
    final x = modalidade(m.modalidade);
    if (x != null) return x;
    final ativas = modalidadesAtivas;
    if (m.modalidade == null && ativas.length == 1) return ativas.first;
    return Modalidade.graneleiro;
  }

  /// O motorista trabalha por viagem (Baú, Sider).
  bool porViagem(String? motoristaId) {
    final m = motorista(motoristaId);
    return m != null && modalidadeDe(m).porViagem;
  }

  /// Acertos de um motorista (mais novos primeiro).
  List<Acerto> acertosDe(String motoristaId) => acertos.where((a) => a.motoristaId == motoristaId).toList();

  Acerto? acerto(String id) => acertos.where((a) => a.id == id).firstOrNull;

  Viagem? viagem(String id) => viagens.where((v) => v.id == id).firstOrNull;

  late final Map<String, Caminhao> _caminhaoPorId = {for (final c in caminhoes) c.id: c};
  late final Map<String, Motorista> _motoristaPorId = {for (final m in motoristas) m.id: m};
  late final Map<String, Perfil> _perfilPorId = {for (final p in perfis) p.id: p};

  Caminhao? caminhao(String? id) => id == null ? null : _caminhaoPorId[id];
  Motorista? motorista(String? id) => id == null ? null : _motoristaPorId[id];

  String placa(String? caminhaoId) => caminhao(caminhaoId)?.placa ?? '';
  String nomeMotorista(String? id) => motorista(id)?.nome ?? '';
  String nomeAutor(String? perfilId) => _perfilPorId[perfilId]?.nome ?? 'Gestão';
  String nomeCategoria(String? id) => categorias.where((c) => c.id == id).map((c) => c.nome).firstOrNull ?? 'Outros';

  Map<String, String> get placas => {for (final c in caminhoes) c.id: c.placa};
  Map<String, String> get nomesMotoristas => {for (final m in motoristas) m.id: m.nome};

  List<Caminhao> get caminhoesAtivos => caminhoes.where((c) => c.ativo).toList();
  List<Motorista> get motoristasAtivos => motoristas.where((m) => m.ativo).toList();
  int get caminhoesNoPlano => caminhoes.where((c) => c.ativo && c.confirmado).length;
  List<PedidoEntrada> get pedidosPendentes => pedidos.where((p) => p.pendente).toList();

  /// Embarcadores que já apareceram nos fretes, em ordem alfabética.
  List<String> get embarcadores {
    final s = <String>{};
    for (final f in fretes) {
      final e = f.embarcador.trim();
      if (e.isNotEmpty) s.add(e);
    }
    return s.toList()..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
  }

  /// Uso de caminhão em aberto do motorista (o caminhão em que ele está).
  UsoCaminhao? usoAtual(String motoristaId) => usos.where((u) => u.motoristaId == motoristaId && u.aberto).firstOrNull;

  Caminhao? caminhaoAtual(String motoristaId) => caminhao(usoAtual(motoristaId)?.caminhaoId);

  /// Motoristas ativos que estão neste caminhão agora.
  List<Motorista> motoristasNoCaminhao(String caminhaoId) {
    final ids = usos.where((u) => u.caminhaoId == caminhaoId && u.aberto).map((u) => u.motoristaId).toSet();
    return motoristas.where((m) => m.ativo && ids.contains(m.id)).toList();
  }

  /// Última vez que algum celular do motorista enviou dados.
  DateTime? ultimoEnvio(Motorista m) {
    DateTime? r;
    for (final d in dispositivos) {
      if (d.perfilId != m.perfilId || d.ultimoEnvio == null) continue;
      if (r == null || d.ultimoEnvio!.isAfter(r)) r = d.ultimoEnvio;
    }
    return r;
  }

  List<Dispositivo> aparelhosDe(Motorista m) =>
      dispositivos.where((d) => d.perfilId == m.perfilId).toList()
        ..sort((a, b) => (b.ultimoEnvio ?? DateTime(2000)).compareTo(a.ultimoEnvio ?? DateTime(2000)));

  List<UsoCaminhao> usosDoMotorista(String motoristaId) => usos.where((u) => u.motoristaId == motoristaId).toList();
  List<UsoCaminhao> usosDoCaminhao(String caminhaoId) => usos.where((u) => u.caminhaoId == caminhaoId).toList();

  /// Correções de um lançamento, da mais nova para a mais antiga.
  List<AjusteGestor> ajustesDe(String tabela, String registroId) =>
      ajustes.where((a) => a.tabelaAlvo == tabela && a.registroId == registroId && !a.apagado).toList();

  Map<String, Object?>? bruto(String tabela, String id) => brutos[tabela]?[id];

  // ------------------------------------------------------------- recortes

  /// Lançamentos de um motorista, de um caminhão ou de um embarcador (ou de
  /// todos, sem filtro). Vale é do motorista, não do caminhão nem do
  /// embarcador, então só entra no recorte por motorista ou da frota toda.
  /// No recorte por embarcador, diesel e gastos entram quando foram ligados
  /// a um frete dele.
  Lancamentos recorte({String? motoristaId, String? caminhaoId, String? embarcador}) {
    bool doMotorista(String id) => motoristaId == null || id == motoristaId;
    bool doCaminhao(String id) => caminhaoId == null || id == caminhaoId;
    final emb = embarcador?.trim().toLowerCase();
    final fretesR = fretes
        .where(
          (f) =>
              doMotorista(f.motoristaId) &&
              doCaminhao(f.caminhaoId) &&
              (emb == null || f.embarcador.trim().toLowerCase() == emb),
        )
        .toList();
    final idsFretes = emb == null ? null : fretesR.map((f) => f.id).toSet();
    bool doFrete(String? freteId) => idsFretes == null || (freteId != null && idsFretes.contains(freteId));
    final semVales = caminhaoId != null || emb != null;
    return Lancamentos(
      fretes: fretesR,
      abastecimentos: abastecimentos
          .where((a) => doMotorista(a.motoristaId) && doCaminhao(a.caminhaoId) && doFrete(a.freteId))
          .toList(),
      gastos: gastos
          .where((g) => doMotorista(g.motoristaId) && doCaminhao(g.caminhaoId) && doFrete(g.freteId))
          .toList(),
      vales: semVales ? const [] : vales.where((v) => doMotorista(v.motoristaId)).toList(),
      ajustesKm: emb != null
          ? const []
          : ajustesKm.where((a) => doMotorista(a.motoristaId) && doCaminhao(a.caminhaoId)).toList(),
      viagens: emb != null
          ? const []
          : viagens.where((v) => doMotorista(v.motoristaId) && doCaminhao(v.caminhaoId)).toList(),
    );
  }

  /// Dados do período prontos para o resumo, a tela e o PDF (mesma conta do
  /// app do motorista).
  DadosRelatorio relatorio(
    Periodo periodo, {
    String? motoristaId,
    String? caminhaoId,
    String? embarcador,
    ConteudoRelatorio conteudo = ConteudoRelatorio.tudo,
  }) {
    final l = recorte(motoristaId: motoristaId, caminhaoId: caminhaoId, embarcador: embarcador);
    return montarDados(
      fretes: l.fretes,
      abastecimentos: l.abastecimentos,
      vales: l.vales,
      gastos: l.gastos,
      ajustes: l.ajustesKm,
      periodo: periodo,
      regras: regras,
      conteudo: conteudo,
      motorista: motoristaId != null ? nomeMotorista(motoristaId) : (caminhaoId == null ? 'Todos' : ''),
      placa: placa(caminhaoId),
      empresa: empresa.nome,
      embarcador: embarcador ?? '',
      placasPorCaminhao: placas,
      viagens: l.viagens,
      porViagem: motoristaId != null && porViagem(motoristaId),
      modalidade: motoristaId == null ? null : modalidadeDe(motorista(motoristaId)!),
    );
  }

  /// Relatório do acerto fechado (as viagens, o diesel, os vales e os gastos do período dele).
  DadosRelatorio relatorioDoAcerto(Acerto a) {
    final l = recorte(motoristaId: a.motoristaId);
    final m = motorista(a.motoristaId);
    return montarDadosDoAcerto(
      acerto: a,
      viagens: l.viagens,
      abastecimentos: l.abastecimentos,
      vales: l.vales,
      gastos: l.gastos,
      regras: regras,
      motorista: m?.nome ?? '',
      placa: caminhaoAtual(a.motoristaId)?.placa ?? '',
      empresa: empresa.nome,
      placasPorCaminhao: placas,
      modalidade: m == null ? null : modalidadeDe(m),
    );
  }

  /// Km rodados pelo caminhão no período, pelo odômetro: do último registro
  /// antes do período (ou do primeiro dentro dele) até o maior km do período.
  double kmRodados(String caminhaoId, Periodo periodo) {
    final doCaminhao = abastecimentos.where((a) => a.caminhaoId == caminhaoId && a.kmOdometro > 0).toList();
    final dentro = doCaminhao.where((a) => periodo.contem(a.data)).toList();
    if (dentro.isEmpty) return 0;
    final maior = dentro.map((a) => a.kmOdometro).reduce((a, b) => a > b ? a : b);
    final antes = doCaminhao.where((a) => a.data.isBefore(periodo.inicio)).map((a) => a.kmOdometro);
    final base = antes.isNotEmpty
        ? antes.reduce((a, b) => a > b ? a : b)
        : dentro.map((a) => a.kmOdometro).reduce((a, b) => a < b ? a : b);
    final km = maior - base;
    return km > 0 ? km : 0;
  }

  /// Uma linha por motorista: caminhão atual, último envio e a conta do período.
  List<LinhaMotorista> linhasMotoristas(Periodo periodo) => [
    for (final m in motoristas)
      () {
        final d = relatorio(periodo, motoristaId: m.id);
        return LinhaMotorista(
          motorista: m,
          resultado: d.resultado,
          caminhao: caminhaoAtual(m.id),
          ultimoEnvio: ultimoEnvio(m),
          porViagem: d.porViagem,
          viagens: d.viagens.length,
          entregas: d.viagens.fold(0, (s, v) => s + v.entregasQuantidade),
          ultimoAcerto: acertosDe(m.id).firstOrNull,
        );
      }(),
  ];

  // --------------------------------------------------------------- alertas

  /// O que o gestor precisa olhar: pedidos de entrada, caminhão cadastrado
  /// por motorista, dois motoristas no mesmo caminhão e quem parou de enviar.
  List<Alerta> alertas(DateTime agora) {
    final r = <Alerta>[];
    if (empresa.suspensa) {
      r.add(
        const Alerta(
          TipoAlerta.suspensa,
          'Empresa suspensa',
          'Os motoristas não conseguem enviar lançamentos novos. Os dados continuam guardados.',
        ),
      );
    }
    final pendentes = pedidosPendentes;
    if (pendentes.isNotEmpty) {
      r.add(
        Alerta(
          TipoAlerta.pedidos,
          pendentes.length == 1 ? '1 motorista quer entrar' : '${pendentes.length} motoristas querem entrar',
          '${pendentes.map((p) => p.nome).join(', ')}. Confira o nome e o CPF e aprove.',
        ),
      );
    }
    for (final c in caminhoes.where((c) => c.ativo && !c.confirmado)) {
      r.add(
        Alerta(
          TipoAlerta.caminhaoNaoConfirmado,
          'Caminhão ${placaTexto(c.placa)} para conferir',
          'Um motorista cadastrou esta placa. Confira os dados e confirme.',
          caminhaoId: c.id,
        ),
      );
    }
    for (final c in caminhoes.where((c) => c.ativo)) {
      final juntos = motoristasNoCaminhao(c.id);
      if (juntos.length > 1) {
        r.add(
          Alerta(
            TipoAlerta.doisMotoristas,
            '${placaTexto(c.placa)} com ${juntos.length} motoristas',
            '${juntos.map((m) => m.primeiroNome).join(' e ')} estão no mesmo caminhão agora. Se não for revezamento, troque o caminhão de um deles.',
            caminhaoId: c.id,
          ),
        );
      }
    }
    for (final m in motoristas.where((m) => m.ativo)) {
      final ultimo = ultimoEnvio(m);
      if (ultimo == null) continue;
      final dias = agora.difference(ultimo).inDays;
      if (dias >= 3) {
        r.add(
          Alerta(
            TipoAlerta.semEnvio,
            '${m.primeiroNome} não envia há $dias dias',
            'Pode estar sem internet. O que ele lançar fica guardado no celular e chega quando tiver sinal.',
            motoristaId: m.id,
          ),
        );
      }
    }
    return r;
  }
}

/// "hoje às 14:20", "ontem às 08:05", "há 5 dias", "nunca".
String quandoTexto(DateTime? d, DateTime agora) {
  if (d == null) return 'nunca';
  final local = d.toLocal();
  final hoje = DateTime(agora.year, agora.month, agora.day);
  final dia = DateTime(local.year, local.month, local.day);
  final dias = hoje.difference(dia).inDays;
  final hora = '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
  if (dias <= 0) return 'hoje às $hora';
  if (dias == 1) return 'ontem às $hora';
  if (dias < 30) return 'há $dias dias';
  return 'em ${dataTexto(local)}';
}
