# Estado do projeto MPD — BD navio-fábrica (atualizado a 14/10/2026)

> **Nota:** desde 14/10 os scripts SQL estão em `data/` com os nomes do modelo do Guia (ver a secção "Feito a 14/10/2026"). As secções anteriores mantêm os nomes antigos (01_schema.sql, 03_triggers.sql, …), que eram os nomes na altura.

## Feito
- Esquema final: 23 tabelas, 34 FK (`01_schema.sql`). Base de dados `sta_princesa` no MySQL 8.4 em Docker (contentor `MPD_pesca`, porta 3307, root/root, aluno/mysql).
- `01b_saida_porao.sql`: migração já aplicada (saida_lote.id_porao + FK composta (id_lote, id_porao) → armazenamento).
- Dados de teste fictícios (`02_dados.sql`): Viagem 11 completa (12/07–24/08/2026) + Viagem 12 em curso; 14 tripulantes; 8 lances; COD 42 200 kg e PRA 14 000 kg em peso vivo; 7 lotes; 2 porões; 1 transbordo + 1 descarga em Tromsø; stock a bordo: lote 4 = 97 cx, lote 6 = 264 cx, lote 7 = 234 cx.
- Correção de 12/10 nos dados: os lotes 4 e 6 passaram para os turnos 5 e 7 (usavam lances que acabavam depois do fim do turno). A consulta 8 devolve zero linhas.
- 14 triggers (`03_triggers.sql`): trg_captura_quota (RN19), trg_saida_stock (RN24), trg_armazenamento_lote, trg_armazenamento_capacidade (RN22), trg_lote_lance_viagem (RN16), trg_turno_responsavel (RN28), trg_tripulacao_comandante (RN10); desde 13/10 também trg_lance_datas / _update (RN31), trg_escala_datas / _update (RN32), trg_viagem_chegada / _update (RN33, + procedimento auxiliar sp_validar_chegada_viagem) e trg_viagem_partida (RN34).
- Testes dos triggers (`04_testes_triggers.sql`): 33/33 OK (18 até 12/10; 22 depois das datas dos lances; 30 depois do FR13).
- `05_consultas.sql`: rendimento, quota consumida, reconciliação com o fator, stock, rastreabilidade, tripulação, documentos a caducar, controlo temporal lote vs lance. Duas vistas: `v_stock` e `v_quota_consumo`.
- Mockups UI01–UI05 (12/10).

## Feito a 12/10/2026 — base de dados pronta para o protótipo
Testado em MySQL 8.0 (01→09 duas vezes do zero, e sobre uma BD antiga). Confirmado no Docker do Rodrigo (MySQL 8.4) a 12/10: 03, 05, 06, 07, 09 e 08 corridos no DBeaver sem erros, 08 com 9/9 OK.
- **Índice + correção do YEAR(inicio):** `ix_lance_zona_inicio (id_zona_pesca, inicio)` no 01; o `trg_captura_quota` (03) e a verificação b) do 02 filtram o ano por intervalo de datas. `06_indice_explain.sql` mostra o EXPLAIN com 50 000 lances de carga: ANTES ref/key_len 4/16 668 linhas lidas, DEPOIS range/key_len 9/2 linhas. O índice substitui o índice automático da FK da zona. O 06 cria o índice se faltar (BD antigas).
- **2.ª vista `v_quota_consumo`** (05, consulta 2): uma linha por quota, com capturado, restante, % e estado (ATENÇÃO ≥ 75 %, CRÍTICO ≥ 90 %). Usa uma subconsulta LATERAL com o mesmo cálculo do trigger. É a fonte do UI04.
- **`sp_fechar_lote`** (`07_fechar_lote.sql`): cria lote + lote_lance + armazenamento numa transação; handler com ROLLBACK + RESIGNAL; lances e porões em JSON (JSON_TABLE); calcula matéria-prima e peso do produto; valida que as caixas dos porões = caixas do lote e que os lances terminaram antes do fim do turno; bloqueia os lances com FOR UPDATE (testado com duas sessões em simultâneo). É chamado pelo UI02.
- **`08_testes_fechar_lote.sql`:** 9/9 OK (TC27, TC31–TC38). Em todos os casos recusados não fica nada gravado, mesmo com o erro no 2.º ou no 3.º passo.
- **`09_utilizadores.sql`:** roles role_consulta/comandante/pesca/fabrica/armador e utilizadores app_comandante, app_pesca, app_fabrica, app_armador (palavras-passe de demonstração Comandante-2026, Pesca-2026, Fabrica-2026, Armador-2026, sem '#' por causa do .env). Só o comandante lê `documento` (RGPD); UPDATE por coluna; a fábrica só cria lotes pelo procedimento. 17 testes de privilégios OK.
- Verificação do 01 corrigida: conta só BASE TABLE (as vistas faziam aparecer 24/25 ao voltar a correr o 01).
- README.md atualizado (estrutura, ordem 01→09, vistas/procedimento/índice, utilizadores, testes, limitações).

