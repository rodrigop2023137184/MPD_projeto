// FR13 — Viagens e escalas, com o utilizador do comandante
//
//   GET   /api/viagens/formulario      viagem em curso, escalas, portos, tripulação, pendentes, viagens
//   POST  /api/viagens/escalas         nova escala (INSERT escala)
//   PATCH /api/viagens/escalas/:id     horas previstas/reais, calado e nível (UPDATE escala)
//   POST  /api/viagens/:id/fechar      chegada + fecho da viagem + desembarques, numa transação
//   POST  /api/viagens                 abrir a viagem seguinte (partida + tripulação), numa transação
//
// A data de chegada não precisa de ser conhecida quando a viagem começa:
// a escala de chegada fica NULL até ao fecho, e a ETA de uma escala
// planeada é só uma previsão (pode mudar ou faltar).
// As regras estão na BD (data/programmable_objects.sql): ATA/ATD não podem ser no
// futuro (trg_escala_datas*); a viagem só fecha numa escala do mesmo
// navio, com ATA, depois da partida e sem lances nem turnos por terminar
// (RN33: trg_viagem_chegada_update -> sp_validar_chegada_viagem); uma
// viagem nova parte de uma escala do navio ainda não usada como partida
// e só se não houver outra em curso (RN34: trg_viagem_partida); um só
// comandante por viagem (RN10); CHECK ck_escala_prevista / ck_escala_real
// / ck_viagem_escalas.

import { Router } from 'express';
import { ligacao } from '../db.js';
import { erroPedido } from '../erros.js';
import { dataHora, numero, id } from '../validacao.js';
import { viagemEmCurso, navioAtual } from '../viagem.js';

export const rotasViagens = Router();

const PAPEL = 'comandante';

const DATA = (coluna) => `DATE_FORMAT(${coluna}, '%Y-%m-%d %H:%i')`;

