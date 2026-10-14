# Notas para o relatório

O relatório está num documento no claude.ai (Project "Projeto MPD - pesca"). Aqui fica tudo o que muda no projeto e ainda não foi passado para lá. Depois de passar uma entrada, marcá-la com [x].

Formato de cada entrada: data · secção do relatório · o que mudou · texto proposto (curto).

## Já no relatório (até 12/10/2026)

- [x] 12/10 · 4.3, 4.4, 5.4 · v_quota_consumo, sp_fechar_lote, índice com EXPLAIN, utilizadores por papel
- [x] 12/10 · 5.1, 5.3, 5.5 · stack decidida, esqueleto, UI04 e UI01 com evidências
- [x] 12/10 · 4.4, 6.1, 6.3 · correção dos triggers (TC41), testes TC42–TC43, limitações do UI01

- [x] 12/10 · 5.1 · Node.js 25.6 em vez de 22 LTS

## Por passar

### Reorganização de 14/10 (estrutura do Guia) — afeta todo o relatório

- [ ] 14/10 · todo o relatório e Anexo A · Nomes dos ficheiros SQL
  > O projeto passou para a estrutura do Guia. Onde o relatório cita scripts numerados, usar os nomes novos: `01_schema.sql` → `data/schema.sql`; `02_dados.sql` → `data/seed.sql`; `03_triggers.sql`, `07_fechar_lote.sql` e `09_utilizadores.sql` → `data/programmable_objects.sql` (partes 1, 2 e 3); `05_consultas.sql` → `data/views.sql` (as 2 vistas) e `data/queries.sql` (as consultas); `04_testes_triggers.sql` → `data/testes/testes_triggers.sql`; `08_testes_fechar_lote.sql` → `data/testes/testes_fechar_lote.sql`; `06_indice_explain.sql` → `data/testes/indice_explain.sql`. O `01b_saida_porao.sql` foi retirado (a alteração já está no schema). Sítios a rever: 4.1, 4.2, 4.4 (EXPLAIN), 5.4 (utilizadores), 6.1 (descrição dos níveis de teste), Anexo A.
- [ ] 14/10 · Anexo A · Tabela de artefactos e execução
  > A tabela do Anexo A fica certa nos destinos; acrescentar `data/testes/` (4 ficheiros) e `data/executar_tudo.ps1`, e retirar "(+ 01b_saida_porao.sql)". Instruções de execução, a substituir:
  > 1. `docker compose up -d` (contentor MPD_pesca, MySQL 8.4, porta 3307).
  > 2. Na pasta do projeto: `.\data\executar_tudo.ps1` — corre schema → seed → views → programmable_objects; `-Testes` corre também os testes. Em Linux/macOS, o ciclo `for` do README.
  > 3. Na pasta `application/`: copiar `.env.example` para `.env`, `npm install`, `npm run verificar` (4 × OK) e `npm start`; abrir http://localhost:3000.
  > O `schema.sql` cria a BD se não existir, por isso também funciona com um `docker run` simples. O script lê a palavra-passe de root dentro do contentor: nenhuma credencial fica escrita nos scripts.
- [ ] 14/10 · 4.3 · O queries.sql tem 17 consultas (Q01–Q17), não 16
  > A tabela de 4.3 conta 16 consultas em 8 grupos, mas são 17 (1a–1c, 2a–2b, 3a–3b, 4a–4c, 5a–5b, 6a–6c, 7, 8). No `data/queries.sql` cada consulta tem agora um identificador Q01–Q17 e mantém o número do grupo usado no relatório ("consulta 5" = Q11–Q12, "consulta 8" = Q17). As vistas saíram para o `data/views.sql`.
- [ ] 14/10 · 3.2 · ERD: nomes das caixas de agrupamento
  > O ERD final (`documentation/diagrams/ERD_sta_princesa.png`, exportado do DbSchema a 14/10, já com a `saida_lote` atual: `id_porao`, `navio_recetor`, `data_saida` e FK composta para `armazenamento`) tem quatro caixas: **"Operação e Tripulação"**, **"Pesca e Quotas"**, **"Fábrica, porões e saídas"** e **"Vistas"**. Atenção ao texto de 3.1/3.2, que fala de quatro áreas com outra arrumação: no ERD, `turno` está na caixa "Operação e Tripulação" (em 3.1 está na Fábrica), `navio` está na caixa "Pesca e Quotas" (em 3.1 está na Operação) e os porões estão na mesma caixa que a fábrica (em 3.1 são uma área própria). Ou se ajusta o texto ao ERD, ou se reposicionam as tabelas no DbSchema e se exporta de novo. Os 4 PNG antigos por área (desatualizados na `saida_lote`) foram apagados.
- [ ] 14/10 · 3.3 · Dicionário de dados
  > O `documentation/data-dictionary.csv` foi gerado a 14/10 a partir do `information_schema` e confrontado com a BD (tipo, PK, nulo e as 35 colunas de FK iguais): 114 atributos, 23 tabelas, colunas do Guia (tabela, atributo, tipo, PK, FK, nulo, único, domínio, descrição, exemplo). O texto de 3.3 fica certo.
