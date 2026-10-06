-- =====================================================================
-- Projeto MPD — Base de dados do navio-fábrica (sta_princesa)
-- 03_triggers.sql — 7 triggers das regras de negócio (secção 13)
-- Correr depois do 01_schema.sql (e do 01b, se a BD for anterior).
-- Pode ser corrido várias vezes: cada trigger é apagado antes de criar.
--
-- Todos os triggers são BEFORE INSERT: validam a linha nova e, se
-- violar a regra, recusam o INSERT com SIGNAL SQLSTATE '45000'.
-- =====================================================================

USE sta_princesa;

DROP TRIGGER IF EXISTS trg_captura_quota;
DROP TRIGGER IF EXISTS trg_saida_stock;
DROP TRIGGER IF EXISTS trg_armazenamento_lote;
DROP TRIGGER IF EXISTS trg_armazenamento_capacidade;
DROP TRIGGER IF EXISTS trg_lote_lance_viagem;
DROP TRIGGER IF EXISTS trg_turno_responsavel;
DROP TRIGGER IF EXISTS trg_tripulacao_comandante;

DELIMITER $$

-- ---------------------------------------------------------------------
-- 1. RN19 — Uma captura não pode ultrapassar a quota do navio para
--    essa espécie, zona e ano. Sem quota definida, a captura é recusada.
-- ---------------------------------------------------------------------
CREATE TRIGGER trg_captura_quota
BEFORE INSERT ON captura
FOR EACH ROW
BEGIN
  DECLARE v_navio INT;
  DECLARE v_zona  INT;
  DECLARE v_ano   INT;
  DECLARE v_quota DECIMAL(12,2);
  DECLARE v_usado DECIMAL(12,2);
  DECLARE v_msg   VARCHAR(128);

  -- Navio, zona e ano do lance onde foi feita a captura
  SELECT v.id_navio, l.id_zona_pesca, YEAR(l.inicio)
    INTO v_navio, v_zona, v_ano
  FROM lance l
  JOIN viagem v ON v.id_viagem = l.id_viagem
  WHERE l.id_lance = NEW.id_lance;

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
    AND YEAR(l.inicio)   = v_ano
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

  SELECT l.id_viagem INTO v_viagem_lance
  FROM lance l WHERE l.id_lance = NEW.id_lance;

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
    SET v_msg = CONCAT('RN16: lance ', NEW.id_lance, ' tem ', v_capturado - v_usado,
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

DELIMITER ;

-- Verificação: deve listar os 7 triggers
SELECT TRIGGER_NAME, EVENT_OBJECT_TABLE AS tabela, ACTION_TIMING AS momento,
       EVENT_MANIPULATION AS evento
FROM information_schema.TRIGGERS
WHERE TRIGGER_SCHEMA = 'sta_princesa'
ORDER BY EVENT_OBJECT_TABLE, ACTION_ORDER;
