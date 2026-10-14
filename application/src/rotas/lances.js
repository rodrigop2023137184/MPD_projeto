// UI01 — Registar lance e capturas (FR05), com o utilizador do mestre de pesca
//
//   GET  /api/lances/formulario           viagem em curso, próximo n.º, zonas, espécies
//   GET  /api/lances/quotas?zona=1&ano=…  quota restante por espécie nessa zona e ano
//   GET  /api/lances                      lances da viagem em curso, com as capturas
//   POST /api/lances                      grava o lance e as capturas numa transação
//
// A regra da quota (BR08/RN19) está no trigger trg_captura_quota. A
// aplicação mostra a quota restante antes de gravar, mas quem decide é a
// BD: se o trigger recusar uma captura, a transação é desfeita e o lance
// também não fica gravado.

import { Router } from 'express';
import { ligacao } from '../db.js';
import { erroPedido } from '../erros.js';
import { dataHora, numero } from '../validacao.js';
import { viagemEmCurso } from '../viagem.js';

export const rotasLances = Router();

const PAPEL = 'pesca';

rotasLances.get('/formulario', async (req, res) => {
  const db = ligacao(PAPEL);
  const viagem = await viagemEmCurso(db);

  let proximoLance = null;
  if (viagem) {
    const [[linha]] = await db.execute(
      'SELECT COALESCE(MAX(num_lance), 0) + 1 AS n FROM lance WHERE id_viagem = ?',
      [viagem.id_viagem],
    );
    proximoLance = linha.n;
  }

  const [zonas] = await db.query(
    'SELECT id_zona, codigo_ices, jurisdicao FROM zona_pesca ORDER BY codigo_ices, jurisdicao',
  );
  const [especies] = await db.query(
    'SELECT cod_fao, nome_comum FROM especie ORDER BY cod_fao',
  );

  res.json({ viagem, proximo_lance: proximoLance, zonas, especies });
});

rotasLances.get('/quotas', async (req, res) => {
  const zona = Number(req.query.zona);
  const ano = Number(req.query.ano);
  if (!Number.isInteger(zona) || !Number.isInteger(ano)) {
    throw erroPedido('Indique a zona e o ano, por exemplo ?zona=1&ano=2026.');
  }

  const db = ligacao(PAPEL);
  const viagem = await viagemEmCurso(db);
  if (!viagem) {
    return res.json([]);
  }

  // Mesma vista do painel de quotas (UI04) = mesmo cálculo do trigger
  const [linhas] = await db.execute(
    `SELECT cod_fao, quota_kg, capturado_kg, restante_kg
       FROM v_quota_consumo
      WHERE id_navio = ? AND id_zona = ? AND ano = ?`,
    [viagem.id_navio, zona, ano],
  );
  res.json(linhas);
});

rotasLances.get('/', async (req, res) => {
  const db = ligacao(PAPEL);
  const viagem = await viagemEmCurso(db);
  if (!viagem) {
    return res.json([]);
  }

  const [linhas] = await db.execute(
    `SELECT l.id_lance, l.num_lance,
            DATE_FORMAT(l.inicio, '%Y-%m-%d %H:%i') AS inicio,
            DATE_FORMAT(l.fim,    '%Y-%m-%d %H:%i') AS fim,
            z.codigo_ices, z.jurisdicao, l.profundidade_m,
            JSON_ARRAYAGG(JSON_OBJECT('cod_fao', c.cod_fao, 'peso_vivo_kg', c.peso_vivo_kg)) AS capturas,
            COALESCE(SUM(c.peso_vivo_kg), 0) AS total_kg
       FROM lance l
       JOIN zona_pesca z ON z.id_zona = l.id_zona_pesca
       LEFT JOIN captura c ON c.id_lance = l.id_lance
      WHERE l.id_viagem = ?
      GROUP BY l.id_lance
      ORDER BY l.num_lance DESC`,
    [viagem.id_viagem],
  );
  res.json(linhas);
});

// ---------------------------------------------------------------------
// POST /api/lances
// { id_zona_pesca, inicio, fim?, latitude?, longitude?, profundidade_m?,
//   capturas: [{ cod_fao, peso_vivo_kg }] }
// Datas em UTC, "AAAA-MM-DD HH:MM" (ou o formato do <input datetime-local>)
// ---------------------------------------------------------------------