## Como correr scripts (Windows, pasta MPD_pesca)
Desde 14/10: `.\data\executar_tudo.ps1` (schema → seed → views → programmable_objects) e `.\data\executar_tudo.ps1 -Testes` (mais os três scripts de `data/testes/`). Um ficheiro só:
cmd /c "docker exec -i MPD_pesca mysql -uroot -proot --default-character-set=utf8mb4 --table < data\FICHEIRO.sql"

## Protótipo — iniciado a 12/10/2026
- **Stack decidida pelo grupo:** Node.js 22 LTS + Express 5.3.0 + mysql2 3.24.5, páginas HTML simples. Fixada em `documentation/technical-stack.md`. Só 2 dependências; o .env é lido com process.loadEnvFile (sem dotenv).
- **Esqueleto em `application/`** (ver application/README.md): `src/config.js` (lê .env), `src/db.js` (um pool mysql2 por papel: armador, pesca, fabrica, comandante), `src/erros.js` (1644 SIGNAL/3819/1452 → 422, 1062 → 409, 1142/1143 → 403, ligação → 503, com a mensagem da BD), `src/rotas/contexto.js` (rodapé: utilizador, viagem em curso), `scripts/verificar-ligacao.js` (`npm run verificar`), `public/css/app.css` (estilo dos mockups), `public/js/comum.js` (barra lateral, api(), formatação pt-PT).
- **UI04 Painel de quotas — feito:** `src/rotas/quotas.js` (GET /api/quotas?ano=, /anos, /csv) com app_armador sobre a v_quota_consumo; `public/quotas.html` + `public/js/quotas.js`. Testado em MySQL 8.0: valores iguais à consulta 2 (TC28 OK), estados ATENÇÃO/CRÍTICO com cor (testados baixando quotas temporariamente), mensagem clara sem BD (503), CSV para Excel PT. Captura: `documentation/evidencias/UI04_painel_quotas.png`.
- Arranque (pasta application): `Copy-Item .env.example .env` → `npm install` → `npm run verificar` → `npm start` → http://localhost:3000.

- Confirmado no PC do Rodrigo (Windows, Docker MySQL 8.4) a 12/10: `npm run verificar` 4 × OK, aplicação a arrancar. Descompactou em MPD_pesca\prototipo_sta_princesa\ (subpasta).
- **UI01 Registar lance e capturas — feito a 12/10:** `src/rotas/lances.js` (GET /formulario, /quotas, /; POST /) com app_pesca; `public/lances.html` + `public/js/lances.js`. Lance + capturas numa transação da aplicação (beginTransaction/commit/rollback); n.º do lance = MAX+1 da viagem, com nova tentativa se o UNIQUE uq_lance colidir. O ecrã mostra a quota restante (v_quota_consumo) e avisa (sem bloquear) quando a BD vai recusar; o trg_captura_quota recusa e nada fica gravado (TC26 OK). Validação só da aplicação: o lance não começa antes da partida da viagem. Evidências: UI01_recusado_pela_bd.png, UI01_lance_gravado.png.
- **Correção nos triggers (03) a 12/10:** trg_captura_quota e trg_lote_lance_viagem davam erro 1231 (MESSAGE_TEXT NULL) com um lance ou lote inexistente; agora "RN19: o lance indicado não existe" / "RN16: o lote/lance indicado não existe". 01→09 do zero duas vezes: 18/18 e 9/9.
- Atenção: o 04 usa ids fixos (lances 9 e 10, turno 8, lotes 8 e 9); depois de usar o protótipo, correr o 02 antes do 04.

- 12/10 (noite): o grupo decidiu manter o **Node.js 25.6** (technical-stack.md atualizado). O desenvolvimento passa para o **Claude Code**, na pasta do projeto no PC do Rodrigo; o contexto está no `CLAUDE.md` e as alterações para o relatório vão para `documentation/NOTAS_RELATORIO.md`.

## Feito a 12/10/2026 (noite, Claude Code)
- **Pasta reorganizada:** o `MPD_pesca_projeto.zip` foi descompactado na raiz (`application/`, `documentation/`, `01b`, ESTADO, NOTAS); `.env` e `node_modules` passaram para `application/`; apagados `prototipo_sta_princesa/` (só falta a subpasta vazia `application`, presa pelo `npm start` antigo), `README_1.md`, `prototipo_sta_princesa.zip` e `mockups.zip`. Confirmado no Docker do Rodrigo: o 03 corrigido já estava corrido.
- **UI02 Fechar lote — feito:** `src/rotas/lotes.js` com app_fabrica; `public/lotes.html` + `public/js/lotes.js`.
  - Turnos da viagem em curso: abrir (INSERT turno; responsável escolhido entre o Factory Manager / 2nd da viagem, validado pelo trg_turno_responsavel) e fechar (UPDATE fim; CHECK ck_turno_horas).
  - Origem do peixe: só lances terminados até ao fim do turno (turno aberto: até agora, UTC — o mesmo limite do sp_fechar_lote) e com peso disponível da espécie do produto (capturado − já usado em lote_lance, o cálculo do RN16).
  - Porões com a capacidade livre (capacidade − v_stock). Código do lote sugerido (SP-T12-COD-001, ...).
  - Gravação **só** com `CALL sp_fechar_lote(...)` (sem INSERT da aplicação, sem transação da aplicação); avisos antes de gravar que não bloqueiam o botão.
  - Decisão do grupo: um lote pode ser fechado num turno fechado ou aberto.
