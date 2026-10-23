import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nucleo/nucleo.dart';
import 'package:visual/visual.dart';

import '../../componentes/comuns.dart';
import '../../dados/equipe.dart';
import '../../dados/provedores.dart';
import '../../relatorio/compartilhar.dart';

/// Viagens, vales, diesel e gastos de um motorista entre dois dias (datas
/// do celular, como o servidor faz com o horário de Brasília).
class ContaDoAcerto {
  ContaDoAcerto(Equipe e, String motoristaId, DateTime inicio, DateTime fim) {
    bool dentro(DateTime d) {
      final l = d.toLocal();
      final x = DateTime(l.year, l.month, l.day);
      return !x.isBefore(inicio) && !x.isAfter(fim);
    }

    final l = e.recorte(motoristaId: motoristaId);
    viagens = l.viagens.where((v) => dentro(v.engateEm)).toList()..sort((a, b) => a.engateEm.compareTo(b.engateEm));
    vales = l.vales.where((v) => dentro(v.data)).fold(0, (s, v) => s + v.valorCentavos);
    diesel = l.abastecimentos.where((a) => !a.pontoDePartida && dentro(a.data)).fold(0, (s, a) => s + a.valorCentavos);
    gastos = l.gastos.where((g) => dentro(g.data)).fold(0, (s, g) => s + g.valorCentavos);
  }

  late final List<Viagem> viagens;
  late final int vales;
  late final int diesel;
  late final int gastos;
}

/// O gestor fecha (ou corrige) o acerto do motorista do Baú ou do Sider:
/// escolhe o período, vê as viagens, lança a comissão e os descontos.
class TelaFazerAcerto extends ConsumerStatefulWidget {
  const TelaFazerAcerto({super.key, required this.motoristaId, this.acerto});

  final String motoristaId;

  /// Acerto já fechado que vai ser corrigido.
  final Acerto? acerto;

  @override
  ConsumerState<TelaFazerAcerto> createState() => _TelaFazerAcertoState();
}

class _LinhaDesconto {
  _LinhaDesconto({String descricao = '', int valor = 0})
    : descricao = TextEditingController(text: descricao),
      valor = TextEditingController(text: textoDinheiro(valor));
  final TextEditingController descricao;
  final TextEditingController valor;

  void dispose() {
    descricao.dispose();
    valor.dispose();
  }
}

class _TelaFazerAcertoState extends ConsumerState<TelaFazerAcerto> {
  late DateTime _inicio;
  late DateTime _fim;
  final _comissao = TextEditingController();
  final _observacao = TextEditingController();
  final _descontos = <_LinhaDesconto>[];
  String? _erroComissao;
  String? _erroDescontos;

  @override
  void initState() {
    super.initState();
    final e = ref.read(equipeProvider).requireValue;
    final hoje = ref.read(relogioProvider)();
    final a = widget.acerto;
    if (a != null) {
      _inicio = a.periodoInicio;
      _fim = a.periodoFim;
      _comissao.text = textoDinheiro(a.comissaoCentavos);
      _observacao.text = a.observacao ?? '';
      for (final d in a.descontos) {
        _descontos.add(_LinhaDesconto(descricao: d.descricao, valor: d.valorCentavos));
      }
    } else {
      // Começa no dia seguinte ao último acerto (ou no primeiro dia do mês).
      final ultimo = e.acertosDe(widget.motoristaId).firstOrNull;
      _inicio = ultimo != null
          ? DateTime(ultimo.periodoFim.year, ultimo.periodoFim.month, ultimo.periodoFim.day + 1)
          : DateTime(hoje.year, hoje.month, 1);
      _fim = DateTime(hoje.year, hoje.month, hoje.day);
      if (_fim.isBefore(_inicio)) _fim = _inicio;
    }
  }

  @override
  void dispose() {
    _comissao.dispose();
    _observacao.dispose();
    for (final d in _descontos) {
      d.dispose();
    }
    super.dispose();
  }

