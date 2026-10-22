import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../dados/armazenamento.dart';
import '../dados/dados.dart';
import '../dados/sincronizador.dart';
import '../servidor/servidor.dart';

/// Em que ponto do caminho o motorista está: sem conta, cadastrando,
/// esperando aprovação, com algo a fazer (termos, código de recuperação),
/// com a empresa bloqueada ou pronto para usar.
enum Etapa {
  boasVindas,
  completarCadastro,
  codigoEmpresa,
  aguardando,
  contaDeGestor,
  trocarSenha,
  termos,
  codigoRecuperacao,
  bloqueada,
  semInternet,
  pronto,
}

class EstadoAcesso {
  const EstadoAcesso(this.etapa, {this.mensagem, this.empresaNome = '', this.email = ''});
  final Etapa etapa;

  /// Recado para mostrar (pedido recusado, sem internet, motivo do bloqueio...).
  final String? mensagem;
  final String empresaNome;
  final String email;
}

Map<String, Object?>? _mapa(Object? v) => v is Map ? v.cast<String, Object?>() : null;

bool _termosPendentes(Map<String, Object?> s) => _mapa(s['termos'])?['aceito'] == false;
bool _empresaBloqueada(Map<String, Object?> s) => _mapa(s['empresa'])?['bloqueada'] == true;
bool _semCodigoRecuperacao(Map<String, Object?> s) => s['recuperacao'] == false;

class Acesso extends AsyncNotifier<EstadoAcesso> {
  Servidor get _s => ref.read(servidorProvider);

  @override
  Future<EstadoAcesso> build() => _decidir();

  Future<Map<String, Object?>?> _situacaoGuardada() async {
    final a = ref.read(armazenamentoProvider);
    final t = await a.lerEstado('situacao');
    if (t == null) return null;
    try {
      final s = _mapa(jsonDecode(t));
      // Versões antigas guardavam o CPF e o e-mail: limpa na primeira leitura.
      final perfil = _mapa(s?['perfil']);
      if (s != null && perfil != null && (perfil.containsKey('cpf') || perfil.containsKey('email'))) {
        await a.gravarEstado('situacao', situacaoParaGuardar(s));
      }
      return s;
    } catch (_) {
      return null;
    }
  }

  EstadoAcesso _bloqueada(Map<String, Object?> s) {
    final e = _mapa(s['empresa']) ?? const {};
    return EstadoAcesso(Etapa.bloqueada, empresaNome: '${e['nome'] ?? ''}', mensagem: '${e['motivo_bloqueio'] ?? ''}');
  }

