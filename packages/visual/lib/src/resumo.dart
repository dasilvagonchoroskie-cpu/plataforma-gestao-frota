import 'package:flutter/material.dart';
import 'package:nucleo/nucleo.dart';

import 'basicos.dart';
import 'placa_estrada.dart';
import 'tema.dart';

/// O resumo do período como o motorista vê no app dele: quanto tem para
/// receber, comissão, gastos, vales, a conta do caminhão e o diesel.
/// O painel do gestor usa o mesmo componente no "Ver como o motorista vê",
/// então os dois mostram sempre a mesma coisa.
class CorpoResumo extends StatelessWidget {
  const CorpoResumo({
    super.key,
    required this.dados,
    required this.todasAbastecidas,
    required this.descricao,
    required this.empresaNome,
    required this.percentualPadrao,
    this.textoVazio = 'Toque em "Lançar" para anotar fretes, abastecidas, gastos e vales. '
        'As contas aparecem aqui sozinhas.',
  });

  /// Lançamentos do período, já filtrados (montarDados).
  final DadosRelatorio dados;

  /// Todas as abastecidas (a média de cada linha olha o tanque anterior).
  final List<Abastecimento> todasAbastecidas;

  /// "outubro de 2026", "últimos 7 dias"...
  final String descricao;
  final String empresaNome;
  final double percentualPadrao;
  final String textoVazio;

  @override
  Widget build(BuildContext context) {
    final d = dados;
    final r = d.resultado;
    final regras = d.regras;
    final cores = context.cores;

    String detalheComissao;
    if (r.quantidadeFretes == 0) {
      detalheComissao = 'Nenhum frete no período';
    } else if (r.percentuaisDiferentes) {
      detalheComissao = 'Na média ${percentualTexto(r.percentualMedio)}% sobre ${reais(r.totalBaseComissao)}';
    } else {
      detalheComissao = '${percentualTexto(r.percentualMedio)}% sobre ${reais(r.totalBaseComissao)}';
    }

    final mediaDiesel = mediaDoPeriodo(d.abastecimentos, todasAbastecidas);
    final litros = d.abastecimentos.fold<double>(0, (s, a) => s + a.litros);
    final titulo = descricao.isEmpty ? '' : descricao[0].toUpperCase() + descricao.substring(1);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Placa(
          rotulo: r.liquido < 0 ? 'Você está devendo' : 'Você tem para receber',
          valor: reais(r.liquido),
          detalhe: titulo,
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
          Aviso(icone: Icons.edit_note, titulo: 'Nada lançado em $descricao', texto: textoVazio),
        ],
        if (!d.vazio) ...[
          TituloSecao(d.variosCaminhoes ? 'Conta dos caminhões' : 'Conta do caminhão'),
          const Nota('O que sobrou depois de pagar o diesel, os gastos e a comissão.'),
          const SizedBox(height: 6),
          if (r.fretesEmAberto > 0) ...[
            Aviso(
              icone: Icons.hourglass_bottom,
              titulo: r.fretesEmAberto == 1 ? '1 frete aguardando saldo' : '${r.fretesEmAberto} fretes aguardando saldo',
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
            corValor: r.sobraDoCaminhao >= 0 ? cores.positivo : (r.fretesEmAberto > 0 ? cores.atencao : cores.negativo),
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
          'As contas seguem o combinado da ${empresaNome.isEmpty ? 'empresa' : empresaNome}: '
          'comissão padrão de ${percentualTexto(percentualPadrao)}%, '
          '${regras.gastosDescontamDoLiquido ? 'gastos por sua conta' : 'gastos pagos pela empresa'} e '
          '${regras.valeDescontaDoLiquido ? 'vale descontando' : 'vale sem descontar'}.',
        ),
      ],
    );
  }
}
