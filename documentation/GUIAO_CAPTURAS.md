# Guião das capturas de ecrã (evidências do protótipo)

Sequência para tirar **todas** as capturas de uma vez, a partir dos dados de teste do `data/seed.sql`. A ordem importa: cada passo usa o que o anterior gravou, e os valores indicados só batem certo seguindo-a do princípio ao fim. Demora cerca de 30 minutos.

Todos os valores e mensagens deste guião foram confirmados a 13/10/2026, correndo a mesma sequência pela API.

## Antes de começar

1. Ter o Docker Desktop aberto com o contentor `MPD_pesca` a correr.
2. Repor os dados de teste (PowerShell, na pasta do projeto):
   ```powershell
   .\data\executar_tudo.ps1
   ```
3. Arrancar a aplicação (pasta `application`): `npm start`. Se já estava a correr, parar com Ctrl+C e arrancar de novo.
4. Abrir http://localhost:3000 no browser, com a janela maximizada. Pôr o zoom a **80 %** (Ctrl e −) para cada ecrã caber numa captura com a mensagem e o resultado.
5. Capturas com **Win + Shift + S** (retângulo da janela do browser) e guardar em `documentation/evidencias/` com o nome indicado, **substituindo** o ficheiro antigo.

Notas:
- As datas e horas dos formulários estão em **UTC**. As deste guião são fixas (27/08/2026), não é preciso converter nada.
- Nos campos de data, escrever no formato que o browser mostra: `dd/mm/aaaa hh:mm`.
- Quando a BD recusa, a mensagem vermelha começa por "A base de dados recusou … — nada foi gravado." seguida da mensagem da regra (RN..). Antes de gravar, o aviso com borda cinzenta já anuncia a recusa — deve aparecer nas capturas de recusa.

## Lista final

| # | Ficheiro | Ecrã | O que mostra |
| --- | --- | --- | --- |
| 1 | `UI04_painel_quotas.png` | Painel de quotas | quotas de 2026, todas OK |
| 2 | `UI01_recusado_pela_bd.png` | Lances e capturas | RN19: camarão numa zona sem quota |
| 3 | `UI01_lance_gravado.png` | Lances e capturas | lance gravado e lista dos 3 lances |
| 4 | `UI02_lote_gravado.png` | Fábrica — lotes | lote fechado (transação) e lista de lotes |
| 5 | `UI02_recusado_pela_bd.png` | Fábrica — lotes | TC27: RN16, lance sem peso disponível |
| 6 | `UI03_recusado_pela_bd.png` | Porões e saídas | RN24: mais caixas do que o stock |
| 7 | `UI03_stock_saidas.png` | Porões e saídas | descarga gravada, stock atualizado |
| 8 | `UI05_rastrear_caixa.png` | Rastreabilidade | lote da Viagem 11: origem e destino |
| 9 | `UI05_lote_viagem12.png` | Rastreabilidade | o lote feito no passo 4, até aos lances |
| 10 | `FR13_fecho_recusado.png` | Viagens e escalas | RN33: turno ainda aberto |
| 11 | `FR13_viagem_fechada.png` | Viagens e escalas | Viagem 12 fechada, 2 ficam a bordo |
| 12 | `FR13_nova_viagem_recusada.png` | Viagens e escalas | RN10: dois comandantes |
| 13 | `FR13_nova_viagem.png` | Viagens e escalas | Viagem 13 aberta |

Mantém-se: `UI05_codigo_inexistente.png` (já está com "Viagem" e com o logótipo).

**Feito a 14/10/2026** (Rodrigo): capturas 1–7 e 9–13 tiradas; a 12 em duas partes (`FR13_nova_viagem_aviso.png` com o aviso e a tripulação, `FR13_nova_viagem_recusada.png` com a mensagem) e mais uma extra, `FR13_nova_viagem_historico.png` (tabela das viagens). A captura 8 ficou a de 13/10 (gerada no Edge, com 97 cx a bordo). Desde 14/10 o rodapé da barra lateral atualiza-se depois de fechar/abrir uma viagem; nas capturas desse dia ainda aparece a viagem antiga no rodapé depois de abrir a Viagem 13.
Capturas antigas apagadas a 14/10 (deixaram de ser precisas): `UI02_lote_gravado_lista.png`, `UI02_turno_aberto.png`, `UI02_turno_fechado.png`, `UI05_lote_descarregado.png`.

---

## 1. Painel de quotas

Abrir **Painel de quotas**. Nada a preencher.

**Captura 1 — `UI04_painel_quotas.png`**: cartões (bacalhau 42 200 kg, camarão 14 000 kg, quota mais consumida 9,33 %, 0 alertas) e a tabela: COD 2.a 4,33 % · COD 2.b ZEE Noruega 5,76 % · COD 2.b Svalbard 3,50 % · PRA 2.b Svalbard 9,33 %.

