// Validação dos campos dos pedidos (formatos e campos obrigatórios).
// As regras de negócio NÃO estão aqui: estão na BD (triggers, CHECK,
// sp_fechar_lote). Isto só dá mensagens claras para pedidos mal formados.

import { erroPedido } from './erros.js';

// Data e hora em UTC, "AAAA-MM-DD HH:MM" (ou o formato do <input datetime-local>)
export function dataHora(valor, campo, obrigatorio) {
  if (valor === undefined || valor === null || valor === '') {
    if (obrigatorio) throw erroPedido(`Indique ${campo}.`);
    return null;
  }
  const texto = String(valor).replace('T', ' ').slice(0, 16);
  if (!/^\d{4}-\d{2}-\d{2} \d{2}:\d{2}$/.test(texto) || Number.isNaN(Date.parse(texto.replace(' ', 'T') + 'Z'))) {
    throw erroPedido(`Indique ${campo} no formato AAAA-MM-DD HH:MM.`);
  }
  return texto;
}

export function numero(valor, campo, { min, max, inteiro = false } = {}) {
  if (valor === undefined || valor === null || valor === '') return null;
  const n = Number(valor);
  if (!Number.isFinite(n) || (inteiro && !Number.isInteger(n)) || n < min || n > max) {
    throw erroPedido(`${campo} inválida: tem de estar entre ${min} e ${max}.`);
  }
  return n;
}

// Identificador numérico (id de turno, produto, lance, porão...)
export function id(valor, mensagem) {
  const n = Number(valor);
  if (valor === '' || valor === null || valor === undefined || !Number.isInteger(n) || n <= 0) {
    throw erroPedido(mensagem);
  }
  return n;
}
