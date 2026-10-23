import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nucleo/nucleo.dart';
import 'package:visual/visual.dart';

import '../../componentes/comuns.dart';
import '../acertos/tela_acertos.dart';
import '../acesso/telas_acesso.dart';
import '../configuracoes/tela_configuracoes.dart';
import '../diesel/form_abastecimento.dart';
import '../fretes/form_frete.dart';
import '../gastos/tela_gastos.dart';
import '../paradas/tela_paradas.dart';
import '../relatorio/tela_relatorio.dart';
import '../vales/tela_vales.dart';
import '../viagens/form_viagem.dart';
import '../viagens/tela_viagens.dart';

/// Início: o resumo do período e o botão grande para lançar.
class TelaResumo extends ConsumerStatefulWidget {
  const TelaResumo({super.key});

  @override
  ConsumerState<TelaResumo> createState() => _TelaResumoState();
}

class _TelaResumoState extends ConsumerState<TelaResumo> {
  var _escolha = const EscolhaPeriodo(TipoPeriodo.mesAtual);

  void _lancar() {
    final dados = assistirDados(ref);
    final aberta = dados.viagemEmAndamento;
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
                if (!dados.porViagem)
                  opcao(Icons.local_shipping_outlined, 'Frete', 'Carga, adiantamento, saldo', const FormFrete())
                else if (aberta == null)
                  opcao(
                    Icons.add_link,
                    'Engatar carreta',
                    'Começo de uma viagem: placa, onde e quando',
                    const FormViagem(),
                  )
                else
                  opcao(
                    Icons.link_off,
                    'Desengatar carreta',
                    'Fim da viagem de ${placaTexto(aberta.placaCarreta)}',
                    FormViagem(modo: ModoViagem.desengatar, viagem: aberta),
                  ),
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
    final periodo = _escolha.periodo ?? calcularPeriodo(TipoPeriodo.mesAtual)!;
    final d = dados.dadosDoPeriodo(periodo);

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
          const AvisoConfirmarEmail(),
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
          // Parado agora: o botão de retomar fica à mão também aqui.
          if (dados.paradasAtivas && dados.paradaEmAndamento != null)
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: CartaoSituacaoParada(soQuandoParado: true),
            ),
          if (dados.porViagem && dados.viagemEmAndamento != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: CartaoViagemAberta(viagem: dados.viagemEmAndamento!),
            ),
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
