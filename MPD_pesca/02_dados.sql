-- =====================================================================
-- Projeto MPD — Base de dados do navio-fábrica (sta_princesa)
-- 02_dados.sql — dados de teste (FICTÍCIOS) de uma maré completa
-- Correr depois do 01_schema.sql. Pode ser corrido várias vezes:
-- começa por esvaziar todas as tabelas.
--
-- Todos os nomes de pessoas, números de documentos, IMO/MMSI e
-- quantidades são inventados. Os dados reais da tripulação NÃO
-- devem ser usados (RGPD).
-- =====================================================================

USE sta_princesa;

-- ---------------------------------------------------------------------
-- 0. Limpeza (permite voltar a correr o script)
-- ---------------------------------------------------------------------
SET FOREIGN_KEY_CHECKS = 0;
TRUNCATE TABLE saida_lote;
TRUNCATE TABLE armazenamento;
TRUNCATE TABLE lote_lance;
TRUNCATE TABLE lote;
TRUNCATE TABLE captura;
TRUNCATE TABLE lance;
TRUNCATE TABLE turno;
TRUNCATE TABLE tripulacao_viagem;
TRUNCATE TABLE viagem;
TRUNCATE TABLE escala;
TRUNCATE TABLE quota;
TRUNCATE TABLE porao;
TRUNCATE TABLE fator_conversao;
TRUNCATE TABLE produto;
TRUNCATE TABLE documento;
TRUNCATE TABLE tripulante;
TRUNCATE TABLE navio;
TRUNCATE TABLE tipo_documento;
TRUNCATE TABLE posto;
TRUNCATE TABLE porto;
TRUNCATE TABLE zona_pesca;
TRUNCATE TABLE apresentacao;
TRUNCATE TABLE especie;
SET FOREIGN_KEY_CHECKS = 1;

-- ---------------------------------------------------------------------
-- 1. Tabelas de referência
-- ---------------------------------------------------------------------

INSERT INTO especie (cod_fao, nome_comum, nome_cientifico) VALUES
  ('COD', 'Bacalhau',       'Gadus morhua'),
  ('PRA', 'Camarão-boreal', 'Pandalus borealis');

INSERT INTO apresentacao (cod_apresentacao, designacao) VALUES
  ('HEG', 'Sem cabeça e eviscerado'),
  ('WHL', 'Inteiro');

INSERT INTO zona_pesca (id_zona, codigo_ices, jurisdicao, designacao) VALUES
  (1, '2.a', 'ZEE Noruega',      'Mar da Noruega'),
  (2, '2.b', 'ZEE Noruega',      'Mar de Barents ocidental'),
  (3, '2.b', 'Zona de Svalbard', 'Zona de proteção de Svalbard');

INSERT INTO porto (cod_unlocode, nome, pais) VALUES
  ('NOTOS', 'Tromsø',    'NO'),
  ('PTAVE', 'Aveiro',    'PT'),
  ('DECUX', 'Cuxhaven',  'DE');

INSERT INTO posto (id_posto, designacao, departamento) VALUES
  (1, 'Captain',             'Ponte'),
  (2, 'Chief Mate',          'Ponte'),
  (3, 'Chief Engineer',      'Máquinas'),
  (4, 'Factory Manager',     'Fábrica'),
  (5, '2nd Factory Manager', 'Fábrica'),
  (6, 'Fishing Master',      'Pesca'),
  (7, 'Trawlboss',           'Pesca'),
  (8, 'Fisherman',           'Pesca'),
  (9, 'Cook',                'Cozinha');

INSERT INTO tipo_documento (id_tipo_doc, designacao) VALUES
  (1, 'Passaporte'),
  (2, 'Cédula marítima'),
  (3, 'Cartão de Cidadão'),
  (4, 'Visto');

-- ---------------------------------------------------------------------
-- 2. Navio, tripulantes e documentos
-- ---------------------------------------------------------------------

