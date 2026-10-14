-- =====================================================================
-- Projeto MPD — Base de dados do navio-fábrica (sta_princesa)
-- data/queries.sql — 17 consultas de análise (Q01–Q17), em 8 grupos
-- Correr depois do data/views.sql (as consultas Q04–Q05 e Q08–Q10 usam
-- as vistas). Só lê dados: pode ser corrido as vezes que for preciso.
--
--   Grupo                                 Consultas    Requisito
--   1. Rendimento da fábrica              Q01–Q03      FR12
--   2. Quota consumida (v_quota_consumo)  Q04–Q05      FR09
--   3. Reconciliação com o fator          Q06–Q07      FR12
--   4. Stock a bordo (v_stock)            Q08–Q10      FR10
--   5. Rastreabilidade de uma caixa       Q11–Q12      FR11
--   6. Tripulação                         Q13–Q15      FR12
--   7. Documentos a caducar               Q16          FR12
--   8. Controlo: coerência temporal       Q17          BR16
--
-- Cada consulta tem também o número do grupo (1a, 2b, ...), que é o
-- usado no relatório ("consulta 5", "consulta 8").
-- Parâmetros: Q06–Q07, Q11–Q12, Q13 e Q16 usam variáveis (@...) definidas
-- logo antes. No DBeaver correr com Alt+X (script inteiro), para as
-- variáveis ficarem na mesma sessão.
-- =====================================================================

USE sta_princesa;
-- =====================================================================
-- 1. RENDIMENTO DA FÁBRICA
--    rendimento = peso do produto / peso da matéria-prima (peso vivo)
--    Bacalhau HEG ronda os 66 % (perde cabeça e vísceras);
--    camarão inteiro (WHL) fica perto dos 99 %.
-- =====================================================================

-- Q01 (1a). Por lote
--     A última coluna confirma que o peso de matéria-prima registado
--     no lote é igual à soma do que veio dos lances (lote_lance).
SELECT lo.codigo_lote,
       p.cod_fao                                          AS especie,
       p.cod_apresentacao                                 AS apresentacao,
       t.id_turno,
       DATE_FORMAT(t.inicio, '%d/%m %H:%i')               AS inicio_turno,
       CONCAT(tr.nomes_proprios, ' ', tr.apelido)         AS responsavel,
       lo.n_caixas,
       lo.peso_liquido_kg,
       lo.peso_materia_prima_kg,
       ROUND(100 * lo.peso_liquido_kg / lo.peso_materia_prima_kg, 2) AS rendimento_pct,
       IF(lo.peso_materia_prima_kg = ll.peso_lances, 'OK', 'DIFERENTE') AS confere_lances
FROM lote lo
JOIN turno      t  ON t.id_turno       = lo.id_turno
JOIN tripulante tr ON tr.id_tripulante = t.id_responsavel
JOIN produto    p  ON p.id_produto     = lo.id_produto
JOIN (SELECT id_lote, SUM(peso_vivo_kg) AS peso_lances
      FROM lote_lance GROUP BY id_lote) ll ON ll.id_lote = lo.id_lote
ORDER BY t.inicio;

-- Q02 (1b). Por turno (um turno pode produzir vários lotes)
--     O rendimento é SUM/SUM (ponderado pelo peso), não a média das
--     percentagens dos lotes — um lote pequeno não pode pesar o mesmo
--     que um lote grande.
SELECT t.id_turno,
       v.num_viagem,
       DATE_FORMAT(t.inicio, '%d/%m %H:%i')               AS inicio,
       DATE_FORMAT(t.fim,    '%H:%i')                     AS fim,
       CONCAT(tr.nomes_proprios, ' ', tr.apelido)         AS responsavel,
       p.cod_fao                                          AS especie,
       COUNT(*)                                           AS n_lotes,
       SUM(lo.n_caixas)                                   AS caixas,
       SUM(lo.peso_liquido_kg)                            AS produto_kg,
       SUM(lo.peso_materia_prima_kg)                      AS materia_prima_kg,
       ROUND(100 * SUM(lo.peso_liquido_kg) / SUM(lo.peso_materia_prima_kg), 2) AS rendimento_pct
