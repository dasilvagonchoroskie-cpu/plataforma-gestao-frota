import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../dados/sincronizador.dart';

import 'inicio/tela_inicio.dart';
import 'inicio/tela_resumo.dart';
import 'lancamentos/tela_lancamentos.dart';

/// Desligado nos testes de tela (sem internet nem sensor de rede).
final sincronizarSozinhoProvider = Provider<bool>((ref) => true);

/// As três abas de baixo (Início, Lançamentos e Resumo). Também cuida de mandar a fila para a nuvem: ao
/// abrir, quando a internet volta, de tempos em tempos e ao voltar para o app.
class Casca extends ConsumerStatefulWidget {
  const Casca({super.key, this.abaInicial = 0});

  final int abaInicial;

  @override
  ConsumerState<Casca> createState() => _CascaState();
}

class _CascaState extends ConsumerState<Casca> with WidgetsBindingObserver {
  late int _aba = widget.abaInicial;
  StreamSubscription<List<ConnectivityResult>>? _rede;
  Timer? _relogio;

  @override
  void initState() {
    super.initState();
    if (!ref.read(sincronizarSozinhoProvider)) return;
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _sincronizar());
    _rede = Connectivity().onConnectivityChanged.listen((r) {
      if (r.any((e) => e != ConnectivityResult.none)) _sincronizar();
    });
    _relogio = Timer.periodic(const Duration(minutes: 5), (_) => _sincronizar());
  }

  void _sincronizar() => ref.read(sincronizadorProvider.notifier).sincronizar();

  @override
  void didChangeAppLifecycleState(AppLifecycleState estado) {
    if (estado == AppLifecycleState.resumed) _sincronizar();
  }

  @override
  void dispose() {
    if (_relogio != null) WidgetsBinding.instance.removeObserver(this);
    _rede?.cancel();
    _relogio?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Como no cartaz: Início (botões grandes), Lançamentos (tudo numa lista)
    // e Resumo. Fretes ou viagens, diesel, gastos, vales e paradas abrem pelo
    // Início.
    final telas = [
      TelaInicio(irParaResumo: () => setState(() => _aba = 2)),
      const TelaLancamentos(),
      const TelaResumo(),
    ];
    final aba = _aba < telas.length ? _aba : 0;
    return PopScope(
      canPop: aba == 0,
      onPopInvokedWithResult: (saiu, _) {
        if (!saiu && aba != 0) setState(() => _aba = 0);
      },
      child: Scaffold(
        body: IndexedStack(index: aba, children: telas),
        bottomNavigationBar: NavigationBar(
          selectedIndex: aba,
          onDestinationSelected: (i) => setState(() => _aba = i),
          destinations: const [
            NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'Início'),
            NavigationDestination(
              icon: Icon(Icons.format_list_bulleted),
              selectedIcon: Icon(Icons.view_list),
              label: 'Lançamentos',
            ),
            NavigationDestination(
              icon: Icon(Icons.insights_outlined),
              selectedIcon: Icon(Icons.insights),
              label: 'Resumo',
            ),
          ],
        ),
      ),
    );
  }
}
