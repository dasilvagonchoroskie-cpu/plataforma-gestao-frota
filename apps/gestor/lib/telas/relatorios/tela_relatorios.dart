import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nucleo/nucleo.dart';
import 'package:visual/visual.dart';

import '../../componentes/comuns.dart';
import '../../dados/equipe.dart';
import '../../dados/provedores.dart';
import '../../relatorio/compartilhar.dart';
import '../casca.dart';

enum Recorte {
  frota('Frota toda'),
  motorista('Um motorista'),
  caminhao('Um caminhão'),
  embarcador('Um embarcador');

  const Recorte(this.rotulo);
  final String rotulo;
}

/// Relatórios em PDF (o mesmo modelo do app do motorista) e planilhas CSV
/// por motorista, caminhão, embarcador ou da frota toda.
class TelaRelatorios extends ConsumerStatefulWidget {
  const TelaRelatorios({super.key});

  @override
  ConsumerState<TelaRelatorios> createState() => _TelaRelatoriosState();
}

class _TelaRelatoriosState extends ConsumerState<TelaRelatorios> {
  var _recorte = Recorte.frota;
  String? _item;
  var _conteudo = ConteudoRelatorio.tudo;

  DadosRelatorio? _dados(Equipe e, Periodo periodo) {
    switch (_recorte) {
      case Recorte.frota:
        return e.relatorio(periodo, conteudo: _conteudo);
      case Recorte.motorista:
        return _item == null ? null : e.relatorio(periodo, motoristaId: _item, conteudo: _conteudo);
      case Recorte.caminhao:
        return _item == null ? null : e.relatorio(periodo, caminhaoId: _item, conteudo: _conteudo);
      case Recorte.embarcador:
        return _item == null ? null : e.relatorio(periodo, embarcador: _item, conteudo: _conteudo);
    }
  }

  Future<void> _planilhas(Equipe e, DadosRelatorio d) async {
    final base = nomeDoArquivoPdf(d).replaceAll('.pdf', '');
    final nomes = e.nomesMotoristas;
    final placas = e.placas;
    final arquivos = <Arquivo>[
      if ((_conteudo == ConteudoRelatorio.tudo || _conteudo == ConteudoRelatorio.fretes) &&
          (d.fretes.isNotEmpty || d.viagens.isEmpty))
        arquivoCsv('${base}_fretes.csv', csvFretes(d.fretes, motoristas: nomes, placas: placas)),
      if ((_conteudo == ConteudoRelatorio.tudo || _conteudo == ConteudoRelatorio.fretes) && d.viagens.isNotEmpty)
        arquivoCsv(
          '${base}_viagens.csv',
          csvViagens(d.viagens, motoristas: nomes, placas: placas, modalidade: d.modalidade),
        ),
      if (_conteudo == ConteudoRelatorio.tudo || _conteudo == ConteudoRelatorio.diesel)
        arquivoCsv(
          '${base}_diesel.csv',
          csvAbastecimentos(d.abastecimentos, e.abastecimentos, motoristas: nomes, placas: placas),
        ),
      if (_conteudo == ConteudoRelatorio.tudo || _conteudo == ConteudoRelatorio.gastos)
        arquivoCsv('${base}_gastos.csv', csvGastos(d.gastos, motoristas: nomes, placas: placas)),
      if ((_conteudo == ConteudoRelatorio.tudo || _conteudo == ConteudoRelatorio.vales) && d.vales.isNotEmpty)
        arquivoCsv('${base}_vales.csv', csvVales(d.vales, motoristas: nomes)),
    ];
    await compartilharArquivos(arquivos, assunto: 'Planilhas da frota');
  }