- [ ] 14/10 · 6.1 · TC18–TC25 automatizados
  > Os testes de restrições TC18, TC19, TC20, TC23, TC24 e TC25 (até aqui manuais ou "por correr") estão agora em `data/testes/testes_restricoes.sql`, numa transação desfeita no fim: **6/6 OK**. Estado na tabela de 6.1: todos "OK". Duas notas: no TC19 (saída de um porão onde o lote nunca esteve) quem recusa primeiro é o trigger RN24 ("há 0 caixas"), porque os triggers BEFORE INSERT correm antes da verificação das FK — a FK composta fica como segunda garantia; no TC24 o teste usa uma escala só com ATA, para ser mesmo o CHECK `ck_viagem_escalas` a recusar (com horas de partida, o trigger RN33 recusava antes). O TC21 (reprodutibilidade) passa a ser `.\data\executar_tudo.ps1 -Testes` corrido duas vezes; o TC22 (migração 01b) fica como teste histórico, porque a migração deixou de fazer parte da entrega.
- [ ] 14/10 · 6.2 · ai-use-summary.md
  > O `documentation/ai-use-summary.md` foi criado com os quatro casos de 6.2 (AI-01 a AI-04), no formato do modelo do Guia. Se o grupo quiser trocar um caso por um da fase do protótipo, candidatos com boa validação humana: datas no futuro aceites pela BD, encontradas pelo Rodrigo nas capturas (→ BR17); erro no JavaScript de dois ecrãs que os testes pela API não apanharam (→ testes também no browser); código de lote repetido entre separadores, encontrado ao preparar o TC27.
- [ ] 14/10 · Resumo inicial do relatório · Números finais
  > "23 tabelas, 34 chaves estrangeiras, 20 regras de negócio garantidas na própria base de dados, 2 vistas, 14 triggers, um procedimento transacional (e um auxiliar dos triggers) e utilizadores por papel"; casos de teste: TC01–TC83; protótipo com seis ecrãs. Grupo: Rodrigo Pereira, Hugo Grou, Marcelo Manteigas, Martim Ferreira (faltam os números de estudante).
- [ ] 14/10 · 5.5 · Evidências finais (substituem as entradas de evidências de 12/10 e 13/10)
  > Tiradas pelo Rodrigo a 14/10 numa só sessão, a partir dos dados de teste, com o `GUIAO_CAPTURAS.md`; todas com "Viagem" e o logótipo. Em `documentation/evidencias/`:
  > | Ficheiro | Ecrã | O que mostra |
  > | --- | --- | --- |
  > | `UI04_painel_quotas.png` | Painel de quotas | 4 quotas de 2026, todas OK; bacalhau 42 200 kg, camarão 14 000 kg, a mais consumida 9,33 % |
  > | `UI01_recusado_pela_bd.png` | Lances e capturas | COD 3 000 + PRA 500 kg na zona 2.a: o aviso antecipa a recusa e a BD recusa (RN19, não há quota de PRA nessa zona); a lista continua vazia |
  > | `UI01_lance_gravado.png` | Lances e capturas | lance n.º 3 gravado com 2 capturas (transação); lista com os 3 lances da Viagem 12 |
  > | `UI02_lote_gravado.png` | Fábrica — lotes | turno 06:00–12:30 fechado; lote SP-T12-COD-001: 106 cx, 2 650 kg de 4 000 kg de peso vivo (66,3 %), lances n.º 1 e 2, Porão 1: 60 cx e Porão 2: 46 cx (`sp_fechar_lote`) |
  > | `UI02_recusado_pela_bd.png` | Fábrica — lotes | **TC27** com dois separadores: o 1.º gravou o SP-T12-COD-002 com os 1 000 kg do lance n.º 3; o 2.º, sem atualizar, pede os mesmos 1 000 kg e a BD recusa (RN16: "o lance n.º 3 tem 0.00 kg de COD disponíveis, pedido 1000.00") — nada gravado |
  > | `UI03_recusado_pela_bd.png` | Porões e saídas | descarga de 120 cx do SP-T11-COD-004 com 97 no porão: aviso + recusa (RN24) |
  > | `UI03_stock_saidas.png` | Porões e saídas | descarga de 60 cx gravada; o lote passa de 97 para 37 cx e a saída aparece na lista |
  > | `UI05_rastrear_caixa.png` | Rastreabilidade | SP-T11-COD-004 (de 13/10, gerada no Edge; mostra 97 cx a bordo, antes da descarga do UI03) |
  > | `UI05_lote_viagem12.png` | Rastreabilidade | SP-T12-COD-001, feito no próprio protótipo: lances n.º 1 (75 %) e n.º 2 (25 %) com posição e zona, entradas de 60 e 46 cx — rastreabilidade de ponta a ponta |
  > | `UI05_codigo_inexistente.png` | Rastreabilidade | código inexistente (de 13/10) |
  > | `FR13_fecho_recusado.png` | Viagens e escalas | fechar a Viagem 12 com o turno das 13:00 aberto: recusado (RN33); cartão "Por fechar antes da chegada: 1" |
  > | `FR13_viagem_fechada.png` | Viagens e escalas | Viagem 12 fechada em Tromsø (escala criada na chegada, só com ATA): 3 desembarcam, 2 ficam a bordo |
  > | `FR13_nova_viagem_aviso.png` + `FR13_nova_viagem_recusada.png` | Viagens e escalas | abrir a Viagem 13 com dois Captain: o aviso antecipa a recusa (RN10) e a BD recusa — nada gravado (a ETD da escala também não) |
  > | `FR13_nova_viagem.png` | Viagens e escalas | Viagem 13 aberta: partida de Tromsø, 4 tripulantes (os 2 que ficaram a bordo + Captain + Factory Manager) |
  > | `FR13_nova_viagem_historico.png` | Viagens e escalas | histórico: Viagem 11 e 12 concluídas, 13 em curso; o aviso RN34 já impede abrir outra |
  > Nota sobre a última: o rodapé ainda dizia "Viagem em curso: Viagem 12", porque só era lido ao abrir a página; corrigido a 14/10 (o rodapé é atualizado depois de abrir ou fechar uma viagem). Não usar essa captura no relatório, ou cortar o rodapé.
  > Depois das capturas, o aviso de quota do UI01 passou a citar "(RN19)" em vez de "(BR08)", como os outros ecrãs e a mensagem da BD; na `UI01_recusado_pela_bd.png` ainda se lê "(BR08)". Se o relatório explicar a captura, dizer que BR08 e RN19 são a mesma regra (a tabela 2.2 já tem a coluna RN).
  > Apagar do relatório as capturas antigas que já não existem: `UI02_turno_aberto`, `UI02_turno_fechado`, `UI02_lote_gravado_lista`, `UI05_lote_descarregado` (com "Trip").

