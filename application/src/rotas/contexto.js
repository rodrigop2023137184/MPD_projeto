// GET /api/contexto/:papel — dados do rodapé da barra lateral:
// utilizador MySQL com que o ecrã trabalha, navio e viagem em curso.

import { Router } from 'express';
import { ligacao, PAPEIS } from '../db.js';
import { erroPedido } from '../erros.js';

export const rotasContexto = Router();

rotasContexto.get('/:papel', async (req, res) => {
  const { papel } = req.params;
  if (!PAPEIS[papel]) {
    throw erroPedido(`Papel desconhecido: ${papel}`);
  }

  const [linhas] = await ligacao(papel).query(`
    SELECT SUBSTRING_INDEX(CURRENT_USER(), '@', 1)            AS utilizador,
           (SELECT nome FROM navio ORDER BY id_navio LIMIT 1)  AS navio,
           (SELECT CONCAT('Viagem ', num_viagem)
              FROM viagem
             WHERE id_escala_chegada IS NULL
             ORDER BY num_viagem DESC
             LIMIT 1)                                          AS viagem_em_curso`);

  res.json(linhas[0]);
});