rotasViagens.get('/formulario', async (req, res) => {
  const db = ligacao(PAPEL);
  const viagem = await viagemEmCurso(db);
  const navio = await navioAtual(db);

  // Escalas do navio e para que viagens servem (partida / chegada)
  const [escalas] = await db.execute(
    `SELECT es.id_escala, es.cod_porto, pt.nome AS porto,
            ${DATA('es.eta')} AS eta, ${DATA('es.etd')} AS etd,
            ${DATA('es.ata')} AS ata, ${DATA('es.atd')} AS atd,
            es.calado_m, es.nivel_seguranca,
            (SELECT GROUP_CONCAT(v.num_viagem ORDER BY v.num_viagem)
               FROM viagem v WHERE v.id_escala_partida = es.id_escala) AS partida_de,
            (SELECT GROUP_CONCAT(v.num_viagem ORDER BY v.num_viagem)
               FROM viagem v WHERE v.id_escala_chegada = es.id_escala) AS chegada_de
       FROM escala es
       JOIN porto pt ON pt.cod_unlocode = es.cod_porto
      WHERE es.id_navio = ?
      ORDER BY COALESCE(es.ata, es.eta, es.atd, es.etd) DESC, es.id_escala DESC`,
    [navio],
  );

  const [portos] = await db.query(
    'SELECT cod_unlocode, nome, pais FROM porto ORDER BY nome',
  );

  // Viagens do navio (histórico)
  const [viagens] = await db.execute(
    `SELECT v.id_viagem, v.num_viagem,
            pp.nome AS porto_partida, ${DATA('COALESCE(ep.atd, ep.etd)')} AS partida,
            pc.nome AS porto_chegada, ${DATA('COALESCE(ec.ata, ec.eta)')} AS chegada,
            (SELECT COUNT(*) FROM lance l WHERE l.id_viagem = v.id_viagem) AS n_lances,
            (SELECT COUNT(*) FROM tripulacao_viagem tv WHERE tv.id_viagem = v.id_viagem) AS n_tripulantes
       FROM viagem v
       JOIN escala ep ON ep.id_escala = v.id_escala_partida
       JOIN porto  pp ON pp.cod_unlocode = ep.cod_porto
       LEFT JOIN escala ec ON ec.id_escala = v.id_escala_chegada
       LEFT JOIN porto  pc ON pc.cod_unlocode = ec.cod_porto
      WHERE v.id_navio = ?
      ORDER BY v.num_viagem DESC`,
    [navio],
  );

  let tripulacao = [];
  let pendentes = null;
  if (viagem) {
    const [[{ id_escala_partida: partida }]] = await db.execute(
      'SELECT id_escala_partida FROM viagem WHERE id_viagem = ?',
      [viagem.id_viagem],
    );
    viagem.id_escala_partida = partida;

    const [linhas] = await db.execute(
      `SELECT tv.id_tripulante, CONCAT(t.nomes_proprios, ' ', t.apelido) AS nome,
              p.designacao AS posto, tv.id_escala_desembarque
         FROM tripulacao_viagem tv
         JOIN tripulante t ON t.id_tripulante = tv.id_tripulante
         JOIN posto      p ON p.id_posto      = tv.id_posto
        WHERE tv.id_viagem = ?
        ORDER BY p.id_posto, t.apelido`,
      [viagem.id_viagem],
    );
    tripulacao = linhas;

    // Para os avisos do ecrã: o que a BD vai verificar no fecho
    const [[lances]] = await db.execute(
      `SELECT COUNT(*) AS total, COALESCE(SUM(fim IS NULL), 0) AS abertos, ${DATA('MAX(fim)')} AS ultimo_fim
         FROM lance WHERE id_viagem = ?`,
      [viagem.id_viagem],
    );
    const [[turnos]] = await db.execute(
      `SELECT COUNT(*) AS total, COALESCE(SUM(fim IS NULL), 0) AS abertos, ${DATA('MAX(fim)')} AS ultimo_fim
         FROM turno WHERE id_viagem = ?`,
      [viagem.id_viagem],
    );
    pendentes = { lances, turnos };
  }

  // Para abrir a viagem seguinte: postos, todos os tripulantes com o último
  // posto e se ficaram a bordo no fim da última viagem (RN9), e o n.º.
  // "Ficou a bordo" só conta numa viagem JÁ FECHADA: numa viagem em curso
  // ninguém tem desembarque registado e todos pareceriam ter ficado.
  const [postos] = await db.query('SELECT id_posto, designacao FROM posto ORDER BY id_posto');
  const ultima = viagens[0] ?? null;   // a de número mais alto
  const ultimaFechada = ultima?.porto_chegada ? ultima.id_viagem : 0;
  const [tripulantes] = await db.execute(
    `SELECT t.id_tripulante, CONCAT(t.nomes_proprios, ' ', t.apelido) AS nome,
            (SELECT tv.id_posto
               FROM tripulacao_viagem tv JOIN viagem v ON v.id_viagem = tv.id_viagem
              WHERE tv.id_tripulante = t.id_tripulante AND v.id_navio = ?
              ORDER BY v.num_viagem DESC LIMIT 1) AS ultimo_posto,
            EXISTS (SELECT 1 FROM tripulacao_viagem tv
                     WHERE tv.id_tripulante = t.id_tripulante
                       AND tv.id_viagem = ?
                       AND tv.id_escala_desembarque IS NULL) AS ficou_a_bordo
       FROM tripulante t
      ORDER BY t.apelido, t.nomes_proprios`,
    [navio, ultimaFechada],
  );
  const novaViagem = {
    num_viagem: (ultima?.num_viagem ?? 0) + 1,
    ultima: ultima ? { num_viagem: ultima.num_viagem, em_curso: !ultima.porto_chegada } : null,
    postos,
    tripulantes,
  };

  res.json({ viagem, escalas, portos, tripulacao, pendentes, viagens, nova_viagem: novaViagem });
});

// ---------------------------------------------------------------------
// Escalas
// ---------------------------------------------------------------------

function texto(valor, campo, max) {
  const t = String(valor ?? '').trim();
  if (t.length > max) throw erroPedido(`${campo}: no máximo ${max} caracteres.`);
  return t || null;
}

// Campos da escala que o comandante pode escrever (data/programmable_objects.sql, parte 3)
function lerEscala(corpo = {}) {
  return {
    eta: dataHora(corpo.eta, 'a ETA', false),
    etd: dataHora(corpo.etd, 'a ETD', false),
    ata: dataHora(corpo.ata, 'a ATA', false),
    atd: dataHora(corpo.atd, 'a ATD', false),
    calado: numero(corpo.calado_m, 'Calado', { min: 0, max: 99.99 }),
    nivel: texto(corpo.nivel_seguranca, 'Nível de segurança', 30),
  };
}

function lerPorto(valor) {
  const porto = String(valor ?? '').trim().toUpperCase();
  if (!/^[A-Z]{5}$/.test(porto)) throw erroPedido('Escolha o porto (código UN/LOCODE de 5 letras).');
  return porto;
}

