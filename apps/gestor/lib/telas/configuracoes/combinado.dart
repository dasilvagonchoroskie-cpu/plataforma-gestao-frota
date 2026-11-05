import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nucleo/nucleo.dart';
import 'package:visual/visual.dart';

import '../../componentes/comuns.dart';
import '../../dados/modelos.dart';
import '../../dados/provedores.dart';

/// O que o dono ou o gestor responde sobre como o motorista ganha (pedido de
/// 05/11/2026): comissão, salário fixo ou fixo + %; a porcentagem é sobre o
/// frete cheio ou o que caiu na conta, com ou sem o pedágio.
class CombinadoEditavel {
  CombinadoEditavel(ConfiguracaoEmpresa c)
    : forma = c.formaDeGanhar,
      percentual = TextEditingController(text: textoDecimal(c.percentualComissaoPadrao)),
      fixo = TextEditingController(text: textoDinheiro(c.salarioFixoCentavos)),
      sobreBruto = c.comissaoSobreBrutoPadrao,
      comPedagio = c.comissaoComPedagioPadrao;

  FormaDeGanhar forma;
  final TextEditingController percentual;
  final TextEditingController fixo;
  bool sobreBruto;
  bool comPedagio;

  double get percentualEscolhido => forma == FormaDeGanhar.fixo ? 0 : lerNumero(percentual.text);
  int get fixoEscolhido => forma == FormaDeGanhar.comissao ? 0 : lerCentavos(fixo.text);

  /// Mensagem do que falta (nulo = pode salvar).
  String? get erro {
    final p = percentualEscolhido;
    if (forma != FormaDeGanhar.fixo && (p <= 0 || p > 100)) return 'A porcentagem fica entre 0 e 100%.';
    if (forma != FormaDeGanhar.comissao && fixoEscolhido <= 0) return 'Informe o salário fixo por mês.';
    return null;
  }

  /// Resumo em uma linha ("Fixo R$ 3.000,00 + 3% do frete cheio, com pedágio").
  static String texto(ConfiguracaoEmpresa c) {
    final pct = '${percentualTexto(c.percentualComissaoPadrao)}% '
        '${c.comissaoSobreBrutoPadrao ? 'do frete cheio' : 'do que caiu na conta'}'
        '${c.comissaoComPedagioPadrao ? ', com pedágio' : ', sem pedágio'}';
    return switch (c.formaDeGanhar) {
      FormaDeGanhar.comissao => 'Comissão de $pct',
      FormaDeGanhar.fixo => 'Salário fixo de ${reais(c.salarioFixoCentavos)} por mês',
      FormaDeGanhar.fixoMaisComissao => 'Fixo de ${reais(c.salarioFixoCentavos)} por mês + $pct',
    };
  }

  void dispose() {
    percentual.dispose();
    fixo.dispose();
  }
}

/// As perguntas do combinado (usadas na regra da empresa e na de um motorista).
class PerguntasDoCombinado extends StatelessWidget {
  const PerguntasDoCombinado({super.key, required this.combinado, required this.aoMudar});

  final CombinadoEditavel combinado;
  final VoidCallback aoMudar;