  List<DescontoAcerto> get _listaDescontos => [
    for (final d in _descontos)
      if (d.descricao.text.trim().isNotEmpty || lerCentavos(d.valor.text) > 0)
        DescontoAcerto(descricao: d.descricao.text.trim(), valorCentavos: lerCentavos(d.valor.text)),
  ];

  Future<void> _fechar() async {
    final e = ref.read(equipeProvider).requireValue;
    final descontos = _listaDescontos;
    setState(() {
      _erroComissao = _comissao.text.trim().isEmpty ? 'Lance a comissão (pode ser zero).' : null;
      _erroDescontos = descontos.any((d) => d.descricao.isEmpty || d.valorCentavos <= 0)
          ? 'Cada desconto precisa do motivo e do valor.'
          : null;
    });
    if (_fim.isBefore(_inicio)) {
      mostrarMensagem(context, 'Confira o período: o fim vem depois do começo.');
      return;
    }
    if (_erroComissao != null || _erroDescontos != null) return;
    final m = e.motorista(widget.motoristaId)!;
    final ok = await confirmar(
      context,
      titulo: widget.acerto == null ? 'Fechar o acerto de ${m.primeiroNome}?' : 'Salvar a correção?',
      texto:
          'Período de ${dataTexto(_inicio)} a ${dataTexto(_fim)}. ${m.primeiroNome} vê o acerto no app dele na '
          'próxima vez que o celular tiver internet.',
      botao: widget.acerto == null ? 'Fechar acerto' : 'Salvar',
    );
    if (!ok || !mounted) return;
    final navegador = Navigator.of(context);
    final feito = await executar(
      context,
      () => ref
          .read(equipeProvider.notifier)
          .fecharAcerto(
            id: widget.acerto?.id,
            motoristaId: widget.motoristaId,
            inicio: _inicio,
            fim: _fim,
            comissaoCentavos: lerCentavos(_comissao.text),
            descontos: descontos,
            observacao: _observacao.text,
          ),
      sucesso: widget.acerto == null ? 'Acerto fechado.' : 'Acerto corrigido.',
    );
    if (feito) navegador.pop();
  }

