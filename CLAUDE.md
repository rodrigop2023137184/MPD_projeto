# CLAUDE.md — Projeto MPD: base de dados do navio-fábrica "Santa Princesa"

Projeto de grupo da UC **Modelação e Preparação de Dados** (ISCAC | Coimbra Business School, 2026/27; docente Prof. Doutor Adriano Lino). Grupo: Rodrigo Pereira, Hugo Grou, Marcelo Manteigas, Martim Ferreira. Base de dados MySQL de um arrastão-fábrica (bacalhau e camarão, Mar da Noruega e Svalbard) e um protótipo web que a usa. Avaliação segundo o Guia do Projeto da UC (rubrica: modelação 35 %, implementação 30 %, protótipo e IA 20 %, validação/documentação/defesa 15 %). Entrega: relatório PDF, apresentação (~10 min + 5 min de perguntas) e ZIP técnico com a estrutura do Guia.

**Língua:** português europeu em tudo — código (nomes de variáveis, comentários), mensagens de erro, documentação e respostas ao utilizador.

## Ambiente (PC do Rodrigo)

- Windows, PowerShell, VS Code. Pasta do projeto: `C:\Users\rodas\Desktop\MPD_pesca`. O Rodrigo tem Git e faz ele o push.
- MySQL 8.4 em Docker: contentor `MPD_pesca`, porta **3307**, BD `sta_princesa`, administração `root`/`root` (`docker-compose.yml`)
- Node.js **25.6** (o grupo decidiu manter a 25; mínimo suportado 22.12), Express 5.3.0, mysql2 3.24.5 — versões fixas em `documentation/technical-stack.md`. Não acrescentar dependências sem as registar lá.
- Aplicação: `npm run dev` (pasta `application`) reinicia o servidor sozinho quando `src/` muda (`node --watch`). Se o Rodrigo estiver a usar `npm start`, **avisar sempre que uma alteração em `src/` exige reiniciar** (aconteceu a 13/10: o ecrã novo falava com o servidor antigo). Alterações em `public/` bastam com F5.
- **Criar / repor a BD:** `.\data\executar_tudo.ps1` (schema → seed → views → programmable_objects); com `-Testes` corre também os testes. Lê a palavra-passe de root dentro do contentor e envia os ficheiros sem estragar os acentos. Para um script solto:
  ```powershell
  Start-Process docker -ArgumentList 'exec -i MPD_pesca sh -c "mysql -uroot -p$MYSQL_ROOT_PASSWORD --default-character-set=utf8mb4 --table"' -NoNewWindow -Wait -RedirectStandardInput data\queries.sql -RedirectStandardOutput saida.txt
  ```
  (Nunca o `<` do PowerShell: estraga os acentos. O `cmd /c "docker exec -i … < ficheiro"` também funciona.)
- DBeaver para consultas (Alt+X). Os ficheiros com `DELIMITER` (`programmable_objects.sql`, testes) correm melhor pelo terminal.

## Estrutura (modelo do Guia; reorganizada a 14/10)

```
data/schema.sql                 DDL: 23 tabelas, 34 FK, 11 UNIQUE, 16 CHECK, índice; cria a BD
data/seed.sql                   dados de teste fictícios (Viagem 11 + início da Viagem 12)
data/views.sql                  v_quota_consumo, v_stock
data/programmable_objects.sql   parte 1: 14 triggers (+ sp_validar_chegada_viagem); parte 2: sp_fechar_lote;
                                parte 3: roles e utilizadores app_* (GRANT)
data/queries.sql                17 consultas Q01–Q17 (com o n.º de grupo do relatório: 1a…8)
data/executar_tudo.ps1          corre os 4 por ordem; -Testes corre data/testes/
data/testes/                    testes_triggers.sql (33), testes_fechar_lote.sql (9),
                                testes_restricoes.sql (6: TC18–TC20, TC23–TC25), indice_explain.sql
application/                    protótipo Node.js + Express (ver application/README.md)
  src/server.js, config.js (.env), db.js (pool por papel), erros.js (erros MySQL -> HTTP)
  src/validacao.js, src/viagem.js   validação de formatos; viagem em curso e navio atual
  src/rotas/*.js                API JSON /api/...
  public/*.html, public/js/*.js, public/css/app.css, public/img/logo.png   ecrãs
documentation/project-brief.md, requirements.md (FR01–FR13), business-rules.md (BR01–BR20),
  technical-stack.md, data-dictionary.csv (114 atributos), ai-use-summary.md (AI-01–AI-04)
documentation/diagrams/ERD_sta_princesa.png   ERD exportado do DbSchema
documentation/mockups/          mockups UI01–UI05 (PNG + HTML)
documentation/evidencias/       capturas de ecrã do protótipo
documentation/GUIAO_CAPTURAS.md sequência (a partir dos dados de teste) para refazer as 13 capturas
documentation/NOTAS_RELATORIO.md   o que mudou e tem de passar para o relatório
ESTADO_DO_PROJETO.md            ponto de situação e decisões do grupo — manter atualizado
README.md                       README do repositório (secções do modelo do Guia)
```

