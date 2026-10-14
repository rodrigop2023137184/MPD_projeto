# AI Use Summary

## Ferramentas usadas
- **Claude (Anthropic), num projeto do claude.ai** — análise, modelação, SQL, dados de teste, testes e relatório. Contexto: documentos da UC, documentos reais do navio (lista de tripulação IMO e declaração SSN), notas da entrevista, documento de modelação e scripts.
- **Claude Code**, na pasta do projeto — protótipo, integração com a BD e documentação técnica. Contexto: um `CLAUDE.md` com o estado do projeto, os artefactos validados e as regras do `technical-stack.md`.

Cada fase seguiu o ciclo do Guia: dar artefactos validados como contexto, pedir uma tarefa concreta, rever, corrigir e só então usar o resultado na fase seguinte. Nenhum resultado da IA foi aceite sem ser executado no MySQL do grupo e comparado com o resultado esperado. Os quatro casos abaixo são os do relatório (secção 6.2).

## AI-01 — Modelação: o modelo cresceu demais e a documentação ficou incoerente
**Ferramenta:** Claude (claude.ai)
**Artefactos de entrada:** documentos SSN e Crew List, notas da entrevista, apresentação da UC.
**Tarefa pedida:** requisitos, regras de negócio e modelo E-A para um navio-fábrica.
**Resultado relevante:** um modelo de cerca de 40 tabelas, que incluía combustível, resíduos, provisões, equipamentos e temperaturas — tudo o que aparecia na declaração SSN.
**Validação humana:** o grupo esclareceu que os documentos eram apenas exemplo e decidiu focar o navio-fábrica. Ao montar o esquema no DbSchema chegou a 35 tabelas e percebeu que estava a usar secções desatualizadas do documento de modelação.
**Problema / limitação encontrada:** a IA não tinha marcado como obsoletas as secções antigas e contou mal o núcleo (disse 20 tabelas e 26 FK quando eram 21 e 32).
**Correção / decisão:** âmbito reduzido a um núcleo; secções antigas marcadas como desatualizadas; contagens refeitas a partir do `information_schema`; uma única referência para o esquema. O grupo decidiu manter `documento` e `tipo_documento`.
**Resultado final:** 23 tabelas e 34 FK (`data/schema.sql`), com o âmbito do `project-brief.md`.
**Evidência:** relatório, secções 1.4 e 6.2.

## AI-02 — SQL: revisão do script gerado pelo DbSchema
**Ferramenta:** Claude (claude.ai)
**Artefactos de entrada:** script SQL exportado do DbSchema pelo grupo.
**Tarefa pedida:** rever o script e detetar erros.
**Resultado relevante:** faltava a tabela `quota`; os códigos FAO, de apresentação e UN/LOCODE estavam como INT, o que impedia inserir 'COD' ou 'NOTOS'; pesos em FLOAT ou DECIMAL(10,0); faltavam colunas e restrições UNIQUE.
**Validação humana:** o grupo tentou aplicar as correções no DbSchema.
**Problema / limitação encontrada:** o ALTER TABLE falhou com um erro de savepoint que escondia a causa real — o MySQL não deixa mudar o tipo de uma coluna referenciada por FK. Algumas indicações da IA sobre menus do DbSchema também não correspondiam à versão instalada.
**Correção / decisão:** recriar o esquema a partir de um script completo, executado primeiro num MySQL de teste e depois no Docker do grupo. Os scripts SQL passaram a ser a fonte da verdade e o DbSchema só serve para os diagramas.
**Resultado final:** `data/schema.sql` executável e repetível; ERD exportado do DbSchema a partir da BD (`documentation/diagrams/`).
**Evidência:** relatório, secções 3.2 e 6.2.

## AI-03 — Dados: erro temporal no seed apanhado por uma consulta de controlo
**Ferramenta:** Claude (claude.ai)
**Artefactos de entrada:** schema, regras de negócio e contagens pretendidas por tabela.
**Tarefa pedida:** dados de teste coerentes para uma maré completa e o início da seguinte.
**Resultado relevante:** 142 linhas com pesos coerentes entre capturas, lotes e porões; o script corria sem erros com os triggers ativos.
**Validação humana:** o grupo pediu uma consulta de controlo para uma regra que nenhum trigger cobria (o lote só pode usar peixe de lances já terminados no fim do turno). A consulta devolveu duas linhas.
**Problema / limitação encontrada:** os lotes SP-T11-COD-004 e SP-T11-COD-005 estavam em turnos que acabavam antes do fim dos lances de onde vinha o peixe. Os triggers não o detetaram porque a regra não existia na BD.
**Correção / decisão:** os lotes passaram para os turnos 5 e 7 e as entradas nos porões foram acertadas. A regra passou a BR16 e a ser validada no `sp_fechar_lote`.
**Resultado final:** a consulta de controlo Q17 devolve zero linhas; testes TC33 e TC34.
**Evidência:** `data/queries.sql` (Q17); relatório, secções 4.2 e 6.2.

## AI-04 — Base de dados: triggers com uma falha só visível a partir do protótipo
**Ferramenta:** Claude (claude.ai) e Claude Code
**Artefactos de entrada:** schema, regras de negócio e dados de teste.
**Tarefa pedida:** triggers para as regras que um CHECK não cobre e um procedimento para os testar.
**Resultado relevante:** 7 triggers e 18 testes dentro de uma transação, que o grupo correu no Docker com 18/18 OK.
**Validação humana:** testes automáticos no Docker do grupo e, depois, testes no ecrã do protótipo (UI01).
**Problema / limitação encontrada:** com um lance inexistente, a BD devolveu o erro 1231 ("MESSAGE_TEXT can't be set to NULL") em vez da mensagem da regra: a mensagem era montada com CONCAT sobre valores NULL. Os 18 testes não cobriam este caso. Nos dados de referência, a IA usou valores não confirmados numa fonte (fator de conversão 1,50 para bacalhau HEG; caixas de 25 e 20 kg).
**Correção / decisão:** os dois triggers passaram a verificar primeiro se o lance ou o lote existem (TC41). Os valores de referência ficaram assinalados como exemplo, a confirmar com o armador.
**Resultado final:** mensagens claras em todos os casos; os testes automáticos passaram a 33 (`data/testes/testes_triggers.sql`).
**Evidência:** relatório, secções 4.4 e 6.2.
