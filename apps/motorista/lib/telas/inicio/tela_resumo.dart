import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nucleo/nucleo.dart';
import 'package:visual/visual.dart';

import '../../componentes/comuns.dart';
import '../configuracoes/tela_configuracoes.dart';
import '../diesel/form_abastecimento.dart';
import '../fretes/form_frete.dart';
import '../gastos/tela_gastos.dart';
import '../relatorio/tela_relatorio.dart';
import '../vales/tela_vales.dart';

/// Início: o resumo do período e o botão grande para lançar.
class TelaResumo extends ConsumerStatefulWidget {
  const TelaResumo({super.key});

  @override
  ConsumerState<TelaResumo> createState() => _TelaResumoState();
}

class _TelaResumoState extends ConsumerState<TelaResumo> {
  var _escolha = const EscolhaPeriodo(TipoPeriodo.mesAtual);

  void _lancar() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        Widget opcao(IconData icone, String titulo, String texto, Widget tela) => ListTile(
              leading: Icon(icone, size: 30),
              title: Text(titulo, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w600)),
              subtitle: Text(texto, style: const TextStyle(fontSize: 15)),
              minVerticalPadding: 14,
              onTap: () {
                Navigator.pop(ctx);
                Navigator.push(context, MaterialPageRoute(builder: (_) => tela));
              },
            );
        return SafeArea(
          child: SingleChildScrollView(
            child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(20, 0, 20, 8),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text('O que você quer lançar?', style: TextStyle(fontSize: 21, fontWeight: FontWeight.w600)),
                ),
              ),
              opcao(Icons.local_shipping_outlined, 'Frete', 'Carga, adiantamento, saldo', const FormFrete()),
              opcao(Icons.local_gas_station_outlined, 'Diesel', 'Abastecida, km e litros', const FormAbastecimento()),
              opcao(Icons.receipt_long_outlined, 'Gasto', 'Borracharia, chapa, lavagem...', const FormGasto()),
              opcao(Icons.payments_outlined, 'Vale', 'Dinheiro que você pegou adiantado', const FormVale()),
              const SizedBox(height: 8),
            ],
          ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final dados = assistirDados(ref);
    final regras = dados.regras;
    final cores = context.cores;
    final periodo = _escolha.periodo ?? calcularPeriodo(TipoPeriodo.mesAtual)!;
    final d = dados.dadosDoPeriodo(periodo);
    final r = d.resultado;
    final descricao = _escolha.descricao;

    String detalheComissao;
    if (r.quantidadeFretes == 0) {
      detalheComissao = 'Nenhum frete no período';
    } else if (r.percentuaisDiferentes) {
      detalheComissao = 'Na média ${percentualTexto(r.percentualMedio)}% sobre ${reais(r.totalBaseComissao)}';
    } else {
      detalheComissao = '${percentualTexto(r.percentualMedio)}% sobre ${reais(r.totalBaseComissao)}';
    }

    final mediaDiesel = mediaDoPeriodo(d.abastecimentos, dados.abastecimentos);
    final litros = d.abastecimentos.fold<double>(0, (s, a) => s + a.litros);

    return Scaffold(
      appBar: AppBar(
        title: Text(dados.info.nome.isEmpty ? 'Resumo' : dados.info.nome.split(' ').first),
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
        onPressed: _lancar,
        icon: const Icon(Icons.add, size: 28),
        label: const Text('Lançar', style: TextStyle(fontSize: 19)),
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 110),
        children: [
          const TopoCaminhao(),
          const LinhaEnvio(),
          if (dados.info.suspensa)
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 4, 20, 8),
              child: Aviso(
                icone: Icons.pause_circle_outline,
                titulo: 'Empresa suspensa',
                texto: 'Os seus lançamentos ficam guardados no celular e vão ser enviados quando a empresa voltar.',
              ),
            ),
          const SizedBox(height: 4),
          SeletorPeriodo(escolha: _escolha, aoMudar: (e) => setState(() => _escolha = e)),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Placa(
                  rotulo: r.liquido < 0 ? 'Você está devendo' : 'Você tem para receber',
                  valor: reais(r.liquido),
                  detalhe: descricao[0].toUpperCase() + descricao.substring(1),
                  tipo: r.liquido < 0 ? TipoPlaca.vermelha : TipoPlaca.verde,
                ),
                const SizedBox(height: 10),
                LinhaValor(
                  rotulo: 'Comissão',
                  valor: '+ ${reais(r.comissao)}',
                  detalhe: detalheComissao,
                  corValor: cores.positivo,
                  corDetalhe: r.percentuaisDiferentes ? cores.atencao : null,
                ),
                LinhaValor(
                  rotulo: 'Diesel e gastos',
                  valor: regras.gastosDescontamDoLiquido ? '$menos ${reais(r.totalGastoGeral)}' : reais(r.totalGastoGeral),
                  detalhe: regras.gastosDescontamDoLiquido
                      ? 'Saem do seu bolso, então descontam'
                      : 'A empresa paga, não descontam do seu líquido',
                  corValor: regras.gastosDescontamDoLiquido ? cores.negativo : cores.textoFraco,
                ),
                LinhaValor(
                  rotulo: 'Vales',
                  valor: regras.valeDescontaDoLiquido ? '$menos ${reais(r.totalVale)}' : reais(r.totalVale),
                  detalhe: regras.valeDescontaDoLiquido
                      ? 'Você já recebeu adiantado, então desconta'
                      : 'Só histórico, não mexe no líquido',
                  corValor: regras.valeDescontaDoLiquido ? cores.negativo : cores.textoFraco,
                ),
                if (d.vazio) ...[
                  const SizedBox(height: 16),
                  Aviso(
                    icone: Icons.edit_note,
                    titulo: 'Nada lançado em $descricao',
                    texto: 'Toque em "Lançar" para anotar fretes, abastecidas, gastos e vales. '
                        'As contas aparecem aqui sozinhas.',
                  ),
                ],
                if (!d.vazio) ...[
                  TituloSecao(d.variosCaminhoes ? 'Conta dos caminhões' : 'Conta do caminhão'),
                  const Nota('O que sobrou depois de pagar o diesel, os gastos e a comissão.'),
                  const SizedBox(height: 6),
                  if (r.fretesEmAberto > 0) ...[
                    Aviso(
                      icone: Icons.hourglass_bottom,
                      titulo: r.fretesEmAberto == 1
                          ? '1 frete aguardando saldo'
                          : '${r.fretesEmAberto} fretes aguardando saldo',
                      texto: 'Devem entrar ${reais(r.contratadoEmAberto)} quando o saldo cair. '
                          'Até lá a conta mostra a despesa sem essa receita.',
                    ),
                    const SizedBox(height: 6),
                  ],
                  LinhaValor(
                    rotulo: 'Frete que caiu na conta',
                    valor: reais(r.totalFretes),
                    detalhe: plural(r.quantidadeFretes, 'frete', 'fretes') +
                        (r.totalDescontoDoFrete > 1 ? ', descontaram ${reais(r.totalDescontoDoFrete)} do contratado' : ''),
                  ),
                  LinhaValor(rotulo: 'Diesel', valor: '$menos ${reais(r.totalAbastecimento)}'),
                  LinhaValor(rotulo: 'Outros gastos', valor: '$menos ${reais(r.totalGastos)}'),
                  LinhaValor(rotulo: 'Comissão do motorista', valor: '$menos ${reais(r.comissaoDoCaminhao)}'),
                  const Divider(height: 18),
                  LinhaValor(
                    rotulo: r.sobraDoCaminhao >= 0 ? 'Sobrou para o caminhão' : 'Faltou',
                    valor: reais(r.sobraDoCaminhao),
                    destaque: true,
                    corValor: r.sobraDoCaminhao >= 0
                        ? cores.positivo
                        : (r.fretesEmAberto > 0 ? cores.atencao : cores.negativo),
                  ),
                  if (r.totalQuebraKg > 0)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Nota(
                        'Quebra de ${semCasas(r.totalQuebraKg)} kg no período'
                        '${r.totalDescontoQuebra > 0 ? ', descontaram ${reais(r.totalDescontoQuebra)}' : ''}.',
                      ),
                    ),
                ],
                if (d.abastecimentos.isNotEmpty) ...[
                  const TituloSecao('Diesel'),
                  LinhaValor(
                    rotulo: d.variosCaminhoes ? 'Média dos caminhões' : 'Média do caminhão',
                    valor: mediaDiesel.media == null ? '—' : '${umaCasa(mediaDiesel.media!)} km/L',
                    detalhe: mediaDiesel.media == null
                        ? 'Precisa de dois tanques cheios para calcular'
                        : '${semCasas(mediaDiesel.km)} km rodados com ${umaCasa(mediaDiesel.litros)} L',
                  ),
                  LinhaValor(
                    rotulo: 'Litros abastecidos',
                    valor: '${umaCasa(litros)} L',
                    detalhe: litros > 0 ? 'Preço médio do litro ${reais(r.totalAbastecimento / litros)}' : null,
                  ),
                ],
                const SizedBox(height: 28),
                Nota(
                  'As contas seguem o combinado da ${dados.info.empresaNome.isEmpty ? 'empresa' : dados.info.empresaNome}: '
                  'comissão padrão de ${percentualTexto(dados.info.configuracao.percentualComissaoPadrao)}%, '
                  '${regras.gastosDescontamDoLiquido ? 'gastos por sua conta' : 'gastos pagos pela empresa'} e '
                  '${regras.valeDescontaDoLiquido ? 'vale descontando' : 'vale sem descontar'}.',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
