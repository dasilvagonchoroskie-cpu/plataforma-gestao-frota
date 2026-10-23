import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nucleo/nucleo.dart';
import 'package:uuid/uuid.dart';
import 'package:visual/visual.dart';

import '../servidor/servidor.dart';
import 'aparelho.dart';
import 'equipe.dart';
import 'modelos.dart';

final servidorProvider = Provider<Servidor>((ref) => throw UnimplementedError('defina no main'));
final relogioProvider = Provider<DateTime Function()>((ref) => DateTime.now);

const _uuid = Uuid();
String novoId() => _uuid.v4();

// ------------------------------------------------------------------- acesso

/// Em que ponto a pessoa está: termos na primeira abertura, sem entrar,
/// terminando o cadastro, sem liberação do dono, com conta de motorista, com
/// algo a fazer (senha, termos), com a empresa bloqueada ou pronta.
enum Etapa {
  termosAbertura,
  entrar,
  completarCadastro,
  naoAutorizado,
  contaMotorista,
  trocarSenha,
  termos,
  bloqueada,
  pronto,

  /// Super administrador sem empresa: só a área da Plataforma.
  plataforma,
}

class EstadoAcesso {
  const EstadoAcesso(
    this.etapa, {
    this.email = '',
    this.nome = '',
    this.empresaNome = '',
    this.mensagem,
    this.dono = false,
    this.excluirEm,
    this.adminPlataforma = false,
  });
  final Etapa etapa;

  /// Super administrador da plataforma (vê a área Plataforma).
  final bool adminPlataforma;
  final String email;
  final String nome;
  final String empresaNome;

  /// Motivo do bloqueio da empresa.
  final String? mensagem;
  final bool dono;

  /// Quando os dados da empresa bloqueada serão apagados.
  final DateTime? excluirEm;
}

class Acesso extends AsyncNotifier<EstadoAcesso> {
  Servidor get _s => ref.read(servidorProvider);
  bool _acessoRegistrado = false;

  @override
  Future<EstadoAcesso> build() => _decidir();

  Future<EstadoAcesso> _decidir() async {
    // Primeira abertura (ou versão nova dos termos): aceitar antes de tudo.
    final aceitaNoAparelho = await ref.read(aparelhoProvider).ler(chaveTermosAparelho);
    if (aceitaNoAparelho != versaoTermos) return const EstadoAcesso(Etapa.termosAbertura);
    if (!_s.temSessao) return const EstadoAcesso(Etapa.entrar);
    final Map<String, Object?> s;
    try {
      s = await _s.situacao();
    } on ErroServidor catch (e) {
      if (e.codigo == 'sessao') {
        await _s.sair();
        return const EstadoAcesso(Etapa.entrar);
      }
      rethrow;
    }
    final email = _s.emailDaSessao ?? '';
    final admin = s['admin_plataforma'] == true;
    // Senha provisória: o banco nega tudo até trocar (o app pede antes).
    final trocar = _s.precisaTrocarSenha || s['senha_provisoria'] == true;
    final perfil = (s['perfil'] as Map?)?.cast<String, Object?>();
    if (perfil == null) {
      if (admin) {
        return EstadoAcesso(trocar ? Etapa.trocarSenha : Etapa.plataforma, email: email, adminPlataforma: true);
      }
      return EstadoAcesso(Etapa.completarCadastro, email: email);
    }
    final nome = '${perfil['nome'] ?? ''}';
    if (perfil['papel'] == 'motorista') return EstadoAcesso(Etapa.contaMotorista, email: email, nome: nome);
    final empresa = (s['empresa'] as Map?)?.cast<String, Object?>();
    if (empresa == null || perfil['ativo'] == false) {
      return EstadoAcesso(Etapa.naoAutorizado, email: email, nome: nome);
    }
    if (trocar) return EstadoAcesso(Etapa.trocarSenha, email: email, nome: nome);
    if ((s['termos'] as Map?)?['aceito'] == false) {
      // Já aceitou neste aparelho ao abrir: o aceite vai para a conta. Se não
      // der agora (sem internet), pede de novo na tela de termos.
      try {
        await _s.aceitarTermos(versaoTermos);
      } on ErroServidor {
        return EstadoAcesso(Etapa.termos, email: email, nome: nome);
      }
    }
    if (empresa['bloqueada'] == true) {
      return EstadoAcesso(
        Etapa.bloqueada,
        email: email,
        nome: nome,
        empresaNome: '${empresa['nome'] ?? ''}',
        mensagem: '${empresa['motivo_bloqueio'] ?? ''}',
        dono: perfil['papel'] == 'dono',
        excluirEm: DateTime.tryParse('${empresa['excluir_em'] ?? ''}'),
      );
    }
    if (!_acessoRegistrado) {
      _acessoRegistrado = true;
      unawaited(_s.registrarAcesso(kIsWeb ? 'web' : 'gestor'));
    }
    return EstadoAcesso(Etapa.pronto, email: email, nome: nome, adminPlataforma: admin);
  }

