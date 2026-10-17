import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nucleo/nucleo.dart';
import 'package:uuid/uuid.dart';
import 'package:visual/visual.dart';

import '../servidor/servidor.dart';
import 'equipe.dart';
import 'modelos.dart';

final servidorProvider = Provider<Servidor>((ref) => throw UnimplementedError('defina no main'));
final relogioProvider = Provider<DateTime Function()>((ref) => DateTime.now);

const _uuid = Uuid();
String novoId() => _uuid.v4();

// ------------------------------------------------------------------- acesso

/// Em que ponto a pessoa está: sem entrar, terminando o cadastro, sem
/// liberação do dono, com conta de motorista ou pronta para usar o painel.
enum Etapa { entrar, completarCadastro, naoAutorizado, contaMotorista, pronto }

class EstadoAcesso {
  const EstadoAcesso(this.etapa, {this.email = '', this.nome = ''});
  final Etapa etapa;
  final String email;
  final String nome;
}

class Acesso extends AsyncNotifier<EstadoAcesso> {
  Servidor get _s => ref.read(servidorProvider);

  @override
  Future<EstadoAcesso> build() => _decidir();

  Future<EstadoAcesso> _decidir() async {
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
    final perfil = (s['perfil'] as Map?)?.cast<String, Object?>();
    if (perfil == null) return EstadoAcesso(Etapa.completarCadastro, email: email);
    final nome = '${perfil['nome'] ?? ''}';
    if (perfil['papel'] == 'motorista') return EstadoAcesso(Etapa.contaMotorista, email: email, nome: nome);
    if (s['empresa'] == null || perfil['ativo'] == false) {
      return EstadoAcesso(Etapa.naoAutorizado, email: email, nome: nome);
    }
    return EstadoAcesso(Etapa.pronto, email: email, nome: nome);
  }

  Future<void> recarregar() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(_decidir);
  }

  Future<void> sair() async {
    await _s.sair();
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
    final resultados = await Future.wait([_s.situacao(), _s.carregar(), _s.pedidosEntrada()]);
    return Equipe.montar(
      situacao: resultados[0] as Map<String, Object?>,
      tabelas: resultados[1] as Map<String, List<Map<String, Object?>>>,
      pedidos: resultados[2] as List<Map<String, Object?>>,
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