FROM turno t
JOIN viagem     v  ON v.id_viagem      = t.id_viagem
JOIN tripulante tr ON tr.id_tripulante = t.id_responsavel
JOIN lote       lo ON lo.id_turno      = t.id_turno
JOIN produto    p  ON p.id_produto     = lo.id_produto
GROUP BY t.id_turno, v.num_viagem, t.inicio, t.fim, tr.nomes_proprios, tr.apelido, p.cod_fao
ORDER BY t.inicio;

-- Q03 (1c). Comparação entre responsáveis (Factory Manager vs 2nd), por espécie
--     Só faz sentido comparar dentro da mesma espécie/apresentação.
SELECT p.cod_fao                                          AS especie,
       ps.designacao                                      AS posto,
       CONCAT(tr.nomes_proprios, ' ', tr.apelido)         AS responsavel,
       COUNT(DISTINCT t.id_turno)                         AS turnos,
       SUM(lo.n_caixas)                                   AS caixas,
       ROUND(100 * SUM(lo.peso_liquido_kg) / SUM(lo.peso_materia_prima_kg), 2) AS rendimento_pct
FROM lote lo
JOIN turno             t  ON t.id_turno       = lo.id_turno
JOIN produto           p  ON p.id_produto     = lo.id_produto
JOIN tripulante        tr ON tr.id_tripulante = t.id_responsavel
JOIN tripulacao_viagem tv ON tv.id_viagem     = t.id_viagem
                         AND tv.id_tripulante = t.id_responsavel
JOIN posto             ps ON ps.id_posto      = tv.id_posto
GROUP BY p.cod_fao, ps.designacao, tr.nomes_proprios, tr.apelido
ORDER BY p.cod_fao, rendimento_pct DESC;


-- =====================================================================
-- 2. QUOTA CONSUMIDA POR ESPÉCIE E ZONA (RN19) — sobre a vista v_quota_consumo
--    A vista (data/views.sql) dá uma linha por quota (navio, espécie,
--    zona, ano) com o capturado, o restante, a percentagem e o estado
--    (ATENÇÃO ≥ 75 %, CRÍTICO ≥ 90 %), com o mesmo cálculo do
--    trg_captura_quota. É a fonte do painel de quotas (UI04).
-- =====================================================================


-- Q04 (2a). Painel de quotas (o que o ecrã UI04 mostra)
--     Esperado (2026): COD 2.a 4,33 % · COD 2.b NO 5,76 %
--                      COD 2.b Svalbard 3,50 % · PRA 2.b Svalbard 9,33 %
--     (todas OK)
SELECT navio, ano, cod_fao AS especie, codigo_ices, jurisdicao,
       quota_kg, capturado_kg, restante_kg, consumida_pct, estado
FROM v_quota_consumo
ORDER BY ano, cod_fao, codigo_ices, jurisdicao;

-- Q05 (2b). Quotas em alerta (ATENÇÃO ou CRÍTICO), da mais consumida para a
--     menos. Esperado com os dados de teste: nenhuma linha.
SELECT cod_fao AS especie, codigo_ices, jurisdicao, consumida_pct, estado
FROM v_quota_consumo
WHERE estado <> 'OK'
ORDER BY consumida_pct DESC;


-- =====================================================================
-- 3. RECONCILIAÇÃO: PESO VIVO vs PRODUTO x FATOR DE CONVERSÃO (RN18)
--    Peso vivo estimado = peso do produto x fator.
--    Se o diário (ERS) e a produção da fábrica não baterem certo, ou o
--    fator está mal, ou houve captura não declarada / mal pesada.
--    @tolerancia_pct é um valor de exemplo, a confirmar com o armador.
-- =====================================================================
SET @tolerancia_pct = 2.0;

-- Q06 (3a). Por lote: matéria-prima que entrou vs o que o produto "explica"
SELECT lo.codigo_lote,
       p.cod_fao                                          AS especie,
       p.cod_apresentacao                                 AS apresentacao,
       fc.fator,
       lo.peso_liquido_kg                                 AS produto_kg,
       ROUND(lo.peso_liquido_kg * fc.fator, 2)            AS peso_vivo_estimado_kg,
       lo.peso_materia_prima_kg                           AS peso_vivo_registado_kg,
       ROUND(lo.peso_materia_prima_kg - lo.peso_liquido_kg * fc.fator, 2) AS diferenca_kg,
       ROUND(100 * (lo.peso_materia_prima_kg - lo.peso_liquido_kg * fc.fator)
                 / lo.peso_materia_prima_kg, 2)           AS diferenca_pct,
       IF(ABS(100 * (lo.peso_materia_prima_kg - lo.peso_liquido_kg * fc.fator)
                  / lo.peso_materia_prima_kg) <= @tolerancia_pct,
          'OK', 'VERIFICAR')                              AS estado
