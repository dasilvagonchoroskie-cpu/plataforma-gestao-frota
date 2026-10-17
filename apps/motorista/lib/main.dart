import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:visual/visual.dart';

import 'app.dart';
import 'config.dart';
import 'dados/armazenamento.dart';
import 'dados/banco.dart';
import 'dados/dados.dart';
import 'servidor/servidor.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Supabase.initialize(url: supabaseUrl, publishableKey: supabaseChavePublica);
  } catch (e) {
    runApp(AppFalhaAoAbrir(nomeApp: 'Frota Motorista', erro: '$e'));
    return;
  }
  runApp(ProviderScope(
    overrides: [
      armazenamentoProvider.overrideWithValue(ArmazenamentoDrift(BancoLocal())),
      servidorProvider.overrideWithValue(ServidorSupabase(Supabase.instance.client)),
    ],
    child: const AplicativoMotorista(),
  ));
  avisarQueAbriu('motorista');
}
