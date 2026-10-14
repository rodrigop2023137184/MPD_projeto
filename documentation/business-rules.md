# Business Rules

20 regras. O identificador é BRxx (como no Guia e no relatório); a linha **RN** dá o código usado durante o desenvolvimento, que aparece nas mensagens dos triggers e nos comentários do schema, para que um erro no ecrã se possa ligar à regra que o originou. Todas as regras são garantidas na base de dados; quando afetam um formulário, a aplicação também avisa antes de gravar.

As regras BR17–BR20 foram acrescentadas a 13/10/2026, durante o desenvolvimento do protótipo.

## BR01 — IMO único
**Regra:** O IMO identifica o navio e é único.
**Razão / significado no domínio:** é o identificador internacional do navio, que não muda com o nome nem com a bandeira.
**RN:** RN2 · **Mecanismo:** UNIQUE `uq_navio_imo` · **Aplicada em:** BD

## BR02 — Numeração das viagens
**Regra:** As viagens são numeradas em sequência por navio.
**Razão / significado no domínio:** a bordo cada maré é conhecida pelo número (Viagem 11, Viagem 12).
**RN:** RN3 · **Mecanismo:** UNIQUE `uq_viagem` · **Aplicada em:** BD; a aplicação propõe o número seguinte

## BR03 — Escalas de partida e de chegada
**Regra:** Uma viagem começa numa escala e acaba noutra; a chegada fica vazia enquanto o navio está no mar.
**Razão / significado no domínio:** a data de chegada só é conhecida quando o navio chega.
**RN:** RN4 · **Mecanismo:** FK + CHECK `ck_viagem_escalas` · **Aplicada em:** BD + aplicação

## BR04 — Datas em UTC e ordem das horas
**Regra:** Datas em UTC; em cada escala a partida é posterior à chegada.
**Razão / significado no domínio:** os documentos de bordo e as declarações às autoridades usam UTC.
**RN:** RN7 · **Mecanismo:** CHECK `ck_escala_prevista`, `ck_escala_real` · **Aplicada em:** BD + aplicação

## BR05 — Posto por viagem e tripulantes que ficam a bordo
**Regra:** Um tripulante tem um posto por viagem, que pode mudar entre viagens, e pode ficar a bordo de uma viagem para a seguinte.
**Razão / significado no domínio:** há troca de tripulação em cada escala, mas alguns tripulantes ficam por opção, por vezes com outro posto.
**RN:** RN8, RN9 · **Mecanismo:** PK composta de `tripulacao_viagem`; desembarque NULL · **Aplicada em:** BD

## BR06 — Um só comandante
**Regra:** Cada viagem tem um único comandante.
**Razão / significado no domínio:** o comandante responde pelo navio perante as autoridades.
**RN:** RN10 · **Mecanismo:** trigger `trg_tripulacao_comandante` · **Aplicada em:** BD + aplicação

## BR07 — Documento único
**Regra:** Um documento é único por tipo, número e país emissor.
**Razão / significado no domínio:** evita registar o mesmo passaporte ou visto duas vezes.
**RN:** RN11 · **Mecanismo:** UNIQUE `uq_documento` · **Aplicada em:** BD

## BR08 — Captura dentro da quota
**Regra:** A captura regista-se lance a lance, em peso vivo, e não pode ultrapassar a quota do navio para a espécie, zona e ano; sem quota não há captura.
**Razão / significado no domínio:** as quotas são fixadas por espécie e zona (divisão ICES) e contam em peso vivo, como no diário ERS.
**RN:** RN14, RN19 · **Mecanismo:** trigger `trg_captura_quota` + CHECK `ck_captura_peso` · **Aplicada em:** BD + aplicação (UI01 mostra a quota restante)

## BR09 — Um produto por espécie
**Regra:** Neste navio cada espécie tem um só produto (bacalhau HEG, camarão WHL).
**Razão / significado no domínio:** é a forma como a fábrica deste navio trabalha.
**RN:** RN30 · **Mecanismo:** UNIQUE `uq_produto_especie` · **Aplicada em:** BD

## BR10 — Origem do lote
**Regra:** Um lote só usa peixe de lances da sua viagem, da espécie do seu produto, sem exceder o peso capturado.
**Razão / significado no domínio:** é a base da rastreabilidade: o peso de cada lance só pode ser usado uma vez.
**RN:** RN16 · **Mecanismo:** trigger `trg_lote_lance_viagem` · **Aplicada em:** BD + aplicação (UI02)

