import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nucleo/nucleo.dart';
import 'package:visual/visual.dart';

import '../../componentes/comuns.dart';
import '../../dados/equipe.dart';
import '../../dados/modelos.dart';
import '../../dados/provedores.dart';

String _maiuscula(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

String _unidade(String campo) => switch (campo) {
  'peso_carga_kg' || 'peso_descarga_kg' => 'kg',
  'litros' => 'L',
  'km_odometro' => 'km',
  _ => '',
};

/// Valor de um campo do jeito que aparece na tela.
String textoDoCampo(String campo, TipoAjuste tipo, Object? v, Equipe e) {
  if (v == null || (v is String && v.trim().isEmpty)) return '—';
  switch (tipo) {
    case TipoAjuste.texto:
      return v.toString();
    case TipoAjuste.data:
      return dataTexto(lerData(v).toLocal());
    case TipoAjuste.centavos:
      return reais(lerInt(v));
    case TipoAjuste.numero:
      final n = lerDouble(v);
      final casas = campo == 'litros' ? 2 : 0;
      return '${numeroBr(n, casas)} ${_unidade(campo)}'.trim();
    case TipoAjuste.percentual:
      return '${percentualTexto(lerDouble(v))}%';
    case TipoAjuste.logico:
      final b = lerBool(v);
      if (campo == 'tanque_cheio') return b ? 'Encheu o tanque' : 'Não encheu';
      if (campo == 'comissao_sobre_bruto') return b ? 'Frete + pedágio' : 'Só o frete';
      return b ? 'Sim' : 'Não';
    case TipoAjuste.caminhao:
      final p = e.placa(v.toString());
      return p.isEmpty ? '—' : placaTexto(p);
    case TipoAjuste.categoria:
      return e.nomeCategoria(v.toString());
  }
}

/// Um lançamento do motorista, com cada campo e o histórico de correções.
/// O gestor nunca muda o original: cada correção é um ajuste com motivo.
class TelaDetalheLancamento extends ConsumerWidget {
  const TelaDetalheLancamento({super.key, required this.tabela, required this.id});

  final String tabela;
  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final e = assistirEquipe(ref);
    final cores = context.cores;
    final m = e.bruto(tabela, id);
    final titulo = nomesDasTabelas[tabela] ?? 'Lançamento';
    if (m == null) {
      return Scaffold(
        appBar: AppBar(title: Text(titulo)),
        body: const EstadoVazio(
          icone: Icons.search_off,
          titulo: 'Lançamento não encontrado',
          texto: 'Ele pode ter sido apagado pelo motorista. Atualize a tela.',
        ),
      );
    }
    final ajustados = lerLista(m['campos_ajustados']).toSet();
    final campos = camposDe(tabela);
    final historico = e.ajustesDe(tabela, id);
    final motoristaId = '${m['motorista_id'] ?? ''}';

    Widget? resumoFrete;
    if (tabela == 'fretes') {
      final f = Frete.deMapa(m);
      resumoFrete = Card(
        elevation: 0,
        margin: const EdgeInsets.fromLTRB(16, 4, 16, 8),
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: Column(
            children: [
              LinhaValor(
                rotulo: 'Frete que caiu na conta',
                valor: reais(f.freteRealCentavos),
                detalhe: 'Adiantamento + saldo',
              ),
              LinhaValor(
                rotulo: 'Contratado',
                valor: reais(f.valorContratadoCentavos),
                detalhe: 'Peso × valor da tonelada',
              ),
              LinhaValor(
                rotulo: 'Comissão do motorista',
                valor: reais(f.minhaParteCentavos),
                detalhe: '${percentualTexto(f.percentualComissao)}% sobre ${reais(f.baseComissaoCentavos)}',
              ),
              if (f.quebraKg != null)
                LinhaValor(
                  rotulo: 'Quebra',
                  valor: '${semCasas(f.quebraKg!)} kg',
                  detalhe: 'Vale ${reais(f.valorQuebraIntegralCentavos)}',
                ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text(titulo), actions: const [BotaoAtualizar(), SizedBox(width: 4)]),
      body: ListaCentral(
        largura: 760,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
            child: Text(
              [
                e.nomeMotorista(motoristaId),
                if (m['criado_no_aparelho_em'] != null)
                  'lançado em ${dataHoraTexto(lerData(m['criado_no_aparelho_em']).toLocal())}',
              ].join('  ·  '),
              style: TextStyle(fontSize: 15, color: cores.textoFraco),
            ),
          ),
          if (ajustados.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: Aviso(
                icone: Icons.edit_note,
                titulo: 'Corrigido pela gestão',
                texto:
                    '${_maiuscula(textoCamposAjustados(ajustados.toList()..sort()))}. '
                    'O motorista vê o valor corrigido e não consegue mais mudar este lançamento.',
              ),
            ),
          ?resumoFrete,
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 12, 20, 4),
            child: Text(
              'Toque em um campo para corrigir. O valor do motorista fica guardado no histórico.',
              style: TextStyle(fontSize: 14.5),
            ),
          ),
          for (final c in campos.entries)
            ListTile(
              title: Text(_maiuscula(nomeDoCampo(c.key)), style: TextStyle(fontSize: 14, color: cores.textoFraco)),
              subtitle: Text(
                textoDoCampo(c.key, c.value, m[c.key], e),
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                  color: ajustados.contains(c.key) ? cores.atencao : Theme.of(context).colorScheme.onSurface,
                ),
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (ajustados.contains(c.key)) const Etiqueta('Corrigido'),
                  const SizedBox(width: 8),
                  const Icon(Icons.edit_outlined),
                ],
              ),
              onTap: () => showDialog<void>(
                context: context,
                builder: (_) =>
                    FormAjuste(tabela: tabela, registroId: id, campo: c.key, tipo: c.value, atual: m[c.key]),
              ),
            ),
          const Padding(padding: EdgeInsets.symmetric(horizontal: 16), child: TituloSecao('Histórico de correções')),
          if (historico.isEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
              child: Text(
                'Nenhuma correção. Está como o motorista lançou.',
                style: TextStyle(color: cores.textoFraco, fontSize: 15),
              ),
            ),
          for (final a in historico)
            ListTile(
              leading: const Icon(Icons.history),
              title: Text(
                '${_maiuscula(nomeDoCampo(a.campo))}: '
                '${textoDoCampo(a.campo, campos[a.campo] ?? TipoAjuste.texto, a.valorAntigo, e)} para '
                '${textoDoCampo(a.campo, campos[a.campo] ?? TipoAjuste.texto, a.valorNovo, e)}',
                style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w600),
              ),
              subtitle: Text('"${a.motivo}"  ·  ${e.nomeAutor(a.autorId)}, ${dataHoraTexto(a.criadoEm.toLocal())}'),
            ),
        ],
      ),
    );
  }
}

