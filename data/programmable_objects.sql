-- =====================================================================
-- Projeto MPD — Base de dados do navio-fábrica (sta_princesa)
-- data/programmable_objects.sql — lógica da base de dados
-- Correr depois do data/views.sql, como root (cria utilizadores e dá
-- acesso às vistas e ao procedimento). Pode ser corrido várias vezes.
--
--   Parte 1  14 triggers das regras de negócio (+ procedimento auxiliar
--            sp_validar_chegada_viagem, usado só pelos triggers)
--   Parte 2  procedimento transacional sp_fechar_lote (ecrã UI02)
--   Parte 3  papéis (roles) e utilizadores MySQL por papel, com GRANT
--
-- Testes: data/testes/ (testes_triggers.sql, testes_fechar_lote.sql,
-- testes_restricoes.sql) e EXPLAIN do índice (indice_explain.sql).
-- =====================================================================

-- #####################################################################
-- PARTE 1 — TRIGGERS
-- #####################################################################
-- =====================================================================
-- Projeto MPD — Base de dados do navio-fábrica (sta_princesa)
-- Parte 1 — 14 triggers das regras de negócio
-- (Depois do data/schema.sql, seed.sql e views.sql.)
-- Pode ser corrido várias vezes: cada trigger é apagado antes de criar.
--
-- Os triggers 1–7 são BEFORE INSERT: validam a linha nova e, se violar
-- a regra, recusam o INSERT com SIGNAL SQLSTATE '45000'. Os triggers
-- 8–13 (datas dos lances, das escalas e chegada da viagem) validam o
-- INSERT e também o UPDATE. O 14 valida a abertura de uma viagem.
-- Cada mensagem começa pelo número da regra (RN..).
--
-- Regras acrescentadas a 13/10/2026 (números RN31–RN34, a seguir à
-- última do catálogo, RN30):
--   RN31  lance sem início nem fim no futuro          (triggers 8, 9)
--   RN32  escala sem ATA nem ATD no futuro            (triggers 10, 11)
--   RN33  fecho da viagem: escala do navio, com ATA,
--         depois da partida, sem lances/turnos abertos (triggers 12, 13)
--   RN34  abertura da viagem: partida numa escala do
--         navio ainda não usada como partida; uma só
--         viagem em curso por navio                   (trigger 14)
--
-- 13/10/2026 (nova viagem): trigger 14, trg_viagem_partida (RN34).
-- 13/10/2026: a mensagem do RN16 passou a mostrar o n.º do lance na
-- viagem (num_lance, o que aparece nos ecrãs) em vez do id_lance.
--
-- 13/10/2026 (FR13): triggers 10–13 e o procedimento auxiliar
-- sp_validar_chegada_viagem — ATA/ATD de uma escala não podem ser no
-- futuro (a ETA/ETD são previsões e podem); uma viagem só fecha numa
-- escala do mesmo navio, com ATA, depois da partida, e sem lances nem
-- turnos por terminar. A data de chegada não precisa de ser conhecida
-- quando a viagem começa: a escala de chegada fica NULL até ao fecho.
--
-- 13/10/2026: triggers 8 e 9 — um lance não pode ter início nem fim
-- depois da hora atual (UTC). Não pode ser um CHECK: o MySQL não aceita
-- UTC_TIMESTAMP() nem NOW() dentro de um CHECK.
--
-- 12/10/2026: trg_captura_quota filtra o ano por intervalo de datas em
-- vez de YEAR(inicio), para usar o índice ix_lance_zona_inicio.
-- Também a 12/10: trg_captura_quota e trg_lote_lance_viagem recusam com
-- mensagem clara um lance ou lote inexistente (antes: erro 1231, porque
-- a mensagem do SIGNAL ficava NULL).
-- =====================================================================

USE sta_princesa;

DROP TRIGGER IF EXISTS trg_captura_quota;
DROP TRIGGER IF EXISTS trg_saida_stock;
DROP TRIGGER IF EXISTS trg_armazenamento_lote;
DROP TRIGGER IF EXISTS trg_armazenamento_capacidade;
DROP TRIGGER IF EXISTS trg_lote_lance_viagem;
DROP TRIGGER IF EXISTS trg_turno_responsavel;
DROP TRIGGER IF EXISTS trg_tripulacao_comandante;
DROP TRIGGER IF EXISTS trg_lance_datas;
DROP TRIGGER IF EXISTS trg_lance_datas_update;
DROP TRIGGER IF EXISTS trg_escala_datas;
DROP TRIGGER IF EXISTS trg_escala_datas_update;
DROP TRIGGER IF EXISTS trg_viagem_chegada;
DROP TRIGGER IF EXISTS trg_viagem_chegada_update;
DROP TRIGGER IF EXISTS trg_viagem_partida;
DROP PROCEDURE IF EXISTS sp_validar_chegada_viagem;

DELIMITER $$

-- ---------------------------------------------------------------------
-- 1. RN19 — Uma captura não pode ultrapassar a quota do navio para
--    essa espécie, zona e ano. Sem quota definida, a captura é recusada.
--    O ano filtra-se como intervalo de datas (1 jan ≤ inicio < 1 jan do
--    ano seguinte) e não com YEAR(l.inicio): uma função sobre a coluna
--    impede o uso do índice ix_lance_zona_inicio (ver data/testes/indice_explain.sql).
-- ---------------------------------------------------------------------
CREATE TRIGGER trg_captura_quota
BEFORE INSERT ON captura
FOR EACH ROW
BEGIN
  DECLARE v_navio      INT;
  DECLARE v_zona       INT;
  DECLARE v_ano        INT;
  DECLARE v_inicio_ano DATETIME;
  DECLARE v_fim_ano    DATETIME;
  DECLARE v_quota      DECIMAL(12,2);
  DECLARE v_usado      DECIMAL(12,2);
  DECLARE v_msg        VARCHAR(128);

  -- Navio, zona e ano do lance onde foi feita a captura
  -- (aqui YEAR() não prejudica: lê-se uma só linha pela chave primária)
  SELECT v.id_navio, l.id_zona_pesca, YEAR(l.inicio)
    INTO v_navio, v_zona, v_ano
  FROM lance l
  JOIN viagem v ON v.id_viagem = l.id_viagem
  WHERE l.id_lance = NEW.id_lance;

  -- Lance inexistente: sem isto a mensagem seguinte ficava NULL (erro 1231)
  IF v_navio IS NULL THEN
    SIGNAL SQLSTATE '45000'
      SET MESSAGE_TEXT = 'RN19: o lance indicado não existe';
  END IF;

  SET v_inicio_ano = MAKEDATE(v_ano, 1);       -- 1 de janeiro
  SET v_fim_ano    = MAKEDATE(v_ano + 1, 1);   -- 1 de janeiro seguinte

  -- Quota aplicável
  SELECT q.quota_kg INTO v_quota
  FROM quota q
  WHERE q.id_navio = v_navio
    AND q.cod_fao  = NEW.cod_fao
    AND q.id_zona  = v_zona
    AND q.ano      = v_ano;

  IF v_quota IS NULL THEN
    SET v_msg = CONCAT('RN19: não existe quota de ', NEW.cod_fao,
                       ' para esta zona em ', v_ano);
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = v_msg;
  END IF;

  -- Peso vivo já capturado nessa espécie, zona e ano
  SELECT COALESCE(SUM(c.peso_vivo_kg), 0) INTO v_usado
  FROM captura c
  JOIN lance  l ON l.id_lance  = c.id_lance
  JOIN viagem v ON v.id_viagem = l.id_viagem
  WHERE v.id_navio       = v_navio
    AND l.id_zona_pesca  = v_zona
    AND l.inicio        >= v_inicio_ano
    AND l.inicio         < v_fim_ano
    AND c.cod_fao        = NEW.cod_fao;

  IF v_usado + NEW.peso_vivo_kg > v_quota THEN
    SET v_msg = CONCAT('RN19: quota excedida (', NEW.cod_fao, '): restam ',
                       v_quota - v_usado, ' kg, pedido ', NEW.peso_vivo_kg, ' kg');
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = v_msg;
  END IF;
