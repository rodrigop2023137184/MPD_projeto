// UI02 — Fechar lote (FR07), com o utilizador da fábrica (app_fabrica)
//
//   GET   /api/lotes/formulario                  viagem em curso, turnos, responsáveis, produtos
//   POST  /api/lotes/turnos                      abre um turno (INSERT turno)
//   PATCH /api/lotes/turnos/:id                  fecha um turno (UPDATE turno SET fim)
//   GET   /api/lotes/origem?turno=…&produto=…    lances com peso disponível, porões, código sugerido
//   GET   /api/lotes                             lotes da viagem em curso, com lances e porões
//   POST  /api/lotes                             fecha o lote: CALL sp_fechar_lote(...)
//
// O lote é gravado SÓ pelo procedimento sp_fechar_lote (data/programmable_objects.sql, parte 2):
// lote + lote_lance + armazenamento numa transação da própria BD. O
// app_fabrica nem tem INSERT nessas tabelas (data/programmable_objects.sql, parte 3).
// O responsável do turno é validado pelo trg_turno_responsavel (RN28).

import { Router } from 'express';
import { ligacao } from '../db.js';
import { erroPedido } from '../erros.js';
import { dataHora, id } from '../validacao.js';
import { viagemEmCurso } from '../viagem.js';

export const rotasLotes = Router();

const PAPEL = 'fabrica';

async function exigirViagem(db) {
  const viagem = await viagemEmCurso(db);
  if (!viagem) throw erroPedido('Não há nenhuma viagem em curso.');
  return viagem;
}

rotasLotes.get('/formulario', async (req, res) => {
  const db = ligacao(PAPEL);
  const viagem = await viagemEmCurso(db);
  if (!viagem) {
    return res.json({ viagem: null, turnos: [], responsaveis: [], produtos: [] });
  }

  const [turnos] = await db.execute(
    `SELECT t.id_turno,
            DATE_FORMAT(t.inicio, '%Y-%m-%d %H:%i') AS inicio,
            DATE_FORMAT(t.fim,    '%Y-%m-%d %H:%i') AS fim,
            CONCAT(tr.nomes_proprios, ' ', tr.apelido) AS responsavel,
            ps.designacao AS posto,
            (SELECT COUNT(*) FROM lote lo WHERE lo.id_turno = t.id_turno) AS n_lotes
       FROM turno t
       JOIN tripulante tr ON tr.id_tripulante = t.id_responsavel
       LEFT JOIN tripulacao_viagem tv ON tv.id_viagem     = t.id_viagem
                                     AND tv.id_tripulante = t.id_responsavel
       LEFT JOIN posto ps ON ps.id_posto = tv.id_posto
      WHERE t.id_viagem = ?
      ORDER BY t.inicio DESC`,
    [viagem.id_viagem],
  );

  // Quem pode ser responsável de turno nesta viagem (RN28). A lista só
  // ajuda o utilizador: quem valida é o trigger trg_turno_responsavel.
  const [responsaveis] = await db.execute(
    `SELECT tr.id_tripulante,
            CONCAT(tr.nomes_proprios, ' ', tr.apelido) AS nome,
            ps.designacao AS posto
       FROM tripulacao_viagem tv
       JOIN posto      ps ON ps.id_posto      = tv.id_posto
       JOIN tripulante tr ON tr.id_tripulante = tv.id_tripulante
      WHERE tv.id_viagem = ?
        AND ps.designacao IN ('Factory Manager', '2nd Factory Manager')
      ORDER BY ps.id_posto, tr.apelido`,
    [viagem.id_viagem],
  );

  const [produtos] = await db.query(
    `SELECT p.id_produto, p.cod_fao, e.nome_comum AS especie,
            p.cod_apresentacao, p.peso_caixa_kg
       FROM produto p
       JOIN especie e ON e.cod_fao = p.cod_fao
      ORDER BY p.id_produto`,
  );

  res.json({ viagem, turnos, responsaveis, produtos });
});

