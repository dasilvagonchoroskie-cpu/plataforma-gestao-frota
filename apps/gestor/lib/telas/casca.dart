import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:visual/visual.dart';

import '../componentes/comuns.dart';
import '../dados/provedores.dart';
import 'caminhoes/tela_caminhoes.dart';
import 'configuracoes/tela_configuracoes.dart';
import 'lancamentos/tela_lancamentos.dart';
import 'motoristas/tela_motoristas.dart';
import 'painel/tela_painel.dart';
import 'relatorios/tela_relatorios.dart';

enum Secao {
  painel('Painel', Icons.space_dashboard_outlined, Icons.space_dashboard),
  motoristas('Motoristas', Icons.badge_outlined, Icons.badge),
  caminhoes('Caminhões', Icons.local_shipping_outlined, Icons.local_shipping),
  lancamentos('Lançamentos', Icons.receipt_long_outlined, Icons.receipt_long),
  relatorios('Relatórios', Icons.picture_as_pdf_outlined, Icons.picture_as_pdf),
  configuracoes('Configurações', Icons.settings_outlined, Icons.settings);

  const Secao(this.rotulo, this.icone, this.iconeMarcado);
  final String rotulo;
  final IconData icone;
  final IconData iconeMarcado;
}

/// Parte do painel aberta agora (as telas podem mudar, ex.: alerta do painel
/// leva para Motoristas).
class SecaoAtual extends Notifier<Secao> {
  @override
  Secao build() => Secao.painel;

  void ir(Secao s) => state = s;
}

final secaoProvider = NotifierProvider<SecaoAtual, Secao>(SecaoAtual.new);

/// Desligado nos testes (sem relógio de atualização).
final atualizarSozinhoProvider = Provider<bool>((ref) => true);

/// Menu lateral no computador e abas embaixo no celular. A mesma tela serve
/// os dois; cada parte se ajusta à largura.
class Casca extends ConsumerStatefulWidget {
  const Casca({super.key});

  @override
  ConsumerState<Casca> createState() => _CascaState();
}

class _CascaState extends ConsumerState<Casca> with WidgetsBindingObserver {
  Timer? _relogio;

  @override
  void initState() {
    super.initState();
    if (!ref.read(atualizarSozinhoProvider)) return;
    WidgetsBinding.instance.addObserver(this);
    // Busca o que os motoristas mandaram de tempos em tempos.
    _relogio = Timer.periodic(const Duration(minutes: 3), (_) => _atualizar());
  }

  Future<void> _atualizar() async {
    try {
      await ref.read(equipeProvider.notifier).recarregar();
    } catch (_) {
      // Sem internet: tenta de novo no próximo ciclo.
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState estado) {
    if (estado == AppLifecycleState.resumed) _atualizar();
  }

  @override
  void dispose() {
    if (_relogio != null) WidgetsBinding.instance.removeObserver(this);
    _relogio?.cancel();
    super.dispose();
  }

  static Widget _tela(Secao s) => switch (s) {
    Secao.painel => const TelaPainel(),
    Secao.motoristas => const TelaMotoristas(),
    Secao.caminhoes => const TelaCaminhoes(),
    Secao.lancamentos => const TelaLancamentos(),
    Secao.relatorios => const TelaRelatorios(),
    Secao.configuracoes => const TelaConfiguracoes(),
  };

  @override
  Widget build(BuildContext context) {
    final secao = ref.watch(secaoProvider);
    final largo = telaLarga(context);
    final e = assistirEquipe(ref);
    final pendentes = e.pedidosPendentes.length;

    Widget icone(Secao s, bool marcado) {
      final i = Icon(marcado ? s.iconeMarcado : s.icone);
      if (s == Secao.motoristas && pendentes > 0) return Badge(label: Text('$pendentes'), child: i);
      return i;
    }

    final corpo = KeyedSubtree(key: ValueKey(secao), child: _tela(secao));

    if (largo) {
      final cores = context.cores;
      return Scaffold(
        body: Row(
          children: [
            NavigationRail(
              extended: MediaQuery.sizeOf(context).width >= 1200,
              minExtendedWidth: 220,
              selectedIndex: secao.index,
              onDestinationSelected: (i) => ref.read(secaoProvider.notifier).ir(Secao.values[i]),
              leading: Padding(
                padding: const EdgeInsets.fromLTRB(8, 12, 8, 16),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(color: cores.placa, borderRadius: BorderRadius.circular(8)),
                      child: Text(
                        'FROTA',
                        style: estiloNumero(18, peso: FontWeight.w700, cor: cores.placaTexto),
                      ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: 180,
                      child: Text(
                        e.empresa.nome,
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 13, color: cores.textoFraco),
                      ),
                    ),
                  ],
                ),
              ),
              destinations: [
                for (final s in Secao.values)
                  NavigationRailDestination(icon: icone(s, false), selectedIcon: icone(s, true), label: Text(s.rotulo)),
              ],
            ),
            const VerticalDivider(width: 1),
            Expanded(child: corpo),
          ],
        ),
      );
    }

    final abas = Secao.values.where((s) => s != Secao.configuracoes).toList();
    return PopScope(
      canPop: secao == Secao.painel,
      onPopInvokedWithResult: (saiu, _) {
        if (!saiu) ref.read(secaoProvider.notifier).ir(Secao.painel);
      },
      child: Scaffold(
        body: corpo,
        bottomNavigationBar: NavigationBarTheme(
          data: NavigationBarTheme.of(context).copyWith(
            labelTextStyle: WidgetStateProperty.resolveWith(
              (estados) => TextStyle(
                fontSize: 12.5,
                fontWeight: estados.contains(WidgetState.selected) ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ),
          child: NavigationBar(
            selectedIndex: abas.contains(secao) ? abas.indexOf(secao) : 0,
            onDestinationSelected: (i) => ref.read(secaoProvider.notifier).ir(abas[i]),
            labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
            destinations: [
              for (final s in abas)
                NavigationDestination(icon: icone(s, false), selectedIcon: icone(s, true), label: s.rotulo),
            ],
          ),
        ),
      ),
    );
  }
}

/// Ações da barra de cima comuns às partes do painel: atualizar e, no
/// celular, o atalho para Configurações.
List<Widget> acoesPadrao(BuildContext context, WidgetRef ref) => [
  const BotaoAtualizar(),
  if (!telaLarga(context))
    IconButton(
      tooltip: 'Configurações',
      icon: const Icon(Icons.settings_outlined),
      onPressed: () => ref.read(secaoProvider.notifier).ir(Secao.configuracoes),
    ),
  const SizedBox(width: 4),
];
