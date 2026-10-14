-- =====================================================================
-- Projeto MPD — Base de dados do navio-fábrica (sta_princesa)
-- data/testes/testes_fechar_lote.sql — testa o sp_fechar_lote (data/programmable_objects.sql, parte 2)
-- Correr depois do data/schema.sql, seed.sql, views.sql e programmable_objects.sql.
--
-- Ao contrário do testes_triggers.sql, aqui NÃO se pode envolver tudo numa transação com
-- ROLLBACK no fim: o próprio sp_fechar_lote abre e fecha a sua transação.
-- Por isso o script:
--   1. cria dados de teste na Viagem 12 (em curso): 2 turnos, 3 lances;
--   2. chama o procedimento em casos válidos e inválidos, e regista
--      quantas linhas ficaram gravadas em lote, lote_lance e armazenamento;
--   3. apaga tudo o que criou (no fim, e também no início, se uma
--      execução anterior tiver sido interrompida).
-- Os dados de teste usam ids 901+ e lotes com código 'TESTE-T12-...'.
--
-- O ponto principal é a coluna "gravado": num caso recusado tem de ser
-- "nada", mesmo quando o erro acontece no 2.º ou no 3.º passo, depois
-- de o lote já ter sido inserido (TC27 do relatório).
-- =====================================================================

USE sta_princesa;

DROP PROCEDURE IF EXISTS sp_limpar_testes_fechar_lote;
DROP PROCEDURE IF EXISTS sp_teste_fechar_lote;
DROP PROCEDURE IF EXISTS sp_testar_fechar_lote;

DELIMITER $$

-- ---------------------------------------------------------------------
-- Apaga os dados de teste e repõe os contadores AUTO_INCREMENT
-- ---------------------------------------------------------------------
CREATE PROCEDURE sp_limpar_testes_fechar_lote()
BEGIN
  DELETE a  FROM armazenamento a JOIN lote lo ON lo.id_lote = a.id_lote
            WHERE lo.codigo_lote LIKE 'TESTE-T12-%';
  DELETE ll FROM lote_lance ll   JOIN lote lo ON lo.id_lote = ll.id_lote
            WHERE lo.codigo_lote LIKE 'TESTE-T12-%';
  DELETE FROM lote    WHERE codigo_lote LIKE 'TESTE-T12-%';
  DELETE FROM captura WHERE id_lance BETWEEN 901 AND 903;
  DELETE FROM lance   WHERE id_lance BETWEEN 901 AND 903;
  DELETE FROM turno   WHERE id_turno BETWEEN 901 AND 902;
  -- = 1 repõe o contador no maior id existente + 1
  ALTER TABLE lote  AUTO_INCREMENT = 1;
  ALTER TABLE lance AUTO_INCREMENT = 1;
  ALTER TABLE turno AUTO_INCREMENT = 1;
END$$

-- ---------------------------------------------------------------------
-- Um teste: chama o procedimento e regista o resultado
-- ---------------------------------------------------------------------
CREATE PROCEDURE sp_teste_fechar_lote(
  IN p_tc       VARCHAR(5),
  IN p_teste    VARCHAR(100),
  IN p_esperado VARCHAR(10),
  IN p_codigo   VARCHAR(30),
  IN p_turno    INT,
  IN p_caixas   INT,
  IN p_lances   JSON,
  IN p_poroes   JSON)
BEGIN
  DECLARE v_msg    TEXT        DEFAULT '';
  DECLARE v_obtido VARCHAR(10) DEFAULT 'ACEITE';
  DECLARE v_id     INT;
  DECLARE v_lo0, v_ll0, v_ar0 INT;
  DECLARE v_lo1, v_ll1, v_ar1 INT;

  SELECT (SELECT COUNT(*) FROM lote), (SELECT COUNT(*) FROM lote_lance),
         (SELECT COUNT(*) FROM armazenamento)
    INTO v_lo0, v_ll0, v_ar0;

  BEGIN
    DECLARE EXIT HANDLER FOR SQLEXCEPTION BEGIN
      GET DIAGNOSTICS CONDITION 1 v_msg = MESSAGE_TEXT;
      SET v_obtido = 'RECUSADO';
    END;
    -- produto 1 = bacalhau HEG, caixas de 25 kg; entrada = fim do turno
    CALL sp_fechar_lote(p_codigo, p_turno, 1, p_caixas, p_lances, p_poroes, NULL, v_id);
  END;

  SELECT (SELECT COUNT(*) FROM lote), (SELECT COUNT(*) FROM lote_lance),
         (SELECT COUNT(*) FROM armazenamento)
    INTO v_lo1, v_ll1, v_ar1;

  INSERT INTO resultado_fechar_lote (tc, teste, esperado, obtido, gravado, mensagem)
  VALUES (p_tc, p_teste, p_esperado, v_obtido,
          IF(v_lo1 = v_lo0 AND v_ll1 = v_ll0 AND v_ar1 = v_ar0, 'nada',
             CONCAT('+', v_lo1 - v_lo0, ' lote, +', v_ll1 - v_ll0,
                    ' lance(s), +', v_ar1 - v_ar0, ' porão(ões)')),
          LEFT(v_msg, 255));
