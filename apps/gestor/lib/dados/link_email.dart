import 'package:flutter_riverpod/flutter_riverpod.dart';

/// O que o link do e-mail faz: criar a senha nova ou confirmar o e-mail.
enum TipoLink { senha, email }

/// Link que chegou por e-mail e abriu o painel
/// (…/plataforma-gestao-frota/?token_hash=…&type=recovery|email_change).
class LinkDoEmail {
  const LinkDoEmail(this.tokenHash, this.tipo);
  final String tokenHash;
  final TipoLink tipo;

  /// Lê o link do endereço da página. Nulo quando não é um link de e-mail.
  static LinkDoEmail? doEndereco(Uri endereco) {
    final q = endereco.queryParameters;
    final hash = q['token_hash'] ?? '';
    if (!RegExp(r'^[A-Za-z0-9_-]{10,200}$').hasMatch(hash)) return null;
    return switch (q['type']) {
      'recovery' => LinkDoEmail(hash, TipoLink.senha),
      'email_change' => LinkDoEmail(hash, TipoLink.email),
      _ => null,
    };
  }
}

/// O link aberto agora (nulo quando a pessoa entrou normalmente).
class LinkAberto extends Notifier<LinkDoEmail?> {
  LinkAberto([this._inicial]);
  final LinkDoEmail? _inicial;

  @override
  LinkDoEmail? build() => _inicial;

  void concluir() => state = null;
}

final linkDoEmailProvider = NotifierProvider<LinkAberto, LinkDoEmail?>(LinkAberto.new);
