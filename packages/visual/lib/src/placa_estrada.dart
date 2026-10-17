import 'package:flutter/material.dart';

import 'tema.dart';

enum TipoPlaca { verde, amarela, vermelha }

/// O numero mais importante da tela, desenhado como placa de estrada:
/// fundo verde, filete branco por dentro e numero grande em letra de placa.
class Placa extends StatelessWidget {
  const Placa({
    super.key,
    required this.rotulo,
    required this.valor,
    this.detalhe,
    this.tipo = TipoPlaca.verde,
    this.tamanhoValor = 46,
  });

  final String rotulo;
  final String valor;
  final String? detalhe;
  final TipoPlaca tipo;
  final double tamanhoValor;

  @override
  Widget build(BuildContext context) {
    final cores = context.cores;
    final Color fundo;
    final Color texto;
    switch (tipo) {
      case TipoPlaca.verde:
        fundo = cores.placa;
        texto = cores.placaTexto;
      case TipoPlaca.amarela:
        fundo = Paleta.amareloFaixa;
        texto = Paleta.asfalto;
      case TipoPlaca.vermelha:
        fundo = Paleta.vermelhoPlaca;
        texto = Colors.white;
    }
    return Semantics(
      container: true,
      label: '$rotulo: $valor${detalhe != null ? '. $detalhe' : ''}',
      excludeSemantics: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: fundo,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Padding(
          padding: const EdgeInsets.all(5),
          child: DecoratedBox(
            decoration: BoxDecoration(
              border: Border.all(color: texto.withValues(alpha: 0.92), width: 2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 14, 18, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    rotulo,
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w500, color: texto.withValues(alpha: 0.9)),
                  ),
                  const SizedBox(height: 2),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(valor, style: estiloNumero(tamanhoValor, peso: FontWeight.w700, cor: texto)),
                  ),
                  if (detalhe != null) ...[
                    const SizedBox(height: 4),
                    Text(detalhe!, style: TextStyle(fontSize: 15, color: texto.withValues(alpha: 0.85))),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
