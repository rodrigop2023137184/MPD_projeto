// UI05 — Rastrear uma caixa (FR10, RN17). Dados: GET /api/rastreio/:codigo
//
// A partir do código impresso na caixa: de que lances veio o peixe (zona,
// posição, datas), em que turno foi feito, e para onde foi (porões,
// descargas, transbordos). Só leitura. Aceita ?codigo=... no endereço.

import { montarLayout, api, mostrarErro, limparErro, esc, kg } from './comum.js';

await montarLayout({ ativo: 'rastreio', papel: 'armador' });

const $ = (id) => document.getElementById(id);

const fmt1 = new Intl.NumberFormat('pt-PT', { minimumFractionDigits: 1, maximumFractionDigits: 1 });

// O arranque está no FIM do ficheiro (as const abaixo têm de existir antes).

// "2026-07-15 12:00" -> "15/07 12:00"
function curta(texto) {
  if (!texto) return '';
  const [d, h] = texto.split(' ');
  const [, m, dia] = d.split('-');
  return `${dia}/${m} ${h}`;
}

// "15/07 12:00–18:00" (ou "15/07 12:00 (aberto)")
function periodo(inicio, fim) {
  if (!fim) return `${curta(inicio)} (aberto)`;
  return `${curta(inicio)}–${fim.slice(0, 10) === inicio.slice(0, 10) ? fim.slice(11) : curta(fim)}`;
}

// 73.75, 19.55 -> "73.75 N · 19.55 E"
function posicao(lat, lon) {
  if (lat == null || lon == null) return '—';
  const f = (n) => Math.abs(n).toFixed(2);
  return `${f(lat)} ${lat >= 0 ? 'N' : 'S'} · ${f(lon)} ${lon >= 0 ? 'E' : 'W'}`;
}

const cartao = (titulo, valor, detalhe) => `<div class="tile"><div class="k">${esc(titulo)}</div>
  <div class="v" style="font-size: 17px">${esc(valor)}</div><div class="s">${esc(detalhe)}</div></div>`;

async function carregarSugestoes() {
  const lotes = await api('/api/rastreio/lotes');
  $('codigos').innerHTML = lotes.map((l) =>
    `<option value="${esc(l.codigo_lote)}">${esc(l.cod_fao)} ${esc(l.cod_apresentacao)} · Viagem ${l.num_viagem}</option>`).join('');
}

async function pesquisar(codigo) {
  limparErro();
  $('resultado').hidden = true;
  // O código fica no endereço, para se poder partilhar ou voltar a abrir
  history.replaceState(null, '', `?codigo=${encodeURIComponent(codigo)}`);

  const r = await api(`/api/rastreio/${encodeURIComponent(codigo)}`);
  const l = r.lote;
  $('codigo').value = l.codigo_lote;

  const aBordo = r.stock.reduce((s, p) => s + p.stock_caixas, 0);
  $('cartoes').innerHTML = [
    cartao('Produto', `${l.especie} ${l.cod_apresentacao}`, `${kg(l.n_caixas)} caixas · ${kg(l.peso_liquido_kg)} kg`),
    cartao('Produzido', periodo(l.turno_inicio, l.turno_fim), `Viagem ${l.num_viagem} · ${l.responsavel}`),
    cartao('Rendimento', `${fmt1.format(l.rendimento_pct)} %`, `de ${kg(l.peso_materia_prima_kg)} kg de peso vivo`),
    cartao('Ainda a bordo', `${kg(aBordo)} caixas`,
      aBordo ? r.stock.map((p) => `${p.porao}: ${kg(p.stock_caixas)}`).join(' · ') : 'já saiu tudo do navio'),
  ].join('');

  $('lances').innerHTML = r.lances.length
    ? r.lances.map((x) => `<tr>
        <td>${x.num_lance}</td>
        <td>${periodo(x.inicio, x.fim)}</td>
        <td>${esc(x.codigo_ices)} ${esc(x.jurisdicao)}</td>
        <td>${posicao(x.latitude, x.longitude)}</td>
        <td class="num">${x.profundidade_m ?? '—'}</td>
        <td class="num">${kg(x.peso_vivo_kg)}</td>
        <td class="num">${fmt1.format(x.pct_do_lote)}</td>
      </tr>`).join('')
    : '<tr><td colspan="7" class="vazio">Sem lances de origem registados.</td></tr>';

  $('movimentos').innerHTML = r.movimentos.length
    ? r.movimentos.map((m) => `<tr>
        <td>${curta(m.data)}</td>
        <td>${esc(m.movimento)}</td>
        <td>${esc(m.porao)}</td>
        <td class="num">${m.caixas > 0 ? '+' : '−'}${kg(Math.abs(m.caixas))}</td>
        <td>${esc(m.destino ?? '—')}</td>
        <td>${esc(m.comprador ?? '—')}</td>
      </tr>`).join('')
    : '<tr><td colspan="6" class="vazio">Sem movimentos.</td></tr>';

  $('resultado').hidden = false;
}

// ---------- eventos ----------

$('pesquisa').addEventListener('submit', (evento) => {
  evento.preventDefault();
  const codigo = $('codigo').value.trim();
  if (!codigo) {
    mostrarErro(new Error('Indique o código do lote.'));
    return;
  }
  pesquisar(codigo).catch(mostrarErro);
});

// ---------- arranque ----------
// (no fim: assim todas as funções e constantes acima já existem)

carregarSugestoes().catch(mostrarErro);
const pedido = new URLSearchParams(location.search).get('codigo');
if (pedido) {
  $('codigo').value = pedido;
  pesquisar(pedido).catch(mostrarErro);
}
