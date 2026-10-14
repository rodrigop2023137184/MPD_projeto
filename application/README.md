# Aplicação — protótipo STA PRINCESA

Aplicação web de bordo do navio-fábrica, sobre a base de dados `sta_princesa`. Stack e versões: `documentation/technical-stack.md`.

| Ecrã | Página | Papel (utilizador MySQL) | Estado |
| --- | --- | --- | --- |
| UI04 Painel de quotas | `/quotas.html` | `app_armador` | Feito (12/10) |
| UI01 Lances e capturas | `/lances.html` | `app_pesca` | Feito (12/10) |
| UI02 Fechar lote | `/lotes.html` | `app_fabrica` | Feito (12/10) |
| UI03 Stock e saídas | `/stock.html` | `app_comandante` | Feito (13/10) |
| UI05 Rastreabilidade | `/rastreio.html` | `app_armador` | Feito (13/10) |
| Viagens e escalas (FR13) | `/viagens.html` | `app_comandante` | Feito (13/10) |

## Pré-requisitos
- Node.js 25.6 (funciona a partir do 22.12): `node -v`
- Contentor `MPD_pesca` a correr (`docker compose up -d`) e a base de dados criada: `.\data\executar_tudo.ps1` na pasta do projeto (ver o README principal)

## Instalar e arrancar (PowerShell, a partir da pasta `application`)

```powershell
Copy-Item .env.example .env     # só na primeira vez; ajustar se a porta não for 3307
npm install                     # instala express e mysql2 (versões do package-lock.json)
npm run verificar               # liga-se com os 4 utilizadores e mostra OK / FALHOU
npm start                       # http://localhost:3000
```

Para parar: **Ctrl+C** no terminal.

**Durante o desenvolvimento**, usar `npm run dev` em vez de `npm start`: o servidor reinicia sozinho quando um ficheiro de `src/` muda (`node --watch`, incluído no Node, sem dependências novas). Com `npm start`, uma alteração às rotas (`src/`) só fica ativa depois de parar e arrancar de novo; as alterações às páginas (`public/`) bastam com F5.

**Os dados registados no protótipo ficam na BD.** Para voltar aos dados de teste: `.\data\executar_tudo.ps1` (na pasta do projeto). O `data/testes/testes_triggers.sql` usa ids fixos e só dá 33/33 sobre os dados de teste; o `testes_fechar_lote.sql` não depende disso.

**Demonstrar o UI02 com os dados de teste:** a Viagem 12 não tem lances nem turnos. Primeiro registar um lance **com fim** no UI01 (ex.: zona 2.b Svalbard, 27/08 06:00–09:30, 3 000 kg de COD); depois, no UI02, abrir um turno (ex.: 27/08 06:00, Nuno Teixeira) e fechá-lo (12:00) — ou deixá-lo aberto — e fechar o lote.

**Fechar a Viagem 12 e abrir a Viagem 13 (FR13):** a BD só deixa fechar com todos os lances e turnos terminados antes da ATA (RN33). Depois de fechada, deixa de haver viagem em curso até se abrir a seguinte no mesmo ecrã ("Abrir nova viagem": escala de partida, ETD/ATD e quem embarca — por omissão, quem ficou a bordo). Na Viagem 13, os turnos da fábrica precisam de um Factory Manager ou 2nd **que tenha embarcado** (RN28). Para voltar aos dados de teste: `.\data\executar_tudo.ps1`.

**Capturas de ecrã para o relatório:** seguir `documentation/GUIAO_CAPTURAS.md` (sequência completa a partir dos dados de teste, com os valores a introduzir e as mensagens esperadas).

**TC27 no ecrã (lance sem peso disponível):** abrir o UI02 em dois separadores com o mesmo turno e produto; fechar o lote no 1.º com o peso todo do lance; no 2.º, que ainda mostra o lance, carregar em Fechar lote. A BD recusa (RN16) e nada fica gravado.

## Estrutura

