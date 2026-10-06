-- =====================================================================
-- Projeto MPD — Base de dados do navio-fábrica (sta_princesa)
-- 01_schema.sql — criação das 23 tabelas (secção 12 do documento)
-- MySQL 8.4 · datas/horas em UTC (RN7)
-- =====================================================================

USE sta_princesa;

-- Apaga as tabelas antigas (ordem indiferente com as FK desligadas)
SET FOREIGN_KEY_CHECKS = 0;
DROP TABLE IF EXISTS armazenamento, saida_lote, lote_lance, lote, captura,
  turno, tripulacao_viagem, lance, viagem, quota, porao, produto,
  fator_conversao, escala, documento, zona_pesca, tripulante,
  tipo_documento, posto, porto, navio, especie, apresentacao;
SET FOREIGN_KEY_CHECKS = 1;

-- ---------------------------------------------------------------------
-- 1. Tabelas de referência (não dependem de nenhuma outra)
-- ---------------------------------------------------------------------

CREATE TABLE especie (
  cod_fao          CHAR(3)      NOT NULL COMMENT 'Código FAO 3-alfa: COD, PRA',
  nome_comum       VARCHAR(100) NOT NULL,
  nome_cientifico  VARCHAR(100) NULL,
  PRIMARY KEY (cod_fao)
);

CREATE TABLE apresentacao (
  cod_apresentacao CHAR(3)      NOT NULL COMMENT 'HEG, WHL',
  designacao       VARCHAR(100) NOT NULL,
  PRIMARY KEY (cod_apresentacao)
);

CREATE TABLE zona_pesca (
  id_zona      INT          NOT NULL AUTO_INCREMENT,
  codigo_ices  VARCHAR(10)  NOT NULL COMMENT 'Divisão ICES: 2.a, 2.b',
  jurisdicao   VARCHAR(50)  NOT NULL COMMENT 'ZEE Noruega, Zona de Svalbard',
  designacao   VARCHAR(100) NULL,
  PRIMARY KEY (id_zona),
  CONSTRAINT uq_zona_pesca UNIQUE (codigo_ices, jurisdicao)
);

CREATE TABLE porto (
  cod_unlocode CHAR(5)     NOT NULL COMMENT 'UN/LOCODE: NOTOS = Tromsø (RN6)',
  nome         VARCHAR(50) NOT NULL,
  pais         CHAR(2)     NOT NULL COMMENT 'ISO 3166-1: NO, PT',
  PRIMARY KEY (cod_unlocode)
);

CREATE TABLE posto (
  id_posto     INT         NOT NULL AUTO_INCREMENT,
  designacao   VARCHAR(50) NOT NULL,
  departamento VARCHAR(30) NULL COMMENT 'Ponte, Máquinas, Fábrica, Pesca, Cozinha',
  PRIMARY KEY (id_posto),
  CONSTRAINT uq_posto UNIQUE (designacao)
);

CREATE TABLE tipo_documento (
  id_tipo_doc INT         NOT NULL AUTO_INCREMENT,
  designacao  VARCHAR(50) NOT NULL,
  PRIMARY KEY (id_tipo_doc),
  CONSTRAINT uq_tipo_documento UNIQUE (designacao)
);

-- ---------------------------------------------------------------------
-- 2. Tabelas base
-- ---------------------------------------------------------------------

CREATE TABLE navio (
  id_navio           INT          NOT NULL AUTO_INCREMENT,
  imo                INT          NOT NULL COMMENT 'Identificador IMO, nunca muda (RN2)',
  nome               VARCHAR(50)  NOT NULL,
  indicativo_chamada VARCHAR(10)  NULL,
  mmsi               INT          NULL,
  tipo_navio         VARCHAR(100) NULL,
  bandeira           CHAR(2)      NULL COMMENT 'ISO 3166-1',
  armador            VARCHAR(100) NULL,
  PRIMARY KEY (id_navio),
  CONSTRAINT uq_navio_imo UNIQUE (imo)
);

CREATE TABLE tripulante (
  id_tripulante    INT         NOT NULL AUTO_INCREMENT,
  apelido          VARCHAR(50) NOT NULL,
  nomes_proprios   VARCHAR(80) NOT NULL,
  data_nascimento  DATE        NULL,
  local_nascimento VARCHAR(50) NULL,
  genero           VARCHAR(10) NULL,
  nacionalidade    CHAR(2)     NULL COMMENT 'ISO 3166-1',
  PRIMARY KEY (id_tripulante)
);

