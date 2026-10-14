// Tradução dos erros do MySQL para respostas HTTP com uma mensagem clara.
//
// As regras de negócio vivem na BD (triggers, CHECK, FK, procedimento).
// Quando a BD recusa uma operação, a mensagem do SIGNAL já explica o
// problema (ex.: "RN19: quota excedida (COD): restam ...") e é mostrada
// tal como está ao utilizador.

const TRADUCOES = {
  // SIGNAL SQLSTATE '45000' dos triggers e do sp_fechar_lote
  1644: { estado: 422, mensagem: (e) => e.sqlMessage },
  // CHECK, UNIQUE e FK
  3819: { estado: 422, mensagem: (e) => `Valor inválido: ${e.sqlMessage}` },
  1062: { estado: 409, mensagem: () => 'Já existe um registo com esse identificador.' },
  1452: { estado: 422, mensagem: () => 'Referência inválida: o registo indicado não existe.' },
  1451: { estado: 409, mensagem: () => 'Não é possível: há registos que dependem deste.' },
  // Privilégios do papel (data/programmable_objects.sql, parte 3)
  1142: { estado: 403, mensagem: (e) => `Sem permissão para esta operação. ${e.sqlMessage}` },
  1143: { estado: 403, mensagem: (e) => `Sem permissão para esta operação. ${e.sqlMessage}` },
  1370: { estado: 403, mensagem: (e) => `Sem permissão para esta operação. ${e.sqlMessage}` },
  // Ligação
  1045: { estado: 503, mensagem: () => 'A BD recusou o utilizador ou a palavra-passe. Confirme o .env e o data/programmable_objects.sql (parte 3).' },
  1049: { estado: 503, mensagem: () => 'A base de dados indicada no .env não existe.' },
};

export function tratarErro(erro, req, res, next) {
  if (res.headersSent) {
    return next(erro);
  }

  let estado = 500;
  let mensagem = 'Erro inesperado no servidor.';

  const traducao = TRADUCOES[erro.errno];
  if (traducao) {
    estado = traducao.estado;
    mensagem = traducao.mensagem(erro);
  } else if (['ECONNREFUSED', 'ETIMEDOUT', 'ENOTFOUND'].includes(erro.code)) {
    estado = 503;
    mensagem = 'Não foi possível ligar ao MySQL. O contentor MPD_pesca está a correr? Confirme DB_HOST e DB_PORT no .env.';
  } else if (erro.type === 'entity.parse.failed') {
    // corpo do pedido que não é JSON válido (express.json)
    estado = 400;
    mensagem = 'O pedido não é JSON válido.';
  } else if (erro.code === 'CONFIG' || erro.code === 'PEDIDO') {
    estado = erro.code === 'CONFIG' ? 500 : 400;
    mensagem = erro.message;
  }

  if (estado >= 500) {
    console.error(`[${req.method} ${req.originalUrl}]`, erro);
  }

  res.status(estado).json({ erro: mensagem, codigo: erro.errno ?? erro.code ?? null });
}

// Erro de validação do pedido (parâmetros em falta ou mal formados)
export function erroPedido(mensagem) {
  const erro = new Error(mensagem);
  erro.code = 'PEDIDO';
  return erro;
}