  @override
  Widget build(BuildContext context) {
    final e = assistirEquipe(ref);
    final escolha = ref.watch(periodoProvider);
    final periodo = escolha.periodoOuMes;
    final cores = context.cores;
    final d = _dados(e, periodo);

    final itens = switch (_recorte) {
      Recorte.frota => const <String, String>{},
      Recorte.motorista => {for (final m in e.motoristas) m.id: m.nome},
      Recorte.caminhao => {for (final c in e.caminhoes) c.id: placaTexto(c.placa)},
      Recorte.embarcador => {for (final x in e.embarcadores) x: x},
    };

    return Scaffold(
      appBar: AppBar(title: const Text('Relatórios'), actions: acoesPadrao(context, ref)),
      body: ListaCentral(
        largura: 760,
        children: [
          const SizedBox(height: 4),
          const FaixaPeriodo(),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const TituloSecao('De quem', espacoAcima: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final r in Recorte.values)
                      ChoiceChip(
                        label: Text(r.rotulo),
                        selected: _recorte == r,
                        showCheckmark: false,
                        onSelected: (_) => setState(() {
                          _recorte = r;
                          _item = null;
                        }),
                      ),
                  ],
                ),
                if (_recorte != Recorte.frota) ...[
                  const SizedBox(height: 14),
                  Escolha<String>(
                    rotulo: _recorte.rotulo.replaceFirst('Um ', ''),
                    valor: _item,
                    largura: double.infinity,
                    itens: itens,
                    aoMudar: (v) => setState(() => _item = v),
                  ),
                ],
                const TituloSecao('O que entra'),
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
                const SizedBox(height: 20),
                if (d == null)
                  const Nota('Escolha na lista acima para ver o relatório.')
                else ...[
                  Card(
                    elevation: 0,
                    color: Theme.of(context).colorScheme.surfaceContainerLow,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
                      child: Column(
                        children: [
                          LinhaValor(rotulo: 'Período', valor: periodo.texto),
                          LinhaValor(
                            rotulo: 'Fretes',
                            valor: reais(d.resultado.totalFretes),
                            detalhe: plural(d.fretes.length, 'frete', 'fretes'),
                          ),
                          LinhaValor(
                            rotulo: 'Diesel',
                            valor: reais(d.resultado.totalAbastecimento),
                            detalhe: plural(d.abastecimentos.length, 'abastecida', 'abastecidas'),
                          ),
                          LinhaValor(
                            rotulo: 'Outros gastos',
                            valor: reais(d.resultado.totalGastos),
                            detalhe: plural(d.gastos.length, 'gasto', 'gastos'),
                          ),
                          LinhaValor(
                            rotulo: 'Vales',
                            valor: reais(d.resultado.totalVale),
                            detalhe: plural(d.vales.length, 'vale', 'vales'),
                          ),
                          LinhaValor(rotulo: 'Comissões', valor: reais(d.resultado.comissaoDoCaminhao)),
                          LinhaValor(
                            rotulo: 'Resultado',
                            valor: reais(d.resultado.sobraDoCaminhao),
                            destaque: true,
                            corValor: d.resultado.sobraDoCaminhao < 0 ? cores.negativo : cores.positivo,
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (_recorte == Recorte.caminhao || _recorte == Recorte.embarcador)
                    const Padding(
                      padding: EdgeInsets.only(top: 8),
                      child: Nota('Vale é do motorista, então não entra no relatório de caminhão nem de embarcador.'),
                    ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      FilledButton.icon(
                        onPressed: d.vazio ? null : () => executar(context, () => compartilharPdf(d)),
                        icon: const Icon(Icons.picture_as_pdf_outlined),
                        label: const Text('Gerar PDF'),
                      ),
                      OutlinedButton.icon(
                        onPressed: d.vazio ? null : () => executar(context, () => _planilhas(e, d)),
                        icon: const Icon(Icons.table_view_outlined),
                        label: const Text('Planilhas (CSV)'),
                      ),
                    ],
                  ),
                  if (d.vazio)
                    const Padding(padding: EdgeInsets.only(top: 10), child: Nota('Nada lançado neste período.')),
                  const SizedBox(height: 10),
                  const Nota(
                    'O PDF é o mesmo modelo que o motorista gera no app. As planilhas abrem no Excel e no Google Planilhas.',
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
