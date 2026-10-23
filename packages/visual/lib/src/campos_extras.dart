import 'package:flutter/material.dart';
import 'package:nucleo/nucleo.dart';

import 'basicos.dart';
import 'campos.dart';
import 'tema.dart';

/// Os campos novos que a Plataforma criou numa modalidade (ficam em
/// "extras"). Cada tipo abre o teclado e o seletor certos. Campo apagado
/// fica como "" (para a mudança chegar na nuvem).
class CamposExtras extends StatefulWidget {
  const CamposExtras({
    super.key,
    required this.campos,
    required this.valores,
    required this.aoMudar,
    this.erros = const {},
    this.sugestoesCidades = const [],
  });

  final List<CampoModalidade> campos;
  final Map<String, Object?> valores;
  final ValueChanged<Map<String, Object?>> aoMudar;
  final Map<String, String> erros;
  final List<String> sugestoesCidades;

  @override
  State<CamposExtras> createState() => _CamposExtrasState();
}

class _CamposExtrasState extends State<CamposExtras> {
  final _controles = <String, TextEditingController>{};

  static const _deTexto = {
    TiposCampo.texto, TiposCampo.cidade, TiposCampo.numero, TiposCampo.inteiro, TiposCampo.dinheiro,
  };

  String _textoInicial(CampoModalidade c) {
    final v = widget.valores[c.chave];
    if (extraVazio(v)) return '';
    return switch (c.tipo) {
      TiposCampo.dinheiro => textoDinheiro(lerInt(v)),
      TiposCampo.inteiro => textoInteiro(lerDouble(v)),
      TiposCampo.numero => textoDecimal(lerDouble(v)),
      _ => v.toString(),
    };
  }

  TextEditingController _controle(CampoModalidade c) =>
      _controles.putIfAbsent(c.chave, () => TextEditingController(text: _textoInicial(c)));

  @override
  void dispose() {
    for (final c in _controles.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _mudar(String chave, Object? valor) => widget.aoMudar({...widget.valores, chave: valor});

  Object _lerTexto(CampoModalidade c, String t) {
    if (t.trim().isEmpty) return '';
    return switch (c.tipo) {
      TiposCampo.dinheiro => lerCentavos(t),
      TiposCampo.inteiro => lerNumero(t).round(),
      TiposCampo.numero => lerNumero(t),
      _ => t.trim(),
    };
  }

  Widget _campo(CampoModalidade c) {
    final erro = widget.erros[c.chave];
    final ajuda = c.obrigatorio ? null : 'Opcional';
    if (_deTexto.contains(c.tipo)) {
      return Campo(
        controle: _controle(c),
        rotulo: c.rotulo,
        erro: erro,
        ajuda: ajuda,
        tipo: switch (c.tipo) {
          TiposCampo.dinheiro => TipoCampo.dinheiro,
          TiposCampo.inteiro => TipoCampo.inteiro,
          TiposCampo.numero => TipoCampo.decimal,
          _ => TipoCampo.texto,
        },
        maiusculas: c.tipo == TiposCampo.cidade ? TextCapitalization.words : TextCapitalization.sentences,
        sugestoes: c.tipo == TiposCampo.cidade ? widget.sugestoesCidades : const [],
        aoMudar: (t) => _mudar(c.chave, _lerTexto(c, t)),
      );
    }
    final v = widget.valores[c.chave];
    switch (c.tipo) {
      case TiposCampo.simNao:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(c.rotulo, style: TextStyle(fontSize: 15, color: context.cores.textoFraco)),
            const SizedBox(height: 6),
            EscolhaDupla(
              valor: lerBool(v),
              textoSim: 'Sim',
              textoNao: 'Não',
              aoMudar: (b) => _mudar(c.chave, b),
            ),
          ],
        );
      case TiposCampo.dataHora:
        return CampoDataHora(
          rotulo: c.rotulo,
          valor: extraVazio(v) ? null : DateTime.tryParse(v.toString())?.toLocal(),
          erro: erro,
          aoMudar: (d) => _mudar(c.chave, dataIso(d)),
        );
      case TiposCampo.data:
        return _CampoDiaOpcional(
          rotulo: c.rotulo,
          valor: extraVazio(v) ? null : DateTime.tryParse(v.toString())?.toLocal(),
          erro: erro,
          aoMudar: (d) => _mudar(c.chave, dataIso(d)),
        );
      default:
        return Text('${c.rotulo}: ${textoDoExtra(c, v)}');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.campos.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final c in widget.campos) ...[
          _campo(c),
          const SizedBox(height: 14),
        ],
      ],
    );
  }
}

class _CampoDiaOpcional extends StatelessWidget {
  const _CampoDiaOpcional({required this.rotulo, required this.valor, required this.aoMudar, this.erro});

  final String rotulo;
  final DateTime? valor;
  final ValueChanged<DateTime> aoMudar;
  final String? erro;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: () async {
        final agora = DateTime.now();
        final d = await showDatePicker(
          context: context,
          initialDate: valor ?? agora,
          firstDate: DateTime(2015),
          lastDate: DateTime(agora.year + 1, 12, 31),
          locale: const Locale('pt', 'BR'),
          helpText: rotulo,
          cancelText: 'Cancelar',
          confirmText: 'Pronto',
        );
        if (d != null) aoMudar(inicioDoDia(d));
      },
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: rotulo,
          errorText: erro,
          suffixIcon: const Icon(Icons.calendar_today_outlined, size: 20),
        ),
        child: Text(
          valor == null ? 'Toque para escolher' : dataTexto(valor!),
          style: estiloNumero(19, peso: FontWeight.w500, cor: valor == null ? context.cores.textoFraco : null),
        ),
      ),
    );
  }
}

/// Mostra os campos novos já preenchidos (detalhe e painel).
class LinhasExtras extends StatelessWidget {
  const LinhasExtras({super.key, required this.extras, this.modalidade});
  final Map<String, Object?> extras;
  final Modalidade? modalidade;

  @override
  Widget build(BuildContext context) {
    final linhas = <Widget>[];
    final vistos = <String>{};
    for (final c in modalidade?.campos ?? const <CampoModalidade>[]) {
      if (!c.extra || !extras.containsKey(c.chave)) continue;
      vistos.add(c.chave);
      final t = textoDoExtra(c, extras[c.chave]);
      if (t.isNotEmpty) linhas.add(LinhaValor(rotulo: c.rotulo, valor: t));
    }
    for (final e in extras.entries) {
      if (vistos.contains(e.key)) continue;
      final t = textoDoExtra(null, e.value);
      if (t.isNotEmpty) linhas.add(LinhaValor(rotulo: e.key, valor: t));
    }
    if (linhas.isEmpty) return const SizedBox.shrink();
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: linhas);
  }
}
