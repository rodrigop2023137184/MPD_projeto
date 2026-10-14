// UI02 — Fechar lote (FR07)
//
// Regras em duas camadas (relatório 2.2):
//  - o ecrã só lista lances terminados com peso disponível, mostra a
//    capacidade livre dos porões e avisa antes de gravar;
//  - a BD decide: o lote é gravado pelo sp_fechar_lote numa só transação
//    e os triggers (RN16, RN22) e CHECK (RN26) recusam o que não bate certo.
// Os avisos não bloqueiam o botão, para se poder ver a própria BD a recusar.

import { montarLayout, api, mostrarErro, mostrarSucesso, limparErro, esc, kg, dataPt } from './comum.js';

await montarLayout({ ativo: 'lotes', papel: 'fabrica' });

const $ = (id) => document.getElementById(id);
const form = $('formulario');

let dados = null;            // viagem em curso, turnos, responsáveis, produtos
let origem = null;           // lances disponíveis, porões e código do turno/produto escolhidos
let poroesManuais = false;   // o utilizador já mexeu nas caixas dos porões?

const fmtRend = new Intl.NumberFormat('pt-PT', { minimumFractionDigits: 1, maximumFractionDigits: 1 });

// O arranque (carregar os dados) está no FIM do ficheiro: as funções
// definidas com const só existem depois de o módulo as ler.

// "2026-08-27 06:00" -> "27/08 06:00"
function curta(texto) {
  if (!texto) return '';
  const [d, h] = texto.split(' ');
  const [, m, dia] = d.split('-');
  return `${dia}/${m} ${h}`;
}

// "27/08 06:00–12:00" (ou "27/08 06:00 (aberto)")
function periodo(t) {
  if (!t.fim) return `${curta(t.inicio)} (aberto)`;
  const mesmoDia = t.fim.slice(0, 10) === t.inicio.slice(0, 10);
  return `${curta(t.inicio)}–${mesmoDia ? t.fim.slice(11) : curta(t.fim)}`;
}

const turnoEscolhido = () => dados?.turnos.find((t) => String(t.id_turno) === $('turno').value) ?? null;
const produtoEscolhido = () => dados?.produtos.find((p) => String(p.id_produto) === $('produto').value) ?? null;

// ---------- formulário: viagem, turnos, responsáveis, produtos ----------

async function carregarFormulario(selecionarTurno) {
  dados = await api('/api/lotes/formulario');
  const v = dados.viagem;

  if (!v) {
    $('gravar').disabled = true;
    $('btnAbrirTurno').disabled = true;
    throw new Error('Não há nenhuma viagem em curso: não é possível fechar lotes.');
  }

  $('tituloTurnos').textContent = `Turnos da Viagem ${v.num_viagem}`;
  $('tituloLotes').textContent = `Lotes da Viagem ${v.num_viagem}`;
  $('turnoInicio').min = (v.partida ?? '').replace(' ', 'T');

  desenharTurnos();

  const responsavel = $('turnoResponsavel').value;
  $('turnoResponsavel').innerHTML = dados.responsaveis.length
    ? dados.responsaveis.map((r) =>
      `<option value="${r.id_tripulante}">${esc(r.nome)} (${esc(r.posto)})</option>`).join('')
    : '<option value="">Sem Factory Manager nesta viagem</option>';
  if (responsavel) $('turnoResponsavel').value = responsavel;

  const turno = selecionarTurno ?? $('turno').value;
  $('turno').innerHTML = dados.turnos.length
    ? dados.turnos.map((t) =>
      `<option value="${t.id_turno}">${esc(periodo(t))} · ${esc(t.responsavel)}</option>`).join('')
    : '<option value="">Abra um turno primeiro</option>';
  if (turno && dados.turnos.some((t) => String(t.id_turno) === String(turno))) {
    $('turno').value = String(turno);
  }

  if (!$('produto').options.length) {
    $('produto').innerHTML = dados.produtos.map((p) =>
      `<option value="${p.id_produto}">${esc(p.especie)} ${esc(p.cod_apresentacao)} · caixa ${kg(p.peso_caixa_kg)} kg</option>`)
      .join('');
  }

  atualizarSubtitulo();
}

function atualizarSubtitulo() {
  const v = dados.viagem;
  const t = turnoEscolhido();
  $('subtitulo').textContent = t
    ? `Viagem ${v.num_viagem} · turno ${periodo(t)} · responsável ${t.responsavel}${t.posto ? ` (${t.posto})` : ''}`
    : `Viagem ${v.num_viagem} · ${v.navio} · responsável de fábrica`;
}