  @override
  Widget build(BuildContext context) {
    final c = combinado;
    Widget pergunta(String texto) => Padding(
      padding: const EdgeInsets.only(top: 22, bottom: 8),
      child: Text(texto, style: const TextStyle(fontSize: 16.5, fontWeight: FontWeight.w600)),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        pergunta('Como o motorista ganha'),
        for (final f in FormaDeGanhar.values)
          OpcaoEscolha<FormaDeGanhar>(
            valor: f,
            escolhido: c.forma,
            titulo: f.rotulo,
            descricao: f.explicacao,
            aoEscolher: (v) {
              c.forma = v;
              aoMudar();
            },
          ),
        if (c.forma != FormaDeGanhar.comissao) ...[
          const SizedBox(height: 12),
          Campo(
            controle: c.fixo,
            rotulo: 'Salário fixo por mês',
            tipo: TipoCampo.dinheiro,
            ajuda: 'Num pedaço do mês, as contas usam a parte dos dias.',
            aoMudar: (_) => aoMudar(),
          ),
        ],
        if (c.forma != FormaDeGanhar.fixo) ...[
          const SizedBox(height: 12),
          Campo(
            controle: c.percentual,
            rotulo: c.forma == FormaDeGanhar.fixoMaisComissao ? 'Porcentagem dos fretes dele' : 'Comissão de cada frete',
            tipo: TipoCampo.decimal,
            sufixo: '%',
            ajuda: 'O motorista pode mudar em cada frete. Fretes já lançados não mudam.',
            aoMudar: (_) => aoMudar(),
          ),
          pergunta('A porcentagem é sobre'),
          OpcaoEscolha<bool>(
            valor: true,
            escolhido: c.sobreBruto,
            titulo: 'O frete cheio',
            descricao: 'Peso descarregado vezes a tonelada, ou o valor fechado. Antes dos descontos da transportadora.',
            aoEscolher: (v) {
              c.sobreBruto = v;
              aoMudar();
            },
          ),
          OpcaoEscolha<bool>(
            valor: false,
            escolhido: c.sobreBruto,
            titulo: 'O que caiu na conta',
            descricao: 'Adiantamento mais saldo, já com os descontos.',
            aoEscolher: (v) {
              c.sobreBruto = v;
              aoMudar();
            },
          ),
          pergunta('E o pedágio (cartão ou tag)?'),
          OpcaoEscolha<bool>(
            valor: true,
            escolhido: c.comPedagio,
            titulo: 'Entra na conta da porcentagem',
            aoEscolher: (v) {
              c.comPedagio = v;
              aoMudar();
            },
          ),
          OpcaoEscolha<bool>(
            valor: false,
            escolhido: c.comPedagio,
            titulo: 'Não entra',
            descricao: 'A porcentagem é só sobre o frete.',
            aoEscolher: (v) {
              c.comPedagio = v;
              aoMudar();
            },
          ),
        ],
      ],
    );
  }
}

/// Combinado de um motorista: o padrão da empresa ou um só para ele.
class TelaCombinadoMotorista extends ConsumerStatefulWidget {
  const TelaCombinadoMotorista({super.key, required this.motoristaId});

  final String motoristaId;

  @override
  ConsumerState<TelaCombinadoMotorista> createState() => _TelaCombinadoMotoristaState();
}

class _TelaCombinadoMotoristaState extends ConsumerState<TelaCombinadoMotorista> {
  late final _e = ref.read(equipeProvider).requireValue;
  late final Motorista _m = _e.motorista(widget.motoristaId)!;
  late bool _proprio = _m.temCombinadoProprio;
  late final _c = CombinadoEditavel(_e.combinadoDe(_m));
  String? _erro;

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  Future<void> _salvar() async {
    final erro = _proprio ? _c.erro : null;
    if (erro != null) return setState(() => _erro = erro);
    final navegador = Navigator.of(context);
    final ok = await executar(
      context,
      () => ref.read(equipeProvider.notifier).salvarCombinado(
        _m.id,
        _proprio
            ? {
                'percentual_comissao': _c.percentualEscolhido,
                'comissao_sobre_bruto': _c.sobreBruto,
                'comissao_com_pedagio': _c.comPedagio,
                'salario_fixo_centavos': _c.fixoEscolhido,
              }
            : const {},
      ),
      sucesso: 'Combinado salvo. O app dele recebe na próxima conexão.',
    );
    if (ok) navegador.pop();
  }

  @override
  Widget build(BuildContext context) {
    final cores = context.cores;
    return Scaffold(
      appBar: AppBar(title: Text('Como ${_m.primeiroNome} ganha')),
      body: ListaCentral(
        largura: 620,
        padding: const EdgeInsets.fromLTRB(0, 8, 0, 120),
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                OpcaoEscolha<bool>(
                  valor: false,
                  escolhido: _proprio,
                  titulo: 'O padrão da empresa',
                  descricao: CombinadoEditavel.texto(_e.empresa.configuracao),
                  aoEscolher: (v) => setState(() => _proprio = v),
                ),
                OpcaoEscolha<bool>(
                  valor: true,
                  escolhido: _proprio,
                  titulo: 'Um combinado só para ele',
                  descricao: 'Para o motorista que acertou diferente com o patrão.',
                  aoEscolher: (v) => setState(() => _proprio = v),
                ),
                if (_proprio) PerguntasDoCombinado(combinado: _c, aoMudar: () => setState(() => _erro = null)),
                if (_erro != null) ...[
                  const SizedBox(height: 10),
                  Text(_erro!, style: TextStyle(color: cores.negativo)),
                ],
                const SizedBox(height: 12),
                const Nota('Vale para os fretes novos e para o resumo dele. Fretes já lançados guardam a comissão que tinham.'),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: RodapeBotao(texto: 'Salvar', aoTocar: _salvar),
    );
  }
}