- Refatoração: `dataHora`/`numero` passaram para `src/validacao.js` e `viagemEmCurso` para `src/viagem.js` (usados por lances.js e lotes.js; UI01 sem mudanças de comportamento). `src/erros.js`: corpo JSON inválido passa a dar 400 (antes 500).
- **Testes TC44–TC50 pela API, todos OK** (contagens de lote/lote_lance/armazenamento lidas com root antes e depois): TC44 abrir/fechar turno; TC45 RN28 recusa Fisherman; TC46 lote aceite 80 cx em 2 porões; TC47 = TC27 no ecrã (2.º separador usa lance já usado → RN16, nada gravado); TC48 kg acima do disponível → RN16, nada gravado; TC49 caixas dos porões ≠ caixas do lote → procedimento recusa; TC50 lote num turno aberto, aceite.
- Depois dos testes: 02 → 04 18/18, 08 9/9; `npm run verificar` 4 × OK.
- Capturas do UI02 (13/10): UI02_turno_aberto, UI02_lote_gravado, UI02_lote_gravado_lista, UI02_turno_fechado. **Falta UI02_recusado_pela_bd.png (TC27).**

## Feito a 13/10/2026 — datas futuras nos lances
- Problema encontrado pelo Rodrigo ao tirar as capturas: o UI01 (e a BD) aceitavam um lance com fim no futuro (ex.: 15/10 num dia 13/10). No UI02 esse lance contaria como "terminado" num turno que acabasse depois dele.
- Decisão do grupo: regra na BD (opção B), não só na aplicação. Não pode ser CHECK (o MySQL não aceita UTC_TIMESTAMP() num CHECK) → 2 triggers novos no 03: `trg_lance_datas` (BEFORE INSERT) e `trg_lance_datas_update` (BEFORE UPDATE, só valida a coluna que muda — o app_pesca fecha lances com UPDATE fim). Mensagem: "Lance: o fim (…) é depois da hora atual (… UTC)". Schema e 09 sem alterações.
- 04: +4 testes (fim futuro, início futuro, UPDATE com fim futuro → recusados; UPDATE com fim passado → aceite), com datas relativas a UTC_TIMESTAMP() para não caducarem. 01→09 do zero: 04 22/22, 08 9/9; `npm run verificar` 4 × OK.
- UI01: aviso antes de gravar (não bloqueia) quando o início ou o fim estão depois da hora atual (UTC).
- Testado pela API: POST de lance com fim futuro → 422 com a mensagem do trigger, nada gravado; com app_pesca direto, UPDATE do fim para o futuro recusado e UPDATE da latitude aceite.
- Fica de fora (opcional): lance antes da partida da viagem (hoje só a aplicação valida; obrigaria a mudar o 06, cujos lances de carga são de 2016–2025 e estão na Viagem 11) e datas futuras nos turnos.
- Pipeline 01→09 já corrida no Docker do Rodrigo a 13/10 (apagou os lances de teste do UI01, incluindo o de fim futuro); BD com os dados do 02. Noutra BD: correr o 03 e depois o 02 — os triggers só validam linhas novas, não apagam lances futuros já gravados.

## Feito a 13/10/2026 — UI03 Stock e saídas
- `src/rotas/stock.js` com app_comandante; `public/stock.html` + `public/js/stock.js`. Sem alterações à BD.
  - Cartões por porão (stock, capacidade, % ocupado) e total a bordo por espécie; tabela de stock por porão e lote (v_stock, consultas 4a–4c); saídas registadas (consulta 5b).
  - Nova saída: lote e porão (só com stock), descarga em porto (escala) ou transbordo (navio recetor), caixas, data (UTC, por omissão agora), comprador. Um único INSERT em saida_lote: trg_saida_stock (RN24), CHECK ck_saida_destino (RN25), ck_saida_caixas e FK composta validam.
  - Avisos sem bloquear: "a BD vai recusar" (caixas acima do stock, RN24) separado de "atenção, a BD não verifica datas" (saída no futuro, antes da entrada do lote no porão, escala que acabou antes da entrada, data fora da escala). Decisão do grupo: datas das saídas só com aviso (opção a), fica nas limitações.