function desenharTurnos() {
  const corpo = $('turnos');
  if (dados.turnos.length === 0) {
    corpo.innerHTML = '<tr><td colspan="5" class="vazio">Ainda não há turnos nesta viagem. Abra o primeiro abaixo.</td></tr>';
    return;
  }
  corpo.innerHTML = dados.turnos.map((t) => `<tr>
      <td>${dataPt(t.inicio)}</td>
      <td>${t.fim ? dataPt(t.fim) : '<span class="pill">aberto</span>'}</td>
      <td>${esc(t.responsavel)}${t.posto ? ` <span class="nota">${esc(t.posto)}</span>` : ''}</td>
      <td class="num">${t.n_lotes}</td>
      <td>${t.fim ? '' : `<div class="acoes">
          <input class="in data" type="datetime-local" id="fim-${t.id_turno}" min="${t.inicio.replace(' ', 'T')}"
                 aria-label="Fim do turno (UTC)">
          <button class="btn sec pequeno" type="button" data-fechar="${t.id_turno}">Fechar turno</button>
        </div>`}</td>
    </tr>`).join('');
}

// ---------- origem do peixe e porões (para o turno e o produto escolhidos) ----------

async function carregarOrigem() {
  origem = null;
  poroesManuais = false;
  atualizarSubtitulo();

  const turno = $('turno').value;
  const produto = produtoEscolhido();
  if (!turno || !produto) {
    $('lances').innerHTML = '<tr><td colspan="5" class="vazio">Abra um turno para poder fechar lotes.</td></tr>';
    $('poroes').innerHTML = '<tr><td colspan="3" class="vazio">—</td></tr>';
    $('codigo').value = '';
    atualizarCalculos();
    return;
  }

  origem = await api(`/api/lotes/origem?turno=${turno}&produto=${produto.id_produto}`);
  $('codigo').value = origem.codigo_sugerido;

  const especie = produto.especie.toLowerCase();
  $('tituloOrigem').textContent = origem.turno.fim
    ? `Origem do peixe (lances desta viagem com ${especie} disponível)`
    : `Origem do peixe (lances com ${especie} disponível, terminados até agora — turno aberto)`;
  $('colDisponivel').textContent = `${produto.cod_fao} disponível (kg)`;

  $('lances').innerHTML = origem.lances.length
    ? origem.lances.map((l) => `<tr data-lance="${l.id_lance}">
        <td>${l.num_lance}</td>
        <td>${curta(l.fim)}</td>
        <td>${esc(l.codigo_ices)} ${esc(l.jurisdicao)}</td>
        <td class="num">${kg(l.disponivel_kg)}</td>
        <td class="num"><input class="in usar" type="number" min="0" step="0.01" value="${l.disponivel_kg}"
              aria-label="Peso vivo do lance ${l.num_lance} a usar (kg)"></td>
      </tr>`).join('')
    : `<tr><td colspan="5" class="vazio">Não há lances terminados com ${esc(especie)} disponível
        ${origem.turno.fim ? 'até ao fim deste turno' : 'até agora'}.</td></tr>`;

  $('poroes').innerHTML = origem.poroes.map((p) => `<tr data-porao="${p.id_porao}">
      <td>${esc(p.designacao)}</td>
      <td class="num livre">${kg(p.livre_caixas)}</td>
      <td class="num"><input class="in cx" type="number" min="0" step="1" placeholder="0"
            aria-label="Caixas a guardar no ${esc(p.designacao)}"></td>
    </tr>`).join('');

  sugerirPoroes();
  atualizarCalculos();
}

// Enquanto o utilizador não mexer nos porões, põe as caixas todas no
// primeiro porão com espaço (só uma sugestão; pode repartir à mão)
function sugerirPoroes() {
  if (!origem || poroesManuais) return;
  const caixas = Number($('caixas').value) || 0;
  const destino = origem.poroes.find((p) => p.livre_caixas >= caixas) ?? origem.poroes[0];
  for (const linha of $('poroes').rows) {
    const campo = linha.querySelector('.cx');
    if (campo) campo.value = caixas > 0 && Number(linha.dataset.porao) === destino?.id_porao ? caixas : '';
  }
}

function lancesUsados() {
  return [...$('lances').querySelectorAll('tr[data-lance]')]
    .map((linha) => ({
      id_lance: Number(linha.dataset.lance),
      peso_vivo_kg: linha.querySelector('.usar').value,
      lance: origem.lances.find((l) => String(l.id_lance) === linha.dataset.lance),
    }))
    .filter((l) => l.peso_vivo_kg !== '' && Number(l.peso_vivo_kg) !== 0);
}

function poroesUsados() {
  return [...$('poroes').querySelectorAll('tr[data-porao]')]
    .map((linha) => ({
      id_porao: Number(linha.dataset.porao),
      n_caixas: linha.querySelector('.cx').value,
      porao: origem.poroes.find((p) => String(p.id_porao) === linha.dataset.porao),
    }))
    .filter((p) => p.n_caixas !== '' && Number(p.n_caixas) !== 0);
}

