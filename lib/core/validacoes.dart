import 'dart:convert';
import 'package:flutter/services.dart';

/// Regras de entrada de texto (exceto CPF/telefone, em documentos.dart, e números, em
/// entrada_numerica.dart). Limites iguais aos do backend e das colunas do banco.
///
/// Cada campo tem dois níveis:
///   * filtro de digitação (inputFormatters): impede caracteres que nunca são válidos ali;
///   * validador (validator): confere o formato completo ao salvar.

// ---- Nome de pessoa (cliente, fiador, funcionário) -------------------------------------------
// Letras (com acento), espaço, apóstrofo, hífen e ponto: "Maria da Silva", "D'Ávila", "João Jr.".
final nomeRegex = RegExp(r"^\p{L}+(?:[ '\-.]{1,2}\p{L}+)*\.?$", unicode: true);
const nomeMax = 150; // pessoas.nome varchar(150)

String? validarNome(String? v, {bool obrigatorio = true}) {
  final t = (v ?? '').trim();
  if (t.isEmpty) return obrigatorio ? 'Campo obrigatório' : null;
  if (t.length < 3) return 'O nome deve ter pelo menos 3 letras';
  if (t.length > nomeMax) return 'Use no máximo $nomeMax caracteres';
  if (!nomeRegex.hasMatch(t)) {
    return 'Use só letras, espaços, apóstrofo, hífen ou ponto';
  }
  return null;
}

final List<TextInputFormatter> filtroNome = [
  FilteringTextInputFormatter.allow(RegExp(r"[\p{L} '\-.]", unicode: true)),
  FilteringTextInputFormatter.deny(RegExp(r'  +'), replacementString: ' '),
  LengthLimitingTextInputFormatter(nomeMax),
];

// ---- Cargo (funcionário) ---------------------------------------------------------------------
final cargoRegex = RegExp(r'^[\p{L}0-9][\p{L}0-9 ./\-]*$', unicode: true);
const cargoMax = 50;

String? validarCargo(String? v) {
  final t = (v ?? '').trim();
  if (t.isEmpty) return 'Campo obrigatório';
  if (t.length < 2) return 'Informe o cargo';
  return cargoRegex.hasMatch(t)
      ? null
      : 'Use letras, números, espaço, ponto, barra ou hífen';
}

final List<TextInputFormatter> filtroCargo = [
  FilteringTextInputFormatter.allow(RegExp(r'[\p{L}0-9 ./\-]', unicode: true)),
  LengthLimitingTextInputFormatter(cargoMax),
];

// ---- Nome comercial -------------------------------------------------------------------------
const nomeLojaMax = 120;

String? validarNomeLoja(String? v) {
  final t = (v ?? '').trim();
  if (t.length < 3) return 'Informe o nome da loja (mínimo 3 caracteres)';
  if (t.length > nomeLojaMax) return 'Use no máximo $nomeLojaMax caracteres';
  return null;
}

final List<TextInputFormatter> filtroNomeLoja = [
  FilteringTextInputFormatter.deny(RegExp(r'[\x00-\x1F\x7F]')),
  LengthLimitingTextInputFormatter(nomeLojaMax),
];

// ---- E-mail ----------------------------------------------------------------------------------
final emailRegex = RegExp(
  r'^[A-Za-z0-9._%+\-]+@[A-Za-z0-9](?:[A-Za-z0-9\-]*[A-Za-z0-9])?'
  r'(?:\.[A-Za-z0-9](?:[A-Za-z0-9\-]*[A-Za-z0-9])?)*\.[A-Za-z]{2,}$',
);
const emailMax = 100; // pessoas.email varchar(100)

String? validarEmail(String? v, {bool obrigatorio = false}) {
  final t = (v ?? '').trim();
  if (t.isEmpty) return obrigatorio ? 'Campo obrigatório' : null;
  if (t.length > emailMax) return 'Use no máximo $emailMax caracteres';
  return emailRegex.hasMatch(t) && !t.contains('..')
      ? null
      : 'Informe um e-mail válido';
}

final List<TextInputFormatter> filtroEmail = [
  FilteringTextInputFormatter.deny(RegExp(r'\s')),
  LengthLimitingTextInputFormatter(emailMax),
];

// ---- Endereço --------------------------------------------------------------------------------
const enderecoMax = 200; // pessoas.endereco varchar(200)

String? validarEndereco(String? v) {
  final t = (v ?? '').trim();
  if (t.isEmpty) return null;
  if (t.length < 5) return 'Endereço muito curto';
  return RegExp(r'\p{L}', unicode: true).hasMatch(t)
      ? null
      : 'Informe rua, número e bairro';
}

