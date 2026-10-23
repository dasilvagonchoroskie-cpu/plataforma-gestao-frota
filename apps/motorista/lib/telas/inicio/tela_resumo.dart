import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nucleo/nucleo.dart';
import 'package:visual/visual.dart';

import '../../componentes/comuns.dart';
import '../acertos/tela_acertos.dart';
import '../configuracoes/tela_configuracoes.dart';
import '../relatorio/tela_relatorio.dart';
import 'lancar.dart';

/// Resumo: as contas do período (o mesmo que o patrão vê) e o botão de lançar.
class TelaResumo extends ConsumerStatefulWidget {
  const TelaResumo({super.key});

  @override
  ConsumerState<TelaResumo> createState() => _TelaResumoState();
}

class _TelaResumoState extends ConsumerState<TelaResumo> {
  var _escolha = const EscolhaPeriodo(TipoPeriodo.mesAtual);

  @override
  Widget build(BuildContext context) {
    final dados = assistirDados(ref);
    final periodo = _escolha.periodo ?? calcularPeriodo(TipoPeriodo.mesAtual)!;
    final d = dados.dadosDoPeriodo(periodo);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Resumo'),
        actions: [
          IconButton(
            tooltip: 'Relatório em PDF',
            icon: const Icon(Icons.picture_as_pdf_outlined),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const TelaRelatorio())),
          ),
          IconButton(
            tooltip: 'Configurações',
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const TelaConfiguracoes())),
          ),
          const SizedBox(width: 4),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'lancar',
        onPressed: () => abrirLancar(context, ref),
        icon: const Icon(Icons.add, size: 28),
        label: const Text('Lançar', style: TextStyle(fontSize: 19)),
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 110),
        children: [
          // O caminhão, os avisos e o que está acontecendo agora ficam no Início.
          const SizedBox(height: 4),
          SeletorPeriodo(escolha: _escolha, aoMudar: (e) => setState(() => _escolha = e)),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
            child: dados.porViagem
                ? CorpoResumoViagens(
                    dados: d,
                    todasAbastecidas: dados.abastecimentos,
                    descricao: _escolha.descricao,
                    empresaNome: dados.info.empresaNome,
                    acertos: dados.acertos,
                    aoAbrirAcerto: (a) =>
                        Navigator.push(context, MaterialPageRoute(builder: (_) => DetalheAcerto(idAcerto: a.id))),
                  )
                : CorpoResumo(
                    dados: d,
                    todasAbastecidas: dados.abastecimentos,
                    descricao: _escolha.descricao,
                    empresaNome: dados.info.empresaNome,
                    percentualPadrao: dados.info.configuracao.percentualComissaoPadrao,
                  ),
          ),
          if (dados.porViagem && dados.acertos.length > 3)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
              child: TextButton(
                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const TelaAcertos())),
                child: const Text('Ver todos os acertos'),
              ),
            ),
        ],
      ),
    );
  }
}