FROM lote lo
JOIN produto         p  ON p.id_produto        = lo.id_produto
JOIN fator_conversao fc ON fc.cod_fao          = p.cod_fao
                       AND fc.cod_apresentacao = p.cod_apresentacao
ORDER BY lo.id_lote;

-- Q07 (3b). Por viagem e espécie: tudo o que foi capturado (diário de pesca)
--     vs tudo o que a fábrica produziu x fator.
--     Capturas e produção são somadas em CTE separadas: se fossem
--     juntas num só JOIN, cada captura repetia-se por cada lote.
--     "por_processar_kg" = capturado que ainda não entrou em nenhum lote.
WITH capturado AS (
    SELECT l.id_viagem, c.cod_fao, SUM(c.peso_vivo_kg) AS peso_vivo_kg
    FROM captura c
    JOIN lance l ON l.id_lance = c.id_lance
    GROUP BY l.id_viagem, c.cod_fao
),
processado AS (
    SELECT l.id_viagem, p.cod_fao, SUM(ll.peso_vivo_kg) AS peso_vivo_kg
    FROM lote_lance ll
    JOIN lance   l  ON l.id_lance   = ll.id_lance
    JOIN lote    lo ON lo.id_lote   = ll.id_lote
    JOIN produto p  ON p.id_produto = lo.id_produto
    GROUP BY l.id_viagem, p.cod_fao
),
produzido AS (
    SELECT t.id_viagem, p.cod_fao,
           SUM(lo.peso_liquido_kg)            AS produto_kg,
           SUM(lo.peso_liquido_kg * fc.fator) AS peso_vivo_estimado_kg
    FROM lote lo
    JOIN turno           t  ON t.id_turno          = lo.id_turno
    JOIN produto         p  ON p.id_produto        = lo.id_produto
    JOIN fator_conversao fc ON fc.cod_fao          = p.cod_fao
                           AND fc.cod_apresentacao = p.cod_apresentacao
    GROUP BY t.id_viagem, p.cod_fao
)
SELECT v.num_viagem,
       ca.cod_fao                                         AS especie,
       ca.peso_vivo_kg                                    AS capturado_kg,
       COALESCE(pr.peso_vivo_kg, 0)                       AS processado_kg,
       ca.peso_vivo_kg - COALESCE(pr.peso_vivo_kg, 0)     AS por_processar_kg,
       COALESCE(pd.produto_kg, 0)                         AS produto_kg,
       ROUND(COALESCE(pd.peso_vivo_estimado_kg, 0), 2)    AS peso_vivo_estimado_kg,
       ROUND(COALESCE(pr.peso_vivo_kg, 0) - COALESCE(pd.peso_vivo_estimado_kg, 0), 2) AS diferenca_kg,
       ROUND(100 * (COALESCE(pr.peso_vivo_kg, 0) - COALESCE(pd.peso_vivo_estimado_kg, 0))
                 / NULLIF(pr.peso_vivo_kg, 0), 2)         AS diferenca_pct
FROM capturado ca
JOIN viagem v ON v.id_viagem = ca.id_viagem
LEFT JOIN processado pr ON pr.id_viagem = ca.id_viagem AND pr.cod_fao = ca.cod_fao
LEFT JOIN produzido  pd ON pd.id_viagem = ca.id_viagem AND pd.cod_fao = ca.cod_fao
ORDER BY v.num_viagem, ca.cod_fao;


-- =====================================================================
-- 4. STOCK A BORDO POR PORÃO E POR LOTE — sobre a vista v_stock
--    A vista (data/views.sql) dá o stock de cada lote em cada porão
--    (caixas armazenadas − caixas saídas desse porão), o mesmo cálculo
--    que o trg_saida_stock (RN24) faz para uma linha.
-- =====================================================================


-- Q08 (4a). Detalhe: o que está em cada porão (só linhas com stock)
--     Esperado: Porão 1 → lote 4 = 97, lote 6 = 150
--               Porão 2 → lote 6 = 114, lote 7 = 234
SELECT po.designacao                                      AS porao,
       lo.codigo_lote,
       pr.cod_fao                                         AS especie,
       pr.cod_apresentacao                                AS apresentacao,
       vs.armazenado,
       vs.saido,
       vs.stock_caixas,
       vs.stock_caixas * pr.peso_caixa_kg                 AS stock_kg