END$$

-- ---------------------------------------------------------------------
-- 2. RN24 — Não podem sair de um porão mais caixas de um lote do que
--    as que lá estão (armazenadas nesse porão menos saídas anteriores).
-- ---------------------------------------------------------------------
CREATE TRIGGER trg_saida_stock
BEFORE INSERT ON saida_lote
FOR EACH ROW
BEGIN
  DECLARE v_armazenado INT;
  DECLARE v_saido      INT;
  DECLARE v_msg        VARCHAR(128);

  SELECT COALESCE(SUM(a.n_caixas), 0) INTO v_armazenado
  FROM armazenamento a
  WHERE a.id_lote = NEW.id_lote AND a.id_porao = NEW.id_porao;

  SELECT COALESCE(SUM(s.n_caixas), 0) INTO v_saido
  FROM saida_lote s
  WHERE s.id_lote = NEW.id_lote AND s.id_porao = NEW.id_porao;

  IF NEW.n_caixas > v_armazenado - v_saido THEN
    SET v_msg = CONCAT('RN24: stock insuficiente no porão: há ',
                       v_armazenado - v_saido, ' caixas, pedido ', NEW.n_caixas);
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = v_msg;
  END IF;
END$$

-- ---------------------------------------------------------------------
-- 3. Não se pode guardar nos porões mais caixas de um lote do que as
--    que o lote produziu (somando todos os porões).
-- ---------------------------------------------------------------------
CREATE TRIGGER trg_armazenamento_lote
BEFORE INSERT ON armazenamento
FOR EACH ROW
BEGIN
  DECLARE v_produzidas INT;
  DECLARE v_guardadas  INT;
  DECLARE v_msg        VARCHAR(128);

  SELECT lo.n_caixas INTO v_produzidas
  FROM lote lo WHERE lo.id_lote = NEW.id_lote;

  SELECT COALESCE(SUM(a.n_caixas), 0) INTO v_guardadas
  FROM armazenamento a WHERE a.id_lote = NEW.id_lote;

  IF v_guardadas + NEW.n_caixas > v_produzidas THEN
    SET v_msg = CONCAT('Lote com ', v_produzidas, ' caixas: já guardadas ',
                       v_guardadas, ', pedido ', NEW.n_caixas);
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = v_msg;
  END IF;
END$$

-- ---------------------------------------------------------------------
-- 4. RN22 — O stock de um porão (entradas menos saídas) não pode
--    ultrapassar a capacidade. Corre depois do trigger anterior.
-- ---------------------------------------------------------------------
CREATE TRIGGER trg_armazenamento_capacidade
BEFORE INSERT ON armazenamento
FOR EACH ROW
FOLLOWS trg_armazenamento_lote
BEGIN
  DECLARE v_capacidade INT;
  DECLARE v_entradas   INT;
  DECLARE v_saidas     INT;
  DECLARE v_msg        VARCHAR(128);

  SELECT p.capacidade_caixas INTO v_capacidade
  FROM porao p WHERE p.id_porao = NEW.id_porao;

  SELECT COALESCE(SUM(a.n_caixas), 0) INTO v_entradas
  FROM armazenamento a WHERE a.id_porao = NEW.id_porao;

  SELECT COALESCE(SUM(s.n_caixas), 0) INTO v_saidas
  FROM saida_lote s WHERE s.id_porao = NEW.id_porao;

  IF v_entradas - v_saidas + NEW.n_caixas > v_capacidade THEN
    SET v_msg = CONCAT('RN22: porão sem espaço: capacidade ', v_capacidade,
                       ', ocupado ', v_entradas - v_saidas, ', pedido ', NEW.n_caixas);
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = v_msg;
  END IF;
END$$