- [ ] 12/10 · 5.3 · UI02 Fechar lote feito (`/lotes.html`, app_fabrica)
  > O ecrã UI02 (Fechar lote) usa o utilizador `app_fabrica`. Mostra os turnos da viagem em curso e permite abrir um turno (INSERT em `turno`, com o responsável escolhido entre o Factory Manager e o 2nd Factory Manager da viagem) e fechá-lo (UPDATE da hora de fim). Para o turno e o produto escolhidos, lista apenas os lances terminados até ao fim do turno — ou até à hora atual, se o turno ainda estiver aberto — que ainda têm peso disponível da espécie do produto (capturado menos o já usado noutros lotes, o mesmo cálculo do trigger `trg_lote_lance_viagem`). Mostra também a capacidade livre de cada porão (capacidade menos o stock da vista `v_stock`) e sugere o código do lote (ex.: SP-T12-COD-001). Antes de gravar, o ecrã avisa quando a BD vai recusar (peso acima do disponível, caixas nos porões diferentes das do lote, produto mais pesado do que a matéria-prima, porão sem espaço), mas não bloqueia o botão: quem decide é a base de dados.

- [ ] 12/10 · 5.4 · Fecho do lote só pelo procedimento; sem privilégios novos
  > A aplicação não escreve em `lote`, `lote_lance` nem `armazenamento`: o fecho do lote é um único `CALL sp_fechar_lote(...)`, que faz os três passos numa transação da própria BD e, se qualquer passo falhar, faz ROLLBACK e devolve a mensagem original (RESIGNAL), que o ecrã mostra ao utilizador. O utilizador `app_fabrica` já tinha tudo o que o ecrã precisa (leitura, INSERT e UPDATE(fim) em `turno`, EXECUTE no procedimento): não foi preciso alterar o esquema nem os privilégios.

- [ ] 12/10 · 6.1 · Testes do UI02: TC44–TC50 (todos OK)
  > Testes feitos pela API do protótipo, com as contagens de `lote` / `lote_lance` / `armazenamento` lidas antes e depois de cada pedido. Depois dos testes, 02 → 04 (18/18) e 08 (9/9).
  >
  > | TC | Caso | Esperado | Obtido |
  > | --- | --- | --- | --- |
  > | TC44 | Abrir turno com o Factory Manager; fechá-lo com fim antes do início; fechá-lo às 12:00; fechá-lo outra vez | aceite; recusado (CHECK `ck_turno_horas`); aceite; recusado (400, já fechado) | OK |
  > | TC45 | Abrir turno com um Fisherman como responsável | recusado: "RN28: o responsável não é Factory Manager nem 2nd Factory Manager nesta viagem" | OK, nenhum turno gravado |
  > | TC46 | Lote de 80 cx (2 000 kg) com 3 000 kg de um lance, porões 1 (50) e 2 (30) | aceite: +1 lote, +1 lote_lance, +2 armazenamento | OK (rendimento 66,7 %) |
  > | TC47 | TC27 no ecrã: 2.º separador, carregado antes do TC46, usa o mesmo lance | recusado: "RN16: lance … tem 0.00 kg de COD disponíveis, pedido 500.00" | OK, nada gravado |
  > | TC48 | Pedir 1 500 kg de um lance com 1 000 kg disponíveis | recusado pelo RN16 no 2.º passo | OK, nada gravado |
  > | TC49 | Lote de 27 cx com 20 cx nos porões | recusado: "Lote: o lote tem 27 caixas, mas os porões recebem 20" | OK, nada gravado |
  > | TC50 | Lote num turno ainda aberto (lances terminados até agora) | aceite; entrada nos porões = hora atual (UTC) | OK |
  >
  > Nota: depois do TC47 e do TC48 o `id_lote` seguinte salta dois números. É a prova de que o lote chegou a ser inserido (passo 1) e foi desfeito pelo ROLLBACK quando o trigger recusou o passo 2: o AUTO_INCREMENT não volta atrás.