INSERT INTO navio (id_navio, imo, nome, indicativo_chamada, mmsi, tipo_navio, bandeira, armador) VALUES
  (1, 9000001, 'Santa Princesa', 'CXXX1', 263000001,
   'Arrastão congelador (factory trawler)', 'PT', 'Armador Exemplo, Lda.');

INSERT INTO tripulante (id_tripulante, apelido, nomes_proprios, data_nascimento, local_nascimento, genero, nacionalidade) VALUES
  ( 1, 'Ferreira',  'António Manuel', '1978-03-11', 'Aveiro',      'M', 'PT'),
  ( 2, 'Santos',    'Rui Miguel',     '1975-06-02', 'Figueira da Foz', 'M', 'PT'),
  ( 3, 'Oliveira',  'Pedro Nuno',     '1984-09-23', 'Ílhavo',      'M', 'PT'),
  ( 4, 'Marques',   'Hugo Filipe',    '1990-01-15', 'Murtosa',     'M', 'PT'),
  ( 5, 'Rocha',     'Tiago André',    '1993-04-30', 'Vagos',       'M', 'PT'),
  ( 6, 'Einarsson', 'Gunnar',         '1982-12-05', 'Reiquiavique','M', 'IS'),
  ( 7, 'Lopes',     'Carlos Alberto', '1971-07-19', 'Aveiro',      'M', 'PT'),
  ( 8, 'Neves',     'João Paulo',     '1986-02-08', 'Estarreja',   'M', 'PT'),
  ( 9, 'Pinto',     'Bruno Miguel',   '1995-10-21', 'Murtosa',     'M', 'PT'),
  (10, 'Popescu',   'Andrei',         '2001-05-14', 'Constança',   'M', 'RO'),
  (11, 'Kovalenko', 'Dmytro',         '1988-08-27', 'Odessa',      'M', 'UA'),
  (12, 'Sousa',     'Ricardo Jorge',  '1999-11-03', 'Aveiro',      'M', 'PT'),
  (13, 'Almeida',   'Fábio Daniel',   '1980-03-29', 'Peniche',     'M', 'PT'),
  (14, 'Teixeira',  'Nuno Alexandre', '1987-06-16', 'Ílhavo',      'M', 'PT');

-- Passaporte de todos; cédula marítima de alguns; documentos a caducar
-- em breve (2026-11 / 2026-12) para testar a consulta de validades.
INSERT INTO documento (id_tripulante, id_tipo_doc, numero, cod_pais_emissor, data_validade) VALUES
  ( 1, 1, 'PX100001', 'PT', '2030-05-10'),
  ( 1, 2, '0012/04',  'PT', NULL),
  ( 2, 1, 'PX100002', 'PT', '2026-11-30'),
  ( 2, 2, '07/93',    'PT', NULL),
  ( 3, 1, 'PX100003', 'PT', '2029-02-01'),
  ( 4, 1, 'PX100004', 'PT', '2031-08-20'),
  ( 5, 1, 'PX100005', 'PT', '2028-04-12'),
  ( 6, 1, 'A9000006', 'IS', '2027-12-31'),
  ( 7, 1, 'PX100007', 'PT', '2026-12-15'),
  ( 7, 2, '000390',   'PT', NULL),
  ( 8, 1, 'PX100008', 'PT', '2032-01-09'),
  ( 9, 1, 'PX100009', 'PT', '2029-09-09'),
  (10, 1, '060000010','RO', '2030-03-03'),
  (11, 1, 'FT000011', 'UA', '2028-07-07'),
  (11, 4, 'NOR-V-0011','NO','2027-01-31'),
  (12, 1, 'PX100012', 'PT', '2033-06-06'),
  (13, 1, 'PX100013', 'PT', '2030-10-10'),
  (14, 1, 'PX100014', 'PT', '2029-12-12');

-- ---------------------------------------------------------------------
-- 3. Produtos, fatores de conversão, porões e quotas
-- ---------------------------------------------------------------------

INSERT INTO produto (id_produto, cod_fao, cod_apresentacao, peso_caixa_kg) VALUES
  (1, 'COD', 'HEG', 25.00),   -- peso por caixa: valor de exemplo
  (2, 'PRA', 'WHL', 20.00);