-- ---------------------------------------------------------------------
-- 5. RN16 — Um lote só pode usar peixe de lances da mesma viagem, da
--    espécie do seu produto, e sem ultrapassar o peso vivo capturado
--    dessa espécie nesse lance.
-- ---------------------------------------------------------------------
CREATE TRIGGER trg_lote_lance_viagem
BEFORE INSERT ON lote_lance
FOR EACH ROW
BEGIN
  DECLARE v_viagem_lote  INT;
  DECLARE v_viagem_lance INT;
  DECLARE v_num_lance    INT;
  DECLARE v_especie      CHAR(3);
  DECLARE v_capturado    DECIMAL(10,2);
  DECLARE v_usado        DECIMAL(10,2);
  DECLARE v_msg          VARCHAR(128);

  -- Viagem e espécie do lote (através do turno e do produto)
  SELECT t.id_viagem, p.cod_fao INTO v_viagem_lote, v_especie
  FROM lote lo
  JOIN turno   t ON t.id_turno   = lo.id_turno
  JOIN produto p ON p.id_produto = lo.id_produto
  WHERE lo.id_lote = NEW.id_lote;

  -- num_lance: o número que o utilizador vê no ecrã (o id_lance é só a chave)
  SELECT l.id_viagem, l.num_lance INTO v_viagem_lance, v_num_lance
  FROM lance l WHERE l.id_lance = NEW.id_lance;

  -- Lote ou lance inexistente: sem isto a mensagem ficava NULL (erro 1231)
  IF v_viagem_lote IS NULL THEN
    SIGNAL SQLSTATE '45000'
      SET MESSAGE_TEXT = 'RN16: o lote indicado não existe';
  END IF;
  IF v_viagem_lance IS NULL THEN
    SIGNAL SQLSTATE '45000'
      SET MESSAGE_TEXT = 'RN16: o lance indicado não existe';
  END IF;

  IF v_viagem_lote <> v_viagem_lance THEN
    SIGNAL SQLSTATE '45000'
      SET MESSAGE_TEXT = 'RN16: o lance pertence a outra viagem que não a do lote';
  END IF;

  -- Peso vivo dessa espécie capturado no lance
  SELECT COALESCE(SUM(c.peso_vivo_kg), 0) INTO v_capturado
  FROM captura c
  WHERE c.id_lance = NEW.id_lance AND c.cod_fao = v_especie;

  -- Peso dessa espécie já usado por outros lotes
  SELECT COALESCE(SUM(ll.peso_vivo_kg), 0) INTO v_usado
  FROM lote_lance ll
  JOIN lote    lo ON lo.id_lote    = ll.id_lote
  JOIN produto p  ON p.id_produto  = lo.id_produto
  WHERE ll.id_lance = NEW.id_lance AND p.cod_fao = v_especie;

  IF v_usado + NEW.peso_vivo_kg > v_capturado THEN
    SET v_msg = CONCAT('RN16: o lance n.º ', v_num_lance, ' tem ', v_capturado - v_usado,
                       ' kg de ', v_especie, ' disponíveis, pedido ', NEW.peso_vivo_kg);
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = v_msg;
  END IF;
END$$

-- ---------------------------------------------------------------------
-- 6. RN28 — O responsável de um turno tem de estar nessa viagem com o
--    posto de Factory Manager ou 2nd Factory Manager.
-- ---------------------------------------------------------------------
CREATE TRIGGER trg_turno_responsavel
BEFORE INSERT ON turno
FOR EACH ROW
BEGIN
  IF NOT EXISTS (
      SELECT 1
      FROM tripulacao_viagem tv
      JOIN posto p ON p.id_posto = tv.id_posto
      WHERE tv.id_viagem     = NEW.id_viagem
        AND tv.id_tripulante = NEW.id_responsavel
        AND p.designacao IN ('Factory Manager', '2nd Factory Manager')
  ) THEN
    SIGNAL SQLSTATE '45000'
      SET MESSAGE_TEXT = 'RN28: o responsável não é Factory Manager nem 2nd Factory Manager nesta viagem';
  END IF;
END$$

-- ---------------------------------------------------------------------
-- 7. RN10 — Cada viagem tem um único comandante (Captain).
-- ---------------------------------------------------------------------
CREATE TRIGGER trg_tripulacao_comandante
BEFORE INSERT ON tripulacao_viagem
FOR EACH ROW
BEGIN
  IF (SELECT designacao FROM posto WHERE id_posto = NEW.id_posto) = 'Captain'
     AND EXISTS (
       SELECT 1
       FROM tripulacao_viagem tv
       JOIN posto p ON p.id_posto = tv.id_posto
       WHERE tv.id_viagem = NEW.id_viagem
         AND p.designacao = 'Captain'
     ) THEN
    SIGNAL SQLSTATE '45000'
      SET MESSAGE_TEXT = 'RN10: esta viagem já tem um comandante (Captain)';
  END IF;
END$$

-- ---------------------------------------------------------------------
-- 8. RN31 — Um lance não pode começar nem acabar depois da hora atual: só se
--    regista o que já aconteceu. As datas estão em UTC (RN7), por isso
--    compara-se com UTC_TIMESTAMP(), que não depende do fuso do servidor.
--    Sem isto, um lance com fim no futuro contava como "terminado" no
--    sp_fechar_lote assim que o turno acabasse depois dele.
-- ---------------------------------------------------------------------
CREATE TRIGGER trg_lance_datas
BEFORE INSERT ON lance
FOR EACH ROW
BEGIN
  DECLARE v_msg VARCHAR(128);

  IF NEW.inicio > UTC_TIMESTAMP() THEN
    SET v_msg = CONCAT('RN31: o início (', DATE_FORMAT(NEW.inicio, '%Y-%m-%d %H:%i'),
                       ') é depois da hora atual (', DATE_FORMAT(UTC_TIMESTAMP(), '%Y-%m-%d %H:%i'), ' UTC)');
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = v_msg;
  END IF;

  IF NEW.fim > UTC_TIMESTAMP() THEN
    SET v_msg = CONCAT('RN31: o fim (', DATE_FORMAT(NEW.fim, '%Y-%m-%d %H:%i'),
                       ') é depois da hora atual (', DATE_FORMAT(UTC_TIMESTAMP(), '%Y-%m-%d %H:%i'), ' UTC)');
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = v_msg;
  END IF;
END$$

-- ---------------------------------------------------------------------
-- 9. RN31 — A mesma regra no UPDATE: o mestre de pesca fecha o lance com
--    UPDATE lance SET fim = ... (parte 3 deste ficheiro). Só se valida a
--    coluna que muda, para uma correção da posição não ser recusada.
-- ---------------------------------------------------------------------
CREATE TRIGGER trg_lance_datas_update
BEFORE UPDATE ON lance
FOR EACH ROW
BEGIN
  DECLARE v_msg VARCHAR(128);

  IF NOT (NEW.inicio <=> OLD.inicio) AND NEW.inicio > UTC_TIMESTAMP() THEN
    SET v_msg = CONCAT('RN31: o início (', DATE_FORMAT(NEW.inicio, '%Y-%m-%d %H:%i'),
                       ') é depois da hora atual (', DATE_FORMAT(UTC_TIMESTAMP(), '%Y-%m-%d %H:%i'), ' UTC)');
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = v_msg;
  END IF;

  IF NOT (NEW.fim <=> OLD.fim) AND NEW.fim > UTC_TIMESTAMP() THEN
    SET v_msg = CONCAT('RN31: o fim (', DATE_FORMAT(NEW.fim, '%Y-%m-%d %H:%i'),
                       ') é depois da hora atual (', DATE_FORMAT(UTC_TIMESTAMP(), '%Y-%m-%d %H:%i'), ' UTC)');
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = v_msg;
  END IF;
END$$

