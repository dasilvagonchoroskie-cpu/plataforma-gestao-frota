import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../componentes/comuns.dart';
import '../dados/sincronizador.dart';

import 'diesel/tela_diesel.dart';
import 'fretes/tela_fretes.dart';
import 'gastos/tela_gastos.dart';
import 'inicio/tela_resumo.dart';
import 'paradas/tela_paradas.dart';
import 'vales/tela_vales.dart';
import 'viagens/tela_viagens.dart';

/// Desligado nos testes de tela (sem internet nem sensor de rede).
final sincronizarSozinhoProvider = Provider<bool>((ref) => true);

/// As abas de baixo (cinco; seis quando a empresa usa o registro de paradas). Também cuida de mandar a fila para a nuvem: ao
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
    // Baú e Sider: a segunda aba é Viagens (por carreta) no lugar de Fretes.
    final dados = assistirDados(ref);
    final porViagem = dados.porViagem;
    // Paradas: só quando a empresa liga (quem não usa nem vê a aba).
    final comParadas = dados.paradasAtivas;
    final telas = [
      const TelaResumo(),
      if (porViagem) const TelaViagens() else const TelaFretes(),
      const TelaDiesel(),
      const TelaGastos(),
      const TelaVales(),
      if (comParadas) const TelaParadas(),
    ];
    // A empresa desligou as paradas com a aba aberta: volta para o Resumo.
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
          destinations: [
            const NavigationDestination(
              icon: Icon(Icons.signpost_outlined),
              selectedIcon: Icon(Icons.signpost),
              label: 'Resumo',
            ),
            if (porViagem)
              const NavigationDestination(
                icon: Icon(Icons.route_outlined),
                selectedIcon: Icon(Icons.route),
                label: 'Viagens',
              )
            else
              const NavigationDestination(
                icon: Icon(Icons.local_shipping_outlined),
                selectedIcon: Icon(Icons.local_shipping),
                label: 'Fretes',
              ),
            const NavigationDestination(
              icon: Icon(Icons.local_gas_station_outlined),
              selectedIcon: Icon(Icons.local_gas_station),
              label: 'Diesel',
            ),
            const NavigationDestination(
              icon: Icon(Icons.receipt_long_outlined),
              selectedIcon: Icon(Icons.receipt_long),
              label: 'Gastos',
            ),
            const NavigationDestination(
              icon: Icon(Icons.payments_outlined),
              selectedIcon: Icon(Icons.payments),
              label: 'Vales',
            ),
            if (comParadas)
              const NavigationDestination(
                icon: Icon(Icons.pause_circle_outline),
                selectedIcon: Icon(Icons.pause_circle),
                label: 'Paradas',
              ),
          ],
        ),
      ),
    );
  }
}
