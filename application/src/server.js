// Servidor da aplicação de bordo (protótipo MPD 2026/27)
// Ecrãs: páginas HTML em public/ · Dados: API JSON em /api/...
// Express 5: os erros das rotas async chegam sozinhos ao tratarErro.

import path from 'node:path';
import express from 'express';
import { config } from './config.js';
import { fecharLigacoes } from './db.js';
import { tratarErro } from './erros.js';
import { rotasContexto } from './rotas/contexto.js';
import { rotasQuotas } from './rotas/quotas.js';
import { rotasLances } from './rotas/lances.js';
import { rotasLotes } from './rotas/lotes.js';
import { rotasStock } from './rotas/stock.js';
import { rotasViagens } from './rotas/viagens.js';
import { rotasRastreio } from './rotas/rastreio.js';

const app = express();
app.disable('x-powered-by');

app.use(express.json());
app.use(express.static(path.join(config.raiz, 'public')));

app.get('/', (req, res) => res.redirect('/quotas.html'));

app.use('/api/contexto', rotasContexto);
app.use('/api/quotas', rotasQuotas);
app.use('/api/lances', rotasLances);
app.use('/api/lotes', rotasLotes);
app.use('/api/stock', rotasStock);
app.use('/api/viagens', rotasViagens);
app.use('/api/rastreio', rotasRastreio);

app.use('/api', (req, res) => {
  res.status(404).json({ erro: `Rota inexistente: ${req.method} ${req.originalUrl}` });
});

app.use(tratarErro);

const servidor = app.listen(config.porta, () => {
  console.log(`Aplicação STA PRINCESA em http://localhost:${config.porta}`);
  console.log(`Base de dados: ${config.db.database} em ${config.db.host}:${config.db.port}`);
});

// Ctrl+C: fecha o servidor e as ligações ao MySQL
process.on('SIGINT', async () => {
  servidor.close();
  await fecharLigacoes();
  process.exit(0);
});