## 2. Lances e capturas

Abrir **Lances e capturas**. A lista "Lances da Viagem 12" está vazia.

**Lance recusado** (camarão na zona 2.a, onde não há quota):

| Campo | Valor |
| --- | --- |
| Zona de pesca | 2.a — ZEE Noruega |
| Início (UTC) | 27/08/2026 06:00 |
| Fim (UTC) | 27/08/2026 09:30 |
| Latitude / Longitude / Profundidade | 71.1 / 17.9 / 290 |
| COD — Bacalhau | 3000 |
| PRA — Camarão-boreal | 500 |

Aparece o aviso "A base de dados vai recusar este lance: não existe quota de PRA…". Carregar em **Gravar lance**.
Mensagem: *"A base de dados recusou o lance — nada foi gravado. RN19: não existe quota de PRA para esta zona em 2026"*. A lista continua vazia.

**Captura 2 — `UI01_recusado_pela_bd.png`** (aviso + mensagem vermelha + lista vazia).

**Lances gravados** — pôr PRA a 0 e gravar; depois os outros dois:

| Lance | Zona | Início → Fim (UTC) | Lat / Long / Prof. | Capturas |
| --- | --- | --- | --- | --- |
| n.º 1 | 2.a — ZEE Noruega | 27/08/2026 06:00 → 09:30 | 71.1 / 17.9 / 290 | COD 3000 |
| n.º 2 | 2.b — ZEE Noruega | 27/08/2026 10:00 → 11:30 | 73.6 / 19.2 / 310 | COD 1000 |
| n.º 3 | 2.b — Zona de Svalbard | 27/08/2026 13:00 → 15:00 | 76.4 / 13.9 / 350 | COD 1000 e PRA 800 |

**Captura 3 — `UI01_lance_gravado.png`** depois do lance n.º 3: mensagem verde *"Lance n.º 3 da Viagem 12 gravado com 2 capturas."* e a lista com os 3 lances.

## 3. Fábrica — lotes

Abrir **Fábrica — lotes**.

**Turno da manhã:**
1. Abrir turno — início **27/08/2026 06:00**, responsável **Nuno Alexandre Teixeira (Factory Manager)** → **Abrir turno**.
2. Na tabela de turnos, na linha desse turno: fim **27/08/2026 12:30** → **Fechar turno**.

**Lote** (turno 27/08 06:00–12:30, produto **Bacalhau HEG**):
- Em "Origem do peixe" aparecem só os lances n.º 1 (3 000 kg) e n.º 2 (1 000 kg). O n.º 3 não aparece porque só terminou às 15:00, depois do fim do turno.
- Caixas produzidas: **106** (peso do produto 2 650 kg · matéria-prima 4 000 kg · rendimento 66,3 %).
- Armazenamento: Porão 1 (vante) **60**, Porão 2 (ré) **46** (o Porão 1 vem preenchido com 106 — corrigir).
- **Fechar lote** → *"Lote SP-T12-COD-001 gravado: 106 caixas, 2 lances de origem, 2 porões."*

**Captura 4 — `UI02_lote_gravado.png`**: mensagem verde e a lista "Lotes da Viagem 12" (se não couber, baixar o zoom para 67 %).

**TC27 — lance sem peso disponível (dois separadores):**
1. Abrir turno — início **27/08/2026 13:00**, Nuno Alexandre Teixeira → **Abrir turno** (fica aberto).
2. Duplicar o separador (botão direito no separador → *Duplicar*).
3. Nos **dois** separadores: turno **27/08 13:00 (aberto)**, produto **Bacalhau HEG**. Aparece o lance n.º 3 com **1 000 kg** de COD disponíveis.
4. **1.º separador**: caixas **26** (o porão vem preenchido) → **Fechar lote** → aceite (*SP-T12-COD-002*).
5. **2.º separador**, sem atualizar a página: caixas **26** → **Fechar lote**.
   Mensagem: *"A base de dados recusou o lote — nada foi gravado. RN16: o lance n.º 3 tem 0.00 kg de COD disponíveis, pedido 1000.00"*.

**Captura 5 — `UI02_recusado_pela_bd.png`** (2.º separador). Fechar o 2.º separador. **Não fechar o turno das 13:00** — é preciso aberto no passo 6.

## 4. Porões e saídas

Abrir **Porões e saídas**.

| Campo | Valor |
| --- | --- |
| Lote e porão | SP-T11-COD-004 · Porão 1 (vante) (97 cx) |
| Tipo | Descarga em porto |
| Escala | Tromsø (NOTOS) · 24/08/2026 |
| Caixas | **120** |
| Data da saída (UTC) | 25/08/2026 09:00 |
| Comprador | Comprador Exemplo A |