CREATE TABLE documento (
  id_documento     INT         NOT NULL AUTO_INCREMENT,
  id_tripulante    INT         NOT NULL,
  id_tipo_doc      INT         NOT NULL,
  numero           VARCHAR(30) NOT NULL COMMENT 'VARCHAR: formatos como 07/93 e zeros à esquerda',
  cod_pais_emissor CHAR(2)     NOT NULL,
  data_validade    DATE        NULL,
  PRIMARY KEY (id_documento),
  CONSTRAINT uq_documento UNIQUE (id_tipo_doc, numero, cod_pais_emissor),
  CONSTRAINT fk_documento_tripulante FOREIGN KEY (id_tripulante)
    REFERENCES tripulante (id_tripulante),
  CONSTRAINT fk_documento_tipo_documento FOREIGN KEY (id_tipo_doc)
    REFERENCES tipo_documento (id_tipo_doc)
);

CREATE TABLE produto (
  id_produto       INT          NOT NULL AUTO_INCREMENT,
  cod_fao          CHAR(3)      NOT NULL,
  cod_apresentacao CHAR(3)      NOT NULL,
  peso_caixa_kg    DECIMAL(6,2) NULL COMMENT 'Por confirmar com o armador',
  PRIMARY KEY (id_produto),
  CONSTRAINT uq_produto_especie UNIQUE (cod_fao) COMMENT 'RN30',
  CONSTRAINT fk_produto_especie FOREIGN KEY (cod_fao)
    REFERENCES especie (cod_fao),
  CONSTRAINT fk_produto_apresentacao FOREIGN KEY (cod_apresentacao)
    REFERENCES apresentacao (cod_apresentacao),
  CONSTRAINT ck_produto_peso CHECK (peso_caixa_kg IS NULL OR peso_caixa_kg > 0)
);

CREATE TABLE fator_conversao (
  cod_fao          CHAR(3)      NOT NULL,
  cod_apresentacao CHAR(3)      NOT NULL,
  fator            DECIMAL(4,2) NOT NULL COMMENT 'Peso vivo = peso produto x fator (RN18)',
  PRIMARY KEY (cod_fao, cod_apresentacao),
  CONSTRAINT fk_fator_conversao_especie FOREIGN KEY (cod_fao)
    REFERENCES especie (cod_fao),
  CONSTRAINT fk_fator_conversao_apresentacao FOREIGN KEY (cod_apresentacao)
    REFERENCES apresentacao (cod_apresentacao),
  CONSTRAINT ck_fator_positivo CHECK (fator > 0)
);

CREATE TABLE porao (
  id_porao          INT          NOT NULL AUTO_INCREMENT,
  id_navio          INT          NOT NULL,
  designacao        VARCHAR(50)  NOT NULL,
  capacidade_caixas INT          NOT NULL,
  temp_alvo_c       DECIMAL(4,1) NULL,
  PRIMARY KEY (id_porao),
  CONSTRAINT uq_porao UNIQUE (id_navio, designacao),
  CONSTRAINT fk_porao_navio FOREIGN KEY (id_navio)
    REFERENCES navio (id_navio),
  CONSTRAINT ck_porao_capacidade CHECK (capacidade_caixas > 0)
);

CREATE TABLE quota (
  id_quota  INT           NOT NULL AUTO_INCREMENT,
  id_navio  INT           NOT NULL,
  cod_fao   CHAR(3)       NOT NULL,
  id_zona   INT           NOT NULL,
  ano       SMALLINT      NOT NULL,
  quota_kg  DECIMAL(12,2) NOT NULL COMMENT 'Em peso vivo (RN19)',
  PRIMARY KEY (id_quota),
  CONSTRAINT uq_quota UNIQUE (id_navio, cod_fao, id_zona, ano),
  CONSTRAINT fk_quota_navio FOREIGN KEY (id_navio)
    REFERENCES navio (id_navio),
  CONSTRAINT fk_quota_especie FOREIGN KEY (cod_fao)
    REFERENCES especie (cod_fao),
  CONSTRAINT fk_quota_zona_pesca FOREIGN KEY (id_zona)
    REFERENCES zona_pesca (id_zona),
  CONSTRAINT ck_quota_positiva CHECK (quota_kg > 0)
);

-- ---------------------------------------------------------------------
-- 3. Operação: escalas, viagens e tripulação
-- ---------------------------------------------------------------------

CREATE TABLE escala (
  id_escala       INT          NOT NULL AUTO_INCREMENT,
  id_navio        INT          NOT NULL,
  cod_porto       CHAR(5)      NOT NULL,
  eta             DATETIME     NULL COMMENT 'Chegada prevista (UTC)',
  etd             DATETIME     NULL COMMENT 'Partida prevista (UTC)',
  ata             DATETIME     NULL COMMENT 'Chegada real (UTC)',
  atd             DATETIME     NULL COMMENT 'Partida real (UTC)',
  calado_m        DECIMAL(4,2) NULL,
  nivel_seguranca VARCHAR(30)  NULL,
  PRIMARY KEY (id_escala),
  CONSTRAINT fk_escala_navio FOREIGN KEY (id_navio)
    REFERENCES navio (id_navio),
  CONSTRAINT fk_escala_porto FOREIGN KEY (cod_porto)
    REFERENCES porto (cod_unlocode),
  CONSTRAINT ck_escala_prevista CHECK (eta IS NULL OR etd IS NULL OR etd > eta),
  CONSTRAINT ck_escala_real     CHECK (ata IS NULL OR atd IS NULL OR atd > ata)
);

