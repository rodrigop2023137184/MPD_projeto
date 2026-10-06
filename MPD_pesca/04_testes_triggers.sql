-- =====================================================================
-- Projeto MPD — Base de dados do navio-fábrica (sta_princesa)
-- 04_testes_triggers.sql — testa os 7 triggers do 03_triggers.sql
-- Correr depois do 02_dados.sql e do 03_triggers.sql.
--
-- Cada teste tenta um INSERT e regista se foi ACEITE ou RECUSADO.
-- Tudo corre dentro de uma transação que é desfeita no fim (ROLLBACK):
-- os dados da base de dados ficam exatamente como estavam.
-- No fim aparece uma tabela com o resultado de cada teste.
-- =====================================================================

USE sta_princesa;

DROP PROCEDURE IF EXISTS sp_testar_triggers;

DELIMITER $$

CREATE PROCEDURE sp_testar_triggers()
BEGIN
  DECLARE v_msg TEXT DEFAULT '';

  DROP TEMPORARY TABLE IF EXISTS resultado_testes;
  -- ENGINE=MEMORY: não é afetada pelo ROLLBACK do fim
  CREATE TEMPORARY TABLE resultado_testes (
    n         INT AUTO_INCREMENT PRIMARY KEY,
    trigger_  VARCHAR(40),
    teste     VARCHAR(120),
    esperado  VARCHAR(10),
    obtido    VARCHAR(10),
    mensagem  VARCHAR(255)
  ) ENGINE = MEMORY;

  START TRANSACTION;

  -- =================================================================
  -- Preparação (também são testes: têm de ser aceites)
  -- =================================================================

  -- Lance 9 (viagem 1, zona 2.a Noruega) e lance 10 (viagem 2)
  BEGIN
    DECLARE EXIT HANDLER FOR SQLEXCEPTION BEGIN
      GET DIAGNOSTICS CONDITION 1 v_msg = MESSAGE_TEXT;
      INSERT INTO resultado_testes (trigger_, teste, esperado, obtido, mensagem)
      VALUES ('—', 'Preparação: lances 9 e 10', 'ACEITE', 'RECUSADO', v_msg);
    END;
    INSERT INTO lance (id_lance, id_viagem, num_lance, inicio, fim, latitude, longitude, id_zona_pesca, profundidade_m)
    VALUES (9,  1, 9, '2026-07-17 06:00', '2026-07-17 09:00', 71.100000, 17.900000, 1, 290),
           (10, 2, 1, '2026-08-27 06:00', '2026-08-27 09:30', 71.050000, 17.800000, 1, 300);
    INSERT INTO resultado_testes (trigger_, teste, esperado, obtido, mensagem)
    VALUES ('—', 'Preparação: lances 9 e 10', 'ACEITE', 'ACEITE', '');
  END;

  -- =================================================================
  -- 1. trg_captura_quota (RN19)
  -- =================================================================
  BEGIN
    DECLARE EXIT HANDLER FOR SQLEXCEPTION BEGIN
      GET DIAGNOSTICS CONDITION 1 v_msg = MESSAGE_TEXT;
      INSERT INTO resultado_testes (trigger_, teste, esperado, obtido, mensagem)
      VALUES ('trg_captura_quota', '1 000 kg de COD no lance 9 (dentro da quota)', 'ACEITE', 'RECUSADO', v_msg);
    END;
    INSERT INTO captura VALUES (9, 'COD', 1000.00);
    INSERT INTO resultado_testes (trigger_, teste, esperado, obtido, mensagem)
    VALUES ('trg_captura_quota', '1 000 kg de COD no lance 9 (dentro da quota)', 'ACEITE', 'ACEITE', '');
  END;

  BEGIN
    DECLARE EXIT HANDLER FOR SQLEXCEPTION BEGIN
      GET DIAGNOSTICS CONDITION 1 v_msg = MESSAGE_TEXT;
      INSERT INTO resultado_testes (trigger_, teste, esperado, obtido, mensagem)
      VALUES ('trg_captura_quota', '500 kg de COD no lance 10 (viagem 2)', 'ACEITE', 'RECUSADO', v_msg);
    END;
    INSERT INTO captura VALUES (10, 'COD', 500.00);
    INSERT INTO resultado_testes (trigger_, teste, esperado, obtido, mensagem)
    VALUES ('trg_captura_quota', '500 kg de COD no lance 10 (viagem 2)', 'ACEITE', 'ACEITE', '');
  END;

  BEGIN
    DECLARE EXIT HANDLER FOR SQLEXCEPTION BEGIN
      GET DIAGNOSTICS CONDITION 1 v_msg = MESSAGE_TEXT;
      INSERT INTO resultado_testes (trigger_, teste, esperado, obtido, mensagem)
      VALUES ('trg_captura_quota', 'Camarão na zona 2.a (sem quota)', 'RECUSADO', 'RECUSADO', v_msg);
    END;
    INSERT INTO captura VALUES (9, 'PRA', 300.00);
    INSERT INTO resultado_testes (trigger_, teste, esperado, obtido, mensagem)
    VALUES ('trg_captura_quota', 'Camarão na zona 2.a (sem quota)', 'RECUSADO', 'ACEITE', '');
  END;

  BEGIN
    DECLARE EXIT HANDLER FOR SQLEXCEPTION BEGIN
      GET DIAGNOSTICS CONDITION 1 v_msg = MESSAGE_TEXT;
      INSERT INTO resultado_testes (trigger_, teste, esperado, obtido, mensagem)
      VALUES ('trg_captura_quota', '390 000 kg de COD na zona 2.a (excede a quota)', 'RECUSADO', 'RECUSADO', v_msg);
    END;
    DELETE FROM captura WHERE id_lance = 10;   -- liberta o lance 10 para o teste
    INSERT INTO captura VALUES (10, 'COD', 390000.00);
    INSERT INTO resultado_testes (trigger_, teste, esperado, obtido, mensagem)
    VALUES ('trg_captura_quota', '390 000 kg de COD na zona 2.a (excede a quota)', 'RECUSADO', 'ACEITE', '');
  END;
  INSERT INTO captura VALUES (10, 'COD', 500.00);   -- repõe a captura do lance 10

  -- =================================================================
  -- 6. trg_turno_responsavel (RN28)
  -- =================================================================
  BEGIN
    DECLARE EXIT HANDLER FOR SQLEXCEPTION BEGIN
      GET DIAGNOSTICS CONDITION 1 v_msg = MESSAGE_TEXT;
      INSERT INTO resultado_testes (trigger_, teste, esperado, obtido, mensagem)
      VALUES ('trg_turno_responsavel', 'Turno da viagem 1 com o 2nd Factory Manager', 'ACEITE', 'RECUSADO', v_msg);
    END;
    INSERT INTO turno (id_turno, id_viagem, inicio, fim, id_responsavel)
    VALUES (8, 1, '2026-07-17 06:00', '2026-07-17 12:00', 5);
    INSERT INTO resultado_testes (trigger_, teste, esperado, obtido, mensagem)
    VALUES ('trg_turno_responsavel', 'Turno da viagem 1 com o 2nd Factory Manager', 'ACEITE', 'ACEITE', '');
  END;

  BEGIN
    DECLARE EXIT HANDLER FOR SQLEXCEPTION BEGIN
      GET DIAGNOSTICS CONDITION 1 v_msg = MESSAGE_TEXT;
      INSERT INTO resultado_testes (trigger_, teste, esperado, obtido, mensagem)
      VALUES ('trg_turno_responsavel', 'Turno com um Fisherman como responsável', 'RECUSADO', 'RECUSADO', v_msg);
    END;
    INSERT INTO turno (id_viagem, inicio, fim, id_responsavel)
    VALUES (1, '2026-07-17 12:00', '2026-07-17 18:00', 8);
    INSERT INTO resultado_testes (trigger_, teste, esperado, obtido, mensagem)
    VALUES ('trg_turno_responsavel', 'Turno com um Fisherman como responsável', 'RECUSADO', 'ACEITE', '');
  END;

  BEGIN
    DECLARE EXIT HANDLER FOR SQLEXCEPTION BEGIN
      GET DIAGNOSTICS CONDITION 1 v_msg = MESSAGE_TEXT;
      INSERT INTO resultado_testes (trigger_, teste, esperado, obtido, mensagem)
      VALUES ('trg_turno_responsavel', 'Factory Manager da viagem 1 num turno da viagem 2', 'RECUSADO', 'RECUSADO', v_msg);
    END;
    INSERT INTO turno (id_viagem, inicio, fim, id_responsavel)
    VALUES (2, '2026-08-27 06:00', '2026-08-27 12:00', 4);
    INSERT INTO resultado_testes (trigger_, teste, esperado, obtido, mensagem)
    VALUES ('trg_turno_responsavel', 'Factory Manager da viagem 1 num turno da viagem 2', 'RECUSADO', 'ACEITE', '');
  END;

  -- =================================================================
  -- 5. trg_lote_lance_viagem (RN16)
  --    Lote 8: bacalhau, turno 8 (viagem 1)
  -- =================================================================
  INSERT INTO lote (id_lote, codigo_lote, id_turno, id_produto, n_caixas, peso_liquido_kg, peso_materia_prima_kg)
  VALUES (8, 'TESTE-COD-001', 8, 1, 50, 1250.00, 1900.00);

  BEGIN
    DECLARE EXIT HANDLER FOR SQLEXCEPTION BEGIN
      GET DIAGNOSTICS CONDITION 1 v_msg = MESSAGE_TEXT;
      INSERT INTO resultado_testes (trigger_, teste, esperado, obtido, mensagem)
      VALUES ('trg_lote_lance_viagem', 'Lote 8 usa 1 000 kg de COD do lance 9', 'ACEITE', 'RECUSADO', v_msg);
    END;
    INSERT INTO lote_lance VALUES (8, 9, 1000.00);
    INSERT INTO resultado_testes (trigger_, teste, esperado, obtido, mensagem)
    VALUES ('trg_lote_lance_viagem', 'Lote 8 usa 1 000 kg de COD do lance 9', 'ACEITE', 'ACEITE', '');
  END;

  BEGIN
    DECLARE EXIT HANDLER FOR SQLEXCEPTION BEGIN
      GET DIAGNOSTICS CONDITION 1 v_msg = MESSAGE_TEXT;
      INSERT INTO resultado_testes (trigger_, teste, esperado, obtido, mensagem)
      VALUES ('trg_lote_lance_viagem', 'Lote 8 usa COD do lance 1 (já todo usado)', 'RECUSADO', 'RECUSADO', v_msg);
    END;
    INSERT INTO lote_lance VALUES (8, 1, 100.00);
    INSERT INTO resultado_testes (trigger_, teste, esperado, obtido, mensagem)
    VALUES ('trg_lote_lance_viagem', 'Lote 8 usa COD do lance 1 (já todo usado)', 'RECUSADO', 'ACEITE', '');
  END;

  BEGIN
    DECLARE EXIT HANDLER FOR SQLEXCEPTION BEGIN
      GET DIAGNOSTICS CONDITION 1 v_msg = MESSAGE_TEXT;
      INSERT INTO resultado_testes (trigger_, teste, esperado, obtido, mensagem)
      VALUES ('trg_lote_lance_viagem', 'Lote 8 (viagem 1) usa o lance 10 (viagem 2)', 'RECUSADO', 'RECUSADO', v_msg);
    END;
    INSERT INTO lote_lance VALUES (8, 10, 100.00);
    INSERT INTO resultado_testes (trigger_, teste, esperado, obtido, mensagem)
    VALUES ('trg_lote_lance_viagem', 'Lote 8 (viagem 1) usa o lance 10 (viagem 2)', 'RECUSADO', 'ACEITE', '');
  END;

  -- =================================================================
  -- 3. trg_armazenamento_lote e 4. trg_armazenamento_capacidade
  -- =================================================================
  BEGIN
    DECLARE EXIT HANDLER FOR SQLEXCEPTION BEGIN
      GET DIAGNOSTICS CONDITION 1 v_msg = MESSAGE_TEXT;
      INSERT INTO resultado_testes (trigger_, teste, esperado, obtido, mensagem)
      VALUES ('trg_armazenamento_lote', 'Guardar 30 das 50 caixas do lote 8 no porão 2', 'ACEITE', 'RECUSADO', v_msg);
    END;
    INSERT INTO armazenamento VALUES (8, 2, 30, '2026-07-17 16:00');
    INSERT INTO resultado_testes (trigger_, teste, esperado, obtido, mensagem)
    VALUES ('trg_armazenamento_lote', 'Guardar 30 das 50 caixas do lote 8 no porão 2', 'ACEITE', 'ACEITE', '');
  END;

  BEGIN
    DECLARE EXIT HANDLER FOR SQLEXCEPTION BEGIN
      GET DIAGNOSTICS CONDITION 1 v_msg = MESSAGE_TEXT;
      INSERT INTO resultado_testes (trigger_, teste, esperado, obtido, mensagem)
      VALUES ('trg_armazenamento_lote', 'Guardar mais 30 caixas do lote 8 (só restam 20)', 'RECUSADO', 'RECUSADO', v_msg);
    END;
    INSERT INTO armazenamento VALUES (8, 1, 30, '2026-07-17 16:00');
    INSERT INTO resultado_testes (trigger_, teste, esperado, obtido, mensagem)
    VALUES ('trg_armazenamento_lote', 'Guardar mais 30 caixas do lote 8 (só restam 20)', 'RECUSADO', 'ACEITE', '');
  END;

  -- Lote 9: lote gigante só para testar a capacidade do porão 1 (20 000 cx)
  INSERT INTO lote (id_lote, codigo_lote, id_turno, id_produto, n_caixas, peso_liquido_kg, peso_materia_prima_kg)
  VALUES (9, 'TESTE-COD-002', 8, 1, 25000, 625000.00, 937500.00);

  BEGIN
    DECLARE EXIT HANDLER FOR SQLEXCEPTION BEGIN
      GET DIAGNOSTICS CONDITION 1 v_msg = MESSAGE_TEXT;
      INSERT INTO resultado_testes (trigger_, teste, esperado, obtido, mensagem)
      VALUES ('trg_armazenamento_capacidade', 'Guardar 25 000 caixas no porão 1 (cap. 20 000)', 'RECUSADO', 'RECUSADO', v_msg);
    END;
    INSERT INTO armazenamento VALUES (9, 1, 25000, '2026-07-17 18:00');
    INSERT INTO resultado_testes (trigger_, teste, esperado, obtido, mensagem)
    VALUES ('trg_armazenamento_capacidade', 'Guardar 25 000 caixas no porão 1 (cap. 20 000)', 'RECUSADO', 'ACEITE', '');
  END;

  -- =================================================================
  -- 2. trg_saida_stock (RN24) — lote 4 tem 97 caixas no porão 1
  -- =================================================================
  BEGIN
    DECLARE EXIT HANDLER FOR SQLEXCEPTION BEGIN
      GET DIAGNOSTICS CONDITION 1 v_msg = MESSAGE_TEXT;
      INSERT INTO resultado_testes (trigger_, teste, esperado, obtido, mensagem)
      VALUES ('trg_saida_stock', 'Descarregar 50 das 97 caixas do lote 4', 'ACEITE', 'RECUSADO', v_msg);
    END;
    INSERT INTO saida_lote (id_lote, id_porao, id_escala, data_saida, n_caixas, comprador)
    VALUES (4, 1, 2, '2026-08-25 10:00', 50, 'Comprador Exemplo A');
    INSERT INTO resultado_testes (trigger_, teste, esperado, obtido, mensagem)
    VALUES ('trg_saida_stock', 'Descarregar 50 das 97 caixas do lote 4', 'ACEITE', 'ACEITE', '');
  END;

  BEGIN
    DECLARE EXIT HANDLER FOR SQLEXCEPTION BEGIN
      GET DIAGNOSTICS CONDITION 1 v_msg = MESSAGE_TEXT;
      INSERT INTO resultado_testes (trigger_, teste, esperado, obtido, mensagem)
      VALUES ('trg_saida_stock', 'Descarregar mais 60 caixas do lote 4 (restam 47)', 'RECUSADO', 'RECUSADO', v_msg);
    END;
    INSERT INTO saida_lote (id_lote, id_porao, id_escala, data_saida, n_caixas, comprador)
    VALUES (4, 1, 2, '2026-08-25 11:00', 60, 'Comprador Exemplo A');
    INSERT INTO resultado_testes (trigger_, teste, esperado, obtido, mensagem)
    VALUES ('trg_saida_stock', 'Descarregar mais 60 caixas do lote 4 (restam 47)', 'RECUSADO', 'ACEITE', '');
  END;

  -- =================================================================
  -- 7. trg_tripulacao_comandante (RN10) — viagem 2 já tem comandante
  -- =================================================================
  BEGIN
    DECLARE EXIT HANDLER FOR SQLEXCEPTION BEGIN
      GET DIAGNOSTICS CONDITION 1 v_msg = MESSAGE_TEXT;
      INSERT INTO resultado_testes (trigger_, teste, esperado, obtido, mensagem)
      VALUES ('trg_tripulacao_comandante', 'Juntar um Fisherman à viagem 2', 'ACEITE', 'RECUSADO', v_msg);
    END;
    INSERT INTO tripulacao_viagem VALUES (2, 8, 8, 2, NULL);
    INSERT INTO resultado_testes (trigger_, teste, esperado, obtido, mensagem)
    VALUES ('trg_tripulacao_comandante', 'Juntar um Fisherman à viagem 2', 'ACEITE', 'ACEITE', '');
  END;

  BEGIN
    DECLARE EXIT HANDLER FOR SQLEXCEPTION BEGIN
      GET DIAGNOSTICS CONDITION 1 v_msg = MESSAGE_TEXT;
      INSERT INTO resultado_testes (trigger_, teste, esperado, obtido, mensagem)
      VALUES ('trg_tripulacao_comandante', 'Segundo Captain na viagem 2', 'RECUSADO', 'RECUSADO', v_msg);
    END;
    INSERT INTO tripulacao_viagem VALUES (2, 1, 1, 2, NULL);
    INSERT INTO resultado_testes (trigger_, teste, esperado, obtido, mensagem)
    VALUES ('trg_tripulacao_comandante', 'Segundo Captain na viagem 2', 'RECUSADO', 'ACEITE', '');
  END;

  -- Desfaz todas as alterações feitas pelos testes
  ROLLBACK;

  SELECT n,
         trigger_ AS `trigger`,
         teste,
         esperado,
         obtido,
         IF(esperado = obtido, 'OK', 'FALHOU') AS resultado,
         mensagem
  FROM resultado_testes
  ORDER BY n;
END$$

DELIMITER ;

CALL sp_testar_triggers();