/// Janela para corrigir um campo: novo valor e o motivo (obrigatório).
class FormAjuste extends ConsumerStatefulWidget {
  const FormAjuste({
    super.key,
    required this.tabela,
    required this.registroId,
    required this.campo,
    required this.tipo,
    required this.atual,
  });

  final String tabela;
  final String registroId;
  final String campo;
  final TipoAjuste tipo;
  final Object? atual;

  @override
  ConsumerState<FormAjuste> createState() => _FormAjusteState();
}

class _FormAjusteState extends ConsumerState<FormAjuste> {
  final _texto = TextEditingController();
  final _motivo = TextEditingController();
  late DateTime _data;
  late bool _logico;
  String? _escolha;
  String? _erro;

  @override
  void initState() {
    super.initState();
    final v = widget.atual;
    _data = v == null ? DateTime.now() : lerData(v).toLocal();
    _logico = lerBool(v);
    _escolha = v?.toString();
    switch (widget.tipo) {
      case TipoAjuste.texto:
        _texto.text = v?.toString() ?? '';
      case TipoAjuste.centavos:
        _texto.text = textoDinheiro(lerInt(v));
      case TipoAjuste.numero:
        _texto.text = widget.campo == 'litros' ? textoDecimal(lerDouble(v)) : textoInteiro(lerDouble(v));
      case TipoAjuste.percentual:
        _texto.text = textoDecimal(lerDouble(v), casas: 1);
      default:
        break;
    }
  }

  @override
  void dispose() {
    _texto.dispose();
    _motivo.dispose();
    super.dispose();
  }

  Object? _valorNovo() {
    switch (widget.tipo) {
      case TipoAjuste.texto:
        return _texto.text.trim();
      case TipoAjuste.centavos:
        return lerCentavos(_texto.text);
      case TipoAjuste.numero:
        return lerNumero(_texto.text);
      case TipoAjuste.percentual:
        final p = lerNumero(_texto.text);
        return p > 100 ? null : p;
      case TipoAjuste.logico:
        return _logico;
      case TipoAjuste.data:
        // Mantém a hora original; muda só o dia.
        final orig = widget.atual == null ? DateTime.now() : lerData(widget.atual).toLocal();
        return DateTime(_data.year, _data.month, _data.day, orig.hour, orig.minute).toUtc().toIso8601String();
      case TipoAjuste.caminhao:
      case TipoAjuste.categoria:
        return _escolha;
    }
  }