rotasViagens.post('/escalas', async (req, res) => {
  const porto = lerPorto(req.body?.cod_porto);
  const e = lerEscala(req.body);
  const db = ligacao(PAPEL);

  // CHECK ck_escala_prevista / ck_escala_real; trg_escala_datas (ATA/ATD no futuro)
  const [resultado] = await db.execute(
    `INSERT INTO escala (id_navio, cod_porto, eta, etd, ata, atd, calado_m, nivel_seguranca)
     VALUES (?, ?, ?, ?, ?, ?, ?, ?)`,
    [await navioAtual(db), porto, e.eta, e.etd, e.ata, e.atd, e.calado, e.nivel],
  );
  res.status(201).json({ id_escala: resultado.insertId });
});

rotasViagens.patch('/escalas/:id', async (req, res) => {
  const idEscala = id(req.params.id, 'Escala inválida.');
  const e = lerEscala(req.body);
  const db = ligacao(PAPEL);
  const navio = await navioAtual(db);

  const [[existe]] = await db.execute(
    'SELECT id_escala FROM escala WHERE id_escala = ? AND id_navio = ?',
    [idEscala, navio],
  );
  if (!existe) throw erroPedido(`A escala ${idEscala} não existe neste navio.`);

  // O formulário envia todos os campos editáveis (vazio = sem valor).
  // trg_escala_datas_update valida a ATA/ATD que mudarem.
  await db.execute(
    `UPDATE escala
        SET eta = ?, etd = ?, ata = ?, atd = ?, calado_m = ?, nivel_seguranca = ?
      WHERE id_escala = ?`,
    [e.eta, e.etd, e.ata, e.atd, e.calado, e.nivel, idEscala],
  );
  res.json({ id_escala: idEscala });
});

// ---------------------------------------------------------------------
// POST /api/viagens/:id/fechar — registar a chegada e fechar a viagem
// Escala já registada: { id_escala, ata?, desembarcam: [ids] }
// Escala nova, criada na chegada: { cod_porto, ata, calado_m?, nivel_seguranca?, desembarcam }
// Vários passos -> transação da aplicação (regra 3): se a BD recusar
// qualquer um, nada fica gravado (nem a escala nova, nem a ATA).
// ---------------------------------------------------------------------

function lerFecho(corpo = {}) {
  const temEscala = !(corpo.id_escala === '' || corpo.id_escala == null);
  const desembarcam = (Array.isArray(corpo.desembarcam) ? corpo.desembarcam : [])
    .map((t) => id(t, 'Há um tripulante inválido na lista de desembarque.'));
  return {
    escala: temEscala ? id(corpo.id_escala, 'Escala inválida.') : null,
    porto: temEscala ? null : lerPorto(corpo.cod_porto),
    ata: dataHora(corpo.ata, 'a ATA', false),
    calado: numero(corpo.calado_m, 'Calado', { min: 0, max: 99.99 }),
    nivel: texto(corpo.nivel_seguranca, 'Nível de segurança', 30),
    desembarcam,
  };
}

rotasViagens.post('/:id/fechar', async (req, res) => {
  const idViagem = id(req.params.id, 'Viagem inválida.');
  const f = lerFecho(req.body);

  const conn = await ligacao(PAPEL).getConnection();
  try {
    await conn.beginTransaction();
    try {
      const [[viagem]] = await conn.execute(
        'SELECT id_viagem, id_navio, num_viagem, id_escala_chegada FROM viagem WHERE id_viagem = ?',
        [idViagem],
      );
      if (!viagem) throw erroPedido(`A viagem ${idViagem} não existe.`);
      if (viagem.id_escala_chegada !== null) throw erroPedido(`A Viagem ${viagem.num_viagem} já está fechada.`);

      // 1. Escala de chegada: a já registada (com a ATA, se vier) ou uma nova
      let idEscala = f.escala;
      if (idEscala) {
        if (f.ata) {
          await conn.execute(
            'UPDATE escala SET ata = ? WHERE id_escala = ? AND id_navio = ?',
            [f.ata, idEscala, viagem.id_navio],
          );
        }
      } else {
        const [r] = await conn.execute(
          `INSERT INTO escala (id_navio, cod_porto, ata, calado_m, nivel_seguranca)
           VALUES (?, ?, ?, ?, ?)`,
          [viagem.id_navio, f.porto, f.ata, f.calado, f.nivel],
        );
        idEscala = r.insertId;
      }

      // 2. Fechar a viagem — trg_viagem_chegada_update valida a chegada
      const [rv] = await conn.execute(
        'UPDATE viagem SET id_escala_chegada = ? WHERE id_viagem = ? AND id_escala_chegada IS NULL',
        [idEscala, idViagem],
      );
      if (rv.affectedRows === 0) throw erroPedido(`A Viagem ${viagem.num_viagem} já foi fechada.`);

      // 3. Quem desembarca nesta escala (os outros ficam a bordo, RN9)
      let desembarcaram = 0;
      if (f.desembarcam.length) {
        const [rt] = await conn.query(
          `UPDATE tripulacao_viagem SET id_escala_desembarque = ?
            WHERE id_viagem = ? AND id_tripulante IN (?) AND id_escala_desembarque IS NULL`,
          [idEscala, idViagem, f.desembarcam],
        );
        desembarcaram = rt.affectedRows;
      }

      await conn.commit();
      res.json({ viagem: viagem.num_viagem, id_escala: idEscala, desembarcaram });
    } catch (erro) {
      await conn.rollback();
      throw erro;
    }
  } finally {
    conn.release();
  }
});

