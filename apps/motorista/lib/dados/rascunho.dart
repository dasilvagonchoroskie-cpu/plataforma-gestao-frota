import 'dart:convert';

import 'armazenamento.dart';

/// O que foi digitado num formulário novo fica guardado mesmo se o app
/// fechar ("nada do que você digitar se perde", como no Meu Frete).
class Rascunho {
  Rascunho(this._a, this.nome);
  final Armazenamento _a;
  final String nome;

  String get _chave => 'rascunho:$nome';

  Future<Map<String, Object?>> ler() async {
    final t = await _a.lerEstado(_chave);
    if (t == null || t.isEmpty) return const {};
    try {
      return (jsonDecode(t) as Map).cast<String, Object?>();
    } catch (_) {
      return const {};
    }
  }

  Future<void> gravar(Map<String, Object?> valores) => _a.gravarEstado(_chave, jsonEncode(valores));

  Future<void> limpar() => _a.gravarEstado(_chave, null);
}