END$$

-- ---------------------------------------------------------------------
-- Todos os testes
-- ---------------------------------------------------------------------
CREATE PROCEDURE sp_testar_fechar_lote()
BEGIN
  DROP TEMPORARY TABLE IF EXISTS resultado_fechar_lote;
  CREATE TEMPORARY TABLE resultado_fechar_lote (
    n        INT AUTO_INCREMENT PRIMARY KEY,
    tc       VARCHAR(5),
    teste    VARCHAR(100),
    esperado VARCHAR(10),
    obtido   VARCHAR(10),
    gravado  VARCHAR(60),
    mensagem VARCHAR(255)
  ) ENGINE = MEMORY;

  CALL sp_limpar_testes_fechar_lote();

  -- Dados de teste na Viagem 12 (id_viagem = 2), zona 2.a, 27/08/2026.
  -- Responsável dos turnos: tripulante 14, Factory Manager da Viagem 12.
  INSERT INTO turno (id_turno, id_viagem, inicio, fim, id_responsavel) VALUES
    (901, 2, '2026-08-27 06:00', '2026-08-27 12:00', 14),
    (902, 2, '2026-08-27 12:00', '2026-08-27 18:00', 14);

  INSERT INTO lance (id_lance, id_viagem, num_lance, inicio, fim, id_zona_pesca) VALUES
    (901, 2, 901, '2026-08-27 05:00', '2026-08-27 09:30', 1),   -- acaba no turno 901
    (902, 2, 902, '2026-08-27 10:30', '2026-08-27 14:00', 1),   -- acaba no turno 902
    (903, 2, 903, '2026-08-27 15:00', NULL,               1);   -- ainda a decorrer

  INSERT INTO captura (id_lance, cod_fao, peso_vivo_kg) VALUES
    (901, 'COD', 3000.00),
    (902, 'COD', 1000.00),
    (903, 'COD',  500.00);

  -- TC31: caso normal. 80 caixas x 25 kg = 2 000 kg de produto, a partir
  -- de 3 000 kg de peso vivo (66,7 %), repartidas por dois porões.
  CALL sp_teste_fechar_lote('TC31', 'Lote de 80 cx com o lance 901, porões 1 (50) e 2 (30)', 'ACEITE',
       'TESTE-T12-COD-001', 901, 80,
       '[{"id_lance": 901, "peso_vivo_kg": 3000}]',
       '[{"id_porao": 1, "n_caixas": 50}, {"id_porao": 2, "n_caixas": 30}]');

  -- TC27: o lance 901 já foi todo usado. O lote é inserido (passo 1) e o
  -- trigger RN16 recusa no passo 2: o lote tem de desaparecer também.
  CALL sp_teste_fechar_lote('TC27', 'Lance 901 já todo usado (RN16 recusa no 2.º passo)', 'RECUSADO',
       'TESTE-T12-COD-002', 902, 20,
       '[{"id_lance": 901, "peso_vivo_kg": 500}]',
       '[{"id_porao": 1, "n_caixas": 20}]');

  -- TC32: falha no último passo — o porão 99 não existe (FK). Lote e
  -- ligação ao lance já estavam inseridos; tem de ficar "nada".
  CALL sp_teste_fechar_lote('TC32', 'Porão inexistente (FK falha no 3.º passo)', 'RECUSADO',
       'TESTE-T12-COD-003', 902, 40,
       '[{"id_lance": 902, "peso_vivo_kg": 1000}]',
       '[{"id_porao": 1, "n_caixas": 20}, {"id_porao": 99, "n_caixas": 20}]');

  -- TC33: o lance 902 só terminou às 14:00 e o turno 901 acabou às 12:00
  CALL sp_teste_fechar_lote('TC33', 'Lance 902 terminou depois do fim do turno 901', 'RECUSADO',
       'TESTE-T12-COD-004', 901, 40,
       '[{"id_lance": 902, "peso_vivo_kg": 1000}]',
       '[{"id_porao": 1, "n_caixas": 40}]');

  -- TC34: o lance 903 ainda está a decorrer (fim = NULL)
  CALL sp_teste_fechar_lote('TC34', 'Lance 903 ainda a decorrer', 'RECUSADO',
       'TESTE-T12-COD-005', 902, 10,
       '[{"id_lance": 903, "peso_vivo_kg": 300}]',
       '[{"id_porao": 1, "n_caixas": 10}]');

  -- TC35: as caixas nos porões (30) não batem com as do lote (40)
  CALL sp_teste_fechar_lote('TC35', 'Porões recebem 30 cx de um lote de 40', 'RECUSADO',
       'TESTE-T12-COD-006', 902, 40,
       '[{"id_lance": 902, "peso_vivo_kg": 1000}]',
       '[{"id_porao": 1, "n_caixas": 30}]');

  -- TC36: código de lote repetido (UNIQUE uq_lote_codigo, BR15)
  CALL sp_teste_fechar_lote('TC36', 'Código de lote já usado no TC31', 'RECUSADO',
       'TESTE-T12-COD-001', 902, 40,
       '[{"id_lance": 902, "peso_vivo_kg": 1000}]',
       '[{"id_porao": 1, "n_caixas": 40}]');

  -- TC37: produto (40 x 25 = 1 000 kg) acima da matéria-prima (900 kg):
  -- CHECK ck_lote_rendimento (RN26) recusa o passo 1
  CALL sp_teste_fechar_lote('TC37', 'Produto de 1 000 kg com 900 kg de peso vivo (RN26)', 'RECUSADO',
       'TESTE-T12-COD-007', 902, 40,
       '[{"id_lance": 902, "peso_vivo_kg": 900}]',
       '[{"id_porao": 1, "n_caixas": 40}]');

  -- TC38: depois das falhas, o lance 902 continua com os 1 000 kg livres
  -- (prova de que os TC32–TC37 não deixaram nada para trás)
  CALL sp_teste_fechar_lote('TC38', 'Lote de 27 cx com os 1 000 kg do lance 902', 'ACEITE',
       'TESTE-T12-COD-008', 902, 27,
       '[{"id_lance": 902, "peso_vivo_kg": 1000}]',
       '[{"id_porao": 2, "n_caixas": 27}]');

  -- Resultados
  SELECT n, tc, teste, esperado, obtido,
         IF(esperado = obtido
            AND (obtido = 'ACEITE') = (gravado <> 'nada'), 'OK', 'FALHOU') AS resultado,
         gravado, mensagem
  FROM resultado_fechar_lote
  ORDER BY n;

  -- Os lotes criados pelos testes aceites, como ficaram gravados
  SELECT lo.codigo_lote, lo.n_caixas, lo.peso_liquido_kg, lo.peso_materia_prima_kg,
         ROUND(100 * lo.peso_liquido_kg / lo.peso_materia_prima_kg, 1) AS rendimento_pct,
         GROUP_CONCAT(DISTINCT CONCAT('porão ', a.id_porao, ': ', a.n_caixas, ' cx')
                      ORDER BY a.id_porao SEPARATOR ', ') AS armazenamento,
         MAX(a.data_entrada) AS entrada
  FROM lote lo
  JOIN armazenamento a ON a.id_lote = lo.id_lote
  WHERE lo.codigo_lote LIKE 'TESTE-T12-%'
  GROUP BY lo.id_lote
  ORDER BY lo.codigo_lote;

  CALL sp_limpar_testes_fechar_lote();
END$$

DELIMITER ;

CALL sp_testar_fechar_lote();

-- Depois da limpeza a BD fica como o data/seed.sql a deixou
-- (esperado: 7 lotes, 10 ligações lote–lance, 8 entradas nos porões)
SELECT (SELECT COUNT(*) FROM lote)          AS lotes,
       (SELECT COUNT(*) FROM lote_lance)    AS lote_lance,
       (SELECT COUNT(*) FROM armazenamento) AS armazenamento,
       (SELECT COUNT(*) FROM lance)         AS lances,
       (SELECT COUNT(*) FROM turno)         AS turnos;