CREATE TABLE viagem (
  id_viagem         INT NOT NULL AUTO_INCREMENT,
  id_navio          INT NOT NULL,
  num_viagem        INT NOT NULL COMMENT 'Sequencial por navio (RN3)',
  id_escala_partida INT NOT NULL,
  id_escala_chegada INT NULL COMMENT 'NULL enquanto a viagem decorre (RN4)',
  PRIMARY KEY (id_viagem),
  CONSTRAINT uq_viagem UNIQUE (id_navio, num_viagem),
  CONSTRAINT fk_viagem_navio FOREIGN KEY (id_navio)
    REFERENCES navio (id_navio),
  CONSTRAINT fk_viagem_escala_partida FOREIGN KEY (id_escala_partida)
    REFERENCES escala (id_escala),
  CONSTRAINT fk_viagem_escala_chegada FOREIGN KEY (id_escala_chegada)
    REFERENCES escala (id_escala),
  CONSTRAINT ck_viagem_escalas CHECK (id_escala_chegada IS NULL
                                      OR id_escala_chegada <> id_escala_partida)
);

CREATE TABLE tripulacao_viagem (
  id_viagem             INT NOT NULL,
  id_tripulante         INT NOT NULL,
  id_posto              INT NOT NULL,
  id_escala_embarque    INT NOT NULL,
  id_escala_desembarque INT NULL COMMENT 'NULL = fica a bordo (RN9)',
  PRIMARY KEY (id_viagem, id_tripulante),
  CONSTRAINT fk_tripulacao_viagem_viagem FOREIGN KEY (id_viagem)
    REFERENCES viagem (id_viagem),
  CONSTRAINT fk_tripulacao_viagem_tripulante FOREIGN KEY (id_tripulante)
    REFERENCES tripulante (id_tripulante),
  CONSTRAINT fk_tripulacao_viagem_posto FOREIGN KEY (id_posto)
    REFERENCES posto (id_posto),
  CONSTRAINT fk_tripulacao_viagem_escala_embarque FOREIGN KEY (id_escala_embarque)
    REFERENCES escala (id_escala),
  CONSTRAINT fk_tripulacao_viagem_escala_desembarque FOREIGN KEY (id_escala_desembarque)
    REFERENCES escala (id_escala)
);

CREATE TABLE turno (
  id_turno       INT      NOT NULL AUTO_INCREMENT,
  id_viagem      INT      NOT NULL,
  inicio         DATETIME NOT NULL,
  fim            DATETIME NULL,
  id_responsavel INT      NOT NULL COMMENT 'Factory Manager ou 2nd (RN28)',
  PRIMARY KEY (id_turno),
  CONSTRAINT fk_turno_viagem FOREIGN KEY (id_viagem)
    REFERENCES viagem (id_viagem),
  CONSTRAINT fk_turno_responsavel FOREIGN KEY (id_responsavel)
    REFERENCES tripulante (id_tripulante),
  CONSTRAINT ck_turno_horas CHECK (fim IS NULL OR fim > inicio)
);

-- ---------------------------------------------------------------------
-- 4. Pesca
-- ---------------------------------------------------------------------

CREATE TABLE lance (
  id_lance       INT          NOT NULL AUTO_INCREMENT,
  id_viagem      INT          NOT NULL,
  num_lance      INT          NOT NULL COMMENT 'Sequencial dentro da viagem',
  inicio         DATETIME     NOT NULL,
  fim            DATETIME     NULL,
  latitude       DECIMAL(9,6) NULL,
  longitude      DECIMAL(9,6) NULL,
  id_zona_pesca  INT          NOT NULL,
  profundidade_m INT          NULL,
  PRIMARY KEY (id_lance),
  CONSTRAINT uq_lance UNIQUE (id_viagem, num_lance),
  CONSTRAINT fk_lance_viagem FOREIGN KEY (id_viagem)
    REFERENCES viagem (id_viagem),
  CONSTRAINT fk_lance_zona_pesca FOREIGN KEY (id_zona_pesca)
    REFERENCES zona_pesca (id_zona),
  CONSTRAINT ck_lance_horas CHECK (fim IS NULL OR fim > inicio)
);