  Future<void> _salvar() async {
    final valor = _valorNovo();
    if (valor == null || (valor is String && valor.isEmpty && widget.tipo != TipoAjuste.texto)) {
      setState(
        () =>
            _erro = widget.tipo == TipoAjuste.percentual ? 'A comissão fica entre 0 e 100%.' : 'Informe o valor certo.',
      );
      return;
    }
    if (_motivo.text.trim().length < 3) {
      setState(() => _erro = 'Escreva o motivo da correção (ex.: "conferido no recibo").');
      return;
    }
    final navegador = Navigator.of(context);
    final ok = await executar(
      context,
      () => ref
          .read(equipeProvider.notifier)
          .ajustar(
            tabela: widget.tabela,
            registroId: widget.registroId,
            campo: widget.campo,
            valorNovo: valor,
            motivo: _motivo.text,
          ),
      sucesso: 'Correção salva. O motorista recebe na próxima vez que o app dele conectar.',
    );
    if (ok) navegador.pop();
  }

  Widget _entrada(Equipe e) {
    switch (widget.tipo) {
      case TipoAjuste.texto:
        return Campo(controle: _texto, rotulo: 'Valor certo', autofoco: true);
      case TipoAjuste.centavos:
        return Campo(controle: _texto, rotulo: 'Valor certo', tipo: TipoCampo.dinheiro, dica: '0,00', autofoco: true);
      case TipoAjuste.numero:
        return Campo(
          controle: _texto,
          rotulo: 'Valor certo',
          tipo: widget.campo == 'litros' ? TipoCampo.decimal : TipoCampo.inteiro,
          sufixo: _unidade(widget.campo),
          autofoco: true,
        );
      case TipoAjuste.percentual:
        return Campo(controle: _texto, rotulo: 'Comissão certa', tipo: TipoCampo.decimal, sufixo: '%', autofoco: true);
      case TipoAjuste.logico:
        return widget.campo == 'tanque_cheio'
            ? EscolhaDupla(
                valor: _logico,
                textoSim: 'Encheu',
                textoNao: 'Não encheu',
                aoMudar: (v) => setState(() => _logico = v),
              )
            : EscolhaDupla(
                valor: _logico,
                textoSim: 'Frete + pedágio',
                textoNao: 'Só o frete',
                aoMudar: (v) => setState(() => _logico = v),
              );
      case TipoAjuste.data:
        return CampoData(rotulo: 'Data certa', valor: _data, aoMudar: (d) => setState(() => _data = d));
      case TipoAjuste.caminhao:
        return Escolha<String>(
          rotulo: 'Caminhão certo',
          valor: _escolha,
          largura: double.infinity,
          itens: {
            for (final c in e.caminhoes)
              c.id: '${placaTexto(c.placa)}${c.numeroFrota == null ? '' : '  ·  frota ${c.numeroFrota}'}',
          },
          aoMudar: (v) => setState(() => _escolha = v),
        );
      case TipoAjuste.categoria:
        return Escolha<String>(
          rotulo: 'Categoria certa',
          valor: _escolha,
          largura: double.infinity,
          itens: {for (final c in e.categorias) c.id: c.nome},
          aoMudar: (v) => setState(() => _escolha = v),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final e = assistirEquipe(ref);
    return AlertDialog(
      title: Text('Corrigir ${nomeDoCampo(widget.campo)}'),
      scrollable: true,
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Agora: ${textoDoCampo(widget.campo, widget.tipo, widget.atual, e)}',
              style: TextStyle(fontSize: 15, color: context.cores.textoFraco),
            ),
            const SizedBox(height: 14),
            _entrada(e),
            const SizedBox(height: 14),
            Campo(
              controle: _motivo,
              rotulo: 'Motivo da correção',
              dica: 'Ex.: conferido no recibo',
              acaoTeclado: TextInputAction.done,
            ),
            if (_erro != null) ...[
              const SizedBox(height: 10),
              Text(_erro!, style: TextStyle(color: context.cores.negativo, fontSize: 14.5)),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
        FilledButton(onPressed: _salvar, child: const Text('Salvar correção')),
      ],
    );
  }
}