FROM v_stock vs
JOIN porao   po ON po.id_porao   = vs.id_porao
JOIN lote    lo ON lo.id_lote    = vs.id_lote
JOIN produto pr ON pr.id_produto = lo.id_produto
WHERE vs.stock_caixas > 0
ORDER BY po.id_porao, lo.codigo_lote;

-- Q09 (4b). Resumo por porão e ocupação face à capacidade (RN22)
--     LEFT JOIN: um porão vazio também tem de aparecer (com 0).
SELECT po.designacao                                      AS porao,
       po.capacidade_caixas,
       COUNT(CASE WHEN vs.stock_caixas > 0 THEN 1 END)    AS lotes_a_bordo,
       COALESCE(SUM(vs.stock_caixas), 0)                  AS stock_caixas,
       COALESCE(SUM(vs.stock_caixas * pr.peso_caixa_kg), 0) AS stock_kg,
       po.capacidade_caixas - COALESCE(SUM(vs.stock_caixas), 0) AS livre_caixas,
       ROUND(100 * COALESCE(SUM(vs.stock_caixas), 0) / po.capacidade_caixas, 2) AS ocupacao_pct
FROM porao po
LEFT JOIN v_stock vs ON vs.id_porao   = po.id_porao
LEFT JOIN lote    lo ON lo.id_lote    = vs.id_lote
LEFT JOIN produto pr ON pr.id_produto = lo.id_produto
GROUP BY po.id_porao, po.designacao, po.capacidade_caixas
ORDER BY po.id_porao;

-- Q10 (4c). Resumo por espécie (o que o comprador vai querer saber)
SELECT pr.cod_fao                                         AS especie,
       e.nome_comum,
       SUM(vs.stock_caixas)                               AS stock_caixas,
       SUM(vs.stock_caixas * pr.peso_caixa_kg)            AS stock_kg
FROM v_stock vs
JOIN lote    lo ON lo.id_lote    = vs.id_lote
JOIN produto pr ON pr.id_produto = lo.id_produto
JOIN especie e  ON e.cod_fao     = pr.cod_fao
WHERE vs.stock_caixas > 0
GROUP BY pr.cod_fao, e.nome_comum;


-- =====================================================================
-- 5. RASTREABILIDADE DE UMA CAIXA (RN17)
--    A partir do código impresso na caixa: de que lances veio o peixe,
--    em que zonas e datas, quem o processou e para onde foi o lote.
--    Exemplo: o lote SP-T11-COD-004 junta bacalhau de DUAS zonas
--    (2.b ZEE Noruega e 2.b Svalbard) e teve um transbordo.
-- =====================================================================
SET @codigo_lote = 'SP-T11-COD-004';

-- Q11 (5a). Origem: lote → turno → lances → zonas
SELECT lo.codigo_lote,
       e.nome_comum                                       AS especie,
       v.num_viagem,
       DATE_FORMAT(t.inicio, '%d/%m/%Y %H:%i')            AS turno_inicio,
       CONCAT(tr.nomes_proprios, ' ', tr.apelido)         AS responsavel_turno,
       la.num_lance,
       DATE_FORMAT(la.inicio, '%d/%m/%Y %H:%i')           AS lance_inicio,
       DATE_FORMAT(la.fim,    '%d/%m/%Y %H:%i')           AS lance_fim,
       z.codigo_ices,
       z.jurisdicao,
       la.latitude,
       la.longitude,
       la.profundidade_m,
       ll.peso_vivo_kg                                    AS peso_vivo_usado_kg,
       ROUND(100 * ll.peso_vivo_kg / lo.peso_materia_prima_kg, 1) AS pct_do_lote
FROM lote lo
JOIN produto    p  ON p.id_produto     = lo.id_produto
JOIN especie    e  ON e.cod_fao        = p.cod_fao
JOIN turno      t  ON t.id_turno       = lo.id_turno
JOIN viagem     v  ON v.id_viagem      = t.id_viagem
JOIN tripulante tr ON tr.id_tripulante = t.id_responsavel
JOIN lote_lance ll ON ll.id_lote       = lo.id_lote
JOIN lance      la ON la.id_lance      = ll.id_lance
JOIN zona_pesca z  ON z.id_zona        = la.id_zona_pesca
WHERE lo.codigo_lote = @codigo_lote
ORDER BY la.inicio;