  Future<void> recarregar() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(_decidir);
  }

  /// Aceite dos termos na primeira abertura: fica guardado neste aparelho e,
  /// com alguém logado, também na conta.
  Future<String?> aceitarTermosNoAparelho() async {
    await ref.read(aparelhoProvider).gravar(chaveTermosAparelho, versaoTermos);
    await recarregar();
    return null;
  }

  /// Aceite dos termos. Devolve a mensagem de erro ou nulo.
  Future<String?> aceitarTermos(String versao) async {
    try {
      await _s.aceitarTermos(versao);
    } on ErroServidor catch (e) {
      return e.mensagem;
    }
    await recarregar();
    return null;
  }

  /// O dono exclui a empresa e todos os dados; depois sai da conta.
  Future<void> excluirEmpresa(String confirmacao) async {
    await _s.excluirMinhaEmpresa(confirmacao);
    await sair();
  }

  Future<void> sair() async {
    await _s.sair();
    _acessoRegistrado = false;
    ref.invalidate(equipeProvider);
    state = const AsyncData(EstadoAcesso(Etapa.entrar));
  }
}

final acessoProvider = AsyncNotifierProvider<Acesso, EstadoAcesso>(Acesso.new);

// ------------------------------------------------------------ dados da empresa

/// Os dados da empresa no painel. Cada ação grava na nuvem e recarrega tudo
/// (no piloto são poucos caminhões; se ficar lento, carregar por período).
class EquipeNotifier extends AsyncNotifier<Equipe> {
  Servidor get _s => ref.read(servidorProvider);

  @override
  Future<Equipe> build() => _carregar();

  Future<Equipe> _carregar() async {
    final resultados = await Future.wait([
      _s.situacao(),
      _s.carregar(),
      _s.pedidosEntrada(),
      _s.modalidadesDaEmpresa(),
    ]);
    return Equipe.montar(
      situacao: resultados[0] as Map<String, Object?>,
      tabelas: resultados[1] as Map<String, List<Map<String, Object?>>>,
      pedidos: resultados[2] as List<Map<String, Object?>>,
      modalidades: resultados[3] as List<Map<String, Object?>>,
      agora: ref.read(relogioProvider)(),
    );
  }

  /// Busca de novo na nuvem. Se falhar, mantém o que já estava na tela.
  Future<void> recarregar() async {
    final novo = await AsyncValue.guard(_carregar);
    if (novo.hasValue || !state.hasValue) state = novo;
    if (novo.hasError && state.hasValue) throw novo.error!;
  }

  Future<void> _eRecarregar(Future<void> Function() acao) async {
    await acao();
    await recarregar();
  }

  Equipe get _e => state.requireValue;

  Future<void> decidirEntrada(String pedidoId, bool aprovar) =>
      _eRecarregar(() => _s.decidirEntrada(pedidoId, aprovar));

  Future<String> gerarNovoCodigo() async {
    final c = await _s.gerarNovoCodigo();
    await recarregar();
    return c;
  }

  Future<void> definirCaminhaoAtual(String motoristaId, String caminhaoId) =>
      _eRecarregar(() => _s.definirCaminhaoAtual(motoristaId, caminhaoId));

  Future<void> ativarMotorista(String motoristaId, bool ativo) =>
      _eRecarregar(() => _s.alterar('motoristas', motoristaId, {'ativo': ativo}));

  Future<Map<String, Object?>> redefinirAcesso(String motoristaId) => _s.redefinirAcesso(motoristaId);

  /// Cadastra o motorista (nome e CPF) e devolve o código individual dele.
  Future<Map<String, Object?>> gerarConvite(String nome, String cpf, {String? modalidade}) async {
    final r = await _s.gerarConvite(nome, cpf, modalidade: modalidade);
    await recarregar();
    return r;
  }

  /// O dono liga ou desliga uma modalidade e ajusta os campos dela.
  Future<void> salvarModalidade(String codigo, bool ativa, {Map<String, Object?>? campos}) =>
      _eRecarregar(() => _s.salvarModalidadeEmpresa(codigo, ativa, campos: campos));

  Future<void> definirModalidade(String motoristaId, String codigo) =>
      _eRecarregar(() => _s.definirModalidadeMotorista(motoristaId, codigo));

  /// Fecha (ou corrige) o acerto. O servidor soma vales, diesel e gastos.
  Future<Acerto> fecharAcerto({
    String? id,
    required String motoristaId,
    required DateTime inicio,
    required DateTime fim,
    required int comissaoCentavos,
    required List<DescontoAcerto> descontos,
    String? observacao,
  }) async {
    final r = await _s.fecharAcerto(
      id: id ?? novoId(),
      motoristaId: motoristaId,
      inicio: inicio,
      fim: fim,
      comissaoCentavos: comissaoCentavos,
      descontos: [for (final d in descontos) d.paraMapa()],
      observacao: (observacao ?? '').trim().isEmpty ? null : observacao!.trim(),
    );
    await recarregar();
    return Acerto.deMapa(r);
  }

  Future<void> cancelarConvite(String id) => _eRecarregar(() => _s.cancelarConvite(id));

