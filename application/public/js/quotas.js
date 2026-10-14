// UI04 — Painel de quotas (FR09). Dados: GET /api/quotas?ano=…

import { montarLayout, api, mostrarErro, limparErro, esc, kg, pct } from './comum.js';

const ctx = await montarLayout({ ativo: 'quotas', papel: 'armador' });
const seletor = document.getElementById('ano');

try {
  const anos = await api('/api/quotas/anos');
  seletor.innerHTML = anos.map((a) => `<option value="${a}">Ano: ${a}</option>`).join('');
  seletor.addEventListener('change', () => carregar(Number(seletor.value)));
  if (anos.length > 0) {
    await carregar(anos[0]);
  } else {
    desenharTabela([]);
  }
} catch (erro) {
  mostrarErro(erro);
  desenharTabela([]);
}

async function carregar(ano) {
  limparErro();
  document.getElementById('titulo').textContent = `Painel de quotas — ${ano}`;
  document.getElementById('subtitulo').textContent =
    `${ctx?.navio ?? 'Navio'} · peso vivo capturado face à quota anual`;
  document.getElementById('exportar').href = `/api/quotas/csv?ano=${ano}`;

  try {
    const quotas = await api(`/api/quotas?ano=${ano}`);
    desenharCartoes(quotas);
    desenharTabela(quotas);
  } catch (erro) {
    mostrarErro(erro);
    desenharCartoes([]);
    desenharTabela([]);
  }
}

// Cartões: um por espécie (capturado / soma das quotas), a quota mais
// consumida e o número de alertas
function desenharCartoes(quotas) {
  const especies = new Map();
  for (const q of quotas) {
    const e = especies.get(q.cod_fao) ?? { nome: q.especie, capturado: 0, quota: 0, zonas: 0 };
    e.capturado += q.capturado_kg;
    e.quota += q.quota_kg;
    e.zonas += 1;
    especies.set(q.cod_fao, e);
  }

  const cartoes = [...especies.values()].map((e) => cartao(
    `${e.nome} capturado`,
    `${kg(e.capturado)} kg`,
    `de ${kg(e.quota)} kg em ${e.zonas} ${e.zonas === 1 ? 'zona' : 'zonas'}`,
  ));

  const maior = quotas.reduce((a, b) => (b.consumida_pct > (a?.consumida_pct ?? -1) ? b : a), null);
  cartoes.push(maior
    ? cartao('Quota mais consumida', pct(maior.consumida_pct), `${maior.cod_fao} · ${maior.codigo_ices} ${maior.jurisdicao}`)
    : cartao('Quota mais consumida', '—', 'sem quotas neste ano'));

  const atencao = quotas.filter((q) => q.estado === 'ATENÇÃO').length;
  const critico = quotas.filter((q) => q.estado === 'CRÍTICO').length;
  const detalhe = atencao + critico === 0
    ? 'nenhuma quota acima de 75 %'
    : [critico && `${critico} CRÍTICO`, atencao && `${atencao} ATENÇÃO`].filter(Boolean).join(' · ');
  cartoes.push(cartao('Alertas', String(atencao + critico), detalhe));

  document.getElementById('cartoes').innerHTML = cartoes.join('');
}

function cartao(titulo, valor, detalhe) {
  return `<div class="tile"><div class="k">${esc(titulo)}</div>
    <div class="v">${esc(valor)}</div><div class="s">${esc(detalhe)}</div></div>`;
}

function desenharTabela(quotas) {
  const corpo = document.getElementById('linhas');
  if (quotas.length === 0) {
    corpo.innerHTML = '<tr><td colspan="7" class="vazio">Sem quotas para mostrar.</td></tr>';
    return;
  }

  corpo.innerHTML = quotas.map((q) => {
    const classe = { 'ATENÇÃO': 'atencao', 'CRÍTICO': 'critico' }[q.estado] ?? '';
    const largura = Math.min(q.consumida_pct, 100);
    return `<tr>
      <td>${esc(q.cod_fao)}</td>
      <td>${esc(q.codigo_ices)} ${esc(q.jurisdicao)}</td>
      <td class="num">${kg(q.capturado_kg)}</td>
      <td class="num">${kg(q.quota_kg)}</td>
      <td><div class="bar ${classe}"><i style="width:${largura}%"></i><b style="left:75%"></b><b style="left:90%"></b></div></td>
      <td class="num">${pct(q.consumida_pct)}</td>
      <td><span class="pill ${classe}">${esc(q.estado)}</span></td>
    </tr>`;
  }).join('');
}
