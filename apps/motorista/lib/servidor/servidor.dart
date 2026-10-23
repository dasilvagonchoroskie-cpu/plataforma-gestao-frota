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

  /// E-mail do motorista já confirmado (nulo enquanto o login é o interno).
  String? get emailConfirmado;

  /// E-mail novo esperando a confirmação pelo link.
  String? get emailEsperando;

  Future<void> pedirCodigoCadastro(String email);
  Future<void> confirmarCodigoCadastro(String email, String codigo);
  Future<void> definirSenha(String senha);
  Future<Map<String, Object?>> completarCadastro(String nome, String cpf);
  Future<void> entrarComCpf(String cpf, String senha, String aparelho);

  /// Cadastro sem e-mail: nome, CPF e senha (Edge Function cadastrar_motorista).
  /// [termos] é a versão dos Termos de Uso aceita na tela de cadastro.
  Future<void> cadastrarMotorista(String nome, String cpf, String senha, String aparelho, {String? termos});

  /// Aceite dos Termos de Uso e da Política de Privacidade. Devolve a situação.
  Future<Map<String, Object?>> aceitarTermos(String versao);

  /// Pede o link para criar a senha nova (vai para o e-mail confirmado do
  /// motorista). Devolve o recado para mostrar.
  Future<String> pedirLinkSenha(String cpf);

  /// Cadastra (ou troca) o e-mail para recuperar a senha. O Supabase manda um
  /// link para o e-mail novo; ele só passa a valer depois de confirmado.
  Future<void> cadastrarEmail(String email);

  /// Busca na nuvem os dados da conta (para saber se o e-mail foi confirmado).
  Future<void> atualizarConta();

  /// Exclui a conta (sem empresa: na hora; com empresa: em até 15 dias).
  Future<Map<String, Object?>> excluirMinhaConta();

  /// Registro de acesso (data, hora e IP) exigido pelo Marco Civil.
  Future<void> registrarAcesso();
  Future<Map<String, Object?>> situacao();
  Future<Map<String, Object?>> pedirEntrada(String codigo);

  /// O motorista escolhe a modalidade (empresa com mais de uma ligada).
  Future<void> escolherModalidade(String codigo);
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
      return const ErroServidor('Espere um minuto antes de pedir de novo.', codigo: 'espera');
    }
    if (e.code == 'email_exists' || m.contains('already been registered')) {
      return const ErroServidor('Este e-mail já está em outra conta. Use outro e-mail.', codigo: 'email_em_uso');
    }
    if (m.contains('password') && (m.contains('least') || m.contains('weak') || m.contains('should contain'))) {
      return const ErroServidor(
        'A senha precisa ter pelo menos 8 caracteres, com letras e números.',
        codigo: 'senha_fraca',
      );
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

  /// Login interno do motorista (não recebe e-mail).
  static bool _interno(String? e) => e == null || e.isEmpty || e.endsWith('@motorista.fortalezadigitalsecurity.com.br');

  @override
  String? get emailConfirmado {
    final e = _auth.currentUser?.email;
    return _interno(e) ? null : e;
  }

  @override
  String? get emailEsperando {
    final e = _auth.currentUser?.newEmail;
    return (e == null || e.isEmpty) ? null : e;
  }

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
  Future<Map<String, Object?>> completarCadastro(String nome, String cpf) => _tentar(
    () async => _mapa(await cliente.rpc('completar_cadastro', params: {'p_nome': nome.trim(), 'p_cpf': cpf})),
  );

  @override
  Future<void> entrarComCpf(String cpf, String senha, String aparelho) => _tentar(() async {
    final r = await cliente.functions.invoke(
      'entrar_com_cpf',
      body: {'cpf': cpf, 'senha': senha, 'aparelho': aparelho},
    );
    final d = _mapa(r.data);
    if (d['ok'] != true || d['refresh_token'] == null) {
      throw ErroServidor('${d['mensagem'] ?? 'CPF ou senha incorretos.'}', codigo: '${d['codigo'] ?? ''}');
    }
    await _auth.setSession(d['refresh_token'] as String);
  });

  @override
  Future<void> cadastrarMotorista(String nome, String cpf, String senha, String aparelho, {String? termos}) =>
      _tentar(() async {
        await cliente.functions.invoke(
          'cadastrar_motorista',
          body: {'nome': nome.trim(), 'cpf': cpf, 'senha': senha, 'aparelho': aparelho, 'termos': ?termos},
        );
      });

  @override
  Future<Map<String, Object?>> aceitarTermos(String versao) =>
      _tentar(() async => _mapa(await cliente.rpc('aceitar_termos', params: {'p_versao': versao})));

  @override
  Future<String> pedirLinkSenha(String cpf) => _tentar(() async {
    final r = await cliente.functions.invoke('pedir_link_senha', body: {'identificador': cpf});
    final d = _mapa(r.data);
    if (d['ok'] != true) throw ErroServidor('${d['mensagem'] ?? 'Não deu para pedir o link agora.'}');
    return '${d['mensagem']}';
  });

  @override
  Future<void> cadastrarEmail(String email) =>
      _tentar(() => _auth.updateUser(UserAttributes(email: email.trim().toLowerCase())));

  @override
  Future<void> atualizarConta() async {
    try {
      await _auth.refreshSession().timeout(const Duration(seconds: 20));
    } catch (_) {
      // Sem internet: mostra o que já sabe.
    }
  }

  @override
  Future<Map<String, Object?>> excluirMinhaConta() =>
      _tentar(() async => _mapa(await cliente.rpc('excluir_minha_conta')));

  @override
  Future<void> registrarAcesso() async {
    try {
      await cliente.rpc('registrar_acesso', params: {'p_app': 'motorista'}).timeout(const Duration(seconds: 20));
    } catch (_) {
      // Sem internet: registra na próxima vez.
    }
  }

  @override
  Future<Map<String, Object?>> situacao() => _tentar(() async => _mapa(await cliente.rpc('situacao_acesso')));

  @override
  Future<Map<String, Object?>> pedirEntrada(String codigo) =>
      _tentar(() async => _mapa(await cliente.rpc('pedir_entrada', params: {'p_codigo': codigo})));

  @override
  Future<void> escolherModalidade(String codigo) =>
      _tentar(() => cliente.rpc('escolher_minha_modalidade', params: {'p_modalidade': codigo}));

  @override
  Future<Map<String, Object?>> sincronizarLote(Map<String, Object?> lote) =>
      _tentar(() async => _mapa(await cliente.rpc('sincronizar_lote', params: {'p_lote': lote})));

  @override
  Future<Map<String, Object?>> baixarAlteracoes(DateTime? desde) => _tentar(
    () async => _mapa(await cliente.rpc('baixar_alteracoes', params: {'p_desde': desde?.toUtc().toIso8601String()})),
  );

  @override
  Future<void> sair() async {
    try {
      await _auth.signOut();
    } catch (_) {
      // Sem internet: a sessão local some do mesmo jeito.
    }
  }
}