- `src/validacao.js`: mensagem de data inválida corrigida ("Indique … no formato AAAA-MM-DD HH:MM."; antes "A data da saída inválido").
- Testes TC57–TC61 pela API, todos OK (descarga e transbordo aceites; RN24 recusa; lote num porão onde nunca esteve recusado pelo RN24 antes da FK; escala + navio recusado pelo CHECK RN25). Depois: 02 → 04 22/22, 08 9/9; `npm run verificar` 4 × OK.
- Estado de demonstração do UI02 recriado pela API depois do 02 (lances 1–3 da Viagem 12, lote SP-T12-COD-001, turno 06:00–12:30 fechado, turno 13:00 aberto com o lance 3 = 1 000 kg disponíveis), para a captura do TC27.
- UI02 (`public/js/lotes.js`): a lista de lotes podia ficar em "A carregar…" se o formulário falhasse ao abrir a página; agora carrega-se à parte e também depois de abrir/fechar turno.
- Capturas do UI03 feitas (13/10): `UI03_stock_saidas.png`, `UI03_recusado_pela_bd.png`. **Falta a do TC27 (`UI02_recusado_pela_bd.png`).**

## Feito a 13/10/2026 — FR13 Viagens e escalas
- Pedido do Rodrigo: a data de chegada não se sabe com exatidão quando a viagem começa (ex.: partir a 24/08 e chegar a 15/10). O modelo já o permitia — `viagem.id_escala_chegada` fica NULL enquanto a viagem decorre e a ETA de uma escala é só uma previsão (opcional, pode mudar). O ecrã foi desenhado para isso: a escala de chegada pode ser planeada antes (com ETA aproximada) ou criada no próprio fecho, com a ATA real.
- **BD (03) — decisão do grupo: regras na BD (opção B).** 4 triggers novos + procedimento auxiliar (13 triggers no total):
  - `trg_escala_datas` (INSERT) e `trg_escala_datas_update` (UPDATE, só a coluna que muda): ATA/ATD não podem ser no futuro; ETA/ETD podem. Mensagem "Escala: …".
  - `trg_viagem_chegada` (INSERT) e `trg_viagem_chegada_update` (UPDATE de id_escala_chegada) chamam `sp_validar_chegada_viagem`: a escala de chegada é do mesmo navio, tem ATA, a chegada é depois da partida (ATD, ou ETD), e não há lances nem turnos da viagem por terminar ou a terminar depois da chegada. Mensagem "Viagem: …". O procedimento é só dos triggers (correm como definer): nenhum utilizador precisa de EXECUTE; 09 sem alterações. Schema sem alterações.
  - 04: +8 testes (escala só com ETA futura aceite; ATA futura recusada no INSERT e no UPDATE; fechar sem ATA, com chegada antes da partida, com lance por terminar → recusados; fechar correto aceite; INSERT de viagem já fechada incoerente recusado). **04: 30/30.**
- **Aplicação:** `src/rotas/viagens.js` (app_comandante), `public/viagens.html` + `public/js/viagens.js`; `navioAtual` passou para `src/viagem.js` (usado por stock.js e viagens.js).
  - Cartões: viagem em curso (dias no mar), tripulação a bordo por posto, lances/turnos por fechar.
  - Escalas do navio (ETA/ETD/ATA/ATD, calado, para que viagem servem) com "Editar"; formulário único para nova escala (INSERT) ou corrigir (UPDATE das 6 colunas permitidas; o porto não muda).
  - "Registar chegada e fechar a Viagem 12": escala nova (porto, ATA, calado, nível) ou escala já registada (+ ATA); caixa "desembarca" por tripulante (desmarcado = fica a bordo, RN9). **Transação da aplicação:** escala (INSERT ou UPDATE da ATA) + `UPDATE viagem SET id_escala_chegada` + `UPDATE tripulacao_viagem SET id_escala_desembarque`.
  - Histórico das viagens do navio. Avisos antes de gravar, sem bloquear (como nos outros ecrãs).
- **Testes TC62–TC71 pela API, todos OK** (ver NOTAS 6.1). O TC68 prova a transação: a escala nova chegou a ser inserida e foi desfeita quando o trigger recusou o fecho.
- Pipeline 01→09 do zero no Docker do Rodrigo: 23 tabelas / 34 FK, 13 triggers, **04 30/30, 08 9/9**; `npm run verificar` 4 × OK. BD com os dados do 02 (Viagem 12 em curso, sem lances).
- (Substituído no mesmo dia: o grupo pediu também "abrir nova viagem" — ver a secção seguinte.)