// ---------------------------------------------------------------------
// Turnos: abrir (INSERT) e fechar (UPDATE fim)
// ---------------------------------------------------------------------

rotasLotes.post('/turnos', async (req, res) => {
  const inicio = dataHora(req.body?.inicio, 'o início do turno', true);
  const responsavel = id(req.body?.id_responsavel, 'Escolha o responsável do turno.');

  const db = ligacao(PAPEL);
  const viagem = await exigirViagem(db);

  // Validação só da aplicação, como no UI01 (não há trigger para isto)
  if (viagem.partida && inicio < viagem.partida) {
    throw erroPedido(`O turno não pode começar antes da partida da Viagem ${viagem.num_viagem} (${viagem.partida} UTC).`);
  }

  // trg_turno_responsavel (RN28) recusa um responsável que não seja
  // Factory Manager nem 2nd Factory Manager nesta viagem
  const [resultado] = await db.execute(
    'INSERT INTO turno (id_viagem, inicio, id_responsavel) VALUES (?, ?, ?)',
    [viagem.id_viagem, inicio, responsavel],
  );
  res.status(201).json({ id_turno: resultado.insertId, viagem: viagem.num_viagem });
});

rotasLotes.patch('/turnos/:id', async (req, res) => {
  const idTurno = id(req.params.id, 'Turno inválido.');
  const fim = dataHora(req.body?.fim, 'o fim do turno', true);

  const db = ligacao(PAPEL);
  const viagem = await exigirViagem(db);

  // CHECK ck_turno_horas (fim > início) recusa um fim antes do início
  const [resultado] = await db.execute(
    'UPDATE turno SET fim = ? WHERE id_turno = ? AND id_viagem = ? AND fim IS NULL',
    [fim, idTurno, viagem.id_viagem],
  );
  if (resultado.affectedRows === 0) {
    throw erroPedido(`O turno ${idTurno} não está aberto na Viagem ${viagem.num_viagem}.`);
  }
  res.json({ id_turno: idTurno, fim });
});

// ---------------------------------------------------------------------
// GET /api/lotes/origem?turno=…&produto=…
// Lances da viagem com peso disponível da espécie do produto, porões com
// a capacidade livre e o código de lote sugerido.
// ---------------------------------------------------------------------

rotasLotes.get('/origem', async (req, res) => {
  const idTurno = id(req.query.turno, 'Escolha o turno.');
  const idProduto = id(req.query.produto, 'Escolha o produto.');

  const db = ligacao(PAPEL);
  const viagem = await exigirViagem(db);

  const [[turno]] = await db.execute(
    `SELECT id_turno,
            DATE_FORMAT(inicio, '%Y-%m-%d %H:%i') AS inicio,
            DATE_FORMAT(fim,    '%Y-%m-%d %H:%i') AS fim
       FROM turno
      WHERE id_turno = ? AND id_viagem = ?`,
    [idTurno, viagem.id_viagem],
  );
  if (!turno) throw erroPedido(`O turno ${idTurno} não é da Viagem ${viagem.num_viagem}.`);

  const [[produto]] = await db.execute(
    'SELECT id_produto, cod_fao, peso_caixa_kg FROM produto WHERE id_produto = ?',
    [idProduto],
  );
  if (!produto) throw erroPedido(`O produto ${idProduto} não existe.`);

  // Lances terminados até ao fim do turno (turno aberto: até agora, em
  // UTC — o mesmo limite que o sp_fechar_lote usa) e com peso disponível
  // da espécie: capturado − já usado em lote_lance, o mesmo cálculo do
  // trg_lote_lance_viagem (RN16).
  const [lances] = await db.execute(
    `SELECT l.id_lance, l.num_lance,
            DATE_FORMAT(l.fim, '%Y-%m-%d %H:%i') AS fim,
            z.codigo_ices, z.jurisdicao,
            c.peso_vivo_kg - COALESCE(u.usado_kg, 0) AS disponivel_kg
       FROM lance l
       JOIN captura    c ON c.id_lance = l.id_lance AND c.cod_fao = ?
       JOIN zona_pesca z ON z.id_zona  = l.id_zona_pesca
       LEFT JOIN (SELECT ll.id_lance, SUM(ll.peso_vivo_kg) AS usado_kg
                    FROM lote_lance ll
                    JOIN lote    lo ON lo.id_lote    = ll.id_lote
                    JOIN produto p  ON p.id_produto  = lo.id_produto
                   WHERE p.cod_fao = ?
                   GROUP BY ll.id_lance) u ON u.id_lance = l.id_lance
      WHERE l.id_viagem = ?
        AND l.fim IS NOT NULL
        AND l.fim <= COALESCE(?, UTC_TIMESTAMP())
     HAVING disponivel_kg > 0
      ORDER BY l.fim, l.num_lance`,
    [produto.cod_fao, produto.cod_fao, viagem.id_viagem, turno.fim],
  );

  // Capacidade livre = capacidade − stock (v_stock), o cálculo do RN22
  const [poroes] = await db.execute(
    `SELECT p.id_porao, p.designacao, p.capacidade_caixas,
            p.capacidade_caixas - COALESCE(SUM(vs.stock_caixas), 0) AS livre_caixas
       FROM porao p
       LEFT JOIN v_stock vs ON vs.id_porao = p.id_porao
      WHERE p.id_navio = ?
      GROUP BY p.id_porao, p.designacao, p.capacidade_caixas
      ORDER BY p.id_porao`,
    [viagem.id_navio],
  );

  res.json({
    turno,
    produto,
    lances,
    poroes,
    codigo_sugerido: await codigoSeguinte(db, viagem.num_viagem, produto.cod_fao),
  });
});