// Peso do produto, matéria-prima, rendimento e avisos (só para mostrar:
// quem calcula e grava estes valores é o sp_fechar_lote)
function atualizarCalculos() {
  const produto = produtoEscolhido();
  const caixas = Number($('caixas').value) || 0;
  const lances = origem ? lancesUsados() : [];
  const poroes = origem ? poroesUsados() : [];

  const pesoCaixa = produto?.peso_caixa_kg ?? 0;
  const produtoKg = caixas * pesoCaixa;
  const materiaKg = lances.reduce((s, l) => s + Number(l.peso_vivo_kg), 0);

  $('pesoProduto').value = caixas > 0 ? `${kg(produtoKg)} (${caixas} × ${kg(pesoCaixa)})` : '—';
  $('materiaPrima').value = materiaKg > 0 ? `${kg(materiaKg)} (soma dos lances)` : '—';
  $('rendimento').value = caixas > 0 && materiaKg > 0 ? `${fmtRend.format((100 * produtoKg) / materiaKg)} %` : '—';

  const avisos = [];
  if (origem) {
    for (const l of lances) {
      if (Number(l.peso_vivo_kg) > l.lance.disponivel_kg) {
        avisos.push(`o lance n.º ${l.lance.num_lance} tem ${kg(l.lance.disponivel_kg)} kg de ${produto.cod_fao} disponíveis, `
          + `pedido ${kg(l.peso_vivo_kg)} kg (RN16)`);
      }
    }
    for (const p of poroes) {
      if (Number(p.n_caixas) > p.porao.livre_caixas) {
        avisos.push(`o ${p.porao.designacao} só tem ${kg(p.porao.livre_caixas)} caixas livres, pedido ${kg(p.n_caixas)} (RN22)`);
      }
    }
    const caixasPoroes = poroes.reduce((s, p) => s + Number(p.n_caixas), 0);
    if (caixas > 0 && caixasPoroes !== caixas) {
      avisos.push(`o lote tem ${kg(caixas)} caixas, mas os porões recebem ${kg(caixasPoroes)}`);
    }
    if (caixas > 0 && materiaKg > 0 && produtoKg > materiaKg) {
      avisos.push(`o peso do produto (${kg(produtoKg)} kg) é maior do que a matéria-prima (${kg(materiaKg)} kg) (RN26)`);
    }
    if (caixas > 0 && lances.length === 0) {
      avisos.push('não há nenhum lance de origem');
    }
  }

  const aviso = $('aviso');
  if (avisos.length) {
    aviso.innerHTML = `<b>A base de dados vai recusar este lote:</b> ${esc(avisos.join('; '))}.`;
    aviso.classList.add('visivel');
  } else {
    aviso.classList.remove('visivel');
  }
}

// ---------- lotes já gravados ----------

async function carregarLotes() {
  const corpo = $('lotes');
  let lotes;
  try {
    lotes = await api('/api/lotes');
  } catch (erro) {
    corpo.innerHTML = '<tr><td colspan="8" class="vazio">Não foi possível carregar os lotes.</td></tr>';
    throw erro;
  }
  if (lotes.length === 0) {
    corpo.innerHTML = '<tr><td colspan="8" class="vazio">Ainda não há lotes nesta viagem.</td></tr>';
    return;
  }
  corpo.innerHTML = lotes.map((l) => {
    const lances = (l.lances ?? []).map((x) => `n.º ${x.num_lance}: ${kg(x.peso_vivo_kg)} kg`).join(' · ');
    const poroes = (l.poroes ?? []).map((x) => `${esc(x.porao)}: ${kg(x.n_caixas)} cx`).join(' · ');
    const rend = (100 * l.peso_liquido_kg) / l.peso_materia_prima_kg;
    return `<tr>
      <td>${esc(l.codigo_lote)}</td>
      <td>${curta(l.turno_inicio)}</td>
      <td class="num">${kg(l.n_caixas)}</td>
      <td class="num">${kg(l.peso_liquido_kg)}</td>
      <td class="num">${kg(l.peso_materia_prima_kg)}</td>
      <td class="num">${fmtRend.format(rend)} %</td>
      <td>${lances || '—'}</td>
      <td>${poroes || '—'}</td>
    </tr>`;
  }).join('');
}

// ---------- eventos ----------

$('turno').addEventListener('change', () => carregarOrigem().catch(mostrarErro));
$('produto').addEventListener('change', () => carregarOrigem().catch(mostrarErro));
$('caixas').addEventListener('input', () => { sugerirPoroes(); atualizarCalculos(); });
$('lances').addEventListener('input', atualizarCalculos);
$('poroes').addEventListener('input', () => { poroesManuais = true; atualizarCalculos(); });

