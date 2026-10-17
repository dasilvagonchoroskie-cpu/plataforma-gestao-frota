import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nucleo/nucleo.dart';
import 'package:visual/visual.dart';

import '../../componentes/comuns.dart';
import '../../relatorio/compartilhar.dart';

/// Monta o relatório em PDF do próprio motorista.
class TelaRelatorio extends ConsumerStatefulWidget {
  const TelaRelatorio({super.key});

  @override
  ConsumerState<TelaRelatorio> createState() => _TelaRelatorioState();
}

class _TelaRelatorioState extends ConsumerState<TelaRelatorio> {
  var _escolha = const EscolhaPeriodo(TipoPeriodo.mesAtual);
  var _conteudo = ConteudoRelatorio.tudo;
  bool _gerando = false;

  Future<void> _gerar(DadosRelatorio d) async {
    setState(() => _gerando = true);
    try {
      await gerarEEnviarPdf(d);
    } catch (e) {
      if (mounted) mostrarMensagem(context, 'Não deu para montar o PDF agora. Tente de novo.');
    } finally {
      if (mounted) setState(() => _gerando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final dados = assistirDados(ref);
    final periodo = _escolha.periodo;
    final d = periodo == null ? null : dados.dadosDoPeriodo(periodo, conteudo: _conteudo);

    final List<String> partes;
    final bool semNada;
    if (d == null) {
      partes = const [];
      semNada = true;
    } else {
      final fr = plural(d.fretes.length, 'frete', 'fretes');
      final ab = plural(d.abastecimentos.length, 'abastecida', 'abastecidas');
      final va = plural(d.vales.length, 'vale', 'vales');
      final ga = plural(d.gastos.length, 'gasto', 'gastos');
      switch (_conteudo) {
        case ConteudoRelatorio.tudo:
          partes = [fr, ab, va, ga];
          semNada = d.vazio;
        case ConteudoRelatorio.fretes:
          partes = [fr];
          semNada = d.fretes.isEmpty;
        case ConteudoRelatorio.diesel:
          partes = [ab];
          semNada = d.abastecimentos.isEmpty;
        case ConteudoRelatorio.vales:
          partes = [va];
          semNada = d.vales.isEmpty;
        case ConteudoRelatorio.gastos:
          partes = [ga];
          semNada = d.gastos.isEmpty;
      }
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Relatório em PDF')),
      bottomNavigationBar: RodapeBotao(
        texto: _gerando ? 'Montando o PDF...' : 'Gerar PDF e enviar',
        icone: Icons.ios_share,
        aoTocar: (_gerando || d == null) ? null : () => _gerar(d),
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 32),
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 4, 20, 10),
            child: Text('De quando até quando', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
          ),
          SeletorPeriodo(escolha: _escolha, aoMudar: (e) => setState(() => _escolha = e)),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  periodo == null ? 'Escolha as datas.' : periodo.texto,
                  style: estiloNumero(17, peso: FontWeight.w500, cor: context.cores.textoFraco),
                ),
                const TituloSecao('O que vai no papel', espacoAcima: 24),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final c in ConteudoRelatorio.values)
                      ChoiceChip(
                        label: Text(c.rotulo),
                        selected: _conteudo == c,
                        showCheckmark: false,
                        onSelected: (_) => setState(() => _conteudo = c),
                      ),
                  ],
                ),
                const SizedBox(height: 10),
                Nota(_conteudo == ConteudoRelatorio.tudo
                    ? 'Vai tudo junto: fretes, diesel, vales, gastos e as contas do período.'
                    : 'Só a parte escolhida, com o fechamento dela.'),
                const TituloSecao('Vai no relatório'),
                if (partes.isNotEmpty) Text(partes.join(', '), style: const TextStyle(fontSize: 17)),
                if (semNada) ...[
                  const SizedBox(height: 12),
                  const Aviso(
                    titulo: 'Nada anotado neste período',
                    texto: 'O PDF vai sair sem registros. Confira se o período escolhido pega a data dos seus lançamentos.',
                  ),
                ],
                const SizedBox(height: 24),
                const Nota('O seu patrão já vê tudo no painel, sem precisar do PDF. Use o PDF quando quiser guardar '
                    'ou mandar o acerto para alguém.'),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