// Código do lote: SP-T<n.º da viagem>-<espécie>-<n.º seguinte>, ex.:
// SP-T12-COD-001. O ecrã mostra-o como sugestão, mas o código gravado é
// calculado de novo no momento de fechar o lote (POST): assim dois
// separadores ou dois utilizadores não tentam gravar o mesmo código.
// Se mesmo assim colidirem, o UNIQUE uq_lote_codigo recusa (409).
async function codigoSeguinte(db, numViagem, codFao) {
  const prefixo = `SP-T${numViagem}-${codFao}-`;
  const [[{ ultimo }]] = await db.execute(
    `SELECT COALESCE(MAX(CAST(SUBSTRING(codigo_lote, ?) AS UNSIGNED)), 0) AS ultimo
       FROM lote
      WHERE codigo_lote LIKE ?`,
    [prefixo.length + 1, `${prefixo}%`],
  );
  return `${prefixo}${String(Number(ultimo) + 1).padStart(3, '0')}`;
}

// ---------------------------------------------------------------------
// GET /api/lotes — lotes da viagem em curso (o que ficou gravado)
// ---------------------------------------------------------------------

rotasLotes.get('/', async (req, res) => {
  const db = ligacao(PAPEL);
  const viagem = await viagemEmCurso(db);
  if (!viagem) return res.json([]);

  const [linhas] = await db.execute(
    `SELECT lo.id_lote, lo.codigo_lote, lo.id_turno,
            DATE_FORMAT(t.inicio, '%Y-%m-%d %H:%i') AS turno_inicio,
            p.cod_fao, p.cod_apresentacao,
            lo.n_caixas, lo.peso_liquido_kg, lo.peso_materia_prima_kg,
            (SELECT JSON_ARRAYAGG(JSON_OBJECT('num_lance', la.num_lance, 'peso_vivo_kg', ll.peso_vivo_kg))
               FROM lote_lance ll JOIN lance la ON la.id_lance = ll.id_lance
              WHERE ll.id_lote = lo.id_lote) AS lances,
            (SELECT JSON_ARRAYAGG(JSON_OBJECT('porao', po.designacao, 'n_caixas', a.n_caixas))
               FROM armazenamento a JOIN porao po ON po.id_porao = a.id_porao
              WHERE a.id_lote = lo.id_lote) AS poroes
       FROM lote lo
       JOIN turno   t ON t.id_turno   = lo.id_turno
       JOIN produto p ON p.id_produto = lo.id_produto
      WHERE t.id_viagem = ?
      ORDER BY lo.id_lote DESC`,
    [viagem.id_viagem],
  );
  res.json(linhas);
});