- [ ] 12/10 · 6.3 · Limitações do UI02
  > A BD não impede turnos sobrepostos na mesma viagem nem um turno com fim no futuro. Num turno aberto, o limite para os lances é a hora atual (UTC), o mesmo que o `sp_fechar_lote` usa. O código do lote é sugerido pela aplicação; se dois utilizadores fecharem um lote ao mesmo tempo com o mesmo código, o UNIQUE `uq_lote_codigo` recusa o segundo (409). Que o turno não começa antes da partida da viagem é validado só pela aplicação, como no UI01.

- [ ] 13/10 · 4.4 (e 2.2, regras de negócio) · Nova regra: lances sem datas no futuro — 2 triggers novos (9 no total)
  > Durante os testes do protótipo verificou-se que a BD aceitava um lance com início ou fim depois da hora atual. Isso permitia, por exemplo, que um lance ainda por acabar contasse como "terminado" no fecho de um lote. A regra — só se regista o que já aconteceu — foi posta na BD e não apenas na aplicação. Não pode ser um CHECK, porque o MySQL não aceita funções não determinísticas como UTC_TIMESTAMP() num CHECK; por isso foram criados dois triggers: `trg_lance_datas` (BEFORE INSERT) e `trg_lance_datas_update` (BEFORE UPDATE). O segundo é necessário porque o mestre de pesca fecha o lance com UPDATE da coluna `fim`, e só valida a coluna que muda, para uma correção da posição não ser recusada. A comparação é com UTC_TIMESTAMP(), coerente com a RN7 (datas em UTC), e não depende do fuso horário do servidor. São os primeiros triggers BEFORE UPDATE do projeto.
  > Número da regra: **RN31** (ver a entrada 2.2 da numeração); as mensagens do trigger começam por "RN31:".

- [ ] 13/10 · 6.1 · Testes TC51–TC56 (todos OK); 04 passa a 22/22
  > | TC | Caso | Esperado | Obtido |
  > | --- | --- | --- | --- |
  > | TC51 | INSERT de lance com fim daqui a 2 dias (04) | recusado: "RN31: o fim (…) é depois da hora atual (… UTC)" | OK |
  > | TC52 | INSERT de lance a começar daqui a 1 dia, sem fim (04) | recusado | OK |
  > | TC53 | UPDATE do fim de um lance para daqui a 2 dias (04) | recusado | OK |
  > | TC54 | UPDATE do fim de um lance para uma data passada (04) | aceite | OK |
  > | TC55 | UI01: gravar lance com fim no futuro | 422 com a mensagem do trigger; lance e capturas não gravados | OK |
  > | TC56 | Utilizador app_pesca: UPDATE do fim para o futuro / UPDATE só da latitude | recusado / aceite | OK |
  >
  > Os testes do 04 usam datas relativas a UTC_TIMESTAMP(), para não deixarem de ser "futuras" com o passar do tempo. Pipeline 01→09 do zero: 04 22/22, 08 9/9.

- [ ] 13/10 · 5.3 · UI01: aviso de datas no futuro
  > O ecrã de lances passou a avisar, antes de gravar, quando o início ou o fim do lance estão depois da hora atual (UTC). Como os outros avisos, não bloqueia o botão: quem recusa é o trigger.

- [ ] 13/10 · 6.3 · Limitações (datas)
  > Continuam só na aplicação a verificação de que o lance não começa antes da partida da viagem; os turnos ainda aceitam datas no futuro. Os triggers de quantidades (RN16, RN19, RN22, RN24) continuam a cobrir só INSERT.

- [ ] 13/10 · 5.3 · UI03 Stock e saídas feito (`/stock.html`, app_comandante)
  > O ecrã UI03 (Stock a bordo e saídas) usa o utilizador `app_comandante`. Mostra a ocupação de cada porão face à capacidade, o total a bordo por espécie e o stock de cada lote em cada porão, a partir da vista `v_stock` (as mesmas consultas 4a–4c do script de análise). Permite registar uma saída — descarga numa escala ou transbordo para outro navio — com um único INSERT em `saida_lote`; as regras são todas da BD: o trigger `trg_saida_stock` (RN24) recusa mais caixas do que as que estão no porão, o CHECK `ck_saida_destino` (RN25) exige descarga ou transbordo e nunca os dois, e a chave estrangeira composta (lote, porão) → armazenamento garante que só sai de um porão o que lá esteve. O ecrã mostra as caixas disponíveis e avisa antes de gravar, sem bloquear o botão. Lista também as saídas registadas.