-- ---------------------------------------------------------------------
-- 10. RN32 — A chegada (ATA) e a partida (ATD) reais de uma escala não podem
--     ser depois da hora atual: só se regista o que já aconteceu. A ETA
--     e a ETD são previsões e podem estar no futuro (a data de chegada
--     de uma viagem muitas vezes só é conhecida com aproximação).
-- ---------------------------------------------------------------------
CREATE TRIGGER trg_escala_datas
BEFORE INSERT ON escala
FOR EACH ROW
BEGIN
  DECLARE v_msg VARCHAR(128);

  IF NEW.ata > UTC_TIMESTAMP() THEN
    SET v_msg = CONCAT('RN32: a ATA (', DATE_FORMAT(NEW.ata, '%Y-%m-%d %H:%i'),
                       ') é depois da hora atual (', DATE_FORMAT(UTC_TIMESTAMP(), '%Y-%m-%d %H:%i'), ' UTC)');
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = v_msg;
  END IF;

  IF NEW.atd > UTC_TIMESTAMP() THEN
    SET v_msg = CONCAT('RN32: a ATD (', DATE_FORMAT(NEW.atd, '%Y-%m-%d %H:%i'),
                       ') é depois da hora atual (', DATE_FORMAT(UTC_TIMESTAMP(), '%Y-%m-%d %H:%i'), ' UTC)');
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = v_msg;
  END IF;
END$$

-- ---------------------------------------------------------------------
-- 11. RN32 — A mesma regra no UPDATE (o comandante regista a ATA e a ATD com
--     UPDATE escala). Só se valida a coluna que muda.
-- ---------------------------------------------------------------------
CREATE TRIGGER trg_escala_datas_update
BEFORE UPDATE ON escala
FOR EACH ROW
BEGIN
  DECLARE v_msg VARCHAR(128);

  IF NOT (NEW.ata <=> OLD.ata) AND NEW.ata > UTC_TIMESTAMP() THEN
    SET v_msg = CONCAT('RN32: a ATA (', DATE_FORMAT(NEW.ata, '%Y-%m-%d %H:%i'),
                       ') é depois da hora atual (', DATE_FORMAT(UTC_TIMESTAMP(), '%Y-%m-%d %H:%i'), ' UTC)');
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = v_msg;
  END IF;

  IF NOT (NEW.atd <=> OLD.atd) AND NEW.atd > UTC_TIMESTAMP() THEN
    SET v_msg = CONCAT('RN32: a ATD (', DATE_FORMAT(NEW.atd, '%Y-%m-%d %H:%i'),
                       ') é depois da hora atual (', DATE_FORMAT(UTC_TIMESTAMP(), '%Y-%m-%d %H:%i'), ' UTC)');
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = v_msg;
  END IF;
END$$

-- ---------------------------------------------------------------------
-- RN33 — Procedimento auxiliar dos triggers 12 e 13: valida a escala de
-- chegada de uma viagem. Fica num procedimento para os dois triggers
-- (INSERT e UPDATE) usarem exatamente as mesmas regras:
--   - a escala é do navio da viagem;
--   - a escala já tem ATA (o navio chegou mesmo);
--   - a chegada é depois da partida (ATD, ou ETD se faltar);
--   - não há lances nem turnos da viagem por terminar, nem a terminar
--     depois da chegada.
-- Os triggers correm com os privilégios de quem os criou, por isso os
-- utilizadores da aplicação não precisam de EXECUTE neste procedimento.
-- ---------------------------------------------------------------------
CREATE PROCEDURE sp_validar_chegada_viagem(
  IN p_id_viagem      INT,
  IN p_id_navio       INT,
  IN p_escala_partida INT,
  IN p_escala_chegada INT
)
READS SQL DATA
COMMENT 'Usado por trg_viagem_chegada e trg_viagem_chegada_update'
validar: BEGIN
  DECLARE v_navio   INT;
  DECLARE v_ata     DATETIME;
  DECLARE v_partida DATETIME;
  DECLARE v_n       INT;
  DECLARE v_msg     VARCHAR(128);

  SELECT e.id_navio, e.ata INTO v_navio, v_ata
  FROM escala e WHERE e.id_escala = p_escala_chegada;

  -- Escala inexistente: a FK fk_viagem_escala_chegada recusa a seguir
  IF v_navio IS NULL THEN
    LEAVE validar;
  END IF;

  IF v_navio <> p_id_navio THEN
    SIGNAL SQLSTATE '45000'
      SET MESSAGE_TEXT = 'RN33: a escala de chegada é de outro navio';
  END IF;

  IF v_ata IS NULL THEN
    SIGNAL SQLSTATE '45000'
      SET MESSAGE_TEXT = 'RN33: a escala de chegada ainda não tem ATA (registe primeiro a chegada real)';
  END IF;

  SELECT COALESCE(e.atd, e.etd) INTO v_partida
  FROM escala e WHERE e.id_escala = p_escala_partida;

  IF v_partida IS NOT NULL AND v_ata <= v_partida THEN
    SET v_msg = CONCAT('RN33: a chegada (', DATE_FORMAT(v_ata, '%Y-%m-%d %H:%i'),
                       ') não é depois da partida (', DATE_FORMAT(v_partida, '%Y-%m-%d %H:%i'), ')');
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = v_msg;
  END IF;

  SELECT COUNT(*) INTO v_n
  FROM lance l
  WHERE l.id_viagem = p_id_viagem AND (l.fim IS NULL OR l.fim > v_ata);
  IF v_n > 0 THEN
    SET v_msg = CONCAT('RN33: há ', v_n, ' lance(s) por terminar ou a terminar depois da chegada');
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = v_msg;
  END IF;

  SELECT COUNT(*) INTO v_n
  FROM turno t
  WHERE t.id_viagem = p_id_viagem AND (t.fim IS NULL OR t.fim > v_ata);
  IF v_n > 0 THEN
    SET v_msg = CONCAT('RN33: há ', v_n, ' turno(s) por fechar ou a fechar depois da chegada');
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = v_msg;
  END IF;
END$$

-- ---------------------------------------------------------------------
-- 12. RN33 — Uma viagem inserida já com escala de chegada (viagem passada)
-- ---------------------------------------------------------------------
CREATE TRIGGER trg_viagem_chegada
BEFORE INSERT ON viagem
FOR EACH ROW
BEGIN
  IF NEW.id_escala_chegada IS NOT NULL THEN
    CALL sp_validar_chegada_viagem(NEW.id_viagem, NEW.id_navio,
                                   NEW.id_escala_partida, NEW.id_escala_chegada);
  END IF;
END$$

