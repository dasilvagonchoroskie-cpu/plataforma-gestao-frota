import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nucleo/nucleo.dart';
import 'package:visual/visual.dart';

import '../../componentes/comuns.dart';
import '../../dados/dados.dart';

/// Trocar de caminhão: escolhe na lista dos caminhões da empresa. Não se
/// digita placa, a não ser em "Não achei meu caminhão".
class TelaTrocarCaminhao extends ConsumerWidget {
  const TelaTrocarCaminhao({super.key, this.primeiraVez = false});

  /// Primeira vez: o motorista ainda não escolheu caminhão nenhum.
  final bool primeiraVez;

  Future<void> _escolher(BuildContext context, WidgetRef ref, Caminhao c) async {
    final d = ref.read(dadosProvider).requireValue;
    if (d.caminhaoAtualId == c.id) {
      Navigator.pop(context);
      return;
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Trocar de caminhão?'),
        content: Text(
          'Você vai lançar no caminhão ${placaTexto(c.placa)}.'
          '${d.caminhaoAtual == null ? '' : ' O que você já lançou continua no caminhão ${placaTexto(d.caminhaoAtual!.placa)}.'}',
          style: const TextStyle(fontSize: 17, height: 1.4),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Trocar')),
        ],
      ),
    );
    if (ok != true) return;
    await ref.read(dadosProvider.notifier).trocarCaminhao(c.id);
    if (context.mounted) {
      final m = ScaffoldMessenger.of(context);
      Navigator.pop(context);
      m.showSnackBar(SnackBar(content: Text('Agora você está no ${placaTexto(c.placa)}.')));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final d = assistirDados(ref);
    final lista = d.caminhoesAtivos;
    final cores = context.cores;
    return Scaffold(
      appBar: AppBar(title: Text(primeiraVez ? 'Qual é o seu caminhão?' : 'Trocar de caminhão')),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 32),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
            child: Nota(primeiraVez
                ? 'Escolha o caminhão que você está dirigindo. Os lançamentos ficam ligados a ele.'
                : 'Escolha o caminhão. O que você já lançou continua no caminhão em que foi lançado.'),
          ),
          if (lista.isEmpty)
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 0, 20, 12),
              child: Aviso(
                titulo: 'Nenhum caminhão na lista ainda',
                texto: 'O seu patrão cadastra os caminhões no painel. Se não estiver aqui, use "Não achei meu caminhão".',
              ),
            ),
          for (final c in lista)
            Card(
              margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: BorderSide(
                  color: c.id == d.caminhaoAtualId ? Theme.of(context).colorScheme.primary : cores.divisor,
                  width: c.id == d.caminhaoAtualId ? 2 : 1,
                ),
              ),
              child: InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: () => _escolher(context, ref, c),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    children: [
                      PlacaVeiculo(c.placa, tamanho: 22),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if ((c.numeroFrota ?? '').isNotEmpty)
                              Text('Frota ${c.numeroFrota}', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
                            if (c.modelo.isNotEmpty) Text(c.modelo, style: TextStyle(fontSize: 15, color: cores.textoFraco)),
                            if (!c.confirmado)
                              Text('Aguardando o gestor conferir', style: TextStyle(fontSize: 13.5, color: cores.atencao)),
                          ],
                        ),
                      ),
                      if (c.id == d.caminhaoAtualId)
                        Icon(Icons.check_circle, color: Theme.of(context).colorScheme.primary, semanticLabel: 'Em uso'),
                    ],
                  ),
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: OutlinedButton.icon(
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const TelaNovaPlaca())),
              icon: const Icon(Icons.search_off),
              label: const Text('Não achei meu caminhão'),
            ),
          ),
        ],
      ),
    );
  }
}

/// O motorista digita a placa; o caminhão entra como "não confirmado" e o
/// gestor confere no painel. Os lançamentos já ficam ligados a ele.
class TelaNovaPlaca extends ConsumerStatefulWidget {
  const TelaNovaPlaca({super.key});

  @override
  ConsumerState<TelaNovaPlaca> createState() => _TelaNovaPlacaState();
}

class _TelaNovaPlacaState extends ConsumerState<TelaNovaPlaca> {
  final _placa = TextEditingController();
  final _frota = TextEditingController();
  String? _erro;

  @override
  void dispose() {
    _placa.dispose();
    _frota.dispose();
    super.dispose();
  }

  Future<void> _salvar() async {
    if (!placaValida(_placa.text)) {
      setState(() => _erro = 'Placa errada. Exemplos: ABC1D23 ou ABC-1234.');
      return;
    }
    final placa = normalizarPlaca(_placa.text);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirmar a placa'),
        content: Text('Você vai lançar no caminhão ${placaTexto(placa)}. O seu patrão confere a placa no painel.',
            style: const TextStyle(fontSize: 17, height: 1.4)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Corrigir')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Confirmar')),
        ],
      ),
    );
    if (ok != true) return;
    await ref.read(dadosProvider.notifier).cadastrarCaminhao(placa, numeroFrota: _frota.text);
    if (!mounted) return;
    final m = ScaffoldMessenger.of(context);
    Navigator.of(context).popUntil((r) => r.isFirst);
    m.showSnackBar(SnackBar(content: Text('Agora você está no ${placaTexto(placa)}.')));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Placa do caminhão')),
      bottomNavigationBar: RodapeBotao(texto: 'Usar esta placa', aoTocar: _salvar),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          const Nota('Digite a placa do caminhão que você está dirigindo.'),
          const SizedBox(height: 18),
          Campo(
            controle: _placa,
            rotulo: 'Placa',
            tipo: TipoCampo.placa,
            dica: 'ABC1D23',
            erro: _erro,
            autofoco: true,
            aoMudar: (_) => setState(() => _erro = null),
          ),
          const SizedBox(height: 14),
          Campo(controle: _frota, rotulo: 'Número da frota', ajuda: 'Opcional, se o caminhão tiver'),
        ],
      ),
    );
  }
}
