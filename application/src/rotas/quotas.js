// UI04 — Painel de quotas (FR09)
// Lê a vista v_quota_consumo (data/views.sql) com o utilizador do
// armador. A vista faz o mesmo cálculo que o trg_captura_quota, por isso
// o painel mostra exatamente o que o trigger usa para recusar capturas.
//
//   GET /api/quotas/anos         anos com quota definida
//   GET /api/quotas?ano=2026     uma linha por quota (navio, espécie, zona)
//   GET /api/quotas/csv?ano=2026 a mesma informação em CSV (Excel PT)

import { Router } from 'express';
import { ligacao } from '../db.js';
import { erroPedido } from '../erros.js';

export const rotasQuotas = Router();

const PAPEL = 'armador';

function lerAno(req) {
  const ano = Number(req.query.ano);
  if (!Number.isInteger(ano) || ano < 2000 || ano > 2100) {
    throw erroPedido('Indique um ano válido, por exemplo ?ano=2026.');
  }
  return ano;
}

async function quotasDoAno(ano) {
  const [linhas] = await ligacao(PAPEL).execute(
    `SELECT id_quota, navio, ano, cod_fao, especie, codigo_ices, jurisdicao,
            quota_kg, capturado_kg, restante_kg, consumida_pct, estado
       FROM v_quota_consumo
      WHERE ano = ?
      ORDER BY cod_fao, codigo_ices, jurisdicao`,
    [ano],
  );
  return linhas;
}

rotasQuotas.get('/anos', async (req, res) => {
  const [linhas] = await ligacao(PAPEL).query(
    'SELECT DISTINCT ano FROM quota ORDER BY ano DESC',
  );
  res.json(linhas.map((l) => l.ano));
});

rotasQuotas.get('/', async (req, res) => {
  res.json(await quotasDoAno(lerAno(req)));
});

rotasQuotas.get('/csv', async (req, res) => {
  const ano = lerAno(req);
  const linhas = await quotasDoAno(ano);

  // Excel em português: separador ';' e vírgula decimal; BOM para os acentos
  const num = (n) => String(n).replace('.', ',');
  const campo = (t) => `"${String(t).replaceAll('"', '""')}"`;
  const cabecalho = ['Espécie', 'Código FAO', 'Divisão ICES', 'Jurisdição',
    'Quota (kg)', 'Capturado (kg)', 'Restante (kg)', 'Consumida (%)', 'Estado'];
  const corpo = linhas.map((l) => [
    campo(l.especie), l.cod_fao, l.codigo_ices, campo(l.jurisdicao),
    num(l.quota_kg), num(l.capturado_kg), num(l.restante_kg), num(l.consumida_pct), l.estado,
  ].join(';'));

  res.set('Content-Type', 'text/csv; charset=utf-8');
  res.set('Content-Disposition', `attachment; filename="quotas_${ano}.csv"`);
  res.send('﻿' + [cabecalho.join(';'), ...corpo].join('\r\n') + '\r\n');
});
