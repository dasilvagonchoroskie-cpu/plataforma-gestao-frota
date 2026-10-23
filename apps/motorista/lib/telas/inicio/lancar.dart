import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nucleo/nucleo.dart';

import '../../dados/dados.dart';
import '../diesel/form_abastecimento.dart';
import '../fretes/form_frete.dart';
import '../gastos/tela_gastos.dart';
import '../vales/tela_vales.dart';
import '../viagens/form_viagem.dart';

/// "Lançar": o que o motorista quer anotar agora (frete ou carreta, diesel,
/// gasto ou vale). O mesmo botão no Início, nos Lançamentos e no Resumo.
void abrirLancar(BuildContext context, WidgetRef ref) {
final dados = ref.read(dadosProvider).value ?? const EstadoDados();
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
