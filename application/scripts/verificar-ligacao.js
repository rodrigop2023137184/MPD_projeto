// npm run verificar
// Liga-se à BD com cada um dos 4 utilizadores do .env e mostra o
// utilizador e os papéis ativos. Serve para confirmar a instalação
// antes de arrancar a aplicação.

import { ligacao, fecharLigacoes, PAPEIS } from '../src/db.js';
import { config } from '../src/config.js';

console.log(`Base de dados ${config.db.database} em ${config.db.host}:${config.db.port}\n`);

let falhas = 0;

for (const papel of Object.keys(PAPEIS)) {
  try {
    const [[linha]] = await ligacao(papel).query(
      `SELECT CURRENT_USER() AS utilizador, CURRENT_ROLE() AS papeis,
              (SELECT COUNT(*) FROM v_quota_consumo) AS quotas`,
    );
    console.log(`OK     ${papel.padEnd(11)} ${linha.utilizador.padEnd(18)} ${linha.papeis}`);
  } catch (erro) {
    falhas += 1;
    console.log(`FALHOU ${papel.padEnd(11)} ${erro.code ?? ''} ${erro.sqlMessage ?? erro.message}`);
  }
}

await fecharLigacoes();

if (falhas > 0) {
  console.log('\nVerifique: contentor MPD_pesca a correr, base de dados criada (.\data\executar_tudo.ps1), valores do .env.');
  process.exit(1);
}
console.log('\nTudo pronto: npm start');
