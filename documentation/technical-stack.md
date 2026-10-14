# Technical Stack

Decidido pelo grupo a 12/10/2026 (Node.js 25 confirmado no mesmo dia). Estas versões são fixas: o código gerado (com ou sem IA) tem de ser compatível com elas, e qualquer mudança é registada aqui.

## Database
- DBMS: MySQL
- Version: 8.4 (imagem Docker `mysql:8.4`, contentor `MPD_pesca`, porta 3307)
- Database name: `sta_princesa`
- SQL dialect: MySQL 8.4 (usa `JSON_TABLE`, `LATERAL`, CTE, `SIGNAL`/`RESIGNAL`, roles)

## Backend
- Language: JavaScript (ES modules)
- Version: Node.js 25.6 (versão usada pelo grupo; mínimo suportado: 22.12, também testado em 22.22 LTS)
- Framework: Express
- Version: 5.3.0

## Database access
- Library / ORM: nenhum ORM — SQL escrito à mão, com parâmetros (`?`) em todas as consultas
- Driver: mysql2 3.24.5 (API de promises, `mysql2/promise`)

## Frontend / UI
- Technology: páginas HTML + CSS + JavaScript no browser (sem framework), servidas pelo Express a partir de `application/public/`
- Version: HTML5 / ES2022 (browsers atuais)

## Runtime / package management
- Runtime: Node.js 25.6
- Package manager: npm (o que vem com o Node); versões fixas no `package.json` e no `package-lock.json`
- Scripts: `npm start` (servidor), `npm run dev` (servidor com `node --watch`, reinicia quando o código muda — funcionalidade do Node, sem dependências), `npm run verificar` (liga-se com os 4 utilizadores)

## Architecture

```
Browser (páginas HTML)  --fetch JSON-->  Express (API /api/...)  --mysql2-->  MySQL 8.4 (sta_princesa)
public/*.html, js/*.js                   src/rotas/*.js                       triggers, vistas, sp_fechar_lote
```

- Cada ecrã é uma página HTML que pede os dados à API com `fetch` e desenha o resultado.
- A API não repete as regras de negócio: estão na BD (CHECK, UNIQUE, FK, 14 triggers, `sp_fechar_lote`). Quando a BD recusa uma operação, `src/erros.js` traduz o erro para HTTP e devolve a mensagem do `SIGNAL` ao ecrã (ex.: `RN19: quota excedida (COD): restam … kg`).
- Os formulários validam os campos antes de enviar, só para dar mensagens mais cedo (regras em duas camadas, relatório 2.2).
- Operações de vários passos chamam o procedimento transacional (`CALL sp_fechar_lote(...)`) ou usam uma transação da aplicação (`beginTransaction`/`commit`/`rollback`: lance + capturas no UI01; escala + fecho da viagem + desembarques, e partida + nova viagem + tripulação, no FR13), nunca vários INSERT/UPDATE soltos.
- Leituras analíticas usam as vistas (`v_quota_consumo`, `v_stock`).

## Authentication / roles

A aplicação não tem tabela de utilizadores. Usa os **utilizadores MySQL por papel** criados no `data/programmable_objects.sql` (parte 3), um pool de ligações por papel (`src/db.js`):

| Papel | Utilizador MySQL | Ecrãs |
| --- | --- | --- |
| Armador | `app_armador` | UI04 Painel de quotas, UI05 Rastreabilidade (só leitura; como no mockup) |
| Mestre de pesca | `app_pesca` | UI01 Lances e capturas |
| Responsável de fábrica | `app_fabrica` | UI02 Fechar lote |
| Comandante | `app_comandante` | UI03 Stock e saídas, viagens e escalas (FR13) |

Cada ecrã liga-se com o utilizador do seu papel, por isso é a própria BD que limita o que o ecrã consegue fazer. O protótipo não tem ecrã de login: o papel é escolhido pelo ecrã (limitação documentada no relatório, 6.3).

## Technical constraints
- The implementation must use the supplied database schema (`data/schema.sql`, `seed.sql`, `views.sql`, `programmable_objects.sql`).
- Changes to the schema must be justified and propagated to the project artefacts.
- Credentials must not be hard-coded: ficam em `application/.env` (fora do Git); o `.env.example` tem os valores de demonstração.
- New dependencies must be identified: hoje só `express` e `mysql2`. O `.env` é lido com `process.loadEnvFile` do Node (disponível desde o 20.12), sem `dotenv`.
- Generated code must be compatible with the versions specified above.
- Todas as consultas usam parâmetros (`?`), nunca texto concatenado (evita SQL injection); o texto vindo da BD é escapado antes de entrar no HTML.
