import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nucleo/nucleo.dart';
import 'package:visual/visual.dart';

import '../../componentes/arquivo_dados.dart';
import '../../componentes/comuns.dart';
import '../../dados/equipe.dart';
import '../../dados/provedores.dart';
import '../caminhoes/detalhe_caminhao.dart';
import '../casca.dart';
import '../motoristas/detalhe_motorista.dart';

/// Painel: os números do período e a lista de motoristas com o último envio.
class TelaPainel extends ConsumerWidget {
  const TelaPainel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final e = assistirEquipe(ref);
    final escolha = ref.watch(periodoProvider);
    final periodo = escolha.periodoOuMes;
    final agora = ref.read(relogioProvider)();
    final d = e.relatorio(periodo);
    final r = d.resultado;
    final cores = context.cores;
    final alertas = e.alertas(agora);
    final media = mediaDoPeriodo(d.abastecimentos, e.abastecimentos);
    final litros = d.abastecimentos.fold<double>(0, (s, a) => s + a.litros);
    // Paradas (quando a empresa usa): quantos passaram do limite no período.
    final acimaDoLimite = !e.paradasAtivas
        ? const <String>[]
        : [
            for (final m in e.motoristas)
              if (e.resumoParadas(m.id, periodo, agora).acimaDoLimite.isNotEmpty) m.primeiroNome,
          ];
    final linhas = e.linhasMotoristas(periodo)
      ..sort((a, b) {
        if (a.motorista.ativo != b.motorista.ativo) return a.motorista.ativo ? -1 : 1;
        return b.resultado.totalFretes.compareTo(a.resultado.totalFretes);
      });