-- ---------------------------------------------------------------------
-- 13. RN33 — Fechar a viagem: UPDATE viagem SET id_escala_chegada = ...
--     (o comandante só pode alterar esta coluna, parte 3 deste ficheiro)
-- ---------------------------------------------------------------------
CREATE TRIGGER trg_viagem_chegada_update
BEFORE UPDATE ON viagem
FOR EACH ROW
BEGIN
  IF NEW.id_escala_chegada IS NOT NULL
     AND NOT (NEW.id_escala_chegada <=> OLD.id_escala_chegada) THEN
    CALL sp_validar_chegada_viagem(NEW.id_viagem, NEW.id_navio,
                                   NEW.id_escala_partida, NEW.id_escala_chegada);
  END IF;
END$$

-- ---------------------------------------------------------------------
-- 14. RN34 — Abrir uma viagem (INSERT viagem). Corre depois do 12.
--     - a escala de partida é do navio da viagem;
--     - a escala ainda não é a partida de outra viagem;
--     - uma viagem nova em curso (sem chegada) só se o navio não tiver
--       outra em curso: primeiro fecha-se a anterior (RN33).
--     O comandante não pode alterar id_escala_partida depois (só tem
--     UPDATE de id_escala_chegada), por isso basta validar o INSERT.
-- ---------------------------------------------------------------------
CREATE TRIGGER trg_viagem_partida
BEFORE INSERT ON viagem
FOR EACH ROW
FOLLOWS trg_viagem_chegada
BEGIN
  DECLARE v_navio INT;
  DECLARE v_num   INT;
  DECLARE v_msg   VARCHAR(128);

  SELECT e.id_navio INTO v_navio
  FROM escala e WHERE e.id_escala = NEW.id_escala_partida;

  -- Escala inexistente: a FK fk_viagem_escala_partida recusa a seguir
  IF v_navio IS NOT NULL AND v_navio <> NEW.id_navio THEN
    SIGNAL SQLSTATE '45000'
      SET MESSAGE_TEXT = 'RN34: a escala de partida é de outro navio';
  END IF;

  SELECT MIN(v.num_viagem) INTO v_num
  FROM viagem v WHERE v.id_escala_partida = NEW.id_escala_partida;
  IF v_num IS NOT NULL THEN
    SET v_msg = CONCAT('RN34: esta escala já é a partida da Viagem ', v_num);
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = v_msg;
  END IF;

  IF NEW.id_escala_chegada IS NULL THEN
    SELECT MIN(v.num_viagem) INTO v_num
    FROM viagem v
    WHERE v.id_navio = NEW.id_navio AND v.id_escala_chegada IS NULL;
    IF v_num IS NOT NULL THEN
      SET v_msg = CONCAT('RN34: o navio ainda tem a Viagem ', v_num, ' em curso (feche-a primeiro)');
      SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = v_msg;
    END IF;
  END IF;
END$$

DELIMITER ;

-- Verificação: deve listar os 14 triggers
SELECT TRIGGER_NAME, EVENT_OBJECT_TABLE AS tabela, ACTION_TIMING AS momento,
       EVENT_MANIPULATION AS evento
FROM information_schema.TRIGGERS
WHERE TRIGGER_SCHEMA = 'sta_princesa'
ORDER BY EVENT_OBJECT_TABLE, ACTION_ORDER;


-- #####################################################################
-- PARTE 2 — PROCEDIMENTO TRANSACIONAL sp_fechar_lote
-- #####################################################################
-- =====================================================================
-- Projeto MPD — Base de dados do navio-fábrica (sta_princesa)
-- Parte 2 — procedimento transacional sp_fechar_lote
-- Depois da parte 1. Pode ser corrido várias vezes.
--
-- Cenário transacional do projeto (ecrã UI02 do protótipo).
-- Fechar um lote são três passos que só fazem sentido juntos:
--   1. criar o lote                       (INSERT em lote)
--   2. ligar o lote aos lances de origem   (INSERT em lote_lance — RN16)
--   3. guardar as caixas nos porões        (INSERT em armazenamento — RN22)
-- Se qualquer passo falhar (um trigger recusa, uma FK ou CHECK falha),
-- nada fica gravado: o handler faz ROLLBACK e volta a lançar o erro,
-- com a mensagem original, para a aplicação a mostrar ao utilizador.
--
-- Os lances e os porões chegam como arrays JSON (um formulário com N
-- linhas), lidos com JSON_TABLE:
--   p_lances: [{"id_lance": 4, "peso_vivo_kg": 6800}, {"id_lance": 5, "peso_vivo_kg": 600}]
--   p_poroes: [{"id_porao": 1, "n_caixas": 197}]
--
-- Calculados pelo procedimento (a aplicação não os envia):
--   peso_materia_prima_kg = soma dos pesos dos lances
--   peso_liquido_kg       = n_caixas x peso por caixa do produto
--   data de entrada       = p_data_entrada, ou o fim do turno se NULL
--
-- Validações próprias, antes de gravar (mensagens começadas por "Lote:"):
--   - arrays JSON preenchidos e completos, sem lances nem porões repetidos;
--   - turno, produto e lances existem;
--   - todas as caixas do lote vão para os porões (soma = n_caixas);
--   - cada lance já tinha terminado no fim do turno: um lote não pode
--     usar peixe que ainda não estava a bordo (a regra da consulta de
--     controlo 8 (Q17) do data/queries.sql, agora aplicada na entrada).
-- As regras de negócio que já têm trigger (RN16, RN22, ...) NÃO são
-- repetidas aqui: os triggers continuam a ser a única garantia.
--
-- Atenção: START TRANSACTION faz COMMIT de uma transação que já esteja
-- aberta. Chamar o procedimento fora de outra transação.
--
-- Exemplo:
--   CALL sp_fechar_lote('SP-T12-COD-001', 9, 1, 80,
--        '[{"id_lance": 11, "peso_vivo_kg": 3000}]',
--        '[{"id_porao": 1, "n_caixas": 50}, {"id_porao": 2, "n_caixas": 30}]',
--        NULL, @id_lote);
--   SELECT @id_lote;
-- =====================================================================

USE sta_princesa;

DROP PROCEDURE IF EXISTS sp_fechar_lote;

DELIMITER $$

