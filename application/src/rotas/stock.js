// UI03 — Stock a bordo e saídas (FR11), com o utilizador do comandante
//
//   GET  /api/stock           stock por porão, por espécie e por porão/lote (v_stock)
//   GET  /api/stock/escalas   escalas do navio (para as descargas em porto)
//   GET  /api/stock/saidas    saídas registadas (descargas e transbordos)
//   POST /api/stock/saidas    regista uma saída (INSERT saida_lote)
//
// As regras estão na BD: trg_saida_stock (RN24) recusa mais caixas do que
// as que estão no porão, o CHECK ck_saida_destino (RN25) exige descarga OU
// transbordo, e a FK composta (id_lote, id_porao) -> armazenamento garante
// que o lote esteve nesse porão. A aplicação só verifica os formatos.

import { Router } from 'express';
import { ligacao } from '../db.js';
import { erroPedido } from '../erros.js';
import { dataHora, id } from '../validacao.js';
import { navioAtual } from '../viagem.js';

export const rotasStock = Router();

const PAPEL = 'comandante';

rotasStock.get('/', async (req, res) => {
  const db = ligacao(PAPEL);
  const navio = await navioAtual(db);

  // Ocupação de cada porão (consulta 4b / Q09 do data/queries.sql): LEFT JOIN para um porão
  // vazio também aparecer
  const [poroes] = await db.execute(
    `SELECT po.id_porao, po.designacao, po.capacidade_caixas,
            COALESCE(SUM(vs.stock_caixas), 0) AS stock_caixas,
            ROUND(100 * COALESCE(SUM(vs.stock_caixas), 0) / po.capacidade_caixas, 2) AS ocupacao_pct
       FROM porao po
       LEFT JOIN v_stock vs ON vs.id_porao = po.id_porao
      WHERE po.id_navio = ?
      GROUP BY po.id_porao, po.designacao, po.capacidade_caixas
      ORDER BY po.id_porao`,
    [navio],
  );

  // Stock por espécie (consulta 4c)
  const [especies] = await db.execute(
    `SELECT pr.cod_fao, e.nome_comum,
            SUM(vs.stock_caixas)                    AS stock_caixas,
            SUM(vs.stock_caixas * pr.peso_caixa_kg) AS stock_kg
       FROM v_stock vs
       JOIN porao   po ON po.id_porao   = vs.id_porao
       JOIN lote    lo ON lo.id_lote    = vs.id_lote
       JOIN produto pr ON pr.id_produto = lo.id_produto
       JOIN especie e  ON e.cod_fao     = pr.cod_fao
      WHERE vs.stock_caixas > 0 AND po.id_navio = ?
      GROUP BY pr.cod_fao, e.nome_comum
      ORDER BY pr.cod_fao`,
    [navio],
  );

  // Stock de cada lote em cada porão (consulta 4a), com a data de entrada
  // para os avisos de datas do ecrã
  const [linhas] = await db.execute(
    `SELECT vs.id_porao, po.designacao AS porao,
            vs.id_lote, lo.codigo_lote, pr.cod_fao, pr.cod_apresentacao,
            vs.armazenado, vs.saido, vs.stock_caixas,
            DATE_FORMAT(a.data_entrada, '%Y-%m-%d %H:%i') AS data_entrada
       FROM v_stock vs
       JOIN armazenamento a ON a.id_lote = vs.id_lote AND a.id_porao = vs.id_porao
       JOIN porao   po ON po.id_porao   = vs.id_porao
       JOIN lote    lo ON lo.id_lote    = vs.id_lote
       JOIN produto pr ON pr.id_produto = lo.id_produto
      WHERE vs.stock_caixas > 0 AND po.id_navio = ?
      ORDER BY po.id_porao, lo.codigo_lote`,
    [navio],
  );

  res.json({ poroes, especies, linhas });
});

