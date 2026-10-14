-- =====================================================================
-- Projeto MPD — Base de dados do navio-fábrica (sta_princesa)
-- data/testes/testes_restricoes.sql — testes das restrições do schema
-- (CHECK, UNIQUE e FK composta): TC18, TC19, TC20, TC23, TC24 e TC25
-- do catálogo de testes (relatório 6.1), que até 14/10/2026 eram
-- manuais ou estavam por correr.
-- Correr depois do data/seed.sql e do data/programmable_objects.sql.
--
-- Tudo corre dentro de uma transação desfeita no fim (ROLLBACK): a BD
-- fica exatamente como estava. No fim aparece uma tabela com o
-- resultado de cada teste, o código do erro do MySQL e a mensagem.
--   3819 = CHECK violado · 1062 = UNIQUE · 1644 = SIGNAL de um trigger
--
-- Nota: os triggers BEFORE INSERT correm antes da verificação das FK e
-- dos CHECK. Quando um trigger já cobre o caso, é ele que recusa primeiro
-- (TC19); a restrição do schema fica como segunda garantia.
-- =====================================================================

USE sta_princesa;

DROP PROCEDURE IF EXISTS sp_testar_restricoes;

DELIMITER $$

CREATE PROCEDURE sp_testar_restricoes()
BEGIN
  DECLARE v_msg   TEXT DEFAULT '';
  DECLARE v_errno INT  DEFAULT 0;

  DROP TEMPORARY TABLE IF EXISTS resultado_restricoes;
  -- ENGINE=MEMORY: não é afetada pelo ROLLBACK do fim
  CREATE TEMPORARY TABLE resultado_restricoes (
    n          INT AUTO_INCREMENT PRIMARY KEY,
    tc         VARCHAR(5),
    restricao  VARCHAR(40),
    teste      VARCHAR(120),
    esperado   VARCHAR(10),
    obtido     VARCHAR(10),
    erro       INT,
    mensagem   VARCHAR(255)
  ) ENGINE = MEMORY;

  START TRANSACTION;

  -- TC18 — BR14: uma saída é descarga OU transbordo, nunca nenhuma das duas
  BEGIN
    DECLARE EXIT HANDLER FOR SQLEXCEPTION BEGIN
      GET DIAGNOSTICS CONDITION 1 v_msg = MESSAGE_TEXT, v_errno = MYSQL_ERRNO;
      INSERT INTO resultado_restricoes (tc, restricao, teste, esperado, obtido, erro, mensagem)
      VALUES ('TC18', 'ck_saida_destino', 'Saída do lote 4 sem escala e sem navio recetor', 'RECUSADO', 'RECUSADO', v_errno, v_msg);
    END;
    INSERT INTO saida_lote (id_lote, id_porao, id_escala, navio_recetor, data_saida, n_caixas)
    VALUES (4, 1, NULL, NULL, '2026-08-25 10:00', 1);
    INSERT INTO resultado_restricoes (tc, restricao, teste, esperado, obtido, erro, mensagem)
    VALUES ('TC18', 'ck_saida_destino', 'Saída do lote 4 sem escala e sem navio recetor', 'RECUSADO', 'ACEITE', 0, '');
  END;

  -- TC19 — BR14: só sai de um porão o que lá esteve (FK composta para
  -- armazenamento). O lote 5 só esteve no porão 2.
  BEGIN
    DECLARE EXIT HANDLER FOR SQLEXCEPTION BEGIN
      GET DIAGNOSTICS CONDITION 1 v_msg = MESSAGE_TEXT, v_errno = MYSQL_ERRNO;
      INSERT INTO resultado_restricoes (tc, restricao, teste, esperado, obtido, erro, mensagem)
      VALUES ('TC19', 'fk_saida_lote_armazenamento', 'Saída do lote 5 do porão 1, onde nunca esteve', 'RECUSADO', 'RECUSADO', v_errno, v_msg);
    END;
    INSERT INTO saida_lote (id_lote, id_porao, id_escala, navio_recetor, data_saida, n_caixas)
    VALUES (5, 1, 2, NULL, '2026-08-25 10:00', 1);
    INSERT INTO resultado_restricoes (tc, restricao, teste, esperado, obtido, erro, mensagem)
    VALUES ('TC19', 'fk_saida_lote_armazenamento', 'Saída do lote 5 do porão 1, onde nunca esteve', 'RECUSADO', 'ACEITE', 0, '');
  END;

  -- TC20 — BR11: o peso do produto não excede o da matéria-prima
  BEGIN
    DECLARE EXIT HANDLER FOR SQLEXCEPTION BEGIN
      GET DIAGNOSTICS CONDITION 1 v_msg = MESSAGE_TEXT, v_errno = MYSQL_ERRNO;
      INSERT INTO resultado_restricoes (tc, restricao, teste, esperado, obtido, erro, mensagem)
      VALUES ('TC20', 'ck_lote_rendimento', 'Lote com 400 kg de produto e 300 kg de matéria-prima', 'RECUSADO', 'RECUSADO', v_errno, v_msg);
    END;
    INSERT INTO lote (codigo_lote, id_turno, id_produto, n_caixas, peso_liquido_kg, peso_materia_prima_kg)
    VALUES ('TESTE-TC20', 1, 1, 16, 400.00, 300.00);
    INSERT INTO resultado_restricoes (tc, restricao, teste, esperado, obtido, erro, mensagem)
    VALUES ('TC20', 'ck_lote_rendimento', 'Lote com 400 kg de produto e 300 kg de matéria-prima', 'RECUSADO', 'ACEITE', 0, '');
  END;

  -- TC23 — BR01: o IMO identifica o navio e é único
  BEGIN
    DECLARE EXIT HANDLER FOR SQLEXCEPTION BEGIN
      GET DIAGNOSTICS CONDITION 1 v_msg = MESSAGE_TEXT, v_errno = MYSQL_ERRNO;
      INSERT INTO resultado_restricoes (tc, restricao, teste, esperado, obtido, erro, mensagem)
      VALUES ('TC23', 'uq_navio_imo', 'Segundo navio com o IMO 9000001', 'RECUSADO', 'RECUSADO', v_errno, v_msg);
    END;
    INSERT INTO navio (imo, nome) VALUES (9000001, 'Navio Repetido');
    INSERT INTO resultado_restricoes (tc, restricao, teste, esperado, obtido, erro, mensagem)
    VALUES ('TC23', 'uq_navio_imo', 'Segundo navio com o IMO 9000001', 'RECUSADO', 'ACEITE', 0, '');
  END;

  -- TC24 — BR03: a escala de chegada é diferente da de partida.
  -- Escala 95 só com ATA (sem horas de partida), para o trigger da
  -- chegada (RN33) não recusar antes e ser mesmo o CHECK a decidir.
  INSERT INTO escala (id_escala, id_navio, cod_porto, ata)
  VALUES (95, 1, 'NOTOS', '2026-09-10 10:00');

  BEGIN
    DECLARE EXIT HANDLER FOR SQLEXCEPTION BEGIN
      GET DIAGNOSTICS CONDITION 1 v_msg = MESSAGE_TEXT, v_errno = MYSQL_ERRNO;
      INSERT INTO resultado_restricoes (tc, restricao, teste, esperado, obtido, erro, mensagem)
      VALUES ('TC24', 'ck_viagem_escalas', 'Viagem com a escala 95 como partida e como chegada', 'RECUSADO', 'RECUSADO', v_errno, v_msg);
    END;
    INSERT INTO viagem (id_navio, num_viagem, id_escala_partida, id_escala_chegada)
    VALUES (1, 99, 95, 95);
    INSERT INTO resultado_restricoes (tc, restricao, teste, esperado, obtido, erro, mensagem)
    VALUES ('TC24', 'ck_viagem_escalas', 'Viagem com a escala 95 como partida e como chegada', 'RECUSADO', 'ACEITE', 0, '');
  END;

  -- TC25 — BR04 / FR13: numa escala, a partida real é depois da chegada real
  BEGIN
    DECLARE EXIT HANDLER FOR SQLEXCEPTION BEGIN
      GET DIAGNOSTICS CONDITION 1 v_msg = MESSAGE_TEXT, v_errno = MYSQL_ERRNO;
      INSERT INTO resultado_restricoes (tc, restricao, teste, esperado, obtido, erro, mensagem)
      VALUES ('TC25', 'ck_escala_real', 'Escala 2: ATD 24/08 05:00, antes da ATA 05:40 (UPDATE)', 'RECUSADO', 'RECUSADO', v_errno, v_msg);
    END;
    UPDATE escala SET atd = '2026-08-24 05:00' WHERE id_escala = 2;
    INSERT INTO resultado_restricoes (tc, restricao, teste, esperado, obtido, erro, mensagem)
    VALUES ('TC25', 'ck_escala_real', 'Escala 2: ATD 24/08 05:00, antes da ATA 05:40 (UPDATE)', 'RECUSADO', 'ACEITE', 0, '');
  END;

  -- Desfaz todas as alterações feitas pelos testes
  ROLLBACK;

  SELECT n, tc, restricao, teste, esperado, obtido,
         IF(esperado = obtido, 'OK', 'FALHOU') AS resultado,
         erro, mensagem
  FROM resultado_restricoes
  ORDER BY n;
END$$

DELIMITER ;

CALL sp_testar_restricoes();