-- Fator do bacalhau HEG = valor de referência, a confirmar
INSERT INTO fator_conversao (cod_fao, cod_apresentacao, fator) VALUES
  ('COD', 'HEG', 1.50),
  ('PRA', 'WHL', 1.00);

INSERT INTO porao (id_porao, id_navio, designacao, capacidade_caixas, temp_alvo_c) VALUES
  (1, 1, 'Porão 1 (vante)', 20000, -25.0),
  (2, 1, 'Porão 2 (ré)',    15000, -25.0);

-- Quotas de 2026, em kg de peso vivo
INSERT INTO quota (id_navio, cod_fao, id_zona, ano, quota_kg) VALUES
  (1, 'COD', 1, 2026, 400000.00),
  (1, 'COD', 2, 2026, 250000.00),
  (1, 'COD', 3, 2026, 300000.00),
  (1, 'PRA', 3, 2026, 150000.00);

-- ---------------------------------------------------------------------
-- 4. Escalas e viagens
--    Trip 11: parte de Tromsø a 12/07 e regressa a 24/08 (concluída)
--    Trip 12: parte a 26/08 e ainda está no mar (chegada = NULL)
-- ---------------------------------------------------------------------

INSERT INTO escala (id_escala, id_navio, cod_porto, eta, etd, ata, atd, calado_m, nivel_seguranca) VALUES
  (1, 1, 'NOTOS', '2026-07-10 06:00', '2026-07-12 15:30',
                  '2026-07-10 07:15', '2026-07-12 15:30', 7.20, 'Security Level 1'),
  (2, 1, 'NOTOS', '2026-08-24 06:00', '2026-08-26 12:00',
                  '2026-08-24 05:40', '2026-08-26 12:30', 7.50, 'Security Level 1');

INSERT INTO viagem (id_viagem, id_navio, num_viagem, id_escala_partida, id_escala_chegada) VALUES
  (1, 1, 11, 1, 2),
  (2, 1, 12, 2, NULL);

-- ---------------------------------------------------------------------
-- 5. Tripulação por viagem
--    Na Trip 11, os tripulantes 7, 11 e 12 ficam a bordo
--    (desembarque = NULL, RN9) e seguem na Trip 12.
--    O tripulante 7 muda de posto: Trawlboss -> Fisherman (RN8).
-- ---------------------------------------------------------------------

INSERT INTO tripulacao_viagem (id_viagem, id_tripulante, id_posto, id_escala_embarque, id_escala_desembarque) VALUES
  (1,  1, 1, 1, 2),
  (1,  2, 2, 1, 2),
  (1,  3, 3, 1, 2),
  (1,  4, 4, 1, 2),
  (1,  5, 5, 1, 2),
  (1,  6, 6, 1, 2),
  (1,  7, 7, 1, NULL),
  (1,  8, 8, 1, 2),
  (1,  9, 8, 1, 2),
  (1, 10, 9, 1, 2),
  (1, 11, 8, 1, NULL),
  (1, 12, 8, 1, NULL),
  (2, 13, 1, 2, NULL),
  (2, 14, 4, 2, NULL),
  (2,  7, 8, 2, NULL),
  (2, 11, 8, 2, NULL),
  (2, 12, 8, 2, NULL);

-- ---------------------------------------------------------------------
-- 6. Lances e capturas da Trip 11 (amostra dos primeiros 4 dias)
--    Peso vivo total: COD 42 200 kg | PRA 14 000 kg
-- ---------------------------------------------------------------------

