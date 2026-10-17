import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../dados/sincronizador.dart';

import 'diesel/tela_diesel.dart';
import 'fretes/tela_fretes.dart';
import 'gastos/tela_gastos.dart';
import 'inicio/tela_resumo.dart';
import 'vales/tela_vales.dart';

/// Desligado nos testes de tela (sem internet nem sensor de rede).
final sincronizarSozinhoProvider = Provider<bool>((ref) => true);

/// As cinco abas de baixo. Também cuida de mandar a fila para a nuvem: ao
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

  static const _telas = [TelaResumo(), TelaFretes(), TelaDiesel(), TelaGastos(), TelaVales()];

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
    return PopScope(
      canPop: _aba == 0,
      onPopInvokedWithResult: (saiu, _) {
        if (!saiu && _aba != 0) setState(() => _aba = 0);
      },
      child: Scaffold(
        body: IndexedStack(index: _aba, children: _telas),
        bottomNavigationBar: NavigationBar(
          selectedIndex: _aba,
          onDestinationSelected: (i) => setState(() => _aba = i),
          destinations: const [
            NavigationDestination(icon: Icon(Icons.signpost_outlined), selectedIcon: Icon(Icons.signpost), label: 'Resumo'),
            NavigationDestination(
                icon: Icon(Icons.local_shipping_outlined), selectedIcon: Icon(Icons.local_shipping), label: 'Fretes'),
            NavigationDestination(
                icon: Icon(Icons.local_gas_station_outlined), selectedIcon: Icon(Icons.local_gas_station), label: 'Diesel'),
            NavigationDestination(icon: Icon(Icons.receipt_long_outlined), selectedIcon: Icon(Icons.receipt_long), label: 'Gastos'),
            NavigationDestination(icon: Icon(Icons.payments_outlined), selectedIcon: Icon(Icons.payments), label: 'Vales'),
          ],
        ),
      ),
    );
  }
}