Aparece o aviso "…só tem 97 caixas do lote SP-T11-COD-004, pedido 120 (RN24)". **Registar saída** → *"A base de dados recusou a saída — nada foi gravado. RN24: stock insuficiente no porão: há 97 caixas, pedido 120"*.

**Captura 6 — `UI03_recusado_pela_bd.png`**.

Mudar as caixas para **60** → **Registar saída** → *"Saída registada: descarga de 60 caixas do lote SP-T11-COD-004 (Porão 1 (vante)) para Tromsø (NOTOS)."* Na tabela, o lote SP-T11-COD-004 passa a 37 caixas.

**Captura 7 — `UI03_stock_saidas.png`**: mensagem verde, cartões e tabela de stock.

## 5. Rastreabilidade

Abrir **Rastreabilidade**.

- Código **SP-T11-COD-004** → **Pesquisar**: 197 cx, rendimento 66,6 %; lances n.º 4 (91,9 %) e n.º 5 (8,1 %) em duas zonas; movimentos +197 (entrada), −100 (transbordo), −60 (a descarga do passo 4); **37 caixas** a bordo.

  **Captura 8 — `UI05_rastrear_caixa.png`**.

- Código **SP-T12-COD-001** (o lote do passo 3) → **Pesquisar**: produzido 27/08 06:00–12:30, Viagem 12 · Nuno Alexandre Teixeira; lances n.º 1 (3 000 kg, 75 %) e n.º 2 (1 000 kg, 25 %); entradas de 60 e 46 caixas.

  **Captura 9 — `UI05_lote_viagem12.png`** — mostra a rastreabilidade de ponta a ponta de um lote feito no próprio protótipo.

## 6. Viagens e escalas

Abrir **Viagens e escalas**. O cartão "Por fechar antes da chegada" mostra **1** (o turno das 13:00).

**Fecho recusado** — secção "Registar chegada e fechar a Viagem 12":
- Escala de chegada: **Nova escala (chegada agora)**; Porto **Tromsø (NOTOS)**; ATA: a que vem preenchida (agora); Calado **7.4**; Nível **Security Level 1**.
- Tripulação: **desmarcar** Dmytro Kovalenko e Ricardo Jorge Sousa (ficam a bordo).
- Aviso "há 1 turno(s) por fechar…". **Fechar viagem** → *"A base de dados recusou o fecho — nada foi gravado. RN33: há 1 turno(s) por fechar ou a fechar depois da chegada"*.

**Captura 10 — `FR13_fecho_recusado.png`**.

**Fechar o turno** — em **Fábrica — lotes**, na linha do turno 27/08/2026 13:00: fim **27/08/2026 18:00** → **Fechar turno**.

**Fecho aceite** — voltar a **Viagens e escalas** (F5) e repetir o formulário de fecho como acima (nova escala Tromsø, calado 7.4, Security Level 1, desmarcar Kovalenko e Sousa) → **Fechar viagem** → *"Viagem 12 fechada em Tromsø (NOTOS) · ATA …: 3 tripulantes desembarcaram, 2 ficam a bordo."* A tabela de escalas mostra a escala nova como "chegada Viagem 12".

**Captura 11 — `FR13_viagem_fechada.png`**.

**Nova viagem recusada** — secção "Abrir a Viagem 13":
- Escala de partida: a que vem escolhida (a chegada da Viagem 12).
- ETD (UTC): **amanhã às 08:00**; ATD: vazio.
- Tripulação: Kovalenko e Sousa já vêm marcados ("ficou a bordo da Viagem 12"). Marcar também **António Manuel Ferreira** e **Fábio Daniel Almeida** (ambos com o posto Captain).
- Aviso "há 2 comandantes (Captain)… (RN10)". **Abrir viagem** → *"A base de dados recusou a nova viagem — nada foi gravado. RN10: esta viagem já tem um comandante (Captain)"*.

**Captura 12 — `FR13_nova_viagem_recusada.png`**.

**Nova viagem aceite** — desmarcar Fábio Daniel Almeida e marcar **Hugo Filipe Marques** (Factory Manager) → **Abrir viagem** → *"Viagem 13 aberta: partida de Tromsø (NOTOS), 4 tripulantes a bordo."* O cabeçalho passa a "Viagem 13 em curso".

**Captura 13 — `FR13_nova_viagem.png`**.

## No fim

1. Apagar as capturas que deixaram de ser precisas (lista acima), se o grupo concordar.
2. Repor os dados de teste com `.\data\executar_tudo.ps1` (o `data/testes/testes_triggers.sql` usa ids fixos e só funciona sobre esses dados).
3. Marcar no `documentation/NOTAS_RELATORIO.md` a entrada das evidências como atualizada.
