// UI03 — Stock a bordo e saídas (FR11)
//
// Regras em duas camadas (relatório 2.2):
//  - o ecrã mostra o stock de cada lote em cada porão e avisa antes de gravar;
//  - a BD decide: trg_saida_stock (RN24) recusa mais caixas do que as que
//    estão no porão e o CHECK ck_saida_destino (RN25) exige descarga OU
//    transbordo. O aviso não bloqueia o botão, para se ver a BD a recusar.
// As datas das saídas NÃO são verificadas pela BD (relatório 6.3): o ecrã
// só avisa quando parecem incoerentes.

import { montarLayout, api, mostrarErro, mostrarSucesso, limparErro, esc, kg, dataPt } from './comum.js';

await montarLayout({ ativo: 'stock', papel: 'comandante' });

const $ = (id) => document.getElementById(id);
const form = $('formulario');

let stock = null;     // { poroes, especies, linhas }
let escalas = [];

const fmtPct1 = new Intl.NumberFormat('pt-PT', { minimumFractionDigits: 1, maximumFractionDigits: 1 });
const agoraUtc = () => new Date().toISOString().slice(0, 16);   // "AAAA-MM-DDTHH:MM"

$('dataSaida').value = agoraUtc();

// O arranque (carregar os dados) está no FIM do ficheiro: as funções
// definidas com const só existem depois de o módulo as ler.

// ---------- stock ----------

async function carregarStock() {
  try {
    stock = await api('/api/stock');
  } catch (erro) {
    $('linhas').innerHTML = '<tr><td colspan="6" class="vazio">Não foi possível carregar o stock.</td></tr>';
    throw erro;
  }
  desenharCartoes();
  desenharLinhas();
  preencherLotes();
  atualizarAvisos();
}

function cartao(titulo, valor, detalhe) {
  return `<div class="tile"><div class="k">${esc(titulo)}</div>
    <div class="v">${esc(valor)}</div><div class="s">${esc(detalhe)}</div></div>`;
}

function desenharCartoes() {
  const cartoes = stock.poroes.map((p) => cartao(
    p.designacao,
    `${kg(p.stock_caixas)} cx`,
    `de ${kg(p.capacidade_caixas)} · ${fmtPct1.format(p.ocupacao_pct)} % ocupado`,
  ));
  const total = stock.poroes.reduce((s, p) => s + p.stock_caixas, 0);
  const porEspecie = stock.especies
    .map((e) => `${e.nome_comum.toLowerCase()} ${kg(e.stock_caixas)}`)
    .join(' · ');
  cartoes.push(cartao('Total a bordo', `${kg(total)} cx`, porEspecie || 'porões vazios'));
  $('cartoes').innerHTML = cartoes.join('');
}

function desenharLinhas() {
  $('linhas').innerHTML = stock.linhas.length
    ? stock.linhas.map((l) => `<tr>
        <td>${esc(l.porao)}</td>
        <td>${esc(l.codigo_lote)}</td>
        <td>${esc(l.cod_fao)} ${esc(l.cod_apresentacao)}</td>
        <td class="num">${kg(l.armazenado)}</td>
        <td class="num">${kg(l.saido)}</td>
        <td class="num">${kg(l.stock_caixas)}</td>
      </tr>`).join('')
    : '<tr><td colspan="6" class="vazio">Não há stock a bordo.</td></tr>';
}

// Só os lotes com stock, um por porão: "SP-T11-COD-004 · Porão 1 (vante) (97 cx)"
function preencherLotes() {
  const anterior = $('lotePorao').value;
  $('lotePorao').innerHTML = stock.linhas.length
    ? stock.linhas.map((l) => `<option value="${l.id_lote}:${l.id_porao}">
        ${esc(l.codigo_lote)} · ${esc(l.porao)} (${kg(l.stock_caixas)} cx)</option>`).join('')
    : '<option value="">Sem stock a bordo</option>';
  if (stock.linhas.some((l) => `${l.id_lote}:${l.id_porao}` === anterior)) {
    $('lotePorao').value = anterior;
  }
}

const linhaEscolhida = () => stock?.linhas.find((l) => `${l.id_lote}:${l.id_porao}` === $('lotePorao').value) ?? null;
const escalaEscolhida = () => escalas.find((e) => String(e.id_escala) === $('escala').value) ?? null;
const tipo = () => form.querySelector('input[name="tipo"]:checked').value;

// ---------- escalas e saídas ----------

async function carregarEscalas() {
  escalas = await api('/api/stock/escalas');
  $('escala').innerHTML = escalas.length
    ? escalas.map((e) => `<option value="${e.id_escala}">
        ${esc(e.porto)} (${esc(e.cod_porto)}) · ${dataPt(e.chegada).slice(0, 10)}</option>`).join('')
    : '<option value="">Sem escalas registadas</option>';
  atualizarAvisos();
}

async function carregarSaidas() {
  let saidas;
  try {
    saidas = await api('/api/stock/saidas');
  } catch (erro) {
    $('saidas').innerHTML = '<tr><td colspan="7" class="vazio">Não foi possível carregar as saídas.</td></tr>';
    throw erro;
  }

  const ultima = saidas[0];
  $('subtitulo').textContent = ultima
    ? `Situação depois da última saída: ${ultima.tipo.toLowerCase()} · ${ultima.destino} · ${dataPt(ultima.data_saida)} UTC`
    : 'Ainda não há saídas registadas';

  $('saidas').innerHTML = saidas.length
    ? saidas.map((s) => `<tr>
        <td>${dataPt(s.data_saida)}</td>
        <td>${esc(s.tipo)}</td>
        <td>${esc(s.destino)}</td>
        <td>${esc(s.codigo_lote)}</td>
        <td>${esc(s.porao)}</td>
        <td class="num">${kg(s.n_caixas)}</td>
        <td>${esc(s.comprador ?? '—')}</td>
      </tr>`).join('')
    : '<tr><td colspan="7" class="vazio">Ainda não há saídas registadas.</td></tr>';
}

