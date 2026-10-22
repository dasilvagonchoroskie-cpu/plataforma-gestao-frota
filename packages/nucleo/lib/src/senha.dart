/// Regra de senha da plataforma: de 8 a 72 caracteres, com pelo menos uma
/// letra e um número. É a mesma no banco (public.senha_aceita), nas Edge
/// Functions e no Supabase Auth.
library;

const mensagemSenha = 'A senha precisa ter pelo menos 8 caracteres, com letras e números.';
const ajudaSenha = 'Pelo menos 8 caracteres, com letras e números.';

final _letra = RegExp(r'[A-Za-z]');
final _numero = RegExp(r'[0-9]');

bool senhaAceita(String senha) =>
    senha.length >= 8 && senha.length <= 72 && _letra.hasMatch(senha) && _numero.hasMatch(senha);