## BR11 — Rendimento
**Regra:** O peso do produto não pode exceder o peso da matéria-prima.
**Razão / significado no domínio:** a fábrica tira cabeça e vísceras; o produto pesa sempre menos ou o mesmo.
**RN:** RN26 · **Mecanismo:** CHECK `ck_lote_rendimento` · **Aplicada em:** BD + aplicação

## BR12 — Responsável do turno
**Regra:** O responsável do turno é Factory Manager ou 2nd Factory Manager nessa viagem.
**Razão / significado no domínio:** só estes postos dirigem a fábrica.
**RN:** RN28 · **Mecanismo:** trigger `trg_turno_responsavel` · **Aplicada em:** BD + aplicação

## BR13 — Caixas e capacidade dos porões
**Regra:** As caixas guardadas não excedem as do lote e o stock de um porão não excede a capacidade.
**Razão / significado no domínio:** cada porão tem uma capacidade física em caixas.
**RN:** RN22 · **Mecanismo:** triggers `trg_armazenamento_lote` e `trg_armazenamento_capacidade` · **Aplicada em:** BD + aplicação (UI02)

## BR14 — Saídas
**Regra:** Só sai de um porão o que lá está guardado; cada saída é descarga em porto ou transbordo, nunca as duas.
**Razão / significado no domínio:** as caixas saem numa escala ou para outro navio no mar.
**RN:** RN24, RN25 · **Mecanismo:** FK composta + trigger `trg_saida_stock` + CHECK `ck_saida_destino` · **Aplicada em:** BD + aplicação (UI03)

## BR15 — Código do lote
**Regra:** O código do lote é único e permite rastrear a caixa até aos lances.
**Razão / significado no domínio:** é o código impresso em cada caixa.
**RN:** RN17 · **Mecanismo:** UNIQUE `uq_lote_codigo` + consultas Q11–Q12 · **Aplicada em:** BD

## BR16 — Lances terminados antes do fim do turno
**Regra:** Um lote só usa peixe de lances que já tinham terminado no fim do turno em que é fechado.
**Razão / significado no domínio:** o peixe só chega à fábrica depois de o lance acabar.
**RN:** — · **Mecanismo:** validação no `sp_fechar_lote` + consulta de controlo Q17 · **Aplicada em:** BD + aplicação (UI02)

## BR17 — Lances sem datas no futuro
**Regra:** Um lance não pode começar nem acabar depois da hora atual.
**Razão / significado no domínio:** só se regista o que já aconteceu; um lance com fim no futuro contaria como terminado no fecho de um lote.
**RN:** RN31 · **Mecanismo:** triggers `trg_lance_datas` (INSERT) e `trg_lance_datas_update` (UPDATE) · **Aplicada em:** BD + aplicação (UI01)

## BR18 — Horas reais das escalas sem datas no futuro
**Regra:** Numa escala, a chegada e a partida reais (ATA/ATD) não podem ser no futuro; as previstas (ETA/ETD) podem.
**Razão / significado no domínio:** a ETA/ETD são previsões que mudam; a ATA/ATD registam factos.
**RN:** RN32 · **Mecanismo:** triggers `trg_escala_datas` e `trg_escala_datas_update` · **Aplicada em:** BD + aplicação (Viagens e escalas)

## BR19 — Fecho da viagem
**Regra:** Uma viagem só fecha numa escala do mesmo navio, com chegada real registada, depois da partida, e sem lances nem turnos por terminar ou a terminar depois da chegada.
**Razão / significado no domínio:** completa a BR03: a viagem acaba quando o navio chega mesmo, e a pesca e a fábrica dessa maré já terminaram.
**RN:** RN33 · **Mecanismo:** triggers `trg_viagem_chegada` e `trg_viagem_chegada_update` (procedimento `sp_validar_chegada_viagem`) · **Aplicada em:** BD + aplicação (Viagens e escalas)

## BR20 — Abertura da viagem seguinte
**Regra:** Uma viagem nova parte de uma escala do navio que ainda não foi partida de outra viagem, e só pode haver uma viagem em curso por navio.
**Razão / significado no domínio:** o navio só está numa maré de cada vez; a seguinte começa depois de fechada a anterior.
**RN:** RN34 · **Mecanismo:** trigger `trg_viagem_partida` · **Aplicada em:** BD + aplicação (Viagens e escalas)