// ---------------------------------------------------------------------
// POST /api/lotes — fecha o lote com o procedimento transacional
// { id_turno, id_produto, n_caixas,
//   lances: [{ id_lance, peso_vivo_kg }], poroes: [{ id_porao, n_caixas }] }
// O código do lote é calculado aqui (codigoSeguinte), não vem do ecrã.
// Aqui só se verificam os formatos. Listas vazias, pesos a zero, caixas
// que não batem certo, lances por terminar... são recusados pelo próprio
// procedimento, com a mensagem dele.
// ---------------------------------------------------------------------

function lerLote(corpo = {}) {
  const nCaixas = Number(corpo.n_caixas);
  if (corpo.n_caixas === '' || corpo.n_caixas == null || !Number.isInteger(nCaixas)) {
    throw erroPedido('Indique o número de caixas produzidas.');
  }

  const lista = (valor) => (Array.isArray(valor) ? valor : []);
  const lances = lista(corpo.lances).map((l) => ({
    id_lance: id(l?.id_lance, 'Há um lance inválido na lista.'),
    peso_vivo_kg: Number(l?.peso_vivo_kg),
  }));
  if (lances.some((l) => !Number.isFinite(l.peso_vivo_kg))) {
    throw erroPedido('O peso a usar de cada lance tem de ser um número.');
  }
  const poroes = lista(corpo.poroes).map((p) => ({
    id_porao: id(p?.id_porao, 'Há um porão inválido na lista.'),
    n_caixas: Number(p?.n_caixas),
  }));
  if (poroes.some((p) => !Number.isInteger(p.n_caixas))) {
    throw erroPedido('As caixas de cada porão têm de ser um número inteiro.');
  }

  return {
    turno: id(corpo.id_turno, 'Escolha o turno.'),
    produto: id(corpo.id_produto, 'Escolha o produto.'),
    nCaixas,
    lances,
    poroes,
  };
}

rotasLotes.post('/', async (req, res) => {
  const lote = lerLote(req.body);

  // Uma ligação só: o @id_lote (OUT) fica na sessão que fez o CALL.
  // Sem beginTransaction: o procedimento abre e fecha a sua transação
  // (e faz ROLLBACK + RESIGNAL se qualquer passo falhar).
  const conn = await ligacao(PAPEL).getConnection();
  try {
    // Código seguinte para a viagem do turno e a espécie do produto. Se o
    // turno ou o produto não existirem, vai NULL e o procedimento recusa
    // com a sua mensagem ("Lote: o turno … não existe") antes de gravar.
    const [[origem]] = await conn.execute(
      `SELECT v.num_viagem, p.cod_fao
         FROM turno t
         JOIN viagem v ON v.id_viagem = t.id_viagem
         JOIN produto p ON p.id_produto = ?
        WHERE t.id_turno = ?`,
      [lote.produto, lote.turno],
    );
    const codigo = origem ? await codigoSeguinte(conn, origem.num_viagem, origem.cod_fao) : null;

    await conn.execute(
      'CALL sp_fechar_lote(?, ?, ?, ?, ?, ?, NULL, @id_lote)',
      [codigo, lote.turno, lote.produto, lote.nCaixas,
        JSON.stringify(lote.lances), JSON.stringify(lote.poroes)],
    );
    const [[{ id_lote: idLote }]] = await conn.query('SELECT @id_lote AS id_lote');

    res.status(201).json({
      id_lote: idLote,
      codigo_lote: codigo,
      n_caixas: lote.nCaixas,
      lances: lote.lances.length,
      poroes: lote.poroes.length,
    });
  } finally {
    conn.release();
  }
});
