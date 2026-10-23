import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nucleo/nucleo.dart';
import 'package:visual/visual.dart';

import '../../componentes/comuns.dart';
import '../../dados/dados.dart';

/// A empresa trabalha com mais de uma modalidade: o motorista escolhe a dele
/// uma vez (depois, só o patrão troca). Precisa de internet.
class TelaEscolherModalidade extends ConsumerStatefulWidget {
  const TelaEscolherModalidade({super.key});

  @override
  ConsumerState<TelaEscolherModalidade> createState() => _TelaEscolherModalidadeState();
}

class _TelaEscolherModalidadeState extends ConsumerState<TelaEscolherModalidade> {
  String? _escolhida;
  bool _enviando = false;
  String? _erro;

  static String descricao(Modalidade m) => m.porViagem
      ? 'Por viagem: você anota a carreta que engatou, até onde levou e as entregas. A comissão sai no acerto.'
      : 'Por frete: você anota a carga, o peso, o adiantamento e o saldo. A comissão é calculada em cada frete.';

  Future<void> _confirmar() async {
    final c = _escolhida;
    if (c == null) return;
    setState(() {
      _enviando = true;
      _erro = null;
    });
    final erro = await ref.read(dadosProvider.notifier).escolherModalidade(c);
    if (!mounted) return;
    setState(() {
      _enviando = false;
      _erro = erro;
    });
  }

  @override
  Widget build(BuildContext context) {
    final dados = assistirDados(ref);
    final lista = dados.info.modalidades;
    return Scaffold(
      appBar: AppBar(title: const Text('Como você trabalha?')),
      bottomNavigationBar: RodapeBotao(
        texto: _enviando ? 'Enviando...' : 'Confirmar',
        aoTocar: (_escolhida == null || _enviando) ? null : _confirmar,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          Nota(
            'A ${dados.info.empresaNome.isEmpty ? 'empresa' : dados.info.empresaNome} trabalha com mais de uma '
            'modalidade. Escolha a sua. Depois, só o seu patrão troca.',
          ),
          const SizedBox(height: 16),
          for (final m in lista)
            OpcaoEscolha<String?>(
              valor: m.codigo,
              escolhido: _escolhida,
              titulo: m.nome,
              descricao: descricao(m),
              aoEscolher: (v) => setState(() => _escolhida = v),
            ),
          if (_erro != null) ...[
            const SizedBox(height: 8),
            Aviso(icone: Icons.wifi_off, titulo: 'Não deu certo', texto: _erro!),
          ],
        ],
      ),
    );
  }
}
