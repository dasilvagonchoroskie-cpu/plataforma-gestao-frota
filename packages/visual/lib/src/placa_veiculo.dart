import 'package:flutter/material.dart';

import 'package:nucleo/nucleo.dart';
import 'tema.dart';

/// Placa do caminhao desenhada no modelo Mercosul (faixa azul em cima).
class PlacaVeiculo extends StatelessWidget {
  const PlacaVeiculo(this.placa, {super.key, this.tamanho = 20});

  final String placa;
  final double tamanho;

  @override
  Widget build(BuildContext context) {
    final texto = placa.isEmpty ? '???????' : placaTexto(placa);
    return Semantics(
      label: 'Placa ${texto.split('').join(' ')}',
      excludeSemantics: true,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(tamanho * 0.22),
          border: Border.all(color: Paleta.asfalto, width: tamanho * 0.08),
        ),
        clipBehavior: Clip.antiAlias,
        // Largura do proprio texto (a faixa azul acompanha), mesmo dentro de Row.
        child: IntrinsicWidth(
          child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              color: const Color(0xFF0B3F91),
              padding: EdgeInsets.symmetric(vertical: tamanho * 0.06),
              alignment: Alignment.center,
              child: Text(
                'BRASIL',
                style: TextStyle(
                  fontSize: tamanho * 0.34,
                  height: 1,
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  letterSpacing: tamanho * 0.05,
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(tamanho * 0.45, tamanho * 0.05, tamanho * 0.45, tamanho * 0.08),
              child: Text(
                texto,
                textAlign: TextAlign.center,
                style: estiloNumero(tamanho, peso: FontWeight.w700, cor: Paleta.asfalto).copyWith(
                  letterSpacing: tamanho * 0.08,
                  height: 1.05,
                ),
              ),
            ),
          ],
        ),
        ),
      ),
    );
  }
}