- [ ] 13/10 · 6.1 · Testes do UI03: TC57–TC61 (todos OK)
  > | TC | Caso | Esperado | Obtido |
  > | --- | --- | --- | --- |
  > | TC57 | Descarga de 60 cx do lote SP-T11-COD-004 (Porão 1) na escala de Tromsø | aceite; stock 97 → 37 | OK |
  > | TC58 | Transbordo de 50 cx do lote SP-T11-PRA-002 (Porão 2) | aceite; stock 234 → 184 | OK |
  > | TC59 | Descarga de 40 cx do lote SP-T11-COD-004 (restam 37) | recusado: "RN24: stock insuficiente no porão: há 37 caixas, pedido 40" | OK, nada gravado |
  > | TC60 | Saída do lote SP-T11-PRA-002 do Porão 1, onde nunca esteve | recusado pelo RN24 ("há 0 caixas") — o trigger corre antes da FK composta, que fica como segunda garantia | OK, nada gravado |
  > | TC61 | Escala e navio recetor ao mesmo tempo (pedido direto à API) | recusado pelo CHECK `ck_saida_destino` (RN25) | OK, nada gravado |
  >
  > Também verificado: sem escala nem navio → CHECK RN25; 0 caixas → CHECK `ck_saida_caixas`. Depois dos testes: 02 → 04 22/22, 08 9/9.

- [ ] 13/10 · 6.3 · Limitação: datas das saídas
  > A BD não verifica as datas das saídas: aceita uma saída no futuro, anterior à entrada do lote no porão, ou uma descarga numa escala que terminou antes de o lote ser produzido. O UI03 avisa nestes casos (sem bloquear), mas a regra não está na BD — decisão do grupo, para não aumentar o número de triggers; seria um trigger BEFORE INSERT em `saida_lote`, como o das datas dos lances.

- [ ] 13/10 · 4.4 (e 2.2) · Escalas e fecho da viagem: 4 triggers novos e um procedimento auxiliar (13 triggers no total)
  > A data de chegada de uma viagem raramente é conhecida com exatidão quando o navio parte. O modelo trata isto sem alterações ao esquema: enquanto a viagem decorre, `viagem.id_escala_chegada` fica a NULL (RN4), e a escala de chegada, se já estiver planeada, só tem uma ETA, que é uma previsão e pode mudar ou faltar. O que tem de ser verdade só se verifica no fecho, e foi posto na BD:
  > - `trg_escala_datas` (BEFORE INSERT) e `trg_escala_datas_update` (BEFORE UPDATE): a chegada e a partida reais (ATA/ATD) de uma escala não podem ser depois da hora atual (UTC); as previstas (ETA/ETD) podem. No UPDATE só se valida a coluna que muda.
  > - `trg_viagem_chegada` (BEFORE INSERT) e `trg_viagem_chegada_update` (BEFORE UPDATE): uma viagem só pode ficar com escala de chegada se essa escala for do mesmo navio, já tiver ATA (o navio chegou mesmo), a chegada for depois da partida (ATD, ou ETD se faltar) e não houver lances nem turnos da viagem por terminar ou a terminar depois da chegada. As regras estão num procedimento auxiliar, `sp_validar_chegada_viagem`, chamado pelos dois triggers, para o INSERT e o UPDATE aplicarem exatamente as mesmas. Como os triggers correm com os privilégios de quem os criou, nenhum utilizador da aplicação precisa de EXECUTE neste procedimento.
  > Estas regras completam os CHECK que já existiam (`ck_escala_prevista`: ETD > ETA; `ck_escala_real`: ATD > ATA; `ck_viagem_escalas`: chegada ≠ partida). Números das regras: **RN32** (datas das escalas) e **RN33** (fecho da viagem); as mensagens começam por "RN32:" e "RN33:".

- [ ] 13/10 · 5.3 · Ecrã Viagens e escalas (FR13) feito (`/viagens.html`, app_comandante)
  > É o ecrã de atualização do protótipo. Mostra a viagem em curso, a tripulação a bordo e o que ainda está por fechar (lances e turnos), as escalas do navio e o histórico das viagens. Permite registar uma escala nova (INSERT) e corrigir uma existente — horas previstas e reais, calado e nível de segurança (UPDATE só das colunas que o papel do comandante pode alterar; o porto não muda). Para fechar a viagem, o comandante escolhe uma escala já planeada (e indica a ATA real) ou cria a escala no momento da chegada, e marca quem desembarca; quem não é marcado fica a bordo para a viagem seguinte (RN9). O fecho é uma operação de vários passos e corre numa transação da aplicação: escala (INSERT, ou UPDATE da ATA) + `UPDATE viagem SET id_escala_chegada` + `UPDATE tripulacao_viagem SET id_escala_desembarque`. Se a BD recusar qualquer passo, nada fica gravado. O ecrã avisa antes de gravar quando a BD vai recusar, sem bloquear o botão.