rotasStock.get('/escalas', async (req, res) => {
  const db = ligacao(PAPEL);
  const [linhas] = await db.execute(
    `SELECT es.id_escala, es.cod_porto, pt.nome AS porto,
            DATE_FORMAT(COALESCE(es.ata, es.eta), '%Y-%m-%d %H:%i') AS chegada,
            DATE_FORMAT(COALESCE(es.atd, es.etd), '%Y-%m-%d %H:%i') AS partida
       FROM escala es
       JOIN porto pt ON pt.cod_unlocode = es.cod_porto
      WHERE es.id_navio = ?
      ORDER BY COALESCE(es.ata, es.eta) DESC`,
    [await navioAtual(db)],
  );
  res.json(linhas);
});

rotasStock.get('/saidas', async (req, res) => {
  const db = ligacao(PAPEL);
  // Consulta 5b (Q12) do data/queries.sql, para todos os lotes
  const [linhas] = await db.execute(
    `SELECT s.id_saida,
            DATE_FORMAT(s.data_saida, '%Y-%m-%d %H:%i') AS data_saida,
            IF(s.id_escala IS NOT NULL, 'Descarga em porto', 'Transbordo') AS tipo,
            COALESCE(CONCAT(pt.nome, ' (', pt.cod_unlocode, ')'), s.navio_recetor) AS destino,
            lo.codigo_lote, po.designacao AS porao, s.n_caixas, s.comprador
       FROM saida_lote s
       JOIN lote  lo ON lo.id_lote  = s.id_lote
       JOIN porao po ON po.id_porao = s.id_porao
       LEFT JOIN escala es ON es.id_escala    = s.id_escala
       LEFT JOIN porto  pt ON pt.cod_unlocode = es.cod_porto
      WHERE po.id_navio = ?
      ORDER BY s.data_saida DESC, s.id_saida DESC
      LIMIT 50`,
    [await navioAtual(db)],
  );
  res.json(linhas);
});

// ---------------------------------------------------------------------
// POST /api/stock/saidas
// { id_lote, id_porao, id_escala?, navio_recetor?, data_saida, n_caixas, comprador? }
// Descarga em porto: id_escala; transbordo: navio_recetor. O ecrã só
// envia um dos dois, mas quem garante a regra é o CHECK ck_saida_destino.
// ---------------------------------------------------------------------

function texto(valor, campo, max) {
  const t = String(valor ?? '').trim();
  if (t.length > max) throw erroPedido(`${campo}: no máximo ${max} caracteres.`);
  return t || null;
}

function lerSaida(corpo = {}) {
  const nCaixas = Number(corpo.n_caixas);
  if (corpo.n_caixas === '' || corpo.n_caixas == null || !Number.isInteger(nCaixas)) {
    throw erroPedido('Indique o número de caixas (inteiro).');
  }
  const temEscala = !(corpo.id_escala === '' || corpo.id_escala == null);
  return {
    lote: id(corpo.id_lote, 'Escolha o lote.'),
    porao: id(corpo.id_porao, 'Escolha o porão.'),
    escala: temEscala ? id(corpo.id_escala, 'Escala inválida.') : null,
    navio: texto(corpo.navio_recetor, 'Navio recetor', 50),
    data: dataHora(corpo.data_saida, 'a data da saída', true),
    nCaixas,
    comprador: texto(corpo.comprador, 'Comprador', 100),
  };
}

rotasStock.post('/saidas', async (req, res) => {
  const s = lerSaida(req.body);

  // trg_saida_stock (RN24), CHECK ck_saida_destino (RN25) e ck_saida_caixas,
  // FK fk_saida_lote_armazenamento: a BD recusa o que não bate certo
  const [resultado] = await ligacao(PAPEL).execute(
    `INSERT INTO saida_lote (id_lote, id_porao, id_escala, navio_recetor, data_saida, n_caixas, comprador)
     VALUES (?, ?, ?, ?, ?, ?, ?)`,
    [s.lote, s.porao, s.escala, s.navio, s.data, s.nCaixas, s.comprador],
  );
  res.status(201).json({ id_saida: resultado.insertId, n_caixas: s.nCaixas });
});
