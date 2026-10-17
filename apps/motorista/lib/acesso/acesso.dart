import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../dados/dados.dart';
import '../dados/sincronizador.dart';
import '../servidor/servidor.dart';

/// Em que ponto do caminho o motorista está: sem conta, cadastrando,
/// esperando aprovação ou pronto para usar.
enum Etapa { boasVindas, completarCadastro, codigoEmpresa, aguardando, contaDeGestor, trocarSenha, semInternet, pronto }

class EstadoAcesso {
  const EstadoAcesso(this.etapa, {this.mensagem, this.empresaNome = '', this.email = ''});
  final Etapa etapa;

  /// Recado para mostrar (pedido recusado, sem internet...).
  final String? mensagem;
  final String empresaNome;
  final String email;
}

class Acesso extends AsyncNotifier<EstadoAcesso> {
  Servidor get _s => ref.read(servidorProvider);

  @override
  Future<EstadoAcesso> build() => _decidir();

  Future<EstadoAcesso> _decidir() async {
    final a = ref.read(armazenamentoProvider);
    // Já tem os dados no celular: abre direto, mesmo sem internet.
    if (await a.lerEstado('pronto') == '1') return const EstadoAcesso(Etapa.pronto);
    if (!_s.temSessao) return const EstadoAcesso(Etapa.boasVindas);
    if (_s.precisaTrocarSenha) return const EstadoAcesso(Etapa.trocarSenha);

    final Map<String, Object?> s;
    try {
      s = await _s.situacao();
    } on ErroServidor catch (e) {
      if (e.codigo == 'sessao') return const EstadoAcesso(Etapa.boasVindas);
      return EstadoAcesso(Etapa.semInternet, mensagem: e.mensagem);
    }
    final perfil = (s['perfil'] as Map?)?.cast<String, Object?>();
    if (perfil == null) {
      return EstadoAcesso(Etapa.completarCadastro, email: _s.emailDaSessao ?? '');
    }
    if (perfil['papel'] != 'motorista') return const EstadoAcesso(Etapa.contaDeGestor);

    final motorista = (s['motorista'] as Map?)?.cast<String, Object?>();
    if (motorista != null) {
      if (motorista['ativo'] == false) {
        return const EstadoAcesso(Etapa.codigoEmpresa,
            mensagem: 'Sua conta foi desligada da empresa. Fale com o seu patrão.');
      }
      // Aprovado: baixa o histórico (celular novo recupera tudo) e abre.
      await a.gravarEstado('situacao', jsonEncode(s));
      try {
        await ref.read(sincronizadorProvider.notifier).baixar(tudo: true);
      } on ErroServidor catch (e) {
        return EstadoAcesso(Etapa.semInternet, mensagem: e.mensagem);
      }
      await a.gravarEstado('pronto', '1');
      await ref.read(dadosProvider.notifier).recarregar();
      return const EstadoAcesso(Etapa.pronto);
    }

    final pedido = (s['pedido'] as Map?)?.cast<String, Object?>();
    if (pedido?['status'] == 'pendente') {
      return EstadoAcesso(Etapa.aguardando, empresaNome: '${pedido?['empresa_nome'] ?? ''}');
    }
    if (pedido?['status'] == 'recusado') {
      return EstadoAcesso(Etapa.codigoEmpresa,
          mensagem: 'O pedido para entrar na ${pedido?['empresa_nome'] ?? 'empresa'} não foi aprovado. '
              'Confira com o seu patrão e digite o código de novo.');
    }
    return const EstadoAcesso(Etapa.codigoEmpresa);
  }

  Future<void> recarregar() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(_decidir);
  }

  /// Sai da conta e limpa o celular.
  Future<void> sair() async {
    await _s.sair();
    await ref.read(armazenamentoProvider).limparTudo();
    await ref.read(dadosProvider.notifier).recarregar();
    await recarregar();
  }
}

final acessoProvider = AsyncNotifierProvider<Acesso, EstadoAcesso>(Acesso.new);
