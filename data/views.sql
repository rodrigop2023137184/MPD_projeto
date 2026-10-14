-- =====================================================================
-- Projeto MPD — Base de dados do navio-fábrica (sta_princesa)
-- data/views.sql — as 2 vistas da solução
-- Correr depois do data/seed.sql (e antes do programmable_objects.sql,
-- que dá aos utilizadores da aplicação acesso a estas vistas).
-- Pode ser corrido várias vezes (CREATE OR REPLACE VIEW).
--
--   v_quota_consumo  quota consumida por espécie, zona e ano (painel UI04,
--                    aviso do UI01; consultas Q04–Q05 do queries.sql)
--   v_stock          stock de cada lote em cada porão (UI03, UI05;
--                    consultas Q08–Q10)
-- =====================================================================

USE sta_princesa;

-- =====================================================================
-- v_quota_consumo — QUOTA CONSUMIDA POR ESPÉCIE E ZONA (RN19 / BR08)
--    Uma linha por quota (navio, espécie, zona, ano) com o capturado, o
--    restante, a percentagem e o estado. É a 2.ª vista do projeto e é a
--    fonte do painel de quotas do protótipo (UI04).
--
--    O capturado de cada quota é calculado por uma subconsulta LATERAL:
--    corre uma vez por quota e soma só as capturas dessa espécie, zona
--    e ano (navio vem da viagem, porque o lance não guarda o navio).
--    É exatamente o cálculo do trg_captura_quota, com o mesmo filtro por
--    intervalo de datas, que usa o índice ix_lance_zona_inicio. Assim o
--    trigger que recusa e o painel que avisa nunca dão valores diferentes.
--
--    Estados: alertas a 75 % e 90 %, os limites do mockup UI04.
-- =====================================================================
CREATE OR REPLACE VIEW v_quota_consumo AS
SELECT q.id_quota,
       q.id_navio,
       n.nome                                             AS navio,
       q.ano,
       q.cod_fao,
       e.nome_comum                                       AS especie,
       q.id_zona,
       z.codigo_ices,
       z.jurisdicao,
       q.quota_kg,
       c.capturado_kg,
       q.quota_kg - c.capturado_kg                        AS restante_kg,
       ROUND(100 * c.capturado_kg / q.quota_kg, 2)        AS consumida_pct,
       CASE
         WHEN c.capturado_kg >= 0.90 * q.quota_kg THEN 'CRÍTICO'
         WHEN c.capturado_kg >= 0.75 * q.quota_kg THEN 'ATENÇÃO'
         ELSE 'OK'
       END                                                AS estado
FROM quota q
JOIN navio      n ON n.id_navio = q.id_navio
JOIN especie    e ON e.cod_fao  = q.cod_fao
JOIN zona_pesca z ON z.id_zona  = q.id_zona
JOIN LATERAL (
    SELECT COALESCE(SUM(cap.peso_vivo_kg), 0) AS capturado_kg
    FROM captura cap
    JOIN lance  l ON l.id_lance  = cap.id_lance
    JOIN viagem v ON v.id_viagem = l.id_viagem
    WHERE v.id_navio      = q.id_navio
      AND cap.cod_fao     = q.cod_fao
      AND l.id_zona_pesca = q.id_zona
      AND l.inicio       >= MAKEDATE(q.ano, 1)
      AND l.inicio        < MAKEDATE(q.ano + 1, 1)
) c;

-- =====================================================================
-- v_stock — STOCK A BORDO POR PORÃO E POR LOTE
--    Vista reutilizável: stock de cada lote em cada porão
--    (caixas armazenadas - caixas saídas desse porão).
--    É o mesmo cálculo que o trg_saida_stock (RN24) faz para uma linha.
-- =====================================================================
CREATE OR REPLACE VIEW v_stock AS
SELECT a.id_porao,
       a.id_lote,
       a.n_caixas                                         AS armazenado,
       COALESCE(s.saido, 0)                               AS saido,
       a.n_caixas - COALESCE(s.saido, 0)                  AS stock_caixas
FROM armazenamento a
LEFT JOIN (SELECT id_lote, id_porao, SUM(n_caixas) AS saido
           FROM saida_lote
           GROUP BY id_lote, id_porao) s
       ON s.id_lote = a.id_lote AND s.id_porao = a.id_porao;

-- Verificação: deve listar as 2 vistas
SELECT TABLE_NAME AS vista
FROM information_schema.VIEWS
WHERE TABLE_SCHEMA = 'sta_princesa'
ORDER BY TABLE_NAME;