## Feito a 13/10/2026 — Nova viagem e numeração das regras novas (RN31–RN34)
- **Numeração** (deixada ao critério do Claude pelo Rodrigo): as regras novas ficam a seguir à última do catálogo, RN30 — RN31 lances sem datas no futuro; RN32 escalas sem ATA/ATD no futuro; RN33 fecho da viagem; RN34 abertura da viagem. As mensagens dos triggers passaram de "Lance:/Escala:/Viagem:" para "RN31:/RN32:/RN33:", e os avisos dos ecrãs citam o número. Nota: o relatório também usa códigos "BR.." em alguns sítios (ex.: BR08 no UI01, BR15 no 08) — confirmar a correspondência BR ↔ RN ao passar para o relatório.
- **BD (03):** trigger 14 `trg_viagem_partida` (BEFORE INSERT viagem, FOLLOWS trg_viagem_chegada) — RN34: a escala de partida é do navio, ainda não é partida de outra viagem, e só pode haver uma viagem em curso por navio. 04: +3 testes (abrir a Viagem 13 depois de fechar a 12 aceite; partida numa escala já usada recusada; 2.ª viagem em curso recusada). **04: 33/33.** Schema e 09 sem alterações (o comandante já tinha INSERT em viagem e tripulacao_viagem e UPDATE de etd/atd).
- **Aplicação:** formulário "Abrir nova viagem" no ecrã Viagens e escalas (`POST /api/viagens`). Transação da aplicação: ETD/ATD da escala de partida (se vierem) + `INSERT viagem` (n.º = máximo do navio + 1) + `INSERT tripulacao_viagem` de quem embarca (embarque na escala de partida). Por omissão a escala de partida é a chegada da última viagem e vêm marcados os tripulantes que ficaram a bordo (RN9), com o último posto. Avisos: "a BD vai recusar" (viagem em curso RN34, dois comandantes RN10, ATD no futuro RN32, ATD ≤ ATA, ETD ≤ ETA) e "atenção, a BD aceita" (sem comandante, sem Factory Manager → sem turnos RN28, quem ficou a bordo e não embarca RN9, escala sem ATA, sem hora de partida).
- Os ecrãs de lances, lotes e viagens passam a aceitar uma viagem em curso sem hora de partida (escala sem ETD/ATD) sem dar erro.
- **Testes TC72–TC77 pela API, todos OK** (ver NOTAS 6.1). O TC72 e o TC73 provam a transação: a ATD gravada no 1.º passo e a viagem inserida no 2.º foram desfeitas quando a BD recusou.
- Pipeline 01→09 do zero no Docker do Rodrigo: 23 tabelas / 34 FK, 14 triggers, **04 33/33, 08 9/9**; `npm run verificar` 4 × OK. BD com os dados do 02.

## Corrigido a 13/10/2026 — ecrãs que não carregavam no browser
- Problema encontrado pelo Rodrigo: no ecrã Viagens e escalas as listas (escala, porto) ficavam vazias e a tripulação em "A carregar…", por isso não era possível fechar a viagem.
- Causa: em `public/js/viagens.js` e `public/js/lotes.js` o arranque (`await carregar…()`) estava no início do módulo, antes de funções auxiliares definidas com `const` (ex.: `lista`, `escalaPorId`, `turnoEscolhido`). Quando os dados chegavam, essas constantes ainda não existiam (ReferenceError) e o desenho parava a meio. Era também a causa real do "A carregar…" na lista de lotes do UI02 (a correção anterior só tinha tratado o sintoma). Os testes pela API não apanhavam isto.
- Correção: o arranque passou para o fim do ficheiro em `viagens.js`, `lotes.js` e `stock.js` (o stock funcionava por acaso de ordem). Na lista "Escala de chegada" deixaram de aparecer escalas que já são partida de uma viagem (seriam sempre recusadas pela RN33).
- Verificado num browser real (Edge sem janela, `--dump-dom`) nos 5 ecrãs: nenhum fica em "A carregar…", sem mensagens de erro, listas preenchidas.
- Também a 13/10 (captura do Rodrigo com a Viagem 13 em curso): no "Abrir nova viagem" todos apareciam como "ficou a bordo da Viagem 13", com o aviso RN9 — numa viagem em curso ninguém tem desembarque. Agora "ficou a bordo" só se calcula a partir da última viagem **fechada** (`src/rotas/viagens.js`). As listas de posto dentro da tabela cortavam o fundo das letras ("Factorv Manaaer"): `td select.in` passou a 32 px de altura com menos margem interior (`app.css`). Confirmado com uma captura do Edge sem janela (`--screenshot`).

## Feito a 13/10/2026 — UI05 Rastrear uma caixa (todos os ecrãs do protótipo prontos)
- `src/rotas/rastreio.js` com **app_armador** (como no mockup; o technical-stack dizia comandante — corrigido), `public/rastreio.html` + `public/js/rastreio.js`. Só leitura; sem alterações à BD.
  - Pesquisa pelo código do lote (sugestões com os códigos existentes; aceita minúsculas e espaços; o código fica no endereço, `?codigo=…`, para partilhar).
  - Cartões: produto (caixas, kg), produzido (turno, viagem, responsável), rendimento (sobre o peso vivo), ainda a bordo (por porão, v_stock).
  - Origem — lances (consulta 5a do 05): período, zona, posição (N/S · E/W), profundidade, peso vivo e % do lote. Destino — movimentos (consulta 5b): entradas nos porões (+), descargas e transbordos (−), destino e comprador.
  - Código inexistente → 404 com mensagem clara.