  /// [conferir] força perguntar à nuvem mesmo com os dados já no celular
  /// (depois de um envio recusado, de aceitar os termos etc.).
  Future<EstadoAcesso> _decidir({bool conferir = false}) async {
    final a = ref.read(armazenamentoProvider);
    final pronto = await a.lerEstado('pronto') == '1';
    final guardada = await _situacaoGuardada();
    // Já tem os dados no celular: abre direto, mesmo sem internet.
    if (pronto && !conferir) {
      final g = guardada ?? const <String, Object?>{};
      if (!_termosPendentes(g) && !_empresaBloqueada(g) && !_semCodigoRecuperacao(g)) {
        return const EstadoAcesso(Etapa.pronto);
      }
    }
    if (!_s.temSessao) return EstadoAcesso(pronto ? Etapa.pronto : Etapa.boasVindas);
    if (_s.precisaTrocarSenha) return const EstadoAcesso(Etapa.trocarSenha);

    final Map<String, Object?> s;
    try {
      s = await _s.situacao();
    } on ErroServidor catch (e) {
      if (pronto) {
        if (guardada != null && _empresaBloqueada(guardada)) return _bloqueada(guardada);
        return const EstadoAcesso(Etapa.pronto);
      }
      if (e.codigo == 'sessao') return const EstadoAcesso(Etapa.boasVindas);
      return EstadoAcesso(Etapa.semInternet, mensagem: e.mensagem);
    }
    final perfil = _mapa(s['perfil']);
    if (perfil == null) {
      if (pronto) {
        // A conta foi excluída: limpa o celular.
        await sair(recarregarDepois: false);
        return const EstadoAcesso(Etapa.boasVindas, mensagem: 'Esta conta foi excluída.');
      }
      return EstadoAcesso(Etapa.completarCadastro, email: _s.emailDaSessao ?? '');
    }
    if (perfil['papel'] != 'motorista') return const EstadoAcesso(Etapa.contaDeGestor);
    if (pronto) await a.gravarEstado('situacao', situacaoParaGuardar(s));
    if (_termosPendentes(s)) return const EstadoAcesso(Etapa.termos);
    if (_empresaBloqueada(s)) return _bloqueada(s);
    if (_semCodigoRecuperacao(s)) return const EstadoAcesso(Etapa.codigoRecuperacao);

    final motorista = _mapa(s['motorista']);
    if (motorista != null) {
      if (motorista['ativo'] == false) {
        if (pronto) return const EstadoAcesso(Etapa.pronto); // o aviso "Acesso desligado" aparece no app
        return const EstadoAcesso(Etapa.codigoEmpresa,
            mensagem: 'Sua conta foi desligada da empresa. Fale com o seu patrão.');
      }
      if (pronto) return const EstadoAcesso(Etapa.pronto);
      // Aprovado: baixa o histórico (celular novo recupera tudo) e abre.
      await a.gravarEstado('situacao', situacaoParaGuardar(s));
      try {
        await ref.read(sincronizadorProvider.notifier).baixar(tudo: true);
      } on ErroServidor catch (e) {
        return EstadoAcesso(Etapa.semInternet, mensagem: e.mensagem);
      }
      await a.gravarEstado('pronto', '1');
      await ref.read(dadosProvider.notifier).recarregar();
      return const EstadoAcesso(Etapa.pronto);
    }

    String? recado;
    if (pronto) {
      // A empresa excluiu o cadastro dele: os lançamentos dela saem do celular.
      final aparelho = await a.lerEstado('dispositivo_id');
      await a.limparTudo();
      if (aparelho != null) await a.gravarEstado('dispositivo_id', aparelho);
      await ref.read(dadosProvider.notifier).recarregar();
      recado = 'A empresa encerrou o seu cadastro e os lançamentos dela foram tirados deste celular. '
          'Se for entrar em outra empresa, digite o código que o novo patrão gerar para você.';
    }

    final pedido = _mapa(s['pedido']);
    if (pedido?['status'] == 'pendente') {
      return EstadoAcesso(Etapa.aguardando, empresaNome: '${pedido?['empresa_nome'] ?? ''}');
    }
    if (recado == null && pedido?['status'] == 'recusado') {
      return EstadoAcesso(Etapa.codigoEmpresa,
          mensagem: 'O pedido para entrar na ${pedido?['empresa_nome'] ?? 'empresa'} não foi aprovado. '
              'Confira com o seu patrão e digite o código de novo.');
    }
    return EstadoAcesso(Etapa.codigoEmpresa, mensagem: recado);
  }

  Future<void> recarregar({bool conferir = false}) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => _decidir(conferir: conferir));
  }

  /// Depois de um envio recusado: pergunta à nuvem e só troca de tela se a
  /// etapa mudou (sem piscar a tela à toa).
  Future<void> conferirEmSilencio() async {
    final novo = await AsyncValue.guard(() => _decidir(conferir: true));
    if (novo.hasValue && novo.value!.etapa != state.value?.etapa) state = novo;
  }

  /// Aceite dos termos. Devolve a mensagem de erro ou nulo.
  Future<String?> aceitarTermos(String versao) async {
    try {
      final s = await _s.aceitarTermos(versao);
      if (await ref.read(armazenamentoProvider).lerEstado('pronto') == '1') {
        await ref.read(armazenamentoProvider).gravarEstado('situacao', situacaoParaGuardar(s));
      }
    } on ErroServidor catch (e) {
      return e.mensagem;
    }
    await recarregar(conferir: true);
    return null;
  }

  /// Exclui a conta e limpa o celular. Devolve o recado para mostrar.
  Future<String> excluirConta() async {
    final r = await _s.excluirMinhaConta();
    await sair();
    return r['apagada'] == true
        ? 'Conta excluída. Os seus dados foram apagados.'
        : 'Pedido de exclusão feito. O seu acesso foi encerrado e os dados serão apagados em até 15 dias.';
  }

  /// Sai da conta e limpa o celular.
  Future<void> sair({bool recarregarDepois = true}) async {
    await _s.sair();
    await ref.read(armazenamentoProvider).limparTudo();
    await ref.read(dadosProvider.notifier).recarregar();
    if (recarregarDepois) await recarregar();
  }
}

final acessoProvider = AsyncNotifierProvider<Acesso, EstadoAcesso>(Acesso.new);