- [ ] 13/10 · 6.1 · Testes do FR13: TC62–TC71 (todos OK); 04 passa a 30/30
  > | TC | Caso | Esperado | Obtido |
  > | --- | --- | --- | --- |
  > | TC62 | Escala planeada em Tromsø só com ETA daqui a 7 dias; depois mudar a ETA | aceite; ETA alterada | OK |
  > | TC63 | Escala com ETD antes da ETA | recusado pelo CHECK `ck_escala_prevista` | OK, nada gravado |
  > | TC64 | Registar uma ATA amanhã | recusado: "RN32: a ATA (…) é depois da hora atual (… UTC)" | OK |
  > | TC65 | Escala de 24/08: ATD antes da ATA (corresponde ao TC25 do catálogo) | recusado pelo CHECK `ck_escala_real` | OK |
  > | TC66 | Fechar a Viagem 12 na escala planeada, ainda sem ATA | recusado: "RN33: a escala de chegada ainda não tem ATA" | OK, nada alterado |
  > | TC67 | Fechar a Viagem 12 na escala de 10/07 | recusado: "RN33: a chegada (2026-07-10 07:15) não é depois da partida (2026-08-26 12:30)" | OK |
  > | TC68 | Fechar a Viagem 12 com uma escala nova, com um lance e um turno por terminar | recusado: "RN33: há 1 lance(s) por terminar…"; a escala nova, já inserida no 1.º passo, foi desfeita (transação) | OK, nada gravado |
  > | TC69 | Fechar a Viagem 12 com uma escala nova (ATA há 1 hora); desembarcam o comandante, o Factory Manager e um pescador; dois pescadores ficam a bordo (corresponde ao TC30 do catálogo) | aceite: viagem concluída, 3 desembarques, 2 a bordo | OK |
  > | TC70 | Fechar a Viagem 12 outra vez | recusado (400, já fechada) | OK |
  > | TC71 | `app_comandante` direto: `UPDATE viagem SET id_escala_partida` | recusado pelo privilégio por coluna (erro 1143) | OK |
  >
  > No 04 (+8 testes, 30 no total), com datas relativas à hora atual: escala só com ETA futura aceite; ATA futura recusada no INSERT e no UPDATE; fechar a viagem sem ATA, com a chegada antes da partida e com um lance por terminar recusado; fechar correto aceite; INSERT de uma viagem já fechada com chegada antes da partida recusado. Pipeline 01→09 do zero: 04 30/30, 08 9/9.

- [ ] 13/10 · 6.3 · Limitações (FR13)
  > Corrigir a ATA de uma escala que já é a chegada de uma viagem fechada não volta a validar o fecho (só a regra de não ser no futuro). Não se verifica que a mesma escala não é a chegada de duas viagens.

- [ ] 13/10 · 2.2 · Regras novas RN31–RN34 (numeração)
  > Durante o desenvolvimento do protótipo foram acrescentadas quatro regras de negócio, numeradas a seguir à última do catálogo (RN30):
  > | Regra | Descrição | Implementação |
  > | --- | --- | --- |
  > | RN31 | Um lance não pode começar nem acabar depois da hora atual (UTC): só se regista o que já aconteceu | `trg_lance_datas`, `trg_lance_datas_update` |
  > | RN32 | A chegada e a partida reais (ATA/ATD) de uma escala não podem ser no futuro; as previstas (ETA/ETD) podem | `trg_escala_datas`, `trg_escala_datas_update` |
  > | RN33 | Uma viagem só fecha numa escala do mesmo navio, com ATA, depois da partida, e sem lances nem turnos por terminar ou a terminar depois da chegada (completa a RN4) | `trg_viagem_chegada`, `trg_viagem_chegada_update` + `sp_validar_chegada_viagem` |
  > | RN34 | Uma viagem nova parte de uma escala do navio que ainda não foi partida de outra viagem, e só pode haver uma viagem em curso por navio | `trg_viagem_partida` |
  > **Atualizado a 14/10, depois de ler o relatório:** o relatório usa BR01–BR16 como identificador e a coluna RN só como código de desenvolvimento. As quatro regras entram na tabela 2.2 como **BR17 (RN31), BR18 (RN32), BR19 (RN33) e BR20 (RN34)**, com o texto do `documentation/business-rules.md`. O total passa de 16 para 20 regras (atualizar o resumo do início do relatório e a 6.3).

- [ ] 13/10 · 4.4 · Trigger 14: `trg_viagem_partida` (RN34) — 14 triggers no total
  > Para abrir a viagem seguinte foi acrescentado o trigger `trg_viagem_partida` (BEFORE INSERT em `viagem`, a correr depois do `trg_viagem_chegada`, com FOLLOWS). Recusa uma viagem cuja escala de partida seja de outro navio ou já seja a partida de outra viagem, e uma viagem nova em curso quando o navio ainda tem outra por fechar: primeiro fecha-se a anterior (RN33). Como o comandante só pode alterar `id_escala_chegada` (privilégio por coluna), não é preciso validar o UPDATE da partida.

- [ ] 13/10 · 5.3 · Ecrã Viagens e escalas: abrir nova viagem
  > O ecrã de viagens permite também abrir a viagem seguinte. O comandante escolhe a escala de partida (por omissão, a chegada da última viagem), indica a partida prevista e/ou real (ETD/ATD) e marca quem embarca, com o posto nesta viagem. Por omissão vêm marcados os tripulantes que ficaram a bordo no fim da viagem anterior (RN9), com o último posto. O número da viagem é o seguinte do navio (RN3). É uma operação de vários passos e corre numa transação da aplicação: horas de partida da escala (UPDATE) + `INSERT viagem` + `INSERT tripulacao_viagem` de cada tripulante; se a BD recusar algum passo (RN34, RN10, RN32), nada fica gravado. Antes de gravar, o ecrã distingue o que a BD vai recusar (viagem anterior em curso, dois comandantes, ATD no futuro) do que a BD aceita mas deixa a viagem incompleta (sem comandante, sem Factory Manager — e portanto sem turnos na fábrica, RN28 —, tripulante que ficou a bordo e não embarca).

