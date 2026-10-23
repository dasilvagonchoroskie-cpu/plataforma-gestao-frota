import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:visual/visual.dart';

import 'dados.dart';

/// Aparência do app (escuro, claro ou igual ao celular), guardada no celular.
/// Começa escuro, como o cartaz da plataforma.
class Aparencia extends Notifier<PreferenciaTema> {
  static const chave = 'tema';

  @override
  PreferenciaTema build() {
    _carregar();
    return PreferenciaTema.escuro;
  }

  Future<void> _carregar() async {
    try {
      final p = PreferenciaTema.deTexto(await ref.read(armazenamentoProvider).lerEstado(chave));
      if (p != state) state = p;
    } catch (_) {
      // Sem armazenamento (abertura com erro): fica o padrão.
    }
  }

  Future<void> escolher(PreferenciaTema p) async {
    state = p;
    try {
      await ref.read(armazenamentoProvider).gravarEstado(chave, p.name);
    } catch (_) {}
  }
}

final aparenciaProvider = NotifierProvider<Aparencia, PreferenciaTema>(Aparencia.new);
