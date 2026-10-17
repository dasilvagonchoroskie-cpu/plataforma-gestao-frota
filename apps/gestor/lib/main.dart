import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app.dart';
import 'config.dart';
import 'dados/provedores.dart';
import 'servidor/servidor.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(url: supabaseUrl, publishableKey: supabaseChavePublica);
  runApp(
    ProviderScope(
      overrides: [servidorProvider.overrideWithValue(ServidorSupabase(Supabase.instance.client))],
      child: const AplicativoGestor(),
    ),
  );
}