CREATE PROCEDURE sp_fechar_lote(
  IN  p_codigo_lote  VARCHAR(30),
  IN  p_id_turno     INT,
  IN  p_id_produto   INT,
  IN  p_n_caixas     INT,
  IN  p_lances       JSON,
  IN  p_poroes       JSON,
  IN  p_data_entrada DATETIME,
  OUT p_id_lote      INT
)
MODIFIES SQL DATA
COMMENT 'Fecha um lote: lote + lote_lance + armazenamento numa só transação'
BEGIN
  DECLARE v_inicio_turno DATETIME;
  DECLARE v_fim_turno    DATETIME;
  DECLARE v_peso_caixa   DECIMAL(6,2);
  DECLARE v_data_entrada DATETIME;
  DECLARE v_materia_kg   DECIMAL(10,2);
  DECLARE v_n            INT;
  DECLARE v_lance        INT;
  DECLARE v_msg          VARCHAR(128);

  -- Qualquer erro, em qualquer passo: desfaz tudo e devolve o erro
  -- original (RESIGNAL mantém o código e a mensagem do trigger).
  DECLARE EXIT HANDLER FOR SQLEXCEPTION
  BEGIN
    ROLLBACK;
    SET p_id_lote = NULL;
    RESIGNAL;
  END;

  SET p_id_lote = NULL;

  START TRANSACTION;

  -- -------------------------------------------------------------------
  -- 0. Validações
  -- -------------------------------------------------------------------

  -- Arrays JSON
  IF p_lances IS NULL OR JSON_TYPE(p_lances) <> 'ARRAY' OR JSON_LENGTH(p_lances) = 0 THEN
    SIGNAL SQLSTATE '45000'
      SET MESSAGE_TEXT = 'Lote: indique pelo menos um lance de origem';
  END IF;

  IF p_poroes IS NULL OR JSON_TYPE(p_poroes) <> 'ARRAY' OR JSON_LENGTH(p_poroes) = 0 THEN
    SIGNAL SQLSTATE '45000'
      SET MESSAGE_TEXT = 'Lote: indique pelo menos um porão';
  END IF;

  SELECT COUNT(*) INTO v_n
  FROM JSON_TABLE(p_lances, '$[*]' COLUMNS (
         id_lance     INT           PATH '$.id_lance',
         peso_vivo_kg DECIMAL(10,2) PATH '$.peso_vivo_kg')) j
  WHERE j.id_lance IS NULL OR j.peso_vivo_kg IS NULL OR j.peso_vivo_kg <= 0;
  IF v_n > 0 THEN
    SIGNAL SQLSTATE '45000'
      SET MESSAGE_TEXT = 'Lote: cada lance precisa de id_lance e de peso_vivo_kg > 0';
  END IF;

  SELECT COUNT(*) INTO v_n
  FROM JSON_TABLE(p_poroes, '$[*]' COLUMNS (
         id_porao INT PATH '$.id_porao',
         n_caixas INT PATH '$.n_caixas')) j
  WHERE j.id_porao IS NULL OR j.n_caixas IS NULL OR j.n_caixas <= 0;
  IF v_n > 0 THEN
    SIGNAL SQLSTATE '45000'
      SET MESSAGE_TEXT = 'Lote: cada porão precisa de id_porao e de n_caixas > 0';
  END IF;

  -- Repetidos (dariam erro de chave primária, com uma mensagem pouco clara)
  SELECT COUNT(*) - COUNT(DISTINCT j.id_lance) INTO v_n
  FROM JSON_TABLE(p_lances, '$[*]' COLUMNS (id_lance INT PATH '$.id_lance')) j;
  IF v_n > 0 THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Lote: há lances repetidos na lista';
  END IF;

  SELECT COUNT(*) - COUNT(DISTINCT j.id_porao) INTO v_n
  FROM JSON_TABLE(p_poroes, '$[*]' COLUMNS (id_porao INT PATH '$.id_porao')) j;
  IF v_n > 0 THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Lote: há porões repetidos na lista';
  END IF;

  -- Bloqueia os lances do lote até ao COMMIT/ROLLBACK (FOR UPDATE).
  -- Dois fechos de lote em simultâneo com o mesmo lance ficam em fila:
  -- o segundo espera e depois o trigger RN16 já conta o peso usado pelo
  -- primeiro. Tem de ser a PRIMEIRA leitura de tabelas da transação: em
  -- REPEATABLE READ a "fotografia" dos dados é tirada na primeira
  -- leitura normal, e tem de ser tirada depois de o bloqueio ser obtido.
  SELECT COUNT(*) INTO v_n
  FROM lance l
  JOIN JSON_TABLE(p_lances, '$[*]' COLUMNS (id_lance INT PATH '$.id_lance')) j
    ON j.id_lance = l.id_lance
  FOR UPDATE OF l;

  -- Turno e produto
  SELECT COUNT(*), MAX(t.inicio), MAX(t.fim)
    INTO v_n, v_inicio_turno, v_fim_turno
  FROM turno t WHERE t.id_turno = p_id_turno;
  IF v_n = 0 THEN
    SET v_msg = CONCAT('Lote: o turno ', COALESCE(p_id_turno, 'NULL'), ' não existe');
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = v_msg;
  END IF;

  SELECT COUNT(*), MAX(p.peso_caixa_kg) INTO v_n, v_peso_caixa
  FROM produto p WHERE p.id_produto = p_id_produto;
  IF v_n = 0 THEN
    SET v_msg = CONCAT('Lote: o produto ', COALESCE(p_id_produto, 'NULL'), ' não existe');
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = v_msg;
  END IF;
  IF v_peso_caixa IS NULL THEN
    SIGNAL SQLSTATE '45000'
      SET MESSAGE_TEXT = 'Lote: o produto não tem peso por caixa definido';
  END IF;

  -- Todas as caixas do lote vão para os porões
  SELECT SUM(j.n_caixas) INTO v_n
  FROM JSON_TABLE(p_poroes, '$[*]' COLUMNS (n_caixas INT PATH '$.n_caixas')) j;
  IF v_n <> p_n_caixas THEN
    SET v_msg = CONCAT('Lote: o lote tem ', p_n_caixas, ' caixas, mas os porões recebem ', v_n);
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = v_msg;
  END IF;

  SET v_data_entrada = COALESCE(p_data_entrada, v_fim_turno, UTC_TIMESTAMP());

  -- Lances: existem e já tinham terminado no fim do turno
  SELECT MIN(j.id_lance) INTO v_lance
  FROM JSON_TABLE(p_lances, '$[*]' COLUMNS (id_lance INT PATH '$.id_lance')) j
  LEFT JOIN lance l ON l.id_lance = j.id_lance
  WHERE l.id_lance IS NULL;
  IF v_lance IS NOT NULL THEN
    SET v_msg = CONCAT('Lote: o lance ', v_lance, ' não existe');
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = v_msg;
  END IF;

  SELECT MIN(l.num_lance) INTO v_lance
  FROM lance l
  JOIN JSON_TABLE(p_lances, '$[*]' COLUMNS (id_lance INT PATH '$.id_lance')) j
    ON j.id_lance = l.id_lance
  WHERE l.fim IS NULL
     OR l.fim > COALESCE(v_fim_turno, v_data_entrada);
  IF v_lance IS NOT NULL THEN
    SET v_msg = CONCAT('Lote: o lance n.º ', v_lance,
                       ' ainda não tinha terminado no fim do turno');
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = v_msg;
  END IF;

  -- -------------------------------------------------------------------
  -- 1. Lote
  --    CHECK ck_lote_rendimento (RN26): produto <= matéria-prima
  -- -------------------------------------------------------------------
  SELECT SUM(j.peso_vivo_kg) INTO v_materia_kg
  FROM JSON_TABLE(p_lances, '$[*]' COLUMNS (
         peso_vivo_kg DECIMAL(10,2) PATH '$.peso_vivo_kg')) j;

  INSERT INTO lote (codigo_lote, id_turno, id_produto, n_caixas,
                    peso_liquido_kg, peso_materia_prima_kg)
  VALUES (p_codigo_lote, p_id_turno, p_id_produto, p_n_caixas,
          p_n_caixas * v_peso_caixa, v_materia_kg);

  SET p_id_lote = LAST_INSERT_ID();

  -- -------------------------------------------------------------------
  -- 2. Origem do lote — trigger trg_lote_lance_viagem (RN16) por linha:
  --    mesma viagem, mesma espécie, peso disponível no lance
  -- -------------------------------------------------------------------
  INSERT INTO lote_lance (id_lote, id_lance, peso_vivo_kg)
  SELECT p_id_lote, j.id_lance, j.peso_vivo_kg
  FROM JSON_TABLE(p_lances, '$[*]' COLUMNS (
         id_lance     INT           PATH '$.id_lance',
         peso_vivo_kg DECIMAL(10,2) PATH '$.peso_vivo_kg')) j;

  -- -------------------------------------------------------------------
  -- 3. Porões — triggers trg_armazenamento_lote e
  --    trg_armazenamento_capacidade (RN22) por linha
  -- -------------------------------------------------------------------
  INSERT INTO armazenamento (id_lote, id_porao, n_caixas, data_entrada)
  SELECT p_id_lote, j.id_porao, j.n_caixas, v_data_entrada
  FROM JSON_TABLE(p_poroes, '$[*]' COLUMNS (
         id_porao INT PATH '$.id_porao',
         n_caixas INT PATH '$.n_caixas')) j;

  COMMIT;
