// Funções partilhadas pelos ecrãs: barra lateral, pedidos à API,
// mensagens de erro e formatação em português.

// Ecrãs da aplicação. "pronto: false" aparece a cinzento na barra lateral.
const ECRAS = [
  { id: 'quotas',  titulo: 'Painel de quotas',  url: '/quotas.html',  pronto: true },
  { id: 'lances',  titulo: 'Lances e capturas', url: '/lances.html',  pronto: true },
  { id: 'lotes',   titulo: 'Fábrica — lotes',   url: '/lotes.html',   pronto: true },
  { id: 'stock',   titulo: 'Porões e saídas',   url: '/stock.html',   pronto: true },
  { id: 'rastreio', titulo: 'Rastreabilidade',  url: '/rastreio.html', pronto: true },
  { id: 'viagens', titulo: 'Viagens e escalas', url: '/viagens.html', pronto: true },
];

// Desenha a barra lateral. "papel" é o utilizador MySQL com que o ecrã
// trabalha (aparece no rodapé, lido da própria BD).
export async function montarLayout({ ativo, papel }) {
  const nav = ECRAS.map((e) => {
    if (e.id === ativo) return `<a class="on" href="${e.url}">${e.titulo}</a>`;
    if (e.pronto) return `<a href="${e.url}">${e.titulo}</a>`;
    return `<span title="Por implementar">${e.titulo}</span>`;
  }).join('');

  const side = document.createElement('aside');
  side.className = 'side';
  side.innerHTML = `
    <a class="brand" href="/quotas.html"><img src="/img/logo.png" alt="Santa Princesa" width="174" height="82"></a>
    <div class="sub">Gestão de Bordo</div>
    <nav class="nav">${nav}</nav>
    <div class="foot" id="rodape">A ligar à base de dados…</div>`;
  document.body.prepend(side);
  return atualizarRodape(papel);
}

// Lê da BD o utilizador e a viagem em curso para o rodapé. Os ecrãs que
// abrem ou fecham viagens voltam a chamá-la depois de gravar.
export async function atualizarRodape(papel) {
  try {
    const ctx = await api(`/api/contexto/${papel}`);
    document.getElementById('rodape').innerHTML =
      `Utilizador: ${esc(ctx.utilizador)}<br>Viagem em curso: ${esc(ctx.viagem_em_curso ?? '—')}`;
    return ctx;
  } catch (erro) {
    document.getElementById('rodape').textContent = 'Sem ligação à base de dados';
    mostrarErro(erro);
    return null;
  }
}

// Pedido à API. Se a resposta for um erro, lança-o com a mensagem do
// servidor (que, nos erros de regras de negócio, é a mensagem da BD).
export async function api(url, opcoes = {}) {
  const resposta = await fetch(url, {
    ...opcoes,
    headers: { 'Content-Type': 'application/json', ...(opcoes.headers ?? {}) },
  });
  const corpo = await resposta.json().catch(() => ({}));
  if (!resposta.ok) {
    const erro = new Error(corpo.erro ?? `Erro ${resposta.status}`);
    erro.estado = resposta.status;
    throw erro;
  }
  return corpo;
}

export function mostrarErro(erro) {
  const caixa = document.getElementById('erro');
  if (!caixa) return;
  caixa.textContent = erro?.message ?? String(erro);
  caixa.classList.add('visivel');
}

export function limparErro() {
  document.getElementById('erro')?.classList.remove('visivel');
  document.getElementById('sucesso')?.classList.remove('visivel');
}

export function mostrarSucesso(texto) {
  const caixa = document.getElementById('sucesso');
  if (!caixa) return;
  caixa.textContent = texto;
  caixa.classList.add('visivel');
}

// "2026-08-27 06:00" -> "27/08/2026 06:00"
export const dataPt = (texto) => {
  if (!texto) return '—';
  const [d, h] = String(texto).split(' ');
  const [a, m, dia] = d.split('-');
  return `${dia}/${m}/${a}${h ? ` ${h}` : ''}`;
};

// Escapa texto vindo da BD antes de o pôr em HTML
export function esc(texto) {
  return String(texto ?? '').replace(/[&<>"']/g, (c) => (
    { '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]
  ));
}

const fmtInteiro = new Intl.NumberFormat('pt-PT', { maximumFractionDigits: 0 });
const fmtPct = new Intl.NumberFormat('pt-PT', { minimumFractionDigits: 2, maximumFractionDigits: 2 });

// 17300 -> "17 300"; os números de 4 algarismos também levam espaço,
// como nos mockups (o pt-PT por omissão só agrupa a partir de 10 000)
export const kg = (n) => {
  const texto = fmtInteiro.format(n);
  return /^\d{4}$/.test(texto) ? `${texto[0]} ${texto.slice(1)}` : texto;
};
export const pct = (n) => `${fmtPct.format(n)} %`;