```
application/
├── package.json / package-lock.json
├── .env.example          # modelo das credenciais (o .env real não vai para o Git)
├── scripts/
│   └── verificar-ligacao.js   # npm run verificar
├── src/
│   ├── server.js         # Express: páginas estáticas + API /api/...
│   ├── config.js         # lê o .env
│   ├── db.js             # um pool mysql2 por papel
│   ├── erros.js          # erros do MySQL -> HTTP + mensagem (SIGNAL, CHECK, FK, privilégios)
│   ├── validacao.js      # formatos dos pedidos (datas UTC, números, ids)
│   ├── viagem.js         # viagem em curso e navio atual (usados por vários ecrãs)
│   └── rotas/
│       ├── contexto.js   # GET /api/contexto/:papel (rodapé: utilizador, viagem em curso)
│       ├── quotas.js     # GET /api/quotas, /anos, /csv  (UI04)
│       ├── lances.js     # GET/POST /api/lances  (UI01)
│       ├── lotes.js      # turnos e CALL sp_fechar_lote  (UI02)
│       ├── stock.js      # stock (v_stock) e saídas  (UI03)
│       ├── viagens.js    # escalas, fecho da viagem e nova viagem  (FR13)
│       └── rastreio.js   # origem e destino de um lote  (UI05)
└── public/
    ├── quotas.html       # UI04
    ├── lances.html       # UI01
    ├── lotes.html        # UI02
    ├── stock.html        # UI03
    ├── viagens.html      # FR13
    ├── rastreio.html     # UI05
    ├── img/logo.png      # logótipo do navio (barra lateral)
    ├── css/app.css       # estilo comum, igual aos mockups
    └── js/
        ├── comum.js      # barra lateral, pedidos à API, formatação pt-PT
        ├── quotas.js     # UI04
        ├── lances.js     # UI01
        ├── lotes.js      # UI02
        ├── stock.js      # UI03
        ├── viagens.js    # FR13
        └── rastreio.js   # UI05
```

## API

| Pedido | Devolve |
| --- | --- |
| `GET /api/contexto/:papel` | utilizador MySQL, navio e viagem em curso |
| `GET /api/quotas/anos` | anos com quota definida |
| `GET /api/quotas?ano=2026` | uma linha por quota, da vista `v_quota_consumo` |
| `GET /api/quotas/csv?ano=2026` | o mesmo em CSV (`;` e vírgula decimal, abre no Excel) |
| `GET /api/lances/formulario` | viagem em curso, próximo n.º de lance, zonas e espécies |
| `GET /api/lances/quotas?zona=1&ano=2026` | quota restante por espécie nessa zona e ano |
| `GET /api/lances` | lances da viagem em curso, com as capturas |
| `POST /api/lances` | grava o lance e as capturas numa transação (201) ou devolve o erro |
| `GET /api/lotes/formulario` | viagem em curso, turnos, responsáveis possíveis (Factory Manager / 2nd) e produtos |
| `POST /api/lotes/turnos` | abre um turno `{ inicio, id_responsavel }` (201); o `trg_turno_responsavel` valida (RN28) |
| `PATCH /api/lotes/turnos/:id` | fecha um turno aberto `{ fim }`; o CHECK `ck_turno_horas` valida |
| `GET /api/lotes/origem?turno=8&produto=1` | lances terminados até ao fim do turno (aberto: até agora) com peso disponível, porões com a capacidade livre, código sugerido |
| `GET /api/lotes` | lotes da viagem em curso, com lances e porões |
| `POST /api/lotes` | fecha o lote com `CALL sp_fechar_lote(...)` (201) ou devolve a mensagem da BD |
| `GET /api/stock` | stock por porão (ocupação), por espécie e por porão/lote (`v_stock`, consultas 4a–4c) |
| `GET /api/stock/escalas` | escalas do navio, para as descargas em porto |
| `GET /api/stock/saidas` | saídas registadas (descargas e transbordos), da mais recente para a mais antiga |
| `POST /api/stock/saidas` | regista uma saída (INSERT `saida_lote`, 201); o `trg_saida_stock` (RN24) e o CHECK `ck_saida_destino` (RN25) validam |
| `GET /api/viagens/formulario` | viagem em curso, escalas do navio (e para que viagens servem), portos, tripulação, lances/turnos por fechar, histórico das viagens |
| `POST /api/viagens/escalas` | nova escala (INSERT `escala`, 201); ETA/ETD/ATA/ATD opcionais |
| `PATCH /api/viagens/escalas/:id` | horas previstas e reais, calado e nível (UPDATE `escala`); `trg_escala_datas_update` e CHECK das horas validam |
| `POST /api/viagens/:id/fechar` | regista a chegada e fecha a viagem numa transação: escala (nova ou ATA da planeada) + `UPDATE viagem` + desembarques; `trg_viagem_chegada_update` valida (RN33) |
| `GET /api/rastreio/lotes` | códigos de lote existentes (sugestões do campo de pesquisa do UI05) |
| `GET /api/rastreio/SP-T11-COD-004` | lote (produto, turno, viagem, responsável, rendimento), origem (lances: zona, posição, peso, % do lote), destino (entradas nos porões, descargas, transbordos) e stock ainda a bordo; 404 se o código não existir |
| `POST /api/viagens` | abre a viagem seguinte numa transação: ETD/ATD da escala de partida + `INSERT viagem` (n.º seguinte) + `INSERT tripulacao_viagem`; `trg_viagem_partida` (RN34) e `trg_tripulacao_comandante` (RN10) validam |