INSERT INTO lance (id_lance, id_viagem, num_lance, inicio, fim, latitude, longitude, id_zona_pesca, profundidade_m) VALUES
  (1, 1, 1, '2026-07-13 06:00', '2026-07-13 09:30', 70.950000, 17.400000, 1, 280),
  (2, 1, 2, '2026-07-13 12:00', '2026-07-13 15:45', 71.020000, 17.650000, 1, 300),
  (3, 1, 3, '2026-07-14 05:30', '2026-07-14 09:00', 73.600000, 19.200000, 2, 320),
  (4, 1, 4, '2026-07-14 11:00', '2026-07-14 14:30', 73.750000, 19.550000, 2, 310),
  (5, 1, 5, '2026-07-15 06:00', '2026-07-15 10:00', 76.400000, 13.800000, 3, 360),
  (6, 1, 6, '2026-07-15 12:30', '2026-07-15 16:30', 76.520000, 13.950000, 3, 380),
  (7, 1, 7, '2026-07-16 05:00', '2026-07-16 08:30', 76.300000, 14.200000, 3, 250),
  (8, 1, 8, '2026-07-16 10:30', '2026-07-16 14:00', 76.450000, 14.050000, 3, 370);

INSERT INTO captura (id_lance, cod_fao, peso_vivo_kg) VALUES
  (1, 'COD', 8200.00),
  (2, 'COD', 9100.00),
  (3, 'COD', 7600.00),
  (4, 'COD', 6800.00),
  (5, 'PRA', 4200.00),
  (5, 'COD',  600.00),   -- captura acessória de bacalhau num lance de camarão
  (6, 'PRA', 5100.00),
  (7, 'COD', 9500.00),
  (8, 'PRA', 4700.00),
  (8, 'COD',  400.00);

-- ---------------------------------------------------------------------
-- 7. Turnos da fábrica (6 h) — responsável: Factory Manager (4)
--    ou 2nd Factory Manager (5), RN28
-- ---------------------------------------------------------------------

INSERT INTO turno (id_turno, id_viagem, inicio, fim, id_responsavel) VALUES
  (1, 1, '2026-07-13 06:00', '2026-07-13 12:00', 4),
  (2, 1, '2026-07-13 12:00', '2026-07-13 18:00', 5),
  (3, 1, '2026-07-14 06:00', '2026-07-14 12:00', 4),
  (4, 1, '2026-07-14 12:00', '2026-07-14 18:00', 5),
  (5, 1, '2026-07-15 12:00', '2026-07-15 18:00', 4),
  (6, 1, '2026-07-16 06:00', '2026-07-16 12:00', 5),
  (7, 1, '2026-07-16 12:00', '2026-07-16 18:00', 4);

-- ---------------------------------------------------------------------
-- 8. Lotes de produção e origem (lote_lance)
--    Bacalhau HEG: caixas de 25 kg | Camarão WHL: caixas de 20 kg
--    peso_liquido_kg = n_caixas x peso da caixa
--    peso_materia_prima_kg = soma do peso vivo vindo dos lances
-- ---------------------------------------------------------------------

INSERT INTO lote (id_lote, codigo_lote, id_turno, id_produto, n_caixas, peso_liquido_kg, peso_materia_prima_kg) VALUES
  (1, 'SP-T11-COD-001', 1, 1, 218, 5450.00, 8200.00),
  (2, 'SP-T11-COD-002', 2, 1, 242, 6050.00, 9100.00),
  (3, 'SP-T11-COD-003', 3, 1, 202, 5050.00, 7600.00),
  (4, 'SP-T11-COD-004', 4, 1, 197, 4925.00, 7400.00),
  (5, 'SP-T11-PRA-001', 5, 2, 460, 9200.00, 9300.00),
  (6, 'SP-T11-COD-005', 6, 1, 264, 6600.00, 9900.00),
  (7, 'SP-T11-PRA-002', 7, 2, 234, 4680.00, 4700.00);

-- Um lote pode juntar vários lances (lotes 4, 5 e 6) e um lance pode
-- dar vários lotes (lance 5: bacalhau -> lote 4, camarão -> lote 5)
INSERT INTO lote_lance (id_lote, id_lance, peso_vivo_kg) VALUES
  (1, 1, 8200.00),
  (2, 2, 9100.00),
  (3, 3, 7600.00),
  (4, 4, 6800.00),
  (4, 5,  600.00),
  (5, 5, 4200.00),
  (5, 6, 5100.00),
  (6, 7, 9500.00),
  (6, 8,  400.00),
  (7, 8, 4700.00);