END$$

DELIMITER ;

-- Verificação: o procedimento existe
SELECT ROUTINE_NAME, ROUTINE_TYPE, SECURITY_TYPE, ROUTINE_COMMENT
FROM information_schema.ROUTINES
WHERE ROUTINE_SCHEMA = 'sta_princesa' AND ROUTINE_NAME = 'sp_fechar_lote';


-- #####################################################################
-- PARTE 3 — PAPÉIS E UTILIZADORES
-- #####################################################################
-- =====================================================================
-- Projeto MPD — Base de dados do navio-fábrica (sta_princesa)
-- Parte 3 — papéis (roles) e utilizadores MySQL por papel
-- Correr como root, depois da parte 2. Pode ser corrido
-- várias vezes: apaga e recria os papéis e os utilizadores.
--
-- Em vez de uma tabela de utilizadores na BD, cada papel da secção 1.3
-- do relatório é um ROLE do MySQL com privilégios mínimos, e cada
-- utilizador da aplicação recebe o seu papel. A segurança fica na
-- própria base de dados: mesmo um pedido direto, sem passar pela
-- aplicação, só consegue o que o papel permite.
--
--   Papel             Utilizador       Escreve em
--   ----------------  ---------------  -----------------------------------
--   (todos)           —                lê tudo menos os documentos
--   Comandante        app_comandante   escalas, viagens, tripulação,
--                                      documentos, saídas
--   Mestre de pesca   app_pesca        lances e capturas
--   Fábrica           app_fabrica      turnos; lotes SÓ pelo sp_fechar_lote
--   Armador           app_armador      quotas
--
-- Três decisões:
--   1. Dados pessoais (RGPD): só o comandante lê a tabela documento
--      (números de passaporte e vistos). Por isso a leitura é dada
--      tabela a tabela e não com sta_princesa.*.
--   2. UPDATE por coluna: cada papel só altera colunas sem regras de
--      quantidade (horas reais da escala, fim do lance ou do turno,
--      valor da quota). Os triggers só validam INSERT; assim um UPDATE
--      não pode contornar as regras RN16, RN19, RN22 e RN24.
--   3. A fábrica não tem INSERT em lote, lote_lance nem armazenamento:
--      só fecha lotes com EXECUTE no sp_fechar_lote. O procedimento
--      corre com os privilégios de quem o criou (SQL SECURITY DEFINER)
--      e garante que os três passos são feitos juntos.
--
-- Palavras-passe: valores de DEMONSTRAÇÃO, para o ambiente local em
-- Docker (ficam também no README como credenciais de demonstração).
-- A aplicação lê-as do ficheiro .env, que não vai para o Git.
-- Sem '#': num .env o '#' começa um comentário e cortava a palavra-passe.
-- Host '%': as ligações a partir do Windows chegam ao contentor pela
-- rede do Docker, não por localhost.
-- =====================================================================

USE sta_princesa;

-- ---------------------------------------------------------------------
-- 0. Recomeçar do zero
-- ---------------------------------------------------------------------
DROP USER IF EXISTS 'app_comandante'@'%', 'app_pesca'@'%',
                    'app_fabrica'@'%', 'app_armador'@'%';
DROP ROLE IF EXISTS 'role_consulta', 'role_comandante', 'role_pesca',
                    'role_fabrica', 'role_armador';

CREATE ROLE 'role_consulta', 'role_comandante', 'role_pesca',
            'role_fabrica', 'role_armador';

