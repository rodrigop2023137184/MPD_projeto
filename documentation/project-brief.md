# Project Brief

## Título do projeto
Base de Dados do Navio-Fábrica "Santa Princesa" (`sta_princesa`)

## Área / tema
Pesca industrial: operação de um arrastão-fábrica português que pesca bacalhau e camarão-boreal no Mar da Noruega e em Svalbard, com base em Tromsø.

## Problema
O levantamento partiu de uma entrevista a um tripulante e de dois documentos reais de operação: a lista de tripulação IMO à partida (Viagem 11, Tromsø, 12/07/2026) e a declaração de chegada SafeSeaNet (SSN) enviada às autoridades norueguesas (24/08/2026).

- A informação está espalhada por folhas de cálculo e formulários, preenchidos à mão e repetidos de viagem para viagem.
- Os mesmos dados aparecem escritos de formas diferentes: postos com grafias distintas, nacionalidade ora como adjetivo ora como país, o nome completo numa só célula, datas inválidas e contagens de tripulação que não batem certo com a lista.
- Nada liga o peixe capturado num lance às caixas que saem do navio, nem controla automaticamente o consumo das quotas por espécie, zona e ano.

O problema é duplo: dar uma estrutura única e coerente a estes dados e garantir, na própria base de dados, as regras que hoje dependem da atenção de quem preenche as folhas.

## Objetivo
Uma base de dados relacional que registe a operação do navio por maré (viagem) e garanta a rastreabilidade do peixe desde o lance de pesca até à caixa descarregada, com um protótipo que demonstre as operações principais sobre a base de dados entregue.

Objetivos de suporte: controlar o consumo das quotas por espécie, zona e ano; registar a tripulação de cada viagem; medir o rendimento da fábrica; saber o stock de cada lote em cada porão; garantir as regras de negócio na própria base de dados.

## Utilizadores / atores
| Ator | Papel | O que precisa do sistema | Utilizador MySQL |
| --- | --- | --- | --- |
| Comandante (Captain) | Responde pelo navio e pelas declarações às autoridades | Escalas, viagens, tripulação, documentos, saídas | `app_comandante` |
| Mestre de pesca (Fishing Master) | Dirige a pesca | Lances e capturas, quota disponível | `app_pesca` |
| Responsável de fábrica (Factory Manager / 2nd) | Dirige os turnos da fábrica | Turnos, lotes, rendimento, armazenamento nos porões | `app_fabrica` |
| Armador (gestão em terra) | Planeia marés, quotas e vendas | Quotas, stock a bordo, rastreabilidade | `app_armador` |
| Agente / comprador | Recebe a descarga | Stock por espécie e origem de cada lote | (consulta através do armador) |

## Âmbito
### Incluído
- Navio e armador; portos e escalas; viagens (marés).
- Tripulantes, postos e documentos; tripulação de cada viagem e trocas de tripulação em porto.
- Zonas de pesca e quotas; lances e capturas em peso vivo.
- Espécies, apresentações, produtos e fatores de conversão; turnos e lotes da fábrica.
- Porões, armazenamento e saídas (descargas em porto e transbordos no mar).

### Excluído
- Combustível e fluidos, resíduos MARPOL, provisões, pilotagem, segurança (ISSC).
- Equipamentos da fábrica, congelação e registo de temperatura dos porões.
- Clientes como entidade (o comprador é texto na saída).

## Dados principais
- Navio, portos, escalas (horas previstas e reais), viagens.
- Tripulantes, postos, documentos, tripulação por viagem.
- Espécies (FAO), zonas de pesca (ICES), quotas anuais, lances e capturas.
- Apresentações, produtos, fatores de conversão, turnos, lotes e a sua origem (lote ↔ lance).
- Porões, armazenamento e saídas.

## Operações principais
- Registar lances e capturas, com a quota verificada pela base de dados.
- Abrir e fechar turnos e fechar lotes (lote + lances de origem + porões numa só transação).
- Registar descargas em porto e transbordos, com o stock verificado.
- Consultar o painel de quotas, o stock a bordo e a rastreabilidade de uma caixa.
- Registar escalas, fechar a viagem na chegada e abrir a viagem seguinte.
- Relatórios de fábrica e tripulação (rendimento, reconciliação com o fator, tripulação a bordo, documentos a caducar).

## Pressupostos / restrições iniciais
- O armador tem um só navio (o modelo suporta vários, mas o armador é texto).
- O bacalhau sai sem cabeça e eviscerado (HEG) e o camarão cru inteiro (WHL).
- A pesca é registada lance a lance, em peso vivo, como no diário eletrónico (ERS).
- Todas as datas e horas são registadas em UTC, como nos documentos de bordo.
- A data de chegada de uma viagem não é conhecida com exatidão quando o navio parte: só fica registada no fecho.
- Todos os dados de teste são fictícios (RGPD); os documentos reais não fazem parte do projeto.