Os scripts numerados antigos (01_schema … 09_utilizadores) já não existem; correspondência: 01→schema, 02→seed, 03+07+09→programmable_objects (partes 1–3), 05→views + queries, 04/06/08→data/testes/.

## Base de dados (resumo)

- 23 tabelas, 34 FK. Grupos: operação/tripulação (navio, porto, escala, viagem, tripulante, posto, tripulacao_viagem, documento, tipo_documento), pesca/quotas (especie, zona_pesca, lance, captura, quota), fábrica (apresentacao, produto, fator_conversao, turno, lote, lote_lance), porões (porao, armazenamento, saida_lote).
- 14 triggers (programmable_objects, parte 1): 7 `BEFORE INSERT` — `trg_captura_quota` (RN19, quota), `trg_saida_stock` (RN24), `trg_armazenamento_lote`, `trg_armazenamento_capacidade` (RN22), `trg_lote_lance_viagem` (RN16), `trg_turno_responsavel` (RN28: responsável do turno = Factory Manager ou 2nd nessa viagem), `trg_tripulacao_comandante` (RN10) — e, desde 13/10: `trg_lance_datas` + `_update` (**RN31**, início/fim do lance não podem ser depois de `UTC_TIMESTAMP()`); `trg_escala_datas` + `_update` (**RN32**, ATA/ATD não podem ser no futuro, ETA/ETD sim); `trg_viagem_chegada` + `_update` (**RN33**, via `sp_validar_chegada_viagem`, só usado pelos triggers: a viagem só fecha numa escala do mesmo navio, com ATA, depois da partida e sem lances/turnos por terminar); `trg_viagem_partida` (**RN34**, INSERT viagem: escala de partida do navio e ainda não usada como partida; uma só viagem em curso por navio). Recusam com `SIGNAL SQLSTATE '45000'` e uma mensagem começada pelo código RN (a mensagem da RN16 usa o `num_lance`, não o `id_lance`).
- **Regras: BRxx no relatório e no `business-rules.md`, RNxx nas mensagens.** BR01–BR16 do relatório; RN31–RN34 = **BR17–BR20** (13/10). Próxima: BR21 / RN35.
- Vistas (`views.sql`): `v_quota_consumo` (quota, capturado, restante, %, estado OK/ATENÇÃO ≥ 75 %/CRÍTICO ≥ 90 %) e `v_stock` (stock de cada lote em cada porão).
- Procedimento `sp_fechar_lote(codigo, id_turno, id_produto, n_caixas, lances_json, poroes_json, data_entrada, OUT id_lote)` (parte 2): lote + lote_lance + armazenamento numa transação; ROLLBACK + RESIGNAL em qualquer erro; valida caixas dos porões = caixas do lote e lances terminados antes do fim do turno; `FOR UPDATE` nos lances. JSON: `[{"id_lance":1,"peso_vivo_kg":3000}]` e `[{"id_porao":1,"n_caixas":50}]`. O código do lote é calculado pela aplicação no momento de gravar.
- Índice `ix_lance_zona_inicio (id_zona_pesca, inicio)`; filtrar anos por intervalo de datas, nunca `YEAR(coluna)`.
- Utilizadores por papel (parte 3), palavras-passe de demonstração no `application/.env.example`:
  - `app_armador` — escreve em quota (UPDATE só `quota_kg`); ecrãs UI04 e UI05
  - `app_pesca` — INSERT lance, captura; UPDATE lance (fim, latitude, longitude, profundidade_m)
  - `app_fabrica` — INSERT turno, UPDATE turno (fim); lotes **só** por `EXECUTE sp_fechar_lote`
  - `app_comandante` — INSERT escala, viagem, tripulante, documento, tripulacao_viagem, saida_lote; UPDATE escala (eta, etd, ata, atd, calado_m, nivel_seguranca), viagem (id_escala_chegada), tripulacao_viagem (id_escala_desembarque)
  - todos leem tudo **menos `documento`** (só o comandante, RGPD)