-- ---------------------------------------------------------------------
-- 1. role_consulta — leitura comum a todos os papéis
--    Todas as tabelas EXCETO documento, e as duas vistas.
-- ---------------------------------------------------------------------
GRANT SELECT ON sta_princesa.especie           TO 'role_consulta';
GRANT SELECT ON sta_princesa.apresentacao      TO 'role_consulta';
GRANT SELECT ON sta_princesa.zona_pesca        TO 'role_consulta';
GRANT SELECT ON sta_princesa.porto             TO 'role_consulta';
GRANT SELECT ON sta_princesa.posto             TO 'role_consulta';
GRANT SELECT ON sta_princesa.tipo_documento    TO 'role_consulta';
GRANT SELECT ON sta_princesa.navio             TO 'role_consulta';
GRANT SELECT ON sta_princesa.tripulante        TO 'role_consulta';
GRANT SELECT ON sta_princesa.produto           TO 'role_consulta';
GRANT SELECT ON sta_princesa.fator_conversao   TO 'role_consulta';
GRANT SELECT ON sta_princesa.porao             TO 'role_consulta';
GRANT SELECT ON sta_princesa.quota             TO 'role_consulta';
GRANT SELECT ON sta_princesa.escala            TO 'role_consulta';
GRANT SELECT ON sta_princesa.viagem            TO 'role_consulta';
GRANT SELECT ON sta_princesa.tripulacao_viagem TO 'role_consulta';
GRANT SELECT ON sta_princesa.turno             TO 'role_consulta';
GRANT SELECT ON sta_princesa.lance             TO 'role_consulta';
GRANT SELECT ON sta_princesa.captura           TO 'role_consulta';
GRANT SELECT ON sta_princesa.lote              TO 'role_consulta';
GRANT SELECT ON sta_princesa.lote_lance        TO 'role_consulta';
GRANT SELECT ON sta_princesa.armazenamento     TO 'role_consulta';
GRANT SELECT ON sta_princesa.saida_lote        TO 'role_consulta';
GRANT SELECT ON sta_princesa.v_stock           TO 'role_consulta';
GRANT SELECT ON sta_princesa.v_quota_consumo   TO 'role_consulta';

-- ---------------------------------------------------------------------
-- 2. role_comandante — escalas, viagens, tripulação, documentos, saídas
-- ---------------------------------------------------------------------
GRANT SELECT, INSERT ON sta_princesa.documento         TO 'role_comandante';
GRANT INSERT         ON sta_princesa.escala            TO 'role_comandante';
GRANT INSERT         ON sta_princesa.viagem            TO 'role_comandante';
GRANT INSERT         ON sta_princesa.tripulante        TO 'role_comandante';
GRANT INSERT         ON sta_princesa.tripulacao_viagem TO 'role_comandante';
GRANT INSERT         ON sta_princesa.saida_lote        TO 'role_comandante';

-- Atualizações permitidas (FR13: horas reais e fecho da viagem)
GRANT UPDATE (eta, etd, ata, atd, calado_m, nivel_seguranca)
      ON sta_princesa.escala            TO 'role_comandante';
GRANT UPDATE (id_escala_chegada)
      ON sta_princesa.viagem            TO 'role_comandante';
GRANT UPDATE (id_escala_desembarque)
      ON sta_princesa.tripulacao_viagem TO 'role_comandante';
GRANT UPDATE (apelido, nomes_proprios, data_nascimento, local_nascimento,
              genero, nacionalidade)
      ON sta_princesa.tripulante        TO 'role_comandante';
GRANT UPDATE (data_validade)
      ON sta_princesa.documento         TO 'role_comandante';

-- ---------------------------------------------------------------------
-- 3. role_pesca — lances e capturas
--    Pode fechar um lance (fim) e corrigir a posição, mas não mudar a
--    zona nem a data de início: isso mudaria a quota a que a captura
--    conta (RN19), e o trigger só valida no INSERT.
-- ---------------------------------------------------------------------
GRANT INSERT ON sta_princesa.lance   TO 'role_pesca';
GRANT INSERT ON sta_princesa.captura TO 'role_pesca';
GRANT UPDATE (fim, latitude, longitude, profundidade_m)
      ON sta_princesa.lance TO 'role_pesca';

-- ---------------------------------------------------------------------
-- 4. role_fabrica — turnos e lotes (lotes só pelo procedimento)
-- ---------------------------------------------------------------------
GRANT INSERT         ON sta_princesa.turno TO 'role_fabrica';
GRANT UPDATE (fim)   ON sta_princesa.turno TO 'role_fabrica';
GRANT EXECUTE ON PROCEDURE sta_princesa.sp_fechar_lote TO 'role_fabrica';

-- ---------------------------------------------------------------------
-- 5. role_armador — quotas
-- ---------------------------------------------------------------------
GRANT INSERT           ON sta_princesa.quota TO 'role_armador';
GRANT UPDATE (quota_kg) ON sta_princesa.quota TO 'role_armador';

-- ---------------------------------------------------------------------
-- 6. Utilizadores (palavras-passe de demonstração)
--    Cada um recebe a leitura comum + o seu papel, ativos ao ligar.
-- ---------------------------------------------------------------------
CREATE USER 'app_comandante'@'%' IDENTIFIED BY 'Comandante-2026';
CREATE USER 'app_pesca'@'%'      IDENTIFIED BY 'Pesca-2026';
CREATE USER 'app_fabrica'@'%'    IDENTIFIED BY 'Fabrica-2026';
CREATE USER 'app_armador'@'%'    IDENTIFIED BY 'Armador-2026';

GRANT 'role_consulta', 'role_comandante' TO 'app_comandante'@'%';
GRANT 'role_consulta', 'role_pesca'      TO 'app_pesca'@'%';
GRANT 'role_consulta', 'role_fabrica'    TO 'app_fabrica'@'%';
GRANT 'role_consulta', 'role_armador'    TO 'app_armador'@'%';

SET DEFAULT ROLE ALL TO 'app_comandante'@'%', 'app_pesca'@'%',
                        'app_fabrica'@'%', 'app_armador'@'%';

-- ---------------------------------------------------------------------
-- 7. Verificação: o que cada papel pode fazer, tabela a tabela
--    (ESCREVE = INSERT; os UPDATE por coluna aparecem em "atualiza")
-- ---------------------------------------------------------------------
SELECT REPLACE(tp.GRANTEE, '''', '')            AS papel,
       tp.TABLE_NAME                            AS tabela,
       GROUP_CONCAT(tp.PRIVILEGE_TYPE ORDER BY tp.PRIVILEGE_TYPE) AS privilegios
FROM information_schema.TABLE_PRIVILEGES tp
WHERE tp.TABLE_SCHEMA = 'sta_princesa'
  AND tp.GRANTEE LIKE '%role_%'
  AND tp.PRIVILEGE_TYPE <> 'SELECT'
GROUP BY tp.GRANTEE, tp.TABLE_NAME
UNION ALL
SELECT REPLACE(cp.GRANTEE, '''', ''),
       cp.TABLE_NAME,
       CONCAT('atualiza: ', GROUP_CONCAT(cp.COLUMN_NAME ORDER BY cp.COLUMN_NAME))
FROM information_schema.COLUMN_PRIVILEGES cp
WHERE cp.TABLE_SCHEMA = 'sta_princesa'
  AND cp.GRANTEE LIKE '%role_%'
GROUP BY cp.GRANTEE, cp.TABLE_NAME
ORDER BY 1, 2;

SHOW GRANTS FOR 'app_fabrica'@'%' USING 'role_consulta', 'role_fabrica';