-- ---------------------------------------------------------------------
-- 9. Armazenamento nos porões
--    O lote 6 fica repartido pelos dois porões (150 + 114 caixas)
-- ---------------------------------------------------------------------

INSERT INTO armazenamento (id_lote, id_porao, n_caixas, data_entrada) VALUES
  (1, 1, 218, '2026-07-13 16:00'),
  (2, 1, 242, '2026-07-13 22:00'),
  (3, 1, 202, '2026-07-14 16:00'),
  (4, 1, 197, '2026-07-14 22:00'),
  (5, 2, 460, '2026-07-15 22:00'),
  (6, 1, 150, '2026-07-16 16:00'),
  (6, 2, 114, '2026-07-16 16:00'),
  (7, 2, 234, '2026-07-16 22:00');

-- ---------------------------------------------------------------------
-- 10. Saídas
--     Transbordo no mar a 20/07 (sem escala, com navio recetor)
--     Descarga em Tromsø na escala 2 (com escala, sem navio recetor)
--     Ficam a bordo: lote 4 (97 cx), lote 6 (264 cx), lote 7 (234 cx)
-- ---------------------------------------------------------------------

INSERT INTO saida_lote (id_lote, id_porao, id_escala, navio_recetor, data_saida, n_caixas, comprador) VALUES
  (4, 1, NULL, 'Reefer Exemplo (IMO 9000002)', '2026-07-20 09:00', 100, 'Comprador Exemplo B'),
  (1, 1, 2,    NULL,                           '2026-08-24 10:00', 218, 'Comprador Exemplo A'),
  (2, 1, 2,    NULL,                           '2026-08-24 10:00', 242, 'Comprador Exemplo A'),
  (3, 1, 2,    NULL,                           '2026-08-24 14:00', 202, 'Comprador Exemplo A'),
  (5, 2, 2,    NULL,                           '2026-08-25 08:00', 460, 'Comprador Exemplo C');

-- =====================================================================
-- Verificações rápidas (devem bater certo com os comentários)
-- =====================================================================

-- a) Captura total por espécie (esperado: COD 42 200 | PRA 14 000)
SELECT c.cod_fao, SUM(c.peso_vivo_kg) AS peso_vivo_total_kg
FROM captura c
GROUP BY c.cod_fao;

-- b) Quota consumida por espécie e zona em 2026
SELECT q.cod_fao, z.codigo_ices, z.jurisdicao, q.quota_kg,
       COALESCE(SUM(c.peso_vivo_kg), 0) AS capturado_kg,
       ROUND(100 * COALESCE(SUM(c.peso_vivo_kg), 0) / q.quota_kg, 2) AS percentagem
FROM quota q
JOIN zona_pesca z ON z.id_zona = q.id_zona
LEFT JOIN lance l   ON l.id_zona_pesca = q.id_zona
                   AND YEAR(l.inicio) = q.ano
LEFT JOIN captura c ON c.id_lance = l.id_lance
                   AND c.cod_fao = q.cod_fao
GROUP BY q.id_quota, q.cod_fao, z.codigo_ices, z.jurisdicao, q.quota_kg;

-- c) Stock a bordo por lote (armazenado - saídas)
--    (esperado: lote 4 = 97, lote 6 = 264, lote 7 = 234, restantes = 0)
SELECT lo.codigo_lote,
       a.armazenado,
       COALESCE(s.saido, 0)               AS saido,
       a.armazenado - COALESCE(s.saido, 0) AS stock_a_bordo
FROM lote lo
JOIN (SELECT id_lote, SUM(n_caixas) AS armazenado
      FROM armazenamento GROUP BY id_lote) a ON a.id_lote = lo.id_lote
LEFT JOIN (SELECT id_lote, SUM(n_caixas) AS saido
           FROM saida_lote GROUP BY id_lote) s ON s.id_lote = lo.id_lote
ORDER BY lo.id_lote;