  Future<void> excluirMotorista(String motoristaId) => _eRecarregar(() => _s.excluirMotorista(motoristaId));

  /// Cadastra (id nulo) ou altera um caminhão. A gestão confirma na hora.
  Future<void> salvarCaminhao({String? id, required String placa, String? numeroFrota, String modelo = '', int? ano}) {
    final dados = <String, Object?>{
      'placa': normalizarPlaca(placa),
      'numero_frota': (numeroFrota ?? '').trim().isEmpty ? null : numeroFrota!.trim(),
      'modelo': modelo.trim(),
      'ano': ano,
      'confirmado': true,
    };
    if (id == null) {
      return _eRecarregar(
        () => _s.inserir('caminhoes', {'id': novoId(), 'empresa_id': _e.empresa.id, ...dados, 'ativo': true}),
      );
    }
    return _eRecarregar(() => _s.alterar('caminhoes', id, dados));
  }

  Future<void> confirmarCaminhao(String id) => _eRecarregar(() => _s.alterar('caminhoes', id, {'confirmado': true}));

  Future<void> ativarCaminhao(String id, bool ativo) =>
      _eRecarregar(() => _s.alterar('caminhoes', id, {'ativo': ativo}));

  /// Correção de um campo de um lançamento, com motivo. O original fica.
  Future<void> ajustar({
    required String tabela,
    required String registroId,
    required String campo,
    required Object valorNovo,
    required String motivo,
  }) => _eRecarregar(
    () => _s.inserir('ajustes_gestor', {
      'id': novoId(),
      'empresa_id': _e.empresa.id,
      'tabela_alvo': tabela,
      'registro_id': registroId,
      'campo': campo,
      'valor_novo': valorNovo,
      'motivo': motivo.trim(),
      'autor_id': _e.eu.id,
    }),
  );

  Future<void> salvarCategoria({String? id, required String nome}) {
    if (id == null) {
      return _eRecarregar(
        () => _s.inserir('categorias_gasto', {'id': novoId(), 'empresa_id': _e.empresa.id, 'nome': nome.trim()}),
      );
    }
    return _eRecarregar(() => _s.alterar('categorias_gasto', id, {'nome': nome.trim()}));
  }

  Future<void> ativarCategoria(String id, bool ativa) =>
      _eRecarregar(() => _s.alterar('categorias_gasto', id, {'ativa': ativa}));

  /// O dono liga ou desliga o registro de paradas e muda o limite.
  Future<void> salvarParadas({required bool ativas, required int limiteMinutos}) =>
      salvarEmpresa({'paradas_ativas': ativas, 'limite_sem_descanso_minutos': limiteMinutos});

  Future<void> salvarEmpresa(Map<String, Object?> campos) =>
      _eRecarregar(() => _s.alterar('empresas', _e.empresa.id, campos));

  /// Libera um e-mail para entrar como gestor (só o dono).
  Future<void> autorizarGestor(String email, {String papel = 'gestor'}) {
    final e = email.trim().toLowerCase();
    final existente = _e.acessos.where((a) => a.email == e).firstOrNull;
    if (existente != null) {
      return _eRecarregar(() => _s.alterar('acessos_autorizados', existente.id, {'ativo': true, 'papel': papel}));
    }
    return _eRecarregar(
      () =>
          _s.inserir('acessos_autorizados', {'id': novoId(), 'empresa_id': _e.empresa.id, 'email': e, 'papel': papel}),
    );
  }

  /// Cria (ou renova) o acesso de um gestor e devolve a senha provisória.
  Future<Map<String, Object?>> criarAcessoGestor(String email, String nome) async {
    final r = await _s.criarAcessoGestor(email, nome);
    await recarregar();
    return r;
  }

  Future<void> ativarAcesso(String id, bool ativo) =>
      _eRecarregar(() => _s.alterar('acessos_autorizados', id, {'ativo': ativo}));

  Future<void> revogarAparelho(String id) =>
      _eRecarregar(() => _s.alterar('dispositivos', id, {'revogado_em': DateTime.now().toUtc().toIso8601String()}));
}

final equipeProvider = AsyncNotifierProvider<EquipeNotifier, Equipe>(EquipeNotifier.new);

// --------------------------------------------------------------- período

/// Período escolhido no painel (vale para o painel, lançamentos e relatórios).
class PeriodoEscolhido extends Notifier<EscolhaPeriodo> {
  @override
  EscolhaPeriodo build() => const EscolhaPeriodo(TipoPeriodo.mesAtual);

  void escolher(EscolhaPeriodo e) => state = e;
}

final periodoProvider = NotifierProvider<PeriodoEscolhido, EscolhaPeriodo>(PeriodoEscolhido.new);

extension PeriodoSeguro on EscolhaPeriodo {
  Periodo get periodoOuMes => periodo ?? calcularPeriodo(TipoPeriodo.mesAtual)!;
}

/// Atalho para os campos ajustáveis de uma tabela.
Map<String, TipoAjuste> camposDe(String tabela) => camposAjustaveis[tabela] ?? const {};
