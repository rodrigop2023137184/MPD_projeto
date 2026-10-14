# Functional Requirements

13 requisitos: 8 de registo (FR01–FR08), 4 de consulta e relatório (FR09–FR12) e 1 de atualização (FR13). "Implementado em" liga cada requisito ao objeto da base de dados (`data/`) e ao ecrã do protótipo que o cumpre.

## FR01 — Registar escalas e viagens
**Descrição:** O sistema deve registar escalas (porto, horas previstas e reais) e viagens (número, escala de partida e de chegada).
**Ator(es):** Comandante
**Condição de aceitação:** uma viagem só aceita escalas existentes; o número não se repete no mesmo navio; só há uma viagem em curso por navio.
**Implementado em:** schema (FK, `uq_viagem`); `trg_viagem_partida` (BR20); ecrã Viagens e escalas (nova escala, abrir a viagem seguinte).

## FR02 — Registar tripulantes e documentos
**Descrição:** O sistema deve registar tripulantes e os seus documentos de identificação.
**Ator(es):** Comandante
**Condição de aceitação:** o mesmo documento (tipo, número, país emissor) não é registado duas vezes; só o comandante lê os documentos (RGPD).
**Implementado em:** schema (`uq_documento`); privilégios por papel (`programmable_objects.sql`, parte 3). Sem ecrã no protótipo.

## FR03 — Registar a tripulação de cada viagem
**Descrição:** O sistema deve registar a tripulação de cada viagem, com posto, escala de embarque e de desembarque.
**Ator(es):** Comandante
**Condição de aceitação:** recusa um segundo comandante na mesma viagem; quem não desembarca fica a bordo para a viagem seguinte.
**Implementado em:** `trg_tripulacao_comandante` (BR06); ecrã Viagens e escalas (embarque ao abrir a viagem, desembarque ao fechá-la).

## FR04 — Registar quotas anuais
**Descrição:** O sistema deve registar as quotas anuais por navio, espécie e zona.
**Ator(es):** Armador
**Condição de aceitação:** uma só quota por navio, espécie, zona e ano.
**Implementado em:** schema (`uq_quota`). Sem ecrã de escrita no protótipo (o painel UI04 só lê).

## FR05 — Registar lances e capturas
**Descrição:** O sistema deve registar lances (início, fim, posição, zona) e capturas por espécie em peso vivo.
**Ator(es):** Mestre de pesca
**Condição de aceitação:** recusa capturas sem quota ou acima da quota restante, e lances com datas no futuro; o lance e as capturas são gravados juntos ou nada é gravado.
**Implementado em:** `trg_captura_quota` (BR08), `trg_lance_datas` (BR17); ecrã UI01 (transação da aplicação).

## FR06 — Registar turnos e lotes
**Descrição:** O sistema deve registar turnos da fábrica e lotes produzidos, com os lances de origem.
**Ator(es):** Responsável de fábrica
**Condição de aceitação:** recusa responsável sem posto de fábrica, lances de outra viagem, sem peso disponível ou ainda não terminados; o lote, a origem e os porões são gravados juntos ou nada é gravado.
**Implementado em:** `trg_turno_responsavel` (BR12), `trg_lote_lance_viagem` (BR10), `sp_fechar_lote` (BR16); ecrã UI02.

## FR07 — Registar a entrada das caixas nos porões
**Descrição:** O sistema deve registar a entrada das caixas de cada lote nos porões.
**Ator(es):** Responsável de fábrica
**Condição de aceitação:** recusa mais caixas do que as do lote ou acima da capacidade do porão.
**Implementado em:** `trg_armazenamento_lote`, `trg_armazenamento_capacidade` (BR13), dentro do `sp_fechar_lote`; ecrã UI02.

## FR08 — Registar saídas
**Descrição:** O sistema deve registar saídas: descarga numa escala ou transbordo para outro navio.
**Ator(es):** Comandante
**Condição de aceitação:** recusa saídas acima do stock do porão e saídas que sejam as duas coisas ou nenhuma.
**Implementado em:** `trg_saida_stock`, `ck_saida_destino`, FK composta (BR14); ecrã UI03.

## FR09 — Painel de quotas
**Descrição:** O sistema deve mostrar a quota consumida por espécie e zona, com alerta a 75 % e 90 %.
**Ator(es):** Armador, Mestre de pesca
**Condição de aceitação:** valores iguais à soma das capturas da zona e do ano.
**Implementado em:** vista `v_quota_consumo`, consultas Q04–Q05; ecrã UI04 (com exportação CSV) e aviso do UI01.

## FR10 — Stock a bordo
**Descrição:** O sistema deve mostrar o stock a bordo por porão, lote e espécie, e a ocupação dos porões.
**Ator(es):** Armador, Comprador
**Condição de aceitação:** stock = entradas − saídas, por porão.
**Implementado em:** vista `v_stock`, consultas Q08–Q10; ecrã UI03.

## FR11 — Rastrear uma caixa
**Descrição:** O sistema deve rastrear uma caixa pelo código do lote: lances, zonas, datas, turno e destino.
**Ator(es):** Comprador, Armador
**Condição de aceitação:** devolve todos os lances do lote e todas as entradas e saídas.
**Implementado em:** consultas Q11–Q12 (consulta 5); ecrã UI05.

## FR12 — Relatórios de fábrica e tripulação
**Descrição:** O sistema deve produzir relatórios de rendimento, reconciliação com o fator de conversão, tripulação a bordo numa data e documentos a caducar.
**Ator(es):** Responsável de fábrica, Comandante
**Condição de aceitação:** rendimento ponderado pelo peso; diferenças acima da tolerância assinaladas.
**Implementado em:** consultas Q01–Q03, Q06–Q07, Q13–Q16 (`data/queries.sql`). Sem ecrã no protótipo.

## FR13 — Atualizar escalas e fechar a viagem
**Descrição:** O sistema deve atualizar uma escala com as horas reais de chegada e partida (ATA/ATD) e fechar a viagem, indicando a escala de chegada.
**Ator(es):** Comandante
**Condição de aceitação:** partida real depois da chegada real; horas reais não podem ser no futuro; a escala de chegada é diferente da de partida, tem ATA e é depois da partida; não há lances nem turnos por terminar.
**Implementado em:** `ck_escala_real`, `ck_viagem_escalas`, `trg_escala_datas` (BR18), `trg_viagem_chegada_update` (BR19); UPDATE por coluna do `app_comandante`; ecrã Viagens e escalas (escala, chegada e desembarques numa transação).