-- Q12 (5b). Destino: em que porão entrou e o que já saiu (descarga ou transbordo)
--     UNION ALL junta numa só lista as entradas e as saídas do lote.
SELECT *
FROM (
    SELECT a.data_entrada                                 AS data,
           'Entrada no porão'                             AS movimento,
           po.designacao                                  AS porao,
           a.n_caixas                                     AS caixas,
           NULL                                           AS destino,
           NULL                                           AS comprador
    FROM armazenamento a
    JOIN lote  lo ON lo.id_lote  = a.id_lote
    JOIN porao po ON po.id_porao = a.id_porao
    WHERE lo.codigo_lote = @codigo_lote

    UNION ALL

    SELECT s.data_saida,
           IF(s.id_escala IS NOT NULL, 'Descarga em porto', 'Transbordo'),
           po.designacao,
           -s.n_caixas,                                   -- negativo = saída
           COALESCE(CONCAT(pt.nome, ' (', pt.cod_unlocode, ')'), s.navio_recetor),
           s.comprador
    FROM saida_lote s
    JOIN lote  lo ON lo.id_lote  = s.id_lote
    JOIN porao po ON po.id_porao = s.id_porao
    LEFT JOIN escala es ON es.id_escala   = s.id_escala
    LEFT JOIN porto  pt ON pt.cod_unlocode = es.cod_porto
    WHERE lo.codigo_lote = @codigo_lote
) mov
ORDER BY data;


-- =====================================================================
-- 6. TRIPULAÇÃO
-- =====================================================================

-- Q13 (6a). Quem está a bordo numa data
--     Primeiro encontra a viagem em curso nessa data (entre a partida
--     de uma escala e a chegada à seguinte; chegada NULL = ainda no
--     mar) e depois lista a sua tripulação. Usa as horas reais e, se
--     faltarem, as previstas.
--     Nota: com o navio em porto (entre viagens) não devolve nada.
--     Experimentar: '2026-07-20 12:00' (Viagem 11, 12 pessoas)
--                   '2026-09-15 12:00' (Viagem 12, 5 pessoas)
SET @data = '2026-07-20 12:00';

SELECT v.num_viagem,
       ps.departamento,
       ps.designacao                                      AS posto,
       CONCAT(tr.nomes_proprios, ' ', tr.apelido)         AS tripulante,
       tr.nacionalidade
FROM viagem v
JOIN escala ep ON ep.id_escala = v.id_escala_partida
LEFT JOIN escala ec ON ec.id_escala = v.id_escala_chegada
JOIN tripulacao_viagem tv ON tv.id_viagem     = v.id_viagem
JOIN tripulante        tr ON tr.id_tripulante = tv.id_tripulante
JOIN posto             ps ON ps.id_posto      = tv.id_posto
WHERE COALESCE(ep.atd, ep.etd) <= @data
  AND (v.id_escala_chegada IS NULL OR COALESCE(ec.ata, ec.eta) >= @data)
ORDER BY ps.id_posto, tr.apelido;

-- Q14 (6b). Quem ficou a bordo de uma viagem para a seguinte (RN9)
--     Auto-junção de tripulacao_viagem: a mesma pessoa na viagem N
--     (sem desembarque) e na viagem N+1 do mesmo navio.
--     Mostra também se mudou de posto (RN8).
--     Esperado: Lopes (Trawlboss → Fisherman), Kovalenko, Sousa
SELECT v1.num_viagem                                      AS viagem,
       v2.num_viagem                                      AS viagem_seguinte,
       CONCAT(tr.nomes_proprios, ' ', tr.apelido)         AS tripulante,
       p1.designacao                                      AS posto_antes,
       p2.designacao                                      AS posto_depois,
       IF(tv1.id_posto <> tv2.id_posto, 'SIM', 'não')     AS mudou_posto
FROM tripulacao_viagem tv1
JOIN viagem v1 ON v1.id_viagem = tv1.id_viagem
JOIN viagem v2 ON v2.id_navio   = v1.id_navio
              AND v2.num_viagem = v1.num_viagem + 1
JOIN tripulacao_viagem tv2 ON tv2.id_viagem     = v2.id_viagem
                          AND tv2.id_tripulante = tv1.id_tripulante
