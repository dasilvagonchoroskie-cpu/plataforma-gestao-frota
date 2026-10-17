import 'dart:async';
import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart';

/// Erro já com a mensagem em português simples para mostrar na tela.
class ErroServidor implements Exception {
  const ErroServidor(this.mensagem, {this.codigo = '', this.semInternet = false});
  final String mensagem;
  final String codigo;
  final bool semInternet;

  @override
  String toString() => mensagem;
}

const _semInternet = ErroServidor('Sem internet agora. Tente de novo quando tiver sinal.', semInternet: true);

/// Tudo que o app conversa com a nuvem. Nos testes entra uma versão falsa.
abstract class Servidor {
  bool get temSessao;
  String? get emailDaSessao;
  bool get precisaTrocarSenha;

  Future<void> pedirCodigoCadastro(String email);
  Future<void> confirmarCodigoCadastro(String email, String codigo);
  Future<void> definirSenha(String senha);
  Future<Map<String, Object?>> completarCadastro(String nome, String cpf);
  Future<void> entrarComCpf(String cpf, String senha, String aparelho);

  /// Cadastro sem e-mail: nome, CPF e senha (Edge Function cadastrar_motorista).
  Future<void> cadastrarMotorista(String nome, String cpf, String senha, String aparelho);
  Future<void> pedirCodigoSenha(String email);
  Future<void> confirmarCodigoSenha(String email, String codigo);
  Future<Map<String, Object?>> situacao();
  Future<Map<String, Object?>> pedirEntrada(String codigo);
  Future<Map<String, Object?>> sincronizarLote(Map<String, Object?> lote);
  Future<Map<String, Object?>> baixarAlteracoes(DateTime? desde);
  Future<void> sair();
}

ErroServidor traduzirErro(Object e) {
  if (e is ErroServidor) return e;
  if (e is SocketException || e is TimeoutException || e is HttpException) return _semInternet;
  final texto = e.toString();
  if (texto.contains('SocketException') ||
      texto.contains('ClientException') ||
      texto.contains('Failed host lookup') ||
      texto.contains('Connection refused') ||
      texto.contains('Network is unreachable')) {
    return _semInternet;
  }
  if (e is PostgrestException) {
    // As funções do banco já devolvem a frase pronta (e um código no hint).
    final codigo = e.hint ?? '';
    if (e.code == 'PGRST301' || e.code == '401' || texto.contains('JWT')) {
      return const ErroServidor('Sua entrada venceu. Entre de novo.', codigo: 'sessao');
    }
    return ErroServidor(e.message, codigo: codigo);
  }
  if (e is AuthException) {
    final m = e.message.toLowerCase();
    if (m.contains('expired') || m.contains('invalid') && m.contains('otp') || m.contains('token has expired')) {
      return const ErroServidor('Código errado ou vencido. Confira ou peça outro.', codigo: 'codigo');
    }
    if (m.contains('for security purposes') || m.contains('rate limit') || e.statusCode == '429') {
      return const ErroServidor('Espere um minuto antes de pedir outro código.', codigo: 'espera');
    }
    if (m.contains('password') && m.contains('least')) {
      return const ErroServidor('A senha precisa ter pelo menos 6 letras ou números.', codigo: 'senha_curta');
    }
    if (m.contains('same') && m.contains('password')) {
      return const ErroServidor('Escolha uma senha diferente da anterior.', codigo: 'senha_igual');
    }
    if (m.contains('signups not allowed') || m.contains('not allowed')) {
      return const ErroServidor('Não foi possível criar a conta com este e-mail.', codigo: 'cadastro');
    }
    if (m.contains('email') && m.contains('invalid')) {
      return const ErroServidor('Este e-mail não parece certo. Confira.', codigo: 'email');
    }
    return const ErroServidor('Não deu certo. Confira os dados e tente de novo.', codigo: 'auth');
  }
  if (e is FunctionException) {
    final detalhes = e.details;
    if (detalhes is Map && detalhes['mensagem'] is String) {
      return ErroServidor(detalhes['mensagem'] as String, codigo: '${detalhes['codigo'] ?? ''}');
    }
  }
  return const ErroServidor('Não deu certo agora. Tente de novo em instantes.');
}