    return Scaffold(
      appBar: AppBar(
        title: Text(e.empresa.nome.isEmpty ? 'Painel' : e.empresa.nome),
        actions: acoesPadrao(context, ref),
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.read(equipeProvider.notifier).recarregar(),
        child: ListaCentral(
          children: [
            const SizedBox(height: 4),
            const FaixaPeriodo(),
            for (final a in alertas)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                child: _CartaoAlerta(alerta: a),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: GradeCartoes(
                larguraMinima: telaLarga(context) ? 220 : 165,
                cartoes: [
                  CartaoNumero(
                    rotulo: 'Faturamento',
                    valor: reais(r.totalFretes),
                    detalhe: '${plural(r.quantidadeFretes, 'frete', 'fretes')} · ${escolha.descricao}',
                    icone: Icons.trending_up,
                    destaque: true,
                  ),
                  CartaoNumero(
                    rotulo: 'Diesel',
                    valor: reais(r.totalAbastecimento),
                    detalhe: litros > 0
                        ? '${umaCasa(litros)} L · ${media.media == null ? 'média ainda sem tanque cheio' : '${umaCasa(media.media!)} km/L'}'
                        : 'Nenhuma abastecida',
                    icone: Icons.local_gas_station_outlined,
                  ),
                  CartaoNumero(
                    rotulo: 'Outros gastos',
                    valor: reais(r.totalGastos),
                    detalhe: plural(d.gastos.length, 'gasto', 'gastos'),
                    icone: Icons.receipt_long_outlined,
                  ),
                  CartaoNumero(
                    rotulo: 'Comissões',
                    valor: reais(r.comissaoDoCaminhao),
                    detalhe: r.quantidadeFretes == 0
                        ? 'Parte dos motoristas'
                        : 'Média de ${percentualTexto(r.totalBaseComissao > 0 ? r.comissaoDoCaminhao / r.totalBaseComissao * 100 : 0)}%',
                    icone: Icons.handshake_outlined,
                  ),
                  CartaoNumero(
                    rotulo: r.sobraDoCaminhao >= 0 ? 'Resultado' : 'Resultado (faltou)',
                    valor: reais(r.sobraDoCaminhao),
                    detalhe: 'Frete − diesel − gastos − comissões',
                    icone: Icons.savings_outlined,
                    cor: r.sobraDoCaminhao >= 0 ? cores.positivo : cores.negativo,
                  ),
                  CartaoNumero(
                    rotulo: 'Vales',
                    valor: reais(r.totalVale),
                    detalhe: plural(d.vales.length, 'vale', 'vales'),
                    icone: Icons.payments_outlined,
                  ),
                  CartaoNumero(
                    rotulo: 'A pagar aos motoristas',
                    valor: reais(r.liquido),
                    detalhe: e.regras.valeDescontaDoLiquido ? 'Comissões menos vales' : 'Comissões',
                    icone: Icons.account_balance_wallet_outlined,
                  ),
                  CartaoNumero(
                    rotulo: 'Saldo a receber',
                    valor: reais(r.contratadoEmAberto),
                    detalhe: r.fretesEmAberto == 0
                        ? 'Nenhum frete esperando saldo'
                        : '${plural(r.fretesEmAberto, 'frete', 'fretes')} sem pagamento',
                    icone: Icons.hourglass_bottom,
                    cor: r.fretesEmAberto > 0 ? cores.atencao : null,
                  ),
                  if (e.paradasAtivas)
                    CartaoNumero(
                      rotulo: 'Paradas',
                      valor: acimaDoLimite.isEmpty ? 'Dentro do limite' : plural(acimaDoLimite.length, 'motorista', 'motoristas'),
                      detalhe: acimaDoLimite.isEmpty
                          ? 'Nenhum intervalo sem descanso acima do limite'
                          : 'Acima do limite: ${acimaDoLimite.join(', ')}',
                      icone: Icons.pause_circle_outline,
                      cor: acimaDoLimite.isEmpty ? null : cores.negativo,
                      aoTocar: () => ref.read(secaoProvider.notifier).ir(Secao.paradas),
                    ),
                ],
              ),
            ),
            const Padding(padding: EdgeInsets.symmetric(horizontal: 16), child: TituloSecao('Motoristas')),
            if (linhas.isEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
                child: Aviso(
                  icone: Icons.person_add_alt,
                  titulo: 'Nenhum motorista ainda',
                  texto:
                      'Passe o código da empresa (${e.empresa.codigoEntrada ?? '—'}) para os motoristas. '
                      'Eles instalam o app Frota Motorista, criam a conta, digitam o código e você aprova aqui.',
                ),
              ),
            for (final l in linhas) _LinhaMotoristaPainel(linha: l, agora: agora),
            const Padding(padding: EdgeInsets.symmetric(horizontal: 16), child: TituloSecao('Caminhões')),
            for (final c in e.caminhoesAtivos) _LinhaCaminhaoPainel(caminhaoId: c.id),
            if (e.caminhoesAtivos.isEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
                child: Text(
                  'Nenhum caminhão cadastrado. Cadastre em Caminhões.',
                  style: TextStyle(color: cores.textoFraco),
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
              child: Nota(
                'Atualizado ${quandoTexto(e.carregadoEm, agora)}. Os números seguem as regras de acerto '
                'da empresa e são os mesmos do app de cada motorista.',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CartaoAlerta extends ConsumerWidget {
  const _CartaoAlerta({required this.alerta});
  final Alerta alerta;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final a = alerta;
    final icone = switch (a.tipo) {
      TipoAlerta.pedidos => Icons.person_add_alt_1,
      TipoAlerta.caminhaoNaoConfirmado => Icons.fact_check_outlined,
      TipoAlerta.doisMotoristas => Icons.group_outlined,
      TipoAlerta.semEnvio => Icons.signal_wifi_statusbar_connected_no_internet_4_outlined,
      TipoAlerta.suspensa => Icons.pause_circle_outline,
      TipoAlerta.exclusaoPedida => Icons.delete_outline,
      TipoAlerta.fimDoAcesso => Icons.lock_clock_outlined,
    };
    VoidCallback? acao;
    if (a.tipo == TipoAlerta.pedidos) acao = () => ref.read(secaoProvider.notifier).ir(Secao.motoristas);
    if (a.caminhaoId != null) {
      acao = () =>
          Navigator.push(context, MaterialPageRoute(builder: (_) => TelaDetalheCaminhao(caminhaoId: a.caminhaoId!)));
    }
    if (a.motoristaId != null) {
      acao = () =>
          Navigator.push(context, MaterialPageRoute(builder: (_) => TelaDetalheMotorista(motoristaId: a.motoristaId!)));
    }
    // Exclusão chegando: o botão do PDF fica no próprio aviso.
    final pdf = switch (a.tipo) {
      TipoAlerta.exclusaoPedida => () => baixarDadosMotorista(context, ref, a.motoristaId!),
      TipoAlerta.fimDoAcesso => () => baixarDadosEmpresa(context, ref),
      _ => null,
    };
    final cartao = InkWell(
      onTap: acao,
      borderRadius: BorderRadius.circular(12),
      child: Aviso(icone: icone, titulo: a.titulo, texto: a.texto),
    );
    if (pdf == null) return cartao;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        cartao,
        TextButton.icon(onPressed: pdf, icon: const Icon(Icons.picture_as_pdf_outlined), label: const Text('Baixar PDF')),
      ],
    );
  }
}

class _LinhaMotoristaPainel extends ConsumerWidget {
  const _LinhaMotoristaPainel({required this.linha, required this.agora});
  final LinhaMotorista linha;
  final DateTime agora;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cores = context.cores;
    final m = linha.motorista;
    final r = linha.resultado;
    final largo = telaLarga(context);
    final envio = quandoTexto(linha.ultimoEnvio, agora);
    final atrasado = linha.ultimoEnvio != null && agora.difference(linha.ultimoEnvio!).inDays >= 3;

    final info = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Flexible(
              child: Text(
                m.nome,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
              ),
            ),
            if (!m.ativo) ...[const SizedBox(width: 8), const Etiqueta('Desligado', atencao: false)],
          ],
        ),
        const SizedBox(height: 3),
        Text(
          '${linha.caminhao == null ? 'sem caminhão' : placaTexto(linha.caminhao!.placa)}  ·  último envio $envio',
          style: TextStyle(fontSize: 14, color: atrasado ? cores.atencao : cores.textoFraco),
        ),
      ],
    );