### Dados de teste (seed.sql) — o que importa para o protótipo
- Viagem 11 (`id_viagem` 1) concluída; **Viagem 12 (`id_viagem` 2) em curso**, partiu de Tromsø a 26/08/2026 12:30 UTC, ainda sem lances nem turnos.
- Terminologia: nos ecrãs, mensagens e documentação diz-se sempre **"Viagem 12"** (o `num_viagem`), nunca "Trip" (decisão de 13/10) nem o `id_viagem`. Exceções: o código do lote `SP-T12-COD-001` (T + n.º da viagem, impresso na caixa) e os mockups originais.
- Tripulação da Viagem 12: 13 Captain, **14 Factory Manager** (único responsável válido para turnos da Viagem 12), 7, 11, 12 Fisherman.
- Produtos: 1 = COD HEG (caixa 25 kg), 2 = PRA WHL (caixa 20 kg). Porões: 1 (20 000 cx), 2 (15 000 cx).
- Quotas 2026: COD 2.a (zona 1) 400 000 kg, COD 2.b NO (zona 2) 250 000, COD 2.b Svalbard (zona 3) 300 000, PRA 2.b Svalbard 150 000. PRA na zona 2.a não tem quota.
- Datas todas em UTC (RN7).

## Regras de trabalho (decisões do grupo — respeitar)

1. **As regras de negócio vivem na BD.** A aplicação não as recalcula nem as substitui: mostra avisos antes de gravar (2.ª camada) e mostra ao utilizador a mensagem do `SIGNAL` quando a BD recusa. Os avisos **não bloqueiam** o botão, de propósito, para se ver a BD a recusar na defesa.
2. **Cada ecrã usa o utilizador MySQL do seu papel** (`ligacao('pesca')`, etc. em `src/db.js`). Se uma operação precisa de um privilégio que o papel não tem, a resposta é rever o papel ou o desenho, não usar root.
3. Operações de vários passos: procedimento transacional ou transação da aplicação (`beginTransaction`/`commit`/`rollback`), nunca INSERTs soltos.
4. SQL sempre com parâmetros `?`; texto vindo da BD sempre escapado (`esc()` em `public/js/comum.js`) antes de entrar no HTML.
5. Erros: `src/erros.js` traduz errno → HTTP (1644 SIGNAL/3819 CHECK/1452 FK → 422; 1062 → 409; 1142/1143 → 403; ligação → 503). Erros de validação do pedido com `erroPedido()` → 400.
6. Ecrãs novos seguem os mockups (`documentation/mockups/`, PNG + HTML; estilo em `public/css/app.css`) e entram na lista `ECRAS` de `public/js/comum.js` (`pronto: true`).
7. Credenciais só no `.env` (fora do Git); nenhuma palavra-passe escrita em scripts novos. Não mudar o schema sem atualizar `data/`, `data-dictionary.csv`, README, ESTADO e notas do relatório.
8. **Testar sempre antes de dar por feito:** `.\data\executar_tudo.ps1 -Testes` do zero tem de dar **23 tabelas / 34 FK, 14 triggers, testes_triggers 33/33, testes_fechar_lote 9/9, testes_restricoes 6/6**; `npm run verificar` 4 × OK. Os testes de triggers usam ids fixos: depois de usar o protótipo, repor os dados (o próprio `executar_tudo.ps1` faz isso).
9. Cada alteração relevante: atualizar `ESTADO_DO_PROJETO.md` e acrescentar uma entrada em `documentation/NOTAS_RELATORIO.md` (secção do relatório + texto proposto). Se mudar um ecrã, rever o `GUIAO_CAPTURAS.md`.
10. Scripts dos ecrãs (`public/js/*.js`, módulos ES): o **arranque** (`await carregar…()`) fica no **fim do ficheiro**, depois de todas as `const`/funções. Se ficar no início, as `const` declaradas abaixo ainda não existem quando os dados chegam e o ecrã para a meio (aconteceu no UI02 e no FR13).
11. Testar os ecrãs também no browser, não só pela API. Sem browser ligado, usar o Edge sem janela (só faz GET):
    `& "${env:ProgramFiles(x86)}\Microsoft\Edge\Application\msedge.exe" --headless=new --disable-gpu --user-data-dir=<pasta temporária> --virtual-time-budget=8000 --dump-dom http://localhost:3000/viagens.html`
    e confirmar que não fica "A carregar…" nem há texto em `id="erro"`. Para ver o aspeto, a mesma linha com `--window-size=1400,3600 --screenshot=<ficheiro.png>` em vez de `--dump-dom` (correr com `Start-Process -Wait`).