- [ ] 13/10 · 6.1 · Testes da nova viagem: TC72–TC77 (todos OK); 04 passa a 33/33
  > | TC | Caso | Esperado | Obtido |
  > | --- | --- | --- | --- |
  > | TC72 | Abrir a Viagem 13 com a Viagem 12 ainda em curso (com ATD na escala de partida) | recusado: "RN34: o navio ainda tem a Viagem 12 em curso (feche-a primeiro)"; a ATD gravada no 1.º passo foi desfeita | OK, nada gravado |
  > | TC73 | Abrir a Viagem 13 com dois comandantes | recusado pelo RN10; a viagem já inserida no 2.º passo foi desfeita | OK, nada gravado |
  > | TC74 | Abrir a Viagem 13 na escala de partida da Viagem 12 | recusado: "RN34: esta escala já é a partida da Viagem 12" | OK |
  > | TC75 | Abrir a Viagem 13 com ATD amanhã | recusado: "RN32: a ATD (…) é depois da hora atual" | OK |
  > | TC76 | Abrir a Viagem 13 a partir da escala de chegada da Viagem 12, com os 2 que ficaram a bordo + comandante + Factory Manager + 1 pescador | aceite: Viagem 13 em curso, 5 tripulantes, ATD gravada | OK |
  > | TC77 | A Viagem 13 nos outros ecrãs: lances usa a Viagem 13; turno com o Factory Manager que embarcou aceite; turno com o Factory Manager da Viagem 12 (não embarcou) recusado pelo RN28 | como descrito | OK |
  >
  > No 04 (+3 testes, 33 no total): abrir a Viagem 13 depois de fechar a 12 aceite; partida numa escala já usada recusada; segunda viagem em curso recusada. Pipeline 01→09 do zero: 04 33/33, 08 9/9.

- [ ] 13/10 · 6.3 · Limitações (nova viagem)
  > A RN34 não verifica que a partida de uma viagem nova é depois da chegada da anterior quando as escalas são diferentes (na mesma escala, o CHECK `ck_escala_real` garante ATD > ATA). A BD também não obriga a que uma viagem tenha comandante ou Factory Manager: com triggers por linha não é possível exigir "pelo menos um" no momento do INSERT da viagem, porque a tripulação é inserida depois; o ecrã avisa.

- [ ] 13/10 · 6.1 · Testes do protótipo: API e browser
  > Os casos de teste do protótipo (TC44–TC77) foram executados pela API, com as contagens de linhas lidas na BD antes e depois de cada pedido. Isso prova as regras e as transações, mas não o ecrã: um erro no JavaScript de dois ecrãs (Fechar lote e Viagens e escalas) — os dados chegavam antes de algumas funções do ecrã estarem definidas, e as listas ficavam vazias — só apareceu ao usar o ecrã. Depois da correção, os cinco ecrãs passaram também a ser verificados num browser (Microsoft Edge sem janela, a gerar a página final), além das capturas de ecrã tiradas à mão.

- [ ] 13/10 · 5.5 · Evidências do FR13 (Viagens e escalas)
  > `FR13_viagem_fechada.png`: a Viagem 12 fechada em Tromsø com uma escala criada no momento da chegada (só com ATA, sem ETA — a chegada não tinha sido prevista); os 5 tripulantes desembarcaram; deixa de haver viagem em curso. `FR13_nova_viagem.png`: a Viagem 13 aberta a partir da mesma escala (ATD registada), com 13 tripulantes; a tabela de escalas mostra a escala como "chegada Viagem 12 · partida Viagem 13".
  > Opcionais, ainda por tirar: um fecho recusado pela BD (ex.: RN33 com um lance por terminar) e uma nova viagem recusada (ex.: RN10 com dois comandantes, ou RN34 com a viagem anterior em curso).

- [ ] 13/10 · 5.3 · UI05 Rastrear uma caixa feito (`/rastreio.html`, app_armador)
  > O ecrã UI05 responde à pergunta de um comprador ou de uma inspeção: de onde veio o peixe desta caixa? A partir do código do lote impresso na caixa (RN17), mostra o produto, o turno e a viagem em que foi produzido, o responsável, o rendimento face ao peso vivo, as caixas ainda a bordo e em que porões; a origem — os lances, com período, zona ICES, posição, profundidade, peso vivo e percentagem do lote; e o destino — as entradas nos porões e as saídas, por descarga em porto ou transbordo, com o comprador. É só de leitura e usa o utilizador `app_armador` (como no mockup): as consultas são as de rastreabilidade do script de análise (5a e 5b), com o código como parâmetro, e o stock vem da vista `v_stock`. O código pode vir no endereço (`?codigo=…`), para partilhar uma pesquisa.