Exemplo de `POST /api/lotes` (peso do produto, matéria-prima e data de entrada nos porões são calculados pelo procedimento; o **código do lote** é calculado pelo servidor no momento de gravar — o ecrã só o mostra como sugestão —, para dois separadores ou dois utilizadores não tentarem o mesmo código; vem na resposta):

```json
{ "id_turno": 8, "id_produto": 1, "n_caixas": 80,
  "lances": [ { "id_lance": 9, "peso_vivo_kg": 3000 } ],
  "poroes": [ { "id_porao": 1, "n_caixas": 50 }, { "id_porao": 2, "n_caixas": 30 } ] }
```

Exemplo de `POST /api/stock/saidas` — descarga em porto com `id_escala`, transbordo com `navio_recetor` (um ou o outro; a BD recusa os dois juntos):

```json
{ "id_lote": 4, "id_porao": 1, "id_escala": 2, "data_saida": "2026-08-25 09:00",
  "n_caixas": 60, "comprador": "Comprador Exemplo A" }
```

Exemplos de `POST /api/viagens/2/fechar` — com uma escala nova criada na chegada, ou com uma escala já planeada (a ETA era só uma previsão):

```json
{ "cod_porto": "NOTOS", "ata": "2026-10-15 09:00", "calado_m": 7.4,
  "nivel_seguranca": "Security Level 1", "desembarcam": [13, 14, 7] }

{ "id_escala": 3, "ata": "2026-10-15 09:00", "desembarcam": [13, 14, 7] }
```

Os tripulantes que não estão em `desembarcam` ficam a bordo para a viagem seguinte (RN9).

Exemplo de `POST /api/viagens` (abrir a Viagem 13; o número é calculado pela aplicação):

```json
{ "id_escala_partida": 92, "atd": "2026-10-13 15:39",
  "tripulacao": [ { "id_tripulante": 1, "id_posto": 1 }, { "id_tripulante": 4, "id_posto": 4 },
                  { "id_tripulante": 11, "id_posto": 8 }, { "id_tripulante": 12, "id_posto": 8 } ] }
```

As datas das saídas não são verificadas pela BD: o UI03 só avisa (sem bloquear) quando a saída é no futuro, anterior à entrada do lote no porão, ou fora da escala escolhida.

Exemplo de `POST /api/lances` (datas em UTC):

```json
{ "id_zona_pesca": 3, "inicio": "2026-08-27 06:00", "fim": "2026-08-27 09:30",
  "latitude": 76.4, "longitude": 13.9, "profundidade_m": 350,
  "capturas": [ { "cod_fao": "COD", "peso_vivo_kg": 1000 }, { "cod_fao": "PRA", "peso_vivo_kg": 500 } ] }
```

O UI05 aceita o código no endereço, para se poder partilhar uma pesquisa: `http://localhost:3000/rastreio.html?codigo=SP-T11-COD-004`.

Erros: `{ "erro": "mensagem", "codigo": … }`, com o estado HTTP 400 (pedido inválido, incluindo corpo que não é JSON), 404 (lote inexistente no UI05), 403 (sem permissão no papel), 409/422 (regra de negócio recusada pela BD) ou 503 (sem ligação ao MySQL).