// Abrir turno (INSERT turno; o trg_turno_responsavel valida o responsável)
$('abrirTurno').addEventListener('submit', async (evento) => {
  evento.preventDefault();
  limparErro();
  if (!$('abrirTurno').checkValidity()) {
    $('abrirTurno').reportValidity();
    return;
  }
  $('btnAbrirTurno').disabled = true;
  try {
    const r = await api('/api/lotes/turnos', {
      method: 'POST',
      body: JSON.stringify({ inicio: $('turnoInicio').value, id_responsavel: $('turnoResponsavel').value }),
    });
    $('turnoInicio').value = '';
    await carregarFormulario(r.id_turno);
    await carregarOrigem();
    await carregarLotes();
    mostrarSucesso(`Turno aberto na Viagem ${r.viagem}: ${periodo(turnoEscolhido())} · ${turnoEscolhido().responsavel}.`);
  } catch (erro) {
    const prefixo = erro.estado === 422 ? 'A base de dados recusou o turno — nada foi gravado. ' : '';
    mostrarErro(new Error(prefixo + erro.message));
  } finally {
    $('btnAbrirTurno').disabled = false;
  }
});

// Fechar turno (UPDATE turno SET fim; o CHECK ck_turno_horas valida fim > início)
$('turnos').addEventListener('click', async (evento) => {
  const botao = evento.target.closest('[data-fechar]');
  if (!botao) return;
  limparErro();
  const idTurno = botao.dataset.fechar;
  const fim = $(`fim-${idTurno}`).value;
  if (!fim) {
    mostrarErro(new Error('Indique a hora de fim do turno (UTC).'));
    return;
  }
  botao.disabled = true;
  try {
    await api(`/api/lotes/turnos/${idTurno}`, { method: 'PATCH', body: JSON.stringify({ fim }) });
    await carregarFormulario(idTurno);
    await carregarOrigem();
    await carregarLotes();
    mostrarSucesso(`Turno fechado: ${periodo(turnoEscolhido())}.`);
  } catch (erro) {
    const prefixo = erro.estado === 422 ? 'A base de dados recusou o fecho do turno. ' : '';
    mostrarErro(new Error(prefixo + erro.message));
    botao.disabled = false;
  }
});

form.addEventListener('reset', () => {
  limparErro();
  // O reset também mudaria o turno e o produto para a primeira opção:
  // guarda-os e, depois de o browser limpar os campos, repõe-nos com os
  // lances e porões sugeridos
  const turno = $('turno').value;
  const produto = $('produto').value;
  setTimeout(() => {
    $('turno').value = turno;
    $('produto').value = produto;
    carregarOrigem().catch(mostrarErro);
  });
});

// Fechar lote: CALL sp_fechar_lote(...) no servidor
form.addEventListener('submit', async (evento) => {
  evento.preventDefault();
  limparErro();

  if (!form.checkValidity()) {
    form.reportValidity();
    return;
  }
  if (!origem) {
    mostrarErro(new Error('Escolha o turno e o produto.'));
    return;
  }

  const corpo = {
    id_turno: $('turno').value,
    id_produto: $('produto').value,
    n_caixas: $('caixas').value,
    lances: lancesUsados().map(({ id_lance, peso_vivo_kg }) => ({ id_lance, peso_vivo_kg })),
    poroes: poroesUsados().map(({ id_porao, n_caixas }) => ({ id_porao, n_caixas })),
  };

  $('gravar').disabled = true;
  try {
    const r = await api('/api/lotes', { method: 'POST', body: JSON.stringify(corpo) });
    $('caixas').value = '';
    await carregarFormulario();
    await carregarOrigem();
    await carregarLotes();
    mostrarSucesso(`Lote ${r.codigo_lote} gravado: ${kg(r.n_caixas)} caixas, `
      + `${r.lances} ${r.lances === 1 ? 'lance' : 'lances'} de origem, `
      + `${r.poroes} ${r.poroes === 1 ? 'porão' : 'porões'}.`);
  } catch (erro) {
    // 422/409 = recusado pela BD (trigger, CHECK, UNIQUE ou validação do
    // procedimento); o procedimento fez ROLLBACK de tudo
    const prefixo = [409, 422].includes(erro.estado) ? 'A base de dados recusou o lote — nada foi gravado. ' : '';
    mostrarErro(new Error(prefixo + erro.message));
  } finally {
    $('gravar').disabled = false;
  }
});

// ---------- arranque ----------
// (no fim: assim todas as funções e constantes acima já existem)

try {
  await carregarFormulario();
  await carregarOrigem();
} catch (erro) {
  mostrarErro(erro);
}
// A lista de lotes não depende do formulário: carrega-se mesmo que ele falhe
carregarLotes().catch(mostrarErro);