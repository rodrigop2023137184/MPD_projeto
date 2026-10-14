// Ligação à base de dados: um pool de ligações por papel.
//
// Cada ecrã usa o utilizador MySQL do seu papel (data/programmable_objects.sql, parte 3):
//   armador    -> app_armador     (painel de quotas, UI04)
//   pesca      -> app_pesca       (lances e capturas, UI01)
//   fabrica    -> app_fabrica     (fechar lote, UI02)
//   comandante -> app_comandante  (escalas, viagens, saídas)
// Assim é a própria BD que decide o que cada ecrã pode fazer: se o
// código pedir algo fora do papel, o MySQL recusa (erro 1142/1143).

import mysql from 'mysql2/promise';
import { config } from './config.js';

export const PAPEIS = {
  armador: 'ARMADOR',
  pesca: 'PESCA',
  fabrica: 'FABRICA',
  comandante: 'COMANDANTE',
};

const pools = new Map();

export function ligacao(papel) {
  const chave = PAPEIS[papel];
  if (!chave) {
    throw new Error(`Papel desconhecido: ${papel}`);
  }

  if (!pools.has(papel)) {
    const user = process.env[`DB_USER_${chave}`];
    const password = process.env[`DB_PASS_${chave}`];
    if (!user || !password) {
      const erro = new Error(`Faltam DB_USER_${chave} / DB_PASS_${chave} no ficheiro .env`);
      erro.code = 'CONFIG';
      throw erro;
    }

    pools.set(papel, mysql.createPool({
      ...config.db,
      user,
      password,
      charset: 'utf8mb4',
      timezone: 'Z',          // as datas da BD estão em UTC (RN7)
      dateStrings: true,      // DATETIME chega como texto, sem conversões de fuso
      decimalNumbers: true,   // DECIMAL chega como número (kg, %)
      connectionLimit: 5,
    }));
  }

  return pools.get(papel);
}

export async function fecharLigacoes() {
  await Promise.all([...pools.values()].map((pool) => pool.end()));
  pools.clear();
}