CREATE TABLE captura (
  id_lance     INT           NOT NULL,
  cod_fao      CHAR(3)       NOT NULL,
  peso_vivo_kg DECIMAL(10,2) NOT NULL COMMENT 'Peso vivo, antes do processamento',
  PRIMARY KEY (id_lance, cod_fao),
  CONSTRAINT fk_captura_lance FOREIGN KEY (id_lance)
    REFERENCES lance (id_lance),
  CONSTRAINT fk_captura_especie FOREIGN KEY (cod_fao)
    REFERENCES especie (cod_fao),
  CONSTRAINT ck_captura_peso CHECK (peso_vivo_kg > 0)
);

-- ---------------------------------------------------------------------
-- 5. Fábrica, porões e saídas
-- ---------------------------------------------------------------------

CREATE TABLE lote (
  id_lote               INT           NOT NULL AUTO_INCREMENT,
  codigo_lote           VARCHAR(30)   NOT NULL COMMENT 'Código impresso na caixa (RN17)',
  id_turno              INT           NOT NULL,
  id_produto            INT           NOT NULL,
  n_caixas              INT           NOT NULL,
  peso_liquido_kg       DECIMAL(10,2) NOT NULL,
  peso_materia_prima_kg DECIMAL(10,2) NOT NULL,
  PRIMARY KEY (id_lote),
  CONSTRAINT uq_lote_codigo UNIQUE (codigo_lote),
  CONSTRAINT fk_lote_turno FOREIGN KEY (id_turno)
    REFERENCES turno (id_turno),
  CONSTRAINT fk_lote_produto FOREIGN KEY (id_produto)
    REFERENCES produto (id_produto),
  CONSTRAINT ck_lote_caixas CHECK (n_caixas > 0),
  CONSTRAINT ck_lote_rendimento CHECK (peso_liquido_kg <= peso_materia_prima_kg) -- RN26
);

CREATE TABLE lote_lance (
  id_lote      INT           NOT NULL,
  id_lance     INT           NOT NULL,
  peso_vivo_kg DECIMAL(10,2) NOT NULL,
  PRIMARY KEY (id_lote, id_lance),
  CONSTRAINT fk_lote_lance_lote FOREIGN KEY (id_lote)
    REFERENCES lote (id_lote),
  CONSTRAINT fk_lote_lance_lance FOREIGN KEY (id_lance)
    REFERENCES lance (id_lance),
  CONSTRAINT ck_lote_lance_peso CHECK (peso_vivo_kg > 0)
);

CREATE TABLE armazenamento (
  id_lote      INT      NOT NULL,
  id_porao     INT      NOT NULL,
  n_caixas     INT      NOT NULL,
  data_entrada DATETIME NOT NULL,
  PRIMARY KEY (id_lote, id_porao),
  CONSTRAINT fk_armazenamento_lote FOREIGN KEY (id_lote)
    REFERENCES lote (id_lote),
  CONSTRAINT fk_armazenamento_porao FOREIGN KEY (id_porao)
    REFERENCES porao (id_porao),
  CONSTRAINT ck_armazenamento_caixas CHECK (n_caixas > 0)
);

CREATE TABLE saida_lote (
  id_saida      INT          NOT NULL AUTO_INCREMENT,
  id_lote       INT          NOT NULL,
  id_porao      INT          NOT NULL COMMENT 'Porão de onde saem as caixas',
  id_escala     INT          NULL COMMENT 'Preenchido numa descarga em porto',
  navio_recetor VARCHAR(50)  NULL COMMENT 'Preenchido num transbordo (nome ou IMO)',
  data_saida    DATETIME     NOT NULL,
  n_caixas      INT          NOT NULL,
  comprador     VARCHAR(100) NULL,
  PRIMARY KEY (id_saida),
  -- A saída tem de corresponder a um lote que esteve guardado nesse porão
  CONSTRAINT fk_saida_lote_armazenamento FOREIGN KEY (id_lote, id_porao)
    REFERENCES armazenamento (id_lote, id_porao),
  CONSTRAINT fk_saida_lote_escala FOREIGN KEY (id_escala)
    REFERENCES escala (id_escala),
  CONSTRAINT ck_saida_caixas CHECK (n_caixas > 0),
  -- RN25: ou descarga em porto, ou transbordo — exatamente um dos dois
  CONSTRAINT ck_saida_destino CHECK ((id_escala IS NULL) <> (navio_recetor IS NULL))
);

-- Verificação: deve devolver 23 tabelas e 34 FK
SELECT
  (SELECT COUNT(*) FROM information_schema.TABLES
    WHERE TABLE_SCHEMA = 'sta_princesa') AS total_tabelas,
  (SELECT COUNT(*) FROM information_schema.REFERENTIAL_CONSTRAINTS
    WHERE CONSTRAINT_SCHEMA = 'sta_princesa') AS total_fk;