Future<T> _tentar<T>(Future<T> Function() f) async {
  try {
    return await f().timeout(const Duration(seconds: 40));
  } catch (e) {
    throw traduzirErro(e);
  }
}

Map<String, Object?> _mapa(Object? v) => v is Map ? v.cast<String, Object?>() : <String, Object?>{};

class ServidorSupabase implements Servidor {
  ServidorSupabase(this.cliente);
  final SupabaseClient cliente;

  GoTrueClient get _auth => cliente.auth;

  @override
  bool get temSessao => _auth.currentSession != null;

  @override
  String? get emailDaSessao => _auth.currentUser?.email;

  @override
  bool get precisaTrocarSenha => _auth.currentUser?.userMetadata?['trocar_senha'] == true;

  @override
  Future<void> pedirCodigoCadastro(String email) =>
      _tentar(() => _auth.signInWithOtp(email: email.trim().toLowerCase(), shouldCreateUser: true));

  @override
  Future<void> confirmarCodigoCadastro(String email, String codigo) => _tentar(() async {
        await _auth.verifyOTP(email: email.trim().toLowerCase(), token: codigo.trim(), type: OtpType.email);
      });

  @override
  Future<void> definirSenha(String senha) => _tentar(() async {
        await _auth.updateUser(UserAttributes(password: senha, data: {'trocar_senha': false}));
      });

  @override
  Future<Map<String, Object?>> completarCadastro(String nome, String cpf) => _tentar(() async =>
      _mapa(await cliente.rpc('completar_cadastro', params: {'p_nome': nome.trim(), 'p_cpf': cpf})));

  @override
  Future<void> entrarComCpf(String cpf, String senha, String aparelho) => _tentar(() async {
        final r = await cliente.functions.invoke('entrar_com_cpf', body: {
          'cpf': cpf,
          'senha': senha,
          'aparelho': aparelho,
        });
        final d = _mapa(r.data);
        if (d['ok'] != true || d['refresh_token'] == null) {
          throw ErroServidor('${d['mensagem'] ?? 'CPF ou senha incorretos.'}', codigo: '${d['codigo'] ?? ''}');
        }
        await _auth.setSession(d['refresh_token'] as String);
      });

  @override
  Future<void> cadastrarMotorista(String nome, String cpf, String senha, String aparelho) => _tentar(() async {
        await cliente.functions.invoke('cadastrar_motorista',
            body: {'nome': nome.trim(), 'cpf': cpf, 'senha': senha, 'aparelho': aparelho});
      });

  @override
  Future<void> pedirCodigoSenha(String email) => _tentar(() => _auth.resetPasswordForEmail(email.trim().toLowerCase()));

  @override
  Future<void> confirmarCodigoSenha(String email, String codigo) => _tentar(() async {
        await _auth.verifyOTP(email: email.trim().toLowerCase(), token: codigo.trim(), type: OtpType.recovery);
      });

  @override
  Future<Map<String, Object?>> situacao() => _tentar(() async => _mapa(await cliente.rpc('situacao_acesso')));

  @override
  Future<Map<String, Object?>> pedirEntrada(String codigo) =>
      _tentar(() async => _mapa(await cliente.rpc('pedir_entrada', params: {'p_codigo': codigo})));

  @override
  Future<Map<String, Object?>> sincronizarLote(Map<String, Object?> lote) =>
      _tentar(() async => _mapa(await cliente.rpc('sincronizar_lote', params: {'p_lote': lote})));

  @override
  Future<Map<String, Object?>> baixarAlteracoes(DateTime? desde) => _tentar(() async => _mapa(await cliente
      .rpc('baixar_alteracoes', params: {'p_desde': desde?.toUtc().toIso8601String()})));

  @override
  Future<void> sair() async {
    try {
      await _auth.signOut();
    } catch (_) {
      // Sem internet: a sessão local some do mesmo jeito.
    }
  }
}
