-- =====================================================================
-- Projeto MPD — Base de dados do navio-fábrica (sta_princesa)
-- data/testes/indice_explain.sql — índice ix_lance_zona_inicio: EXPLAIN antes/depois
-- Correr depois do data/schema.sql e do seed.sql. Deixa os dados como estavam.
--
-- O problema: o trg_captura_quota (RN19) soma as capturas de uma zona
-- num ano. Antes filtrava com YEAR(l.inicio) = ano. Uma função aplicada
-- à coluna obriga o MySQL a calcular YEAR() linha a linha: não consegue
-- usar um índice sobre inicio.
--
-- A correção (12/10/2026):
--   1. índice composto (id_zona_pesca, inicio) na tabela lance
--      (data/schema.sql). Substitui o índice automático da FK da zona,
--      porque começa pela mesma coluna: a tabela não fica com mais um índice;
--   2. o filtro passa a intervalo de datas:
--        l.inicio >= '2026-01-01' AND l.inicio < '2027-01-01'
--      (trg_captura_quota no programmable_objects.sql, v_quota_consumo no views.sql).
--
-- Com os 8 lances do seed qualquer plano serve. Para a diferença se ver,
-- o script carrega 50 000 lances históricos fictícios (2016–2025),
-- mede, e apaga-os no fim. São identificados por num_lance > 100000.
-- =====================================================================

USE sta_princesa;

-- ---------------------------------------------------------------------
-- 0. BD criadas antes de 12/10: cria o índice se ainda não existir
--    (numa BD criada com o data/schema.sql atual já existe)
-- ---------------------------------------------------------------------
SET @existe = (SELECT COUNT(*) FROM information_schema.STATISTICS
               WHERE TABLE_SCHEMA = 'sta_princesa'
                 AND TABLE_NAME   = 'lance'
                 AND INDEX_NAME   = 'ix_lance_zona_inicio');
SET @sql = IF(@existe = 0,
              'CREATE INDEX ix_lance_zona_inicio ON lance (id_zona_pesca, inicio)',
              'DO 0');
PREPARE s FROM @sql; EXECUTE s; DEALLOCATE PREPARE s;

-- Índices da tabela lance (o da FK da zona já não aparece à parte)
SELECT INDEX_NAME AS indice,
       GROUP_CONCAT(COLUMN_NAME ORDER BY SEQ_IN_INDEX) AS colunas
FROM information_schema.STATISTICS
WHERE TABLE_SCHEMA = 'sta_princesa' AND TABLE_NAME = 'lance'
GROUP BY INDEX_NAME
ORDER BY INDEX_NAME;

-- ---------------------------------------------------------------------
-- 1. Carga de teste: 50 000 lances fictícios, um a cada 100 minutos,
--    de 2016 a 2025, repartidos pelas 3 zonas (cerca de 16 700 cada)
-- ---------------------------------------------------------------------
DELETE FROM lance WHERE num_lance > 100000;     -- restos de uma execução anterior
SET SESSION cte_max_recursion_depth = 60000;

INSERT INTO lance (id_viagem, num_lance, inicio, fim, id_zona_pesca)
WITH RECURSIVE n(i) AS (
  SELECT 1 UNION ALL SELECT i + 1 FROM n WHERE i < 50000
)
SELECT 1,
       100000 + i,
       TIMESTAMP('2016-01-01') + INTERVAL (i * 100)      MINUTE,
       TIMESTAMP('2016-01-01') + INTERVAL (i * 100 + 60) MINUTE,
       1 + (i % 3)
FROM n;

ANALYZE TABLE lance;   -- atualiza as estatísticas que o otimizador usa

-- ---------------------------------------------------------------------
-- 2. ANTES: filtro com YEAR(inicio)
--    Lances da zona 2.a (id 1) em 2026: o mesmo filtro que o trigger usa.
--    Esperado: type = ref, key_len = 4 (só a coluna id_zona_pesca) e
--    rows na casa das dezenas de milhar (é uma estimativa) — percorre
--    todos os lances da zona e calcula YEAR() em cada um. Antes de
--    12/10 o único índice útil era o da FK (id_zona_pesca) e o plano
--    era este mesmo.
-- ---------------------------------------------------------------------
SELECT 'ANTES: YEAR(l.inicio) = 2026' AS consulta;

EXPLAIN
SELECT COUNT(*)
FROM lance l
WHERE l.id_zona_pesca = 1
  AND YEAR(l.inicio) = 2026;

-- ---------------------------------------------------------------------
-- 3. DEPOIS: filtro como intervalo de datas
--    Esperado: type = range, key_len = 9 (id_zona_pesca 4 + inicio 5),
--    rows = 2 — vai diretamente aos lances de 2026 dessa zona.
-- ---------------------------------------------------------------------
SELECT 'DEPOIS: inicio >= 2026-01-01 AND inicio < 2027-01-01' AS consulta;

EXPLAIN
SELECT COUNT(*)
FROM lance l
WHERE l.id_zona_pesca = 1
  AND l.inicio >= '2026-01-01'
  AND l.inicio <  '2027-01-01';

-- ---------------------------------------------------------------------
-- 4. A mesma comparação com EXPLAIN ANALYZE: executa a consulta e
--    mostra as linhas realmente lidas (rows=) e o tempo (actual time=).
--    Medido a 12/10 (MySQL 8.0): ANTES lê 16 668 entradas do índice
--    em ~4,8 ms; DEPOIS lê 2 em ~0,02 ms. Os tempos variam de máquina
--    para máquina; as linhas lidas não.
-- ---------------------------------------------------------------------
EXPLAIN ANALYZE
SELECT COUNT(*) FROM lance l
WHERE l.id_zona_pesca = 1 AND YEAR(l.inicio) = 2026;

EXPLAIN ANALYZE
SELECT COUNT(*) FROM lance l
WHERE l.id_zona_pesca = 1
  AND l.inicio >= '2026-01-01' AND l.inicio < '2027-01-01';

-- ---------------------------------------------------------------------
-- 5. A consulta do trigger, já corrigida (captura de COD na zona 2.a,
--    2026). Esperado: começa pelo lance com range em
--    ix_lance_zona_inicio e chega à viagem e à captura pela chave
--    primária (eq_ref).
-- ---------------------------------------------------------------------
SELECT 'Consulta do trg_captura_quota (versão corrigida)' AS consulta;

EXPLAIN
SELECT COALESCE(SUM(c.peso_vivo_kg), 0)
FROM captura c
JOIN lance  l ON l.id_lance  = c.id_lance
JOIN viagem v ON v.id_viagem = l.id_viagem
WHERE v.id_navio      = 1
  AND l.id_zona_pesca = 1
  AND l.inicio       >= '2026-01-01'
  AND l.inicio        < '2027-01-01'
  AND c.cod_fao       = 'COD';

-- ---------------------------------------------------------------------
-- 6. Limpeza: apaga os lances de carga e repõe as estatísticas
-- ---------------------------------------------------------------------
DELETE FROM lance WHERE num_lance > 100000;
ANALYZE TABLE lance;

SELECT COUNT(*) AS lances_no_fim   -- esperado: 8
FROM lance;