- [ ] 13/10 · 6.1 · Testes do UI05: TC78–TC83 (todos OK)
  > | TC | Caso | Esperado | Obtido |
  > | --- | --- | --- | --- |
  > | TC78 | Rastrear SP-T11-COD-004 | 197 cx, 4 925 kg, rendimento 66,6 %; lances 4 (6 800 kg, 91,9 %) e 5 (600 kg, 8,1 %) em duas zonas; entrada de 197 cx e transbordo de 100; 97 cx a bordo no Porão 1 — iguais ao mockup e à consulta 5 | OK |
  > | TC79 | Rastrear SP-T11-COD-005 (lote repartido) | duas entradas (150 cx no Porão 1, 114 no Porão 2) e stock nos dois porões | OK |
  > | TC80 | Rastrear SP-T11-COD-001 (descarregado) | descarga em Tromsø (NOTOS) com comprador; nada a bordo | OK |
  > | TC81 | Código em minúsculas e com espaços | encontra o lote | OK |
  > | TC82 | Código inexistente | 404: "Não existe nenhum lote com o código …" | OK |
  > | TC83 | Tentativa de injeção SQL no código (`' OR '1'='1`) | tratada como texto (parâmetro `?`): lote inexistente | OK |

- [ ] 13/10 · 4.4 e 5.3 · Mensagens com o número que o utilizador vê; código do lote atribuído ao gravar
  > A mensagem da RN16 passou a indicar o número do lance na viagem ("RN16: o lance n.º 3 tem 0.00 kg de COD disponíveis…") e não o identificador interno, que não aparece nos ecrãs e pode não coincidir (um INSERT desfeito também consome um valor de AUTO_INCREMENT). No ecrã Fechar lote, o código do lote (SP-T12-COD-002, …) passou a ser atribuído pelo servidor no momento de gravar; o ecrã mostra-o como sugestão. Assim, dois utilizadores a fechar lotes ao mesmo tempo não tentam o mesmo código — e o caso TC27 com dois separadores chega mesmo à RN16, em vez de ser travado antes pela unicidade do código.

- [ ] 13/10 · 5.5 · Capturas de ecrã: guião
  > As capturas do relatório vão ser refeitas no fim, numa só sessão e a partir dos dados de teste, seguindo `documentation/GUIAO_CAPTURAS.md` (13 capturas: um sucesso e uma recusa da BD por ecrã, incluindo o TC27). Quando estiverem feitas, atualizar as entradas 5.5 destas notas com os nomes finais.

- [ ] 13/10 · 5.3 (e todo o relatório) · "Viagem" em vez de "Trip"
  > Os mockups e a primeira versão do protótipo identificavam as viagens como "Trip 11" e "Trip 12", termo herdado dos documentos de bordo em inglês. Para cumprir a regra de usar português em todo o projeto, os ecrãs, as mensagens da aplicação e da base de dados e a documentação passaram a dizer "Viagem 11" e "Viagem 12" (o número da viagem do navio, `num_viagem`; o `id_viagem` é só a chave técnica). Mantêm-se o código do lote impresso na caixa (`SP-T12-COD-001`: T + número da viagem) e os mockups originais. **Ao passar para o relatório: trocar "Trip" por "Viagem" no texto que já lá estiver.** As capturas de ecrã tiradas antes desta mudança ainda mostram "Trip".

- [ ] 13/10 · 5.3 · Identidade visual: logótipo na barra lateral
  > Em todos os ecrãs, o topo da barra lateral mostra o logótipo do navio (ilustração do arrastão com o nome "Santa Princesa") em vez do nome em texto usado nos mockups. É a única diferença visual deliberada em relação aos mockups.

- [ ] 13/10 · 5.5 · Evidências do UI05
  > `UI05_rastrear_caixa.png` (rastreio do SP-T11-COD-004, igual ao mockup, com os dados reais) e `UI05_codigo_inexistente.png` (mensagem de lote inexistente). Geradas pelo Microsoft Edge a partir da aplicação em funcionamento. `UI05_lote_descarregado.png` (tirada pelo Rodrigo): o SP-T11-COD-002, de um só lance (100 % do lote), com a entrada no Porão 1 e a descarga em Tromsø — "0 caixas, já saiu tudo do navio".

- [ ] 13/10 · 5.5 · Evidências do UI03
  > `UI03_stock_saidas.png`: descarga de 60 cx do lote SP-T11-COD-004 em Tromsø registada; o stock do lote no Porão 1 passa de 97 para 37 e a saída aparece na lista. `UI03_recusado_pela_bd.png`: pedido de 40 cx com 37 disponíveis — o ecrã avisa antes ("A base de dados vai recusar esta saída…") e a BD recusa com "RN24: stock insuficiente no porão: há 37 caixas, pedido 40"; o stock não muda.

- [ ] 13/10 · 5.5 · Evidências do UI02
  > Em `documentation/evidencias/`: `UI02_turno_aberto.png` (turno aberto com o Factory Manager; lances terminados com bacalhau disponível), `UI02_lote_gravado.png` (mensagem "Lote SP-T12-COD-001 gravado: 106 caixas, 2 lances de origem, 2 porões"), `UI02_lote_gravado_lista.png` (o lote na lista: 106 cx, 2 650 kg de produto, 4 000 kg de matéria-prima, 66,3 %, porões 60 + 46; os lances deixam de aparecer porque já não têm peso disponível) e `UI02_turno_fechado.png` (turno 06:00–12:30 fechado, com 1 lote).
  > **Por tirar:** `UI02_recusado_pela_bd.png` (TC27 no ecrã: mensagem RN16, nada gravado).