// ---------------------------------------------------------------------
// POST /api/viagens — abrir a viagem seguinte
// { id_escala_partida, etd?, atd?, tripulacao: [{ id_tripulante, id_posto }] }
// Vários passos -> transação da aplicação (regra 3):
//   1. horas de partida da escala (ETD prevista e/ou ATD real), se vierem
//      (RN32: a ATD não pode ser no futuro; CHECK ck_escala_real);
//   2. INSERT viagem com o n.º seguinte do navio (RN3) e sem chegada
//      (RN34: escala do navio, ainda não usada, nenhuma viagem em curso);
//   3. INSERT tripulacao_viagem de cada tripulante, embarcado na escala de
//      partida (RN10: um só comandante).
// Se a BD recusar qualquer passo, nada fica gravado.
// ---------------------------------------------------------------------

function lerNovaViagem(corpo = {}) {
  const tripulacao = (Array.isArray(corpo.tripulacao) ? corpo.tripulacao : []).map((t) => ({
    tripulante: id(t?.id_tripulante, 'Há um tripulante inválido na lista.'),
    posto: id(t?.id_posto, 'Escolha o posto de cada tripulante.'),
  }));
  if (new Set(tripulacao.map((t) => t.tripulante)).size !== tripulacao.length) {
    throw erroPedido('Há tripulantes repetidos na lista.');
  }
  return {
    partida: id(corpo.id_escala_partida, 'Escolha a escala de partida.'),
    etd: dataHora(corpo.etd, 'a ETD', false),
    atd: dataHora(corpo.atd, 'a ATD', false),
    tripulacao,
  };
}

rotasViagens.post('/', async (req, res) => {
  const p = lerNovaViagem(req.body);

  const conn = await ligacao(PAPEL).getConnection();
  try {
    await conn.beginTransaction();
    try {
      const navio = await navioAtual(conn);

      // 1. Horas de partida da escala (só as que vierem preenchidas)
      if (p.etd) {
        await conn.execute('UPDATE escala SET etd = ? WHERE id_escala = ? AND id_navio = ?', [p.etd, p.partida, navio]);
      }
      if (p.atd) {
        await conn.execute('UPDATE escala SET atd = ? WHERE id_escala = ? AND id_navio = ?', [p.atd, p.partida, navio]);
      }

      // 2. A viagem, com o número seguinte do navio. Se outro utilizador
      //    abrir uma viagem ao mesmo tempo, o UNIQUE uq_viagem recusa (409)
      //    — e, de qualquer forma, o trg_viagem_partida só deixa uma em curso.
      const [[{ n }]] = await conn.execute(
        'SELECT COALESCE(MAX(num_viagem), 0) + 1 AS n FROM viagem WHERE id_navio = ?',
        [navio],
      );
      const [rv] = await conn.execute(
        'INSERT INTO viagem (id_navio, num_viagem, id_escala_partida) VALUES (?, ?, ?)',
        [navio, n, p.partida],
      );

      // 3. Tripulação, embarcada na escala de partida (desembarque NULL)
      for (const t of p.tripulacao) {
        await conn.execute(
          `INSERT INTO tripulacao_viagem (id_viagem, id_tripulante, id_posto, id_escala_embarque)
           VALUES (?, ?, ?, ?)`,
          [rv.insertId, t.tripulante, t.posto, p.partida],
        );
      }

      await conn.commit();
      res.status(201).json({ id_viagem: rv.insertId, num_viagem: n, tripulantes: p.tripulacao.length });
    } catch (erro) {
      await conn.rollback();
      throw erro;
    }
  } finally {
    conn.release();
  }
});