  @override
  Widget build(BuildContext context) {
    final e = assistirEquipe(ref);
    final m = e.motorista(widget.motoristaId);
    final cores = context.cores;
    if (m == null) return Scaffold(appBar: AppBar(), body: const SizedBox.shrink());
    final conta = ContaDoAcerto(e, m.id, _inicio, _fim);
    final regras = e.regras;
    final receber = calcularParaReceber(
      comissaoCentavos: lerCentavos(_comissao.text),
      descontos: [for (final d in _listaDescontos) if (d.valorCentavos > 0) d],
      valesCentavos: conta.vales,
      dieselCentavos: conta.diesel,
      gastosCentavos: conta.gastos,
      regras: regras,
    );

    return Scaffold(
      appBar: AppBar(title: Text(widget.acerto == null ? 'Acerto de ${m.primeiroNome}' : 'Corrigir acerto')),
      bottomNavigationBar: RodapeBotao(
        texto: widget.acerto == null ? 'Fechar acerto' : 'Salvar correção',
        aoTocar: _fechar,
      ),
      body: ListaCentral(
        largura: 760,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const TituloSecao('Período', espacoAcima: 4),
                Row(
                  children: [
                    Expanded(
                      child: CampoData(
                        rotulo: 'De',
                        valor: _inicio,
                        aoMudar: (d) => setState(() => _inicio = DateTime(d.year, d.month, d.day)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: CampoData(
                        rotulo: 'Até',
                        valor: _fim,
                        aoMudar: (d) => setState(() => _fim = DateTime(d.year, d.month, d.day)),
                      ),
                    ),
                  ],
                ),
                TituloSecao('Viagens (${conta.viagens.length})'),
                if (conta.viagens.isEmpty) const Nota('Nenhuma viagem com engate neste período.'),
                for (final v in conta.viagens)
                  LinhaValor(
                    rotulo: '${dataTexto(v.engateEm)}  ${v.rota}',
                    valor: plural(v.entregasQuantidade, 'entrega', 'entregas'),
                    detalhe: 'Carreta ${placaTexto(v.placaCarreta)}'
                        '${v.entregasCidades.isEmpty ? '' : '  ·  ${v.entregasCidades.join(', ')}'}',
                  ),
                const TituloSecao('Comissão e descontos'),
                Campo(
                  controle: _comissao,
                  rotulo: 'Comissão do período',
                  tipo: TipoCampo.dinheiro,
                  erro: _erroComissao,
                  ajuda: 'Valor em reais que o motorista ganha de comissão neste acerto.',
                  aoMudar: (_) => setState(() => _erroComissao = null),
                ),
                const SizedBox(height: 14),
                for (final d in _descontos) ...[
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 3,
                        child: Campo(
                          controle: d.descricao,
                          rotulo: 'Motivo do desconto',
                          aoMudar: (_) => setState(() => _erroDescontos = null),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        flex: 2,
                        child: Campo(
                          controle: d.valor,
                          rotulo: 'Valor',
                          tipo: TipoCampo.dinheiro,
                          aoMudar: (_) => setState(() => _erroDescontos = null),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Tirar este desconto',
                        icon: const Icon(Icons.close),
                        onPressed: () => setState(() {
                          _descontos.remove(d);
                          d.dispose();
                        }),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                ],
                if (_erroDescontos != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(_erroDescontos!, style: TextStyle(color: cores.negativo)),
                  ),
                Align(
                  alignment: Alignment.centerLeft,
                  child: OutlinedButton.icon(
                    onPressed: () => setState(() => _descontos.add(_LinhaDesconto())),
                    icon: const Icon(Icons.remove_circle_outline),
                    label: const Text('Pôr um desconto'),
                  ),
                ),
                const TituloSecao('O que o servidor soma no período'),
                LinhaValor(
                  rotulo: 'Vales',
                  valor: regras.valeDescontaDoLiquido ? '$menos ${reais(conta.vales)}' : reais(conta.vales),
                  detalhe: regras.valeDescontaDoLiquido ? 'Desconta do acerto' : 'Só histórico (regra da empresa)',
                ),
                LinhaValor(
                  rotulo: 'Diesel e gastos',
                  valor: regras.gastosDescontamDoLiquido
                      ? '$menos ${reais(conta.diesel + conta.gastos)}'
                      : reais(conta.diesel + conta.gastos),
                  detalhe:
                      'Diesel ${reais(conta.diesel)}  ·  gastos ${reais(conta.gastos)}  ·  '
                      '${regras.gastosDescontamDoLiquido ? 'descontam (regra da empresa)' : 'a empresa paga'}',
                ),
                const SizedBox(height: 10),
                Placa(
                  rotulo: receber < 0 ? 'O motorista fica devendo' : 'Para receber',
                  valor: reais(receber),
                  detalhe: '${dataTexto(_inicio)} a ${dataTexto(_fim)}',
                  tipo: receber < 0 ? TipoPlaca.vermelha : TipoPlaca.verde,
                  tamanhoValor: 40,
                ),
                const SizedBox(height: 14),
                Campo(controle: _observacao, rotulo: 'Observação', ajuda: 'Opcional. O motorista vê.'),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Um acerto já fechado: o que foi lançado, o PDF e a correção.
class TelaAcertoFechado extends ConsumerWidget {
  const TelaAcertoFechado({super.key, required this.acertoId});
  final String acertoId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final e = assistirEquipe(ref);
    final a = e.acerto(acertoId);
    final cores = context.cores;
    if (a == null) return Scaffold(appBar: AppBar(), body: const SizedBox.shrink());
    final m = e.motorista(a.motoristaId);
    final relatorio = e.relatorioDoAcerto(a);
    return Scaffold(
      appBar: AppBar(
        title: Text('Acerto de ${m?.primeiroNome ?? ''}'),
        actions: [
          IconButton(
            tooltip: 'Corrigir',
            icon: const Icon(Icons.edit_outlined),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => TelaFazerAcerto(motoristaId: a.motoristaId, acerto: a)),
            ),
          ),
          const SizedBox(width: 4),
        ],
      ),
      bottomNavigationBar: RodapeBotao(
        texto: 'PDF do acerto',
        icone: Icons.picture_as_pdf_outlined,
        aoTocar: () => executar(context, () => compartilharPdf(relatorio)),
      ),
      body: ListaCentral(
        largura: 760,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Placa(
                  rotulo: a.paraReceberCentavos < 0 ? 'O motorista fica devendo' : 'Para receber',
                  valor: reais(a.paraReceberCentavos),
                  detalhe: a.periodoTexto,
                  tipo: a.paraReceberCentavos < 0 ? TipoPlaca.vermelha : TipoPlaca.verde,
                  tamanhoValor: 40,
                ),
                const SizedBox(height: 10),
                LinhaValor(rotulo: 'Comissão', valor: '+ ${reais(a.comissaoCentavos)}', corValor: cores.positivo),
                for (final x in a.descontos)
                  LinhaValor(rotulo: x.descricao, valor: '$menos ${reais(x.valorCentavos)}', corValor: cores.negativo),
                LinhaValor(
                  rotulo: 'Vales',
                  valor: a.descontaVales ? '$menos ${reais(a.valesCentavos)}' : reais(a.valesCentavos),
                ),
                LinhaValor(
                  rotulo: 'Diesel e gastos',
                  valor: a.descontaGastos
                      ? '$menos ${reais(a.dieselCentavos + a.gastosCentavos)}'
                      : reais(a.dieselCentavos + a.gastosCentavos),
                  detalhe: 'Diesel ${reais(a.dieselCentavos)}  ·  gastos ${reais(a.gastosCentavos)}',
                ),
                if ((a.observacao ?? '').isNotEmpty) ...[const SizedBox(height: 8), Nota('Observação: ${a.observacao}')],
                if (a.fechadoEm != null) ...[
                  const SizedBox(height: 8),
                  Nota('Fechado em ${dataHoraTexto(a.fechadoEm!)} por ${e.nomeAutor(a.autorId)}.'),
                ],
                TituloSecao('Viagens do período (${relatorio.viagens.length})'),
                for (final v in relatorio.viagens)
                  LinhaValor(
                    rotulo: '${dataTexto(v.engateEm)}  ${v.rota}',
                    valor: plural(v.entregasQuantidade, 'entrega', 'entregas'),
                    detalhe: 'Carreta ${placaTexto(v.placaCarreta)}',
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Aba "Acertos" do motorista: fazer um novo e ver os fechados.
class ListaAcertos extends ConsumerWidget {
  const ListaAcertos({super.key, required this.motoristaId});
  final String motoristaId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final e = assistirEquipe(ref);
    final cores = context.cores;
    final lista = e.acertosDe(motoristaId);
    return ListaCentral(
      largura: 760,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
          child: Row(
            children: [
              const Expanded(
                child: Nota('Escolha o período, confira as viagens e lance a comissão e os descontos.'),
              ),
              const SizedBox(width: 8),
              FilledButton.icon(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => TelaFazerAcerto(motoristaId: motoristaId)),
                ),
                icon: const Icon(Icons.request_quote_outlined),
                label: const Text('Fazer acerto'),
              ),
            ],
          ),
        ),
        if (lista.isEmpty)
          const Padding(padding: EdgeInsets.fromLTRB(20, 16, 20, 0), child: Nota('Nenhum acerto fechado ainda.')),
        for (final a in lista)
          ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 2),
            title: Text(a.periodoTexto, style: estiloNumero(17, peso: FontWeight.w600)),
            subtitle: Text(
              '${plural(a.quantidadeViagens, 'viagem', 'viagens')}  ·  comissão ${reais(a.comissaoCentavos)}',
            ),
            trailing: Text(
              reais(a.paraReceberCentavos),
              style: estiloNumero(18, cor: a.paraReceberCentavos < 0 ? cores.negativo : cores.positivo),
            ),
            onTap: () =>
                Navigator.push(context, MaterialPageRoute(builder: (_) => TelaAcertoFechado(acertoId: a.id))),
          ),
      ],
    );
  }
}