- **Testes TC78–TC83 pela API, todos OK** (ver NOTAS 6.1): valores do SP-T11-COD-004 iguais ao mockup e à consulta 5; lote em dois porões; descarga em porto; minúsculas/espaços; código inexistente; tentativa de injeção SQL tratada como texto.
- Verificado no Edge sem janela: os 6 ecrãs carregam sem erro, nenhum "por implementar" na barra lateral. Capturas geradas no Edge a partir da aplicação: `UI05_rastrear_caixa.png`, `UI05_codigo_inexistente.png`; e uma do Rodrigo no browser dele: `UI05_lote_descarregado.png` (SP-T11-COD-002, valores confirmados com o 02). `npm run verificar` 4 × OK.

## Feito a 13/10/2026 — logótipo na barra lateral
- Pedido do Rodrigo: o texto "STA PRINCESA" no topo da barra lateral foi trocado pela imagem do navio com "Santa Princesa". A imagem original (1024 × 1024, fundo branco) foi cortada às margens, ficou com o fundo transparente e foi reduzida a 400 × 189 px: `application/public/img/logo.png` (65 KB). Muda em `public/js/comum.js` (barra lateral comum a todos os ecrãs; o logótipo leva ao painel de quotas) e `public/css/app.css` (`.brand img`, espaço do subtítulo). Por baixo do logótipo fica só "Gestão de Bordo", centrado com o logótipo (antes "Gestão de bordo · navio-fábrica", alinhado à esquerda; alterado a pedido do Rodrigo). Verificado no Edge sem janela.

## Feito a 13/10/2026 — "Trip" passa a "Viagem"
- Dúvida do Rodrigo: porque aparecia "Trip 11/12" em vez de "viagem"? Vinha dos mockups, dos comentários do 02 e do CLAUDE.md (anteriores ao Claude Code), provavelmente dos documentos reais em inglês (de onde vêm também os postos Captain/Factory Manager e as siglas ETA/ATA). Na BD a coluna sempre foi `num_viagem`. **Decisão: passar a "Viagem" (português em tudo).**
- Trocado "Trip" por "Viagem" (palavra inteira — "Tripulação"/"Tripulante" não mudam) em: ecrãs (`public/js/*.js`), mensagens da API (`src/rotas/*.js`, rodapé em `contexto.js`), mensagem do trigger RN34 (03), descrições dos testes (04), comentários do 02, 05 e 08, e toda a documentação (README, application/README, CLAUDE.md, NOTAS, ESTADO). "Viagem" é feminino como era tratada a "Trip" ("a Viagem 13 … fechada"), por isso as frases ficam certas.
- Não mudam: os **códigos dos lotes** (`SP-T12-COD-001` — o "T12" é o código impresso na caixa: T + número da viagem; mudá-lo alterava os dados de teste) e os **mockups** (`documentation/mockups`, desenho original de referência, PNG). As capturas já tiradas mostram "Trip"; retirar só se o grupo quiser (as duas do UI05 geradas no Edge já foram refeitas com "Viagem" e com o logótipo).
- Nas descrições dos testes do 04, "viagem 1/2" (que era o `id_viagem`) passou a "Viagem 11/12", e o número da viagem passou a ser a única forma de a identificar nos textos.
- Testado: pipeline 01→09 do zero — 14 triggers, **04 33/33** (mensagem RN34: "o navio ainda tem a Viagem 13 em curso"), **08 9/9**; `npm run verificar` 4 × OK; os 6 ecrãs no Edge sem janela sem "Trip" e sem erros (rodapé "Viagem em curso: Viagem 12").

## Feito a 13/10/2026 — guião das capturas (e 3 correções encontradas ao prepará-lo)
- `documentation/GUIAO_CAPTURAS.md`: sequência única, a partir do 02, para refazer as 13 capturas do relatório (com "Viagem" e o logótipo), incluindo o TC27 (UI02, dois separadores) e as recusas do FR13 (RN33, RN10). Valores a introduzir, mensagens esperadas e nome de cada ficheiro. Toda a sequência foi simulada pela API antes de escrever o guião. Decisão: refazer as capturas **no fim**, quando os ecrãs estiverem finais.
- **Código do lote calculado no servidor** (`src/rotas/lotes.js`, `codigoSeguinte`): o ecrã mostra-o só como sugestão; o `POST /api/lotes` calcula-o no momento de gravar. Antes, dois separadores sugeriam o mesmo código e o 2.º era recusado pelo UNIQUE (código repetido) antes de chegar à RN16 — o TC27 no ecrã mostrava o erro errado.
- **Mensagem da RN16** (03, `trg_lote_lance_viagem`): passou a mostrar o n.º do lance na viagem ("RN16: o lance n.º 3 tem 0.00 kg…") em vez do `id_lance` (que podia ser 12 para o lance n.º 3, porque um INSERT desfeito também gasta um id). Pipeline 01→09 do zero: 04 33/33, 08 9/9.
- Erro visto pelo Rodrigo depois disto ("Indique um código de lote"): o servidor dele tinha arrancado antes da alteração ao `lotes.js` e ainda pedia o código, que a página nova já não envia. Basta reiniciar. Para não voltar a acontecer: script `npm run dev` (`node --watch src/server.js`, sem dependências novas), que reinicia o servidor quando `src/` muda (README da aplicação).
- **UI03**: depois de registar uma saída, a data mantém-se (antes voltava a "agora" e aparecia o aviso de data fora da escala com o formulário vazio).
- BD reposta com o 02.

