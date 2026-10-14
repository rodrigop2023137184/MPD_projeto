// Lê o ficheiro .env da pasta application/ (sem dependências: usa o
// process.loadEnvFile do Node 22) e expõe a configuração da aplicação.
// As credenciais nunca ficam no código.

import path from 'node:path';
import { fileURLToPath } from 'node:url';

const raiz = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const ficheiroEnv = path.join(raiz, '.env');

try {
  process.loadEnvFile(ficheiroEnv);
} catch (erro) {
  if (erro.code === 'ENOENT') {
    console.error(`Falta o ficheiro ${ficheiroEnv}.`);
    console.error('Copie o .env.example para .env (na pasta application) e volte a correr.');
    process.exit(1);
  }
  throw erro;
}

export const config = {
  raiz,
  porta: Number(process.env.PORT ?? 3000),
  db: {
    host: process.env.DB_HOST ?? 'localhost',
    port: Number(process.env.DB_PORT ?? 3307),
    database: process.env.DB_NAME ?? 'sta_princesa',
  },
};
