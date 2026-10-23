import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:visual/visual.dart';

import 'aparelho.dart';

/// Aparência do painel (escuro, claro ou igual ao aparelho), guardada no
/// aparelho. Começa escuro, como o cartaz da plataforma.
class Aparencia extends Notifier<PreferenciaTema> {
  static const chave = 'tema';

  @override
  PreferenciaTema build() {
    _carregar();
    return PreferenciaTema.escuro;
  }

  Future<void> _carregar() async {
    try {
      final p = PreferenciaTema.deTexto(await ref.read(aparelhoProvider).ler(chave));
      if (p != state) state = p;
    } catch (_) {}
  }

  Future<void> escolher(PreferenciaTema p) async {
    state = p;
    try {
      await ref.read(aparelhoProvider).gravar(chave, p.name);
    } catch (_) {}
  }
}

final aparenciaProvider = NotifierProvider<Aparencia, PreferenciaTema>(Aparencia.new);