final List<TextInputFormatter> filtroEndereco = [
  // Sem caracteres de controle (tab etc.); quebra de linha é permitida no campo de várias linhas.
  FilteringTextInputFormatter.deny(RegExp(r'[\x00-\x09\x0B-\x1F\x7F]')),
  LengthLimitingTextInputFormatter(enderecoMax),
];

// ---- Descrição de item de venda --------------------------------------------------------------
const descricaoMax = 200; // itens_venda.descricao_produto varchar(200)

String? validarDescricao(String? v) {
  final t = (v ?? '').trim();
  if (t.isEmpty) return 'Informe a descrição';
  return RegExp(r'[\p{L}0-9]', unicode: true).hasMatch(t)
      ? null
      : 'Descreva o produto com letras ou números';
}

final List<TextInputFormatter> filtroDescricao = [
  FilteringTextInputFormatter.deny(RegExp(r'[\x00-\x1F\x7F]')),
  LengthLimitingTextInputFormatter(descricaoMax),
];

// ---- Matrícula (opcional) --------------------------------------------------------------------
final matriculaRegex = RegExp(r'^[A-Za-z0-9][A-Za-z0-9./\-]*$');
const matriculaMax = 50;

String? validarMatricula(String? v) {
  final t = (v ?? '').trim();
  if (t.isEmpty) return null;
  return matriculaRegex.hasMatch(t)
      ? null
      : 'Use letras, números, ponto, barra ou hífen';
}

final List<TextInputFormatter> filtroMatricula = [
  FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9./\-]')),
  LengthLimitingTextInputFormatter(matriculaMax),
];

// ---- Login e senha ---------------------------------------------------------------------------
final loginRegex = RegExp(
  r'^[A-Za-z0-9._\-]{3,50}$',
); // = Dtos.LOGIN_REGEX do backend

/// Criação de login: só os caracteres aceitos pelo backend.
final List<TextInputFormatter> filtroLoginNovo = [
  FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9._\-]')),
  LengthLimitingTextInputFormatter(50),
];

/// Tela de entrada: só bloqueia espaços (não trava contas antigas com outro formato).
final List<TextInputFormatter> filtroLoginEntrada = [
  FilteringTextInputFormatter.deny(RegExp(r'\s')),
  LengthLimitingTextInputFormatter(50),
];

const senhaMax = 72; // limite em bytes UTF-8 do BCrypt
String? validarSenha(String? value) {
  if (value == null || value.trim().isEmpty || value.length < 8) {
    return 'A senha deve ter pelo menos 8 caracteres';
  }
  if (utf8.encode(value).length > senhaMax) {
    return 'A senha deve ter no máximo 72 bytes (acentos e emojis ocupam mais espaço)';
  }
  return null;
}

final List<TextInputFormatter> filtroSenha = [
  LengthLimitingTextInputFormatter(senhaMax),
];

// ---- Código do convite -----------------------------------------------------------------------
// 20 caracteres do alfabeto do backend (sem 0, O, 1, I). Hífens e espaços são ignorados.
final conviteRegex = RegExp(r'^[A-HJ-NP-Z2-9]{20}$');

String? validarConvite(String? v) {
  final t = (v ?? '').replaceAll(RegExp(r'[\s\-]'), '').toUpperCase();
  if (t.isEmpty) return 'Campo obrigatório';
  return conviteRegex.hasMatch(t)
      ? null
      : 'O código tem 20 caracteres (letras e números, sem 0, O, 1 ou I)';
}

class _Maiusculas extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue o, TextEditingValue n) =>
      n.copyWith(text: n.text.toUpperCase());
}

final List<TextInputFormatter> filtroConvite = [
  FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9\- ]')),
  _Maiusculas(),
  LengthLimitingTextInputFormatter(29), // 20 + separadores
];

// ---- Códigos de auditoria (filtro exato no backend: "VENDA_CRIADA") -------------------------
class _CodigoAuditoria extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue o, TextEditingValue n) {
    final t = n.text
        .toUpperCase()
        .replaceAll(' ', '_')
        .replaceAll(RegExp(r'[^A-Z_]'), '');
    return TextEditingValue(
      text: t,
      selection: TextSelection.collapsed(offset: t.length),
    );
  }
}

final List<TextInputFormatter> filtroCodigoAuditoria = [
  _CodigoAuditoria(),
  LengthLimitingTextInputFormatter(50),
];
