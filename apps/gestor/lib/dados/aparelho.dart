import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// O pouco que o painel guarda no próprio aparelho (no navegador ou no
/// celular), sem dado pessoal: hoje, só a versão dos termos que foi aceita
/// na primeira abertura.
abstract class Aparelho {
  Future<String?> ler(String chave);
  Future<void> gravar(String chave, String valor);
}

/// Chave da versão dos Termos de Uso aceita neste aparelho.
const chaveTermosAparelho = 'termos_local';

/// Guarda nas preferências do aparelho (localStorage no navegador).
class AparelhoPreferencias implements Aparelho {
  AparelhoPreferencias(this._p);
  final SharedPreferences _p;

  static Future<AparelhoPreferencias> abrir() async => AparelhoPreferencias(await SharedPreferences.getInstance());

  @override
  Future<String?> ler(String chave) async => _p.getString(chave);

  @override
  Future<void> gravar(String chave, String valor) => _p.setString(chave, valor);
}

/// Só na memória (testes).
class AparelhoMemoria implements Aparelho {
  AparelhoMemoria([Map<String, String>? inicial]) : _dados = {...?inicial};
  final Map<String, String> _dados;

  @override
  Future<String?> ler(String chave) async => _dados[chave];

  @override
  Future<void> gravar(String chave, String valor) async => _dados[chave] = valor;
}

final aparelhoProvider = Provider<Aparelho>((ref) => AparelhoMemoria());
