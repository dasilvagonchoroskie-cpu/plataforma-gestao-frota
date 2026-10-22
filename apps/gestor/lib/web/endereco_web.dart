import 'package:web/web.dart';

/// Tira token_hash e type do endereço, sem recarregar a página.
void limparLinkDoEndereco() {
  final atual = Uri.parse(window.location.href);
  final resto = Map<String, String>.of(atual.queryParameters)
    ..remove('token_hash')
    ..remove('type');
  final limpo = Uri(
    scheme: atual.scheme,
    userInfo: atual.userInfo,
    host: atual.host,
    port: atual.hasPort ? atual.port : null,
    path: atual.path,
    queryParameters: resto.isEmpty ? null : resto,
    fragment: atual.fragment.isEmpty ? null : atual.fragment,
  );
  window.history.replaceState(null, '', limpo.toString());
}