    return InkWell(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => TelaDetalheMotorista(motoristaId: m.id))),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
        child: linha.porViagem
            ? Row(
                children: [
                  Expanded(flex: 4, child: info),
                  if (largo) ...[
                    Expanded(flex: 2, child: _Coluna('Viagens', '${linha.viagens}')),
                    Expanded(flex: 3, child: _Coluna('Entregas', '${linha.entregas}')),
                    Expanded(
                      flex: 6,
                      child: _Coluna(
                        'Último acerto',
                        linha.ultimoAcerto == null ? '—' : reais(linha.ultimoAcerto!.paraReceberCentavos),
                      ),
                    ),
                    const Icon(Icons.chevron_right),
                  ] else ...[
                    const SizedBox(width: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text('${linha.viagens}', style: estiloNumero(18)),
                        Text(
                          linha.viagens == 1 ? 'viagem' : 'viagens',
                          style: TextStyle(fontSize: 13, color: cores.textoFraco),
                        ),
                      ],
                    ),
                  ],
                ],
              )
            : largo
            ? Row(
                children: [
                  Expanded(flex: 4, child: info),
                  Expanded(flex: 2, child: _Coluna('Fretes', '${r.quantidadeFretes}')),
                  Expanded(flex: 3, child: _Coluna('Faturamento', reais(r.totalFretes))),
                  Expanded(flex: 3, child: _Coluna('Comissão', reais(r.comissao))),
                  Expanded(
                    flex: 3,
                    child: _Coluna('A receber', reais(r.liquido), cor: r.liquido < 0 ? cores.negativo : null),
                  ),
                  const Icon(Icons.chevron_right),
                ],
              )
            : Row(
                children: [
                  Expanded(child: info),
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(reais(r.totalFretes), style: estiloNumero(18)),
                      Text(
                        plural(r.quantidadeFretes, 'frete', 'fretes'),
                        style: TextStyle(fontSize: 13, color: cores.textoFraco),
                      ),
                    ],
                  ),
                ],
              ),
      ),
    );
  }
}

class _Coluna extends StatelessWidget {
  const _Coluna(this.rotulo, this.valor, {this.cor});
  final String rotulo;
  final String valor;
  final Color? cor;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.end,
    children: [
      Text(rotulo, style: TextStyle(fontSize: 12.5, color: context.cores.textoFraco)),
      Text(valor, style: estiloNumero(17, cor: cor)),
    ],
  );
}

class _LinhaCaminhaoPainel extends ConsumerWidget {
  const _LinhaCaminhaoPainel({required this.caminhaoId});
  final String caminhaoId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final e = assistirEquipe(ref);
    final c = e.caminhao(caminhaoId)!;
    final periodo = ref.watch(periodoProvider).periodoOuMes;
    final d = e.relatorio(periodo, caminhaoId: c.id);
    final media = mediaDoPeriodo(d.abastecimentos, e.abastecimentos).media;
    final km = e.kmRodados(c.id, periodo);
    final quem = e.motoristasNoCaminhao(c.id).map((m) => m.primeiroNome).join(', ');
    final cores = context.cores;
    return InkWell(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => TelaDetalheCaminhao(caminhaoId: c.id))),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 10),
        child: Row(
          children: [
            // No celular a placa fica menor para sobrar lugar para o texto.
            PlacaVeiculo(c.placa, tamanho: telaLarga(context) ? 16 : 12),
            SizedBox(width: telaLarga(context) ? 14 : 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    quem.isEmpty ? 'Sem motorista agora' : quem,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                  Text(
                    [
                      if (km > 0) '${semCasas(km)} km',
                      media == null ? 'média —' : '${umaCasa(media)} km/L',
                      if (!c.confirmado) 'para conferir',
                    ].join('  ·  '),
                    style: TextStyle(fontSize: 14, color: c.confirmado ? cores.textoFraco : cores.atencao),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  reais(d.resultado.sobraDoCaminhao),
                  style: estiloNumero(17, cor: d.resultado.sobraDoCaminhao < 0 ? cores.negativo : cores.positivo),
                ),
                Text('resultado', style: TextStyle(fontSize: 12.5, color: cores.textoFraco)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