// ---------- avisos antes de gravar ----------

function atualizarAvisos() {
  const linha = linhaEscolhida();
  $('disponivel').innerHTML = linha
    ? `Disponível neste porão: <b>${kg(linha.stock_caixas)} caixas</b>`
    : 'Disponível neste porão: —';

  const recusa = [];   // a BD vai recusar
  const atencao = [];  // a BD aceita, mas parece incoerente (datas: sem regra na BD)

  const caixas = Number($('caixas').value) || 0;
  if (linha && caixas > linha.stock_caixas) {
    recusa.push(`o ${linha.porao} só tem ${kg(linha.stock_caixas)} caixas do lote ${linha.codigo_lote}, `
      + `pedido ${kg(caixas)} (RN24)`);
  }

  const data = $('dataSaida').value.replace('T', ' ');
  if (data && data > agoraUtc().replace('T', ' ')) {
    atencao.push(`a data da saída (${dataPt(data)}) é no futuro`);
  }
  if (linha && data && data < linha.data_entrada) {
    atencao.push(`a data da saída (${dataPt(data)}) é anterior à entrada do lote no porão (${dataPt(linha.data_entrada)})`);
  }
  const escala = tipo() === 'descarga' ? escalaEscolhida() : null;
  if (escala && linha && escala.partida && escala.partida < linha.data_entrada) {
    atencao.push(`a escala de ${escala.porto} (${dataPt(escala.chegada)}–${dataPt(escala.partida)}) `
      + `acabou antes de o lote entrar no porão (${dataPt(linha.data_entrada)})`);
  }
  if (escala && data && (data < escala.chegada || (escala.partida && data > escala.partida))) {
    atencao.push(`a data da saída não está dentro da escala de ${escala.porto} `
      + `(${dataPt(escala.chegada)}–${escala.partida ? dataPt(escala.partida) : '…'})`);
  }

  const partes = [];
  if (recusa.length) partes.push(`<b>A base de dados vai recusar esta saída:</b> ${esc(recusa.join('; '))}.`);
  if (atencao.length) partes.push(`<b>Atenção (a base de dados não verifica datas):</b> ${esc(atencao.join('; '))}.`);
  $('aviso').innerHTML = partes.join('<br>');
  $('aviso').classList.toggle('visivel', partes.length > 0);
}

// Descarga em porto -> escala; transbordo -> navio recetor
function mudarTipo() {
  const descarga = tipo() === 'descarga';
  $('campoEscala').hidden = !descarga;
  $('escala').required = descarga;
  $('campoNavio').hidden = descarga;
  $('navio').required = !descarga;
  atualizarAvisos();
}

// ---------- eventos ----------

form.querySelectorAll('input[name="tipo"]').forEach((r) => r.addEventListener('change', mudarTipo));
for (const id of ['lotePorao', 'escala', 'caixas', 'dataSaida']) {
  $(id).addEventListener('input', atualizarAvisos);
  $(id).addEventListener('change', atualizarAvisos);
}

form.addEventListener('submit', async (evento) => {
  evento.preventDefault();
  limparErro();

  if (!form.checkValidity()) {
    form.reportValidity();
    return;
  }

  const linha = linhaEscolhida();
  const descarga = tipo() === 'descarga';
  const corpo = {
    id_lote: linha.id_lote,
    id_porao: linha.id_porao,
    id_escala: descarga ? $('escala').value : null,
    navio_recetor: descarga ? null : $('navio').value,
    data_saida: $('dataSaida').value,
    n_caixas: $('caixas').value,
    comprador: $('comprador').value,
  };

  $('gravar').disabled = true;
  try {
    await api('/api/stock/saidas', { method: 'POST', body: JSON.stringify(corpo) });
    const destino = descarga
      ? `${escalaEscolhida().porto} (${escalaEscolhida().cod_porto})`
      : corpo.navio_recetor;
    mostrarSucesso(`Saída registada: ${descarga ? 'descarga' : 'transbordo'} de ${kg(Number(corpo.n_caixas))} caixas `
      + `do lote ${linha.codigo_lote} (${linha.porao}) para ${destino}.`);
    $('caixas').value = '';
    $('comprador').value = '';
    $('navio').value = '';
    // A data fica como estava: várias saídas seguidas costumam ser da mesma
    // descarga (repô-la em "agora" fazia aparecer o aviso de fora da escala)
    await carregarStock();
    await carregarSaidas();
  } catch (erro) {
    // 422 = recusado pela BD (RN24, RN25, FK); nada foi gravado
    const prefixo = [409, 422].includes(erro.estado) ? 'A base de dados recusou a saída — nada foi gravado. ' : '';
    mostrarErro(new Error(prefixo + erro.message));
  } finally {
    $('gravar').disabled = false;
  }
});

// ---------- arranque ----------
// (no fim: assim todas as funções e constantes acima já existem)
// Cada parte carrega-se à parte: uma falha não deixa as outras por carregar
carregarStock().catch(mostrarErro);
carregarEscalas().catch(mostrarErro);
carregarSaidas().catch(mostrarErro);