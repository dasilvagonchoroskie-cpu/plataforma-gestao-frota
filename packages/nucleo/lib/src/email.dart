/// Confere o formato do e-mail (a mesma regra das Edge Functions:
/// algo@algo.algo, sem espaços, até 254 caracteres).
bool emailValido(String email) {
  final e = email.trim();
  return e.length <= 254 && RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(e);
}