## Feito a 14/10/2026 — estrutura do Guia e artefactos da entrega
Com base nas orientações do docente (`project all files.zip`: Guia, modelo de pastas, README e templates) e no relatório final exportado.
- **Scripts SQL em `data/`** (como o modelo do Guia e o Anexo A do relatório):
  - `schema.sql` (antigo 01; agora com `CREATE DATABASE IF NOT EXISTS`), `seed.sql` (02), `views.sql` (as 2 vistas do 05), `queries.sql` (as consultas do 05, agora com identificadores **Q01–Q17** — são 17, o relatório conta 16), `programmable_objects.sql` (03 + 07 + 09, em três partes: triggers, sp_fechar_lote, papéis e utilizadores).
  - `data/testes/`: `testes_triggers.sql` (04), `testes_fechar_lote.sql` (08), `indice_explain.sql` (06) e o novo `testes_restricoes.sql`.
  - `data/executar_tudo.ps1`: corre tudo pela ordem dentro do contentor (lê a palavra-passe de root do próprio contentor, sem credenciais no script); `-Testes` corre também os testes; para no primeiro erro.
  - Apagados: os 9 scripts numerados e o `01b_saida_porao.sql` (a migração já está no schema), o `MPD_pesca_projeto.zip` antigo.
  - Referências atualizadas nos comentários do SQL, da aplicação (`src/`, `.env.example`, `scripts/verificar-ligacao.js`), no README da aplicação, no `GUIAO_CAPTURAS.md`, no `technical-stack.md` e no `CLAUDE.md`. Sem alterações de comportamento na BD nem na aplicação.
- **Testes TC18–TC25 em script** (`data/testes/testes_restricoes.sql`): TC18 (saída sem destino, CHECK), TC19 (lote num porão onde nunca esteve — recusa primeiro a RN24), TC20 (rendimento > 100 %, CHECK), TC23 (IMO repetido, UNIQUE), TC24 (escala de partida = chegada, CHECK), TC25 (ATD antes da ATA, CHECK). Tudo numa transação desfeita no fim: **6/6 OK**, BD fica como estava.
- **ERD:** `documentation/diagrams/ERD_sta_princesa.png` (DbSchema, feito pelo Rodrigo; já com a `saida_lote` atual). O Rodrigo mudou os nomes das caixas para "Operação e Tripulação", "Pesca e Quotas", "Fábrica, porões e saídas" e "Vistas", sem mudar a posição das tabelas — o texto de 3.1/3.2 do relatório tem de ser ajustado (nota nas NOTAS). Apagados os 4 PNG antigos por área (desatualizados).
- **Documentos do modelo do Guia** em `documentation/`, coerentes com o relatório:
  - `project-brief.md` (cap. 1), `requirements.md` (FR01–FR13, com onde está implementado), `business-rules.md` (**BR01–BR20**: as RN31–RN34 entram como BR17–BR20), `ai-use-summary.md` (AI-01 a AI-04 do 6.2).
  - `data-dictionary.csv`: 114 atributos das 23 tabelas, gerado a partir do `information_schema` e confrontado com a BD.
- **README.md** reescrito com as secções do modelo do Guia (objetivo, pré-requisitos, BD, aplicação, credenciais de demonstração, estrutura, modelo, regras, testes, RGPD, limitações, autores: Rodrigo Pereira, Hugo Grou, Marcelo Manteigas, Martim Ferreira — **faltam os números de estudante**).
- **Normalização (3.4):** já está escrita no relatório final; nada a fazer no repositório.
- **Testado:** `.\data\executar_tudo.ps1 -Testes` do zero — 23 tabelas / 34 FK, 14 triggers, **testes_triggers 33/33, testes_fechar_lote 9/9, testes_restricoes 6/6**; `queries.sql` e `indice_explain.sql` sem erros. BD com os dados do seed.
- **Relatório:** o relatório exportado está desatualizado em vários pontos (7 triggers, 43 TC, "Trip", nomes dos scripts, ecrãs por fazer). Tudo o que muda está nas NOTAS (entradas de 13/10 e 14/10).

