// UI05 — Rastrear uma caixa (FR10, RN17), com o utilizador do armador
//
//   GET /api/rastreio/lotes      códigos de lote existentes (sugestões do campo de pesquisa)
//   GET /api/rastreio/:codigo    lote, origem (lances) e destino (movimentos nos porões)
//
// Só leitura: as consultas são a 5a (origem) e a 5b (destino) do
// data/queries.sql (Q11, Q12), com o código do lote como parâmetro (?), e o stock
// ainda a bordo vem da vista v_stock.

import { Router } from 'express';
import { ligacao } from '../db.js';
import { erroPedido } from '../erros.js';

export const rotasRastreio = Router();

const PAPEL = 'armador';

const DATA = (coluna) => `DATE_FORMAT(${coluna}, '%Y-%m-%d %H:%i')`;

rotasRastreio.get('/lotes', async (req, res) => {
  const [linhas] = await ligacao(PAPEL).query(
    `SELECT lo.codigo_lote, p.cod_fao, p.cod_apresentacao, v.num_viagem
       FROM lote lo
       JOIN produto p ON p.id_produto = lo.id_produto
       JOIN turno   t ON t.id_turno   = lo.id_turno
       JOIN viagem  v ON v.id_viagem  = t.id_viagem
      ORDER BY lo.codigo_lote`,
  );
  res.json(linhas);
});

rotasRastreio.get('/:codigo', async (req, res) => {
  // O código vem impresso na caixa; aceita minúsculas e espaços à volta
  const codigo = String(req.params.codigo ?? '').trim().toUpperCase();
  if (!codigo || codigo.length > 30) throw erroPedido('Indique o código do lote (até 30 caracteres).');

  const db = ligacao(PAPEL);

  // Resumo: produto, turno, viagem e responsável
  const [[lote]] = await db.execute(
    `SELECT lo.id_lote, lo.codigo_lote, e.nome_comum AS especie, p.cod_fao,
            p.cod_apresentacao, ap.designacao AS apresentacao,
            lo.n_caixas, lo.peso_liquido_kg, lo.peso_materia_prima_kg,
            ROUND(100 * lo.peso_liquido_kg / lo.peso_materia_prima_kg, 1) AS rendimento_pct,
            v.num_viagem, ${DATA('t.inicio')} AS turno_inicio, ${DATA('t.fim')} AS turno_fim,
            CONCAT(tr.nomes_proprios, ' ', tr.apelido) AS responsavel, ps.designacao AS posto
       FROM lote lo
       JOIN produto      p  ON p.id_produto        = lo.id_produto
       JOIN especie      e  ON e.cod_fao           = p.cod_fao
       JOIN apresentacao ap ON ap.cod_apresentacao = p.cod_apresentacao
       JOIN turno        t  ON t.id_turno          = lo.id_turno
       JOIN viagem       v  ON v.id_viagem         = t.id_viagem
       JOIN tripulante   tr ON tr.id_tripulante    = t.id_responsavel
       LEFT JOIN tripulacao_viagem tv ON tv.id_viagem     = t.id_viagem
                                     AND tv.id_tripulante = t.id_responsavel
       LEFT JOIN posto ps ON ps.id_posto = tv.id_posto
      WHERE lo.codigo_lote = ?`,
    [codigo],
  );
  if (!lote) {
    return res.status(404).json({ erro: `Não existe nenhum lote com o código ${codigo}.`, codigo: null });
  }

  // 5a. Origem: lances de onde veio o peixe
  const [lances] = await db.execute(
    `SELECT la.num_lance, ${DATA('la.inicio')} AS inicio, ${DATA('la.fim')} AS fim,
            z.codigo_ices, z.jurisdicao, la.latitude, la.longitude, la.profundidade_m,
            ll.peso_vivo_kg,
            ROUND(100 * ll.peso_vivo_kg / lo.peso_materia_prima_kg, 1) AS pct_do_lote
       FROM lote_lance ll
       JOIN lote       lo ON lo.id_lote  = ll.id_lote
       JOIN lance      la ON la.id_lance = ll.id_lance
       JOIN zona_pesca z  ON z.id_zona   = la.id_zona_pesca
      WHERE ll.id_lote = ?
      ORDER BY la.inicio`,
    [lote.id_lote],
  );

  // 5b. Destino: entradas nos porões e saídas (descarga ou transbordo)
  const [movimentos] = await db.execute(
    `SELECT *
       FROM (SELECT ${DATA('a.data_entrada')} AS data, 'Entrada no porão' AS movimento,
                    po.designacao AS porao, a.n_caixas AS caixas,
                    NULL AS destino, NULL AS comprador
               FROM armazenamento a
               JOIN porao po ON po.id_porao = a.id_porao
              WHERE a.id_lote = ?
             UNION ALL
             SELECT ${DATA('s.data_saida')},
                    IF(s.id_escala IS NOT NULL, 'Descarga em porto', 'Transbordo'),
                    po.designacao, -s.n_caixas,
                    COALESCE(CONCAT(pt.nome, ' (', pt.cod_unlocode, ')'), s.navio_recetor),
                    s.comprador
               FROM saida_lote s
               JOIN porao po ON po.id_porao = s.id_porao
               LEFT JOIN escala es ON es.id_escala    = s.id_escala
               LEFT JOIN porto  pt ON pt.cod_unlocode = es.cod_porto
              WHERE s.id_lote = ?) mov
      ORDER BY data`,
    [lote.id_lote, lote.id_lote],
  );

  // O que ainda está a bordo, por porão (vista v_stock)
  const [stock] = await db.execute(
    `SELECT po.designacao AS porao, vs.stock_caixas
       FROM v_stock vs
       JOIN porao po ON po.id_porao = vs.id_porao
      WHERE vs.id_lote = ? AND vs.stock_caixas > 0
      ORDER BY po.id_porao`,
    [lote.id_lote],
  );

  res.json({ lote, lances, movimentos, stock });
});