function lerPedido(corpo = {}) {
  const zona = Number(corpo.id_zona_pesca);
  if (!Number.isInteger(zona)) throw erroPedido('Escolha a zona de pesca.');

  const inicio = dataHora(corpo.inicio, 'o início do lance', true);
  const fim = dataHora(corpo.fim, 'o fim do lance', false);
  if (fim && fim <= inicio) throw erroPedido('O fim do lance tem de ser depois do início.');

  const capturas = (Array.isArray(corpo.capturas) ? corpo.capturas : [])
    .filter((c) => c && c.peso_vivo_kg !== '' && c.peso_vivo_kg !== null && c.peso_vivo_kg !== undefined)
    .map((c) => ({ cod_fao: String(c.cod_fao ?? '').toUpperCase(), peso: Number(c.peso_vivo_kg) }));

  if (capturas.length === 0) throw erroPedido('Indique o peso vivo de pelo menos uma espécie.');
  for (const c of capturas) {
    if (!/^[A-Z]{3}$/.test(c.cod_fao)) throw erroPedido(`Código de espécie inválido: ${c.cod_fao}.`);
    if (!Number.isFinite(c.peso) || c.peso <= 0) throw erroPedido(`O peso de ${c.cod_fao} tem de ser maior que zero.`);
  }
  if (new Set(capturas.map((c) => c.cod_fao)).size !== capturas.length) {
    throw erroPedido('Há espécies repetidas nas capturas.');
  }

  return {
    zona,
    inicio,
    fim,
    latitude: numero(corpo.latitude, 'Latitude', { min: -90, max: 90 }),
    longitude: numero(corpo.longitude, 'Longitude', { min: -180, max: 180 }),
    profundidade: numero(corpo.profundidade_m, 'Profundidade', { min: 0, max: 3000, inteiro: true }),
    capturas,
  };
}

rotasLances.post('/', async (req, res) => {
  const pedido = lerPedido(req.body);
  const db = ligacao(PAPEL);

  const viagem = await viagemEmCurso(db);
  if (!viagem) throw erroPedido('Não há nenhuma viagem em curso.');

  // Validação só da aplicação (não há trigger para isto, ver relatório 6.3)
  if (viagem.partida && pedido.inicio < viagem.partida) {
    throw erroPedido(`O lance não pode começar antes da partida da Viagem ${viagem.num_viagem} (${viagem.partida} UTC).`);
  }

  // Lance + capturas numa só transação: se o trigger da quota recusar
  // qualquer captura, o lance também é desfeito.
  // O n.º do lance é o seguinte da viagem; se outro utilizador gravar ao
  // mesmo tempo, o UNIQUE uq_lance recusa e tenta-se com o número seguinte.
  const conn = await db.getConnection();
  try {
    for (let tentativa = 1; ; tentativa += 1) {
      await conn.beginTransaction();
      try {
        const [[{ n }]] = await conn.execute(
          'SELECT COALESCE(MAX(num_lance), 0) + 1 AS n FROM lance WHERE id_viagem = ?',
          [viagem.id_viagem],
        );

        const [resultado] = await conn.execute(
          `INSERT INTO lance (id_viagem, num_lance, inicio, fim, latitude, longitude,
                              id_zona_pesca, profundidade_m)
           VALUES (?, ?, ?, ?, ?, ?, ?, ?)`,
          [viagem.id_viagem, n, pedido.inicio, pedido.fim, pedido.latitude,
            pedido.longitude, pedido.zona, pedido.profundidade],
        );

        for (const c of pedido.capturas) {
          // trigger trg_captura_quota (RN19) corre em cada INSERT
          await conn.execute(
            'INSERT INTO captura (id_lance, cod_fao, peso_vivo_kg) VALUES (?, ?, ?)',
            [resultado.insertId, c.cod_fao, c.peso],
          );
        }

        await conn.commit();
        return res.status(201).json({
          id_lance: resultado.insertId,
          num_lance: n,
          viagem: viagem.num_viagem,
          capturas: pedido.capturas.length,
        });
      } catch (erro) {
        await conn.rollback();
        const colisaoNumero = erro.errno === 1062 && String(erro.sqlMessage).includes('uq_lance');
        if (!colisaoNumero || tentativa >= 3) throw erro;
      }
    }
  } finally {
    conn.release();
  }
});