12. Scripts PowerShell novos com acentos: gravar em UTF-8 **com BOM** (o PowerShell 5.1 lê sem BOM como ANSI).

## Estado (14/10/2026)

- **BD e protótipo completos.** Seis ecrãs prontos e testados: UI04 Painel de quotas (app_armador), UI01 Registar lance (app_pesca), UI02 Fechar lote (app_fabrica), UI03 Stock e saídas (app_comandante), UI05 Rastrear uma caixa (app_armador), Viagens e escalas / FR13 (app_comandante; escalas, fecho da viagem e abertura da seguinte). Testes do protótipo TC44–TC83 (nas NOTAS).
- **Projeto reorganizado na estrutura do Guia** (14/10): `data/`, artefactos obrigatórios em `documentation/` (project-brief, requirements, business-rules, data-dictionary, ai-use-summary, ERD), README com as secções do modelo.
- Relatório final exportado (14/10) em `C:\Users\rodas\Downloads\Relatório Final — Base de Dados do Navio-Fábrica.docx`: **desatualizado** (descreve o estado de 12/10: 7 triggers, 43 TC, "Trip", ecrãs por fazer, scripts numerados). O que falta passar está nas NOTAS.
- Decisões do grupo registadas em `ESTADO_DO_PROJETO.md` (secção "Decisões do grupo"). **Documentar sempre as decisões novas lá e nas NOTAS.**

## Próximos passos

1. ~~Capturas finais~~ (feitas a 14/10, em `documentation/evidencias/`; descritas nas NOTAS 5.5). As 4 capturas antigas com "Trip" foram apagadas.
2. Passar as NOTAS para o relatório (o grupo); números de estudante dos autores no README.
3. Verificação final, ZIP de entrega (sem `node_modules`, `.env`, `.claude`) e apresentação.

## Relatório

O relatório está num documento no claude.ai (Project "Projeto MPD - pesca"); o Claude Code não o edita. Tudo o que tiver de lá entrar vai para `documentation/NOTAS_RELATORIO.md`, para ser passado depois. Secções: 1 definição; 2.1 FR01–FR13; 2.2 BR01–BR16 (+ BR17–BR20 nas NOTAS); 3.1–3.4 modelo, ERD, dicionário, normalização (já escrita no relatório); 4.1–4.4 implementação; 5.1–5.5 protótipo; 6.1 testes (TC01–TC43 no relatório; TC44–TC83 nas NOTAS; próximos a partir de TC84); 6.2 IA (AI-01–AI-04); 6.3 limitações; Anexo A artefactos e execução.
