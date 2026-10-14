// Viagem em curso (sem escala de chegada) e a hora de partida real
// (ou prevista) da escala de onde saiu. Usada pelos ecrãs de bordo.

export async function viagemEmCurso(db) {
  const [linhas] = await db.query(`
    SELECT v.id_viagem, v.id_navio, v.num_viagem, n.nome AS navio,
           p.nome AS porto_partida,
           DATE_FORMAT(COALESCE(e.atd, e.etd), '%Y-%m-%d %H:%i') AS partida
      FROM viagem v
      JOIN navio  n ON n.id_navio  = v.id_navio
      JOIN escala e ON e.id_escala = v.id_escala_partida
      JOIN porto  p ON p.cod_unlocode = e.cod_porto
     WHERE v.id_escala_chegada IS NULL
     ORDER BY v.num_viagem DESC
     LIMIT 1`);
  return linhas[0] ?? null;
}

// Navio da viagem em curso (ou o primeiro navio, com o navio em porto)
export async function navioAtual(db) {
  const viagem = await viagemEmCurso(db);
  if (viagem) return viagem.id_navio;
  const [[navio]] = await db.query('SELECT MIN(id_navio) AS id_navio FROM navio');
  return navio.id_navio;
}