JOIN tripulante tr ON tr.id_tripulante = tv1.id_tripulante
JOIN posto      p1 ON p1.id_posto      = tv1.id_posto
JOIN posto      p2 ON p2.id_posto      = tv2.id_posto
WHERE tv1.id_escala_desembarque IS NULL
ORDER BY v1.num_viagem, tr.apelido;

-- Q15 (6c). Controlo da RN9: ficou a bordo no fim de uma viagem já
--     terminada, mas não aparece na viagem seguinte (dado incoerente).
--     Esperado: nenhuma linha.
SELECT v1.num_viagem,
       CONCAT(tr.nomes_proprios, ' ', tr.apelido)         AS tripulante
FROM tripulacao_viagem tv1
JOIN viagem     v1 ON v1.id_viagem     = tv1.id_viagem
JOIN tripulante tr ON tr.id_tripulante = tv1.id_tripulante
WHERE tv1.id_escala_desembarque IS NULL
  AND v1.id_escala_chegada IS NOT NULL
  AND NOT EXISTS (
        SELECT 1
        FROM viagem v2
        JOIN tripulacao_viagem tv2 ON tv2.id_viagem = v2.id_viagem
        WHERE v2.id_navio       = v1.id_navio
          AND v2.num_viagem     = v1.num_viagem + 1
          AND tv2.id_tripulante = tv1.id_tripulante);


-- =====================================================================
-- 7. EXTRA — DOCUMENTOS A CADUCAR — Q16
--    Documentos com validade nos próximos @meses meses, dos tripulantes
--    que estão na viagem em curso ou que ficaram a bordo. Útil antes de
--    uma escala (a declaração de chegada pede passaportes/vistos válidos).
--    Esperado com @hoje = 2026-10-06 e 6 meses: Lopes (passaporte,
--    15/12/2026) e Kovalenko (visto NO, 31/01/2027).
-- =====================================================================
SET @hoje  = '2026-10-06';
SET @meses = 6;

SELECT CONCAT(tr.nomes_proprios, ' ', tr.apelido)         AS tripulante,
       td.designacao                                      AS documento,
       d.numero,
       d.cod_pais_emissor                                 AS pais,
       DATE_FORMAT(d.data_validade, '%d/%m/%Y')           AS validade,
       DATEDIFF(d.data_validade, @hoje)                   AS dias_restantes,
       IF(d.data_validade < @hoje, 'CADUCADO', 'A CADUCAR') AS estado
FROM documento d
JOIN tipo_documento td ON td.id_tipo_doc   = d.id_tipo_doc
JOIN tripulante     tr ON tr.id_tripulante = d.id_tripulante
WHERE d.data_validade IS NOT NULL
  AND d.data_validade < DATE_ADD(@hoje, INTERVAL @meses MONTH)
  AND EXISTS (SELECT 1
              FROM tripulacao_viagem tv
              JOIN viagem v ON v.id_viagem = tv.id_viagem
              WHERE tv.id_tripulante = d.id_tripulante
                AND v.id_escala_chegada IS NULL)
ORDER BY d.data_validade;


-- =====================================================================
-- 8. CONTROLO — COERÊNCIA TEMPORAL LOTE vs LANCE — Q17
--    Um lote não pode usar peixe de um lance que só chegou a bordo
--    (fim do lance) depois de o turno que fez o lote ter acabado.
--    Desde 12/10 o sp_fechar_lote recusa estes casos (BR16); esta consulta
--    controla os dados já gravados.
--    Esperado: nenhuma linha.
-- =====================================================================
SELECT lo.codigo_lote,
       t.id_turno,
       DATE_FORMAT(t.inicio, '%d/%m %H:%i')               AS turno_inicio,
       DATE_FORMAT(t.fim,    '%d/%m %H:%i')               AS turno_fim,
       la.num_lance,
       DATE_FORMAT(la.fim,   '%d/%m %H:%i')               AS lance_fim,
       TIMESTAMPDIFF(MINUTE, t.fim, la.fim)               AS minutos_depois_do_turno
FROM lote lo
JOIN turno      t  ON t.id_turno  = lo.id_turno
JOIN lote_lance ll ON ll.id_lote  = lo.id_lote
JOIN lance      la ON la.id_lance = ll.id_lance
WHERE la.fim > t.fim
ORDER BY lo.codigo_lote, la.num_lance;