## Feito a 14/10/2026 — capturas finais
- O Rodrigo tirou as capturas com o `GUIAO_CAPTURAS.md`; guardadas em `documentation/evidencias/` com os nomes do guião (lista e descrição nas NOTAS, 5.5). A captura 8 (`UI05_rastrear_caixa.png`) ficou a de 13/10.
- Encontrado nas capturas: o rodapé ("Viagem em curso") só era lido ao abrir a página, por isso depois de abrir a Viagem 13 continuava a dizer Viagem 12. Corrigido: `atualizarRodape()` em `public/js/comum.js`, chamada pelo `viagens.js` depois de fechar ou abrir uma viagem (só `public/`, basta F5).
- BD reposta e testada: `.\data\executar_tudo.ps1 -Testes` → 33/33, 9/9, 6/6; Edge sem janela sem erros.
- Apagadas a pedido do Rodrigo as 4 capturas antigas, com "Trip" e sem logótipo (`UI02_lote_gravado_lista`, `UI02_turno_aberto`, `UI02_turno_fechado`, `UI05_lote_descarregado`). Ficam 16 em `documentation/evidencias/`.
- UI01 (`public/js/lances.js`): os avisos de quota passaram de "(BR08)" para "(RN19)", como os avisos dos outros ecrãs e a mensagem da BD (decisão do Rodrigo). A captura `UI01_recusado_pela_bd.png` ainda mostra "(BR08)" no aviso; a documentação continua a usar BR08 (catálogo do relatório).

## Decisões do grupo (registo)
| Data | Decisão |
| --- | --- |
| 12/10 | Stack: Node.js 25.6 (mínimo 22.12), Express 5.3.0, mysql2 3.24.5, HTML sem framework. Um utilizador MySQL por papel; sem ecrã de login. |
| 12/10 | Regras de negócio na BD; a aplicação só avisa antes de gravar, sem bloquear o botão, para se ver a BD a recusar. |
| 12/10 | UI02: um lote pode ser fechado num turno fechado ou aberto (turno aberto: lances terminados até agora, UTC). |
| 13/10 | Lances sem datas no futuro: regra na BD (triggers), não só na aplicação (opção B). |
| 13/10 | UI03: datas das saídas só com avisos no ecrã (opção a); fica nas limitações. |
| 13/10 | FR13: datas das escalas (ATA/ATD no futuro) e fecho da viagem (escala do navio, com ATA, depois da partida, sem lances/turnos abertos): regras na BD (opção B). A chegada não precisa de ser conhecida quando a viagem começa. |
| 13/10 | FR13: o protótipo também abre a viagem seguinte (opção b, pedida pelo Rodrigo), com a regra RN34 na BD. |
| 13/10 | Numeração das regras novas ao critério do Claude: RN31–RN34, a seguir à RN30. |
| 13/10 | UI05 Rastreabilidade com o utilizador `app_armador`, como no mockup (só leitura). |
| 13/10 | Logótipo do navio no topo da barra lateral, em vez do texto "STA PRINCESA" (afasta-se dos mockups neste ponto). |
| 13/10 | "Viagem 12" em vez de "Trip 12" em todos os ecrãs, mensagens e documentação; os códigos dos lotes (SP-T12-…) mantêm-se. |
| 13/10 | Capturas de ecrã refeitas todas no fim, com o `GUIAO_CAPTURAS.md` (inclui o TC27). |
| 13/10 | Captura do TC27 (`UI02_recusado_pela_bd.png`) adiada. |
| 14/10 | Estrutura de pastas do Guia: scripts SQL em `data/` com os nomes do modelo (os scripts numerados deixam de existir), testes em `data/testes/`, `executar_tudo.ps1` para correr tudo. |
| 14/10 | ERD único (`documentation/diagrams/ERD_sta_princesa.png`) com as caixas "Operação e Tripulação", "Pesca e Quotas", "Fábrica, porões e saídas" e "Vistas"; os PNG antigos por área foram apagados. |
| 14/10 | RN31–RN34 entram no catálogo do relatório como BR17–BR20 (`business-rules.md`). |
| 14/10 | Avisos e mensagens dos ecrãs citam sempre o código RN (o UI01 dizia BR08, como o mockup; passa a RN19). Os documentos usam BR. |

## Próximo passo
- ~~Capturas finais~~ (feito a 14/10; capturas antigas apagadas).
- Passar as NOTAS para o relatório (incluindo as caixas do ERD em 3.1/3.2).
- Números de estudante no README.
- Git: o Rodrigo faz o commit e o push quando concluir.

## Por fazer depois
- ZIP final da entrega (sem `node_modules`, `.env`, `.claude`).
- Apresentação.
- Opcional: triggers BEFORE UPDATE para as regras de quantidades; numeração automática de viagens/lances.
- Parte de NoSQL da UC (comparação com MongoDB), se o enunciado pedir.
