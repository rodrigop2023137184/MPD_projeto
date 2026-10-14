// FR13 — Viagens e escalas
//
// Regras em duas camadas (relatório 2.2):
//  - o ecrã avisa antes de gravar quando a BD vai recusar;
//  - a BD decide (data/programmable_objects.sql): ATA/ATD não podem ser no futuro; a
//    viagem só fecha numa escala do mesmo navio, com ATA, depois da
//    partida e sem lances nem turnos por terminar; CHECK das horas.
// Os avisos não bloqueiam os botões, para se poder ver a BD a recusar.
// A data de chegada não tem de ser conhecida antes: a ETA é só uma
// previsão e a escala de chegada pode ser criada no próprio fecho.

import { montarLayout, atualizarRodape, api, mostrarErro, mostrarSucesso, limparErro, esc, kg, dataPt } from './comum.js';

await montarLayout({ ativo: 'viagens', papel: 'comandante' });

const $ = (id) => document.getElementById(id);

let dados = null;   // viagem em curso, escalas, portos, tripulação, pendentes, viagens

const agoraUtc = () => new Date().toISOString().slice(0, 16).replace('T', ' ');   // "AAAA-MM-DD HH:MM"
const paraCampo = (texto) => (texto ? texto.replace(' ', 'T') : '');
const doCampo = (id) => $(id).value.replace('T', ' ');

// O arranque (carregar os dados) está no FIM do ficheiro: as funções
// definidas com const só existem depois de o módulo as ler.

async function carregar(escalaEscolhida) {
  try {
    dados = await api('/api/viagens/formulario');
  } catch (erro) {
    for (const [id, colunas] of [['escalas', 8], ['tripulacao', 3], ['viagens', 6]]) {
      $(id).innerHTML = `<tr><td colspan="${colunas}" class="vazio">Não foi possível carregar os dados.</td></tr>`;
    }
    throw erro;
  }
  desenharCabecalho();
  desenharEscalas();
  preencherFormEscala(escalaEscolhida);
  preencherFormFechar();
  preencherFormNova();
  desenharViagens();
}

// ---------- cabeçalho e cartões ----------

function cartao(titulo, valor, detalhe) {
  return `<div class="tile"><div class="k">${esc(titulo)}</div>
    <div class="v">${esc(valor)}</div><div class="s">${esc(detalhe)}</div></div>`;
}

function desenharCabecalho() {
  const v = dados.viagem;
  $('subtitulo').textContent = v
    ? `${v.navio} · Viagem ${v.num_viagem} em curso · partida de ${v.porto_partida} a ${dataPt(v.partida)} UTC`
    : 'Navio em porto: não há nenhuma viagem em curso';

  const cartoes = [];
  if (v) {
    const dias = v.partida
      ? Math.floor((Date.now() - Date.parse(`${v.partida.replace(' ', 'T')}Z`)) / 86400000)
      : null;
    cartoes.push(cartao('Viagem em curso', `Viagem ${v.num_viagem}`, v.partida
      ? `partida ${v.porto_partida} ${dataPt(v.partida).slice(0, 10)} · ${dias} dias no mar`
      : `partida de ${v.porto_partida} sem hora registada`));

    const porPosto = new Map();
    for (const t of dados.tripulacao) porPosto.set(t.posto, (porPosto.get(t.posto) ?? 0) + 1);
    cartoes.push(cartao('Tripulação a bordo', String(dados.tripulacao.length),
      [...porPosto].map(([posto, n]) => `${n} ${posto}`).join(' · ') || 'sem tripulação registada'));

    const { lances, turnos } = dados.pendentes;
    cartoes.push(cartao('Por fechar antes da chegada', String(lances.abertos + turnos.abertos),
      `${lances.abertos} ${lances.abertos === 1 ? 'lance' : 'lances'} · ${turnos.abertos} `
      + `${turnos.abertos === 1 ? 'turno' : 'turnos'} em aberto`));
  } else {
    cartoes.push(cartao('Viagem em curso', '—', 'todas as viagens estão fechadas'));
  }
  $('cartoes').innerHTML = cartoes.join('');
}

// ---------- escalas ----------

const lista = (texto) => (texto ? String(texto).split(',') : []);

function usoEscala(e) {
  return [
    ...lista(e.chegada_de).map((n) => `chegada Viagem ${n}`),
    ...lista(e.partida_de).map((n) => `partida Viagem ${n}`),
  ].join(' · ');
}

function rotuloEscala(e) {
  const data = e.ata ? `ATA ${dataPt(e.ata)}` : e.eta ? `ETA ${dataPt(e.eta)}` : 'sem datas';
  return `${e.porto} (${e.cod_porto}) · ${data}`;
}

function desenharEscalas() {
  $('escalas').innerHTML = dados.escalas.length
    ? dados.escalas.map((e) => `<tr>
        <td>${esc(e.porto)} (${esc(e.cod_porto)})</td>
        <td>${dataPt(e.eta)}</td>
        <td>${dataPt(e.etd)}</td>
        <td>${dataPt(e.ata)}</td>
        <td>${dataPt(e.atd)}</td>
        <td class="num">${e.calado_m ?? '—'}</td>
        <td>${esc(usoEscala(e)) || '<span class="nota">planeada</span>'}</td>
        <td><button class="btn sec pequeno" type="button" data-editar="${e.id_escala}">Editar</button></td>
      </tr>`).join('')
    : '<tr><td colspan="8" class="vazio">Ainda não há escalas.</td></tr>';
}

const escalaPorId = (id) => dados.escalas.find((e) => String(e.id_escala) === String(id)) ?? null;

function preencherFormEscala(escolher) {
  const atual = escolher ?? $('escala').value;
  $('escala').innerHTML = '<option value="">Nova escala</option>'
    + dados.escalas.map((e) => `<option value="${e.id_escala}">${esc(rotuloEscala(e))}</option>`).join('');
  if (!$('porto').options.length) {
    $('porto').innerHTML = dados.portos
      .map((p) => `<option value="${esc(p.cod_unlocode)}">${esc(p.nome)} (${esc(p.cod_unlocode)})</option>`).join('');
    $('porto').value = 'NOTOS';
  }
  $('escala').value = escalaPorId(atual) ? String(atual) : '';
  mudarEscala();
}

// Escolher uma escala preenche o formulário; "Nova escala" limpa-o
function mudarEscala() {
  const e = escalaPorId($('escala').value);
  $('tituloEscala').textContent = e ? `Corrigir escala: ${rotuloEscala(e)}` : 'Nova escala';
  $('porto').disabled = Boolean(e);   // o porto de uma escala não muda (sem privilégio)
  if (e) $('porto').value = e.cod_porto;
  $('calado').value = e?.calado_m ?? '';
  $('nivel').value = e?.nivel_seguranca ?? '';
  for (const campo of ['eta', 'etd', 'ata', 'atd']) $(campo).value = paraCampo(e?.[campo]);
  avisarEscala();
}

function avisarEscala() {
  const agora = agoraUtc();
  const [eta, etd, ata, atd] = ['eta', 'etd', 'ata', 'atd'].map(doCampo);
  const avisos = [];
  if (ata && ata > agora) avisos.push(`a ATA (${dataPt(ata)}) é depois da hora atual (${dataPt(agora)} UTC) (RN32)`);
  if (atd && atd > agora) avisos.push(`a ATD (${dataPt(atd)}) é depois da hora atual (${dataPt(agora)} UTC) (RN32)`);
  if (ata && atd && atd <= ata) avisos.push('a ATD tem de ser depois da ATA');
  if (eta && etd && etd <= eta) avisos.push('a ETD tem de ser depois da ETA');
  mostrarAviso('avisoEscala', avisos, 'esta escala');
}

function mostrarAviso(id, avisos, oque) {
  $(id).innerHTML = avisos.length
    ? `<b>A base de dados vai recusar ${oque}:</b> ${esc(avisos.join('; '))}.`
    : '';
  $(id).classList.toggle('visivel', avisos.length > 0);
}

// ---------- fechar a viagem ----------

const modo = () => document.querySelector('input[name="modo"]:checked').value;

function preencherFormFechar() {
  const v = dados.viagem;
  $('semViagem').hidden = Boolean(v);
  $('blocoFechar').hidden = !v;
  $('tituloFechar').textContent = v
    ? `Registar chegada e fechar a Viagem ${v.num_viagem}`
    : 'Registar chegada e fechar a viagem';
  if (!v) return;

  // Escalas que podem ser de chegada: nem já usadas como chegada, nem como
  // partida (a partida desta viagem ou de uma anterior é sempre antes)
  const candidatas = dados.escalas.filter((e) => !e.chegada_de && !e.partida_de);
  $('escalaChegada').innerHTML = candidatas.length
    ? candidatas.map((e) => `<option value="${e.id_escala}">${esc(rotuloEscala(e))}</option>`).join('')
    : '<option value="">Não há escalas planeadas</option>';

  if (!$('portoChegada').options.length) {
    $('portoChegada').innerHTML = dados.portos
      .map((p) => `<option value="${esc(p.cod_unlocode)}">${esc(p.nome)} (${esc(p.cod_unlocode)})</option>`).join('');
    $('portoChegada').value = 'NOTOS';
  }
  $('ataChegada').value = paraCampo(agoraUtc());

  $('tripulacao').innerHTML = dados.tripulacao.length
    ? dados.tripulacao.map((t) => `<tr>
        <td>${esc(t.nome)}</td>
        <td>${esc(t.posto)}</td>
        <td><label class="marca"><input type="checkbox" class="desembarca" value="${t.id_tripulante}" checked>
          desembarca</label></td>
      </tr>`).join('')
    : '<tr><td colspan="3" class="vazio">Sem tripulação registada nesta viagem.</td></tr>';

  mudarModo();
}

function mudarModo() {
  const nova = modo() === 'nova';
  $('campoExistente').hidden = nova;
  $('campoPortoChegada').hidden = !nova;
  $('camposNova').hidden = !nova;
  if (nova) {
    $('ataChegada').value = paraCampo(agoraUtc());
  } else {
    // ATA da escala escolhida, se já estiver registada
    $('ataChegada').value = paraCampo(escalaPorId($('escalaChegada').value)?.ata);
  }
  avisarFecho();
}

function avisarFecho() {
  const v = dados?.viagem;
  if (!v) return;
  const agora = agoraUtc();
  const ata = doCampo('ataChegada');
  const { lances, turnos } = dados.pendentes;
  const avisos = [];

  if (modo() === 'existente' && !$('escalaChegada').value) avisos.push('escolha a escala de chegada');
  if (!ata) avisos.push('falta a ATA: a viagem só fecha depois de registada a chegada real (RN33)');
  if (ata && ata > agora) avisos.push(`a ATA (${dataPt(ata)}) é depois da hora atual (${dataPt(agora)} UTC) (RN32)`);
  if (ata && v.partida && ata <= v.partida) {
    avisos.push(`a chegada (${dataPt(ata)}) não é depois da partida (${dataPt(v.partida)}) (RN33)`);
  }
  if (lances.abertos > 0) avisos.push(`há ${lances.abertos} lance(s) por terminar — registe o fim no ecrã de lances (RN33)`);
  else if (ata && lances.ultimo_fim && lances.ultimo_fim > ata) {
    avisos.push(`o último lance termina (${dataPt(lances.ultimo_fim)}) depois da chegada (RN33)`);
  }
  if (turnos.abertos > 0) avisos.push(`há ${turnos.abertos} turno(s) por fechar — feche-os no ecrã da fábrica (RN33)`);
  else if (ata && turnos.ultimo_fim && turnos.ultimo_fim > ata) {
    avisos.push(`o último turno fecha (${dataPt(turnos.ultimo_fim)}) depois da chegada (RN33)`);
  }
  mostrarAviso('avisoFechar', avisos, 'o fecho da viagem');
}

// ---------- abrir a viagem seguinte ----------

const postoPorId = (id) => dados.nova_viagem.postos.find((p) => String(p.id_posto) === String(id)) ?? null;

function preencherFormNova() {
  const nv = dados.nova_viagem;
  $('tituloNova').textContent = `Abrir a Viagem ${nv.num_viagem}`;
  $('numNova').value = `Viagem ${nv.num_viagem} (automático)`;

  // Escalas que ainda não serviram de partida; por omissão, a chegada da última viagem
  const candidatas = dados.escalas.filter((e) => !e.partida_de);
  $('escalaPartida').innerHTML = candidatas.length
    ? candidatas.map((e) => `<option value="${e.id_escala}">${esc(rotuloEscala(e))}${
      e.chegada_de ? ` · chegada da Viagem ${esc(e.chegada_de)}` : ''}</option>`).join('')
    : '<option value="">Não há escalas livres — crie uma acima</option>';
  const chegadaUltima = nv.ultima && candidatas.find((e) => lista(e.chegada_de).includes(String(nv.ultima.num_viagem)));
  if (chegadaUltima) $('escalaPartida').value = String(chegadaUltima.id_escala);

  const fisherman = nv.postos.find((p) => p.designacao === 'Fisherman')?.id_posto;
  $('tripulacaoNova').innerHTML = nv.tripulantes.map((t) => `<tr data-tripulante="${t.id_tripulante}">
      <td><label class="marca"><input type="checkbox" class="embarca" ${t.ficou_a_bordo ? 'checked' : ''}> embarca</label></td>
      <td>${esc(t.nome)}</td>
      <td><select class="in posto" aria-label="Posto de ${esc(t.nome)}">${nv.postos.map((p) =>
        `<option value="${p.id_posto}" ${p.id_posto === (t.ultimo_posto ?? fisherman) ? 'selected' : ''}>${esc(p.designacao)}</option>`).join('')}
      </select></td>
      <td>${t.ficou_a_bordo && nv.ultima
        ? `<span class="pill">ficou a bordo da Viagem ${nv.ultima.num_viagem}</span>` : ''}</td>
    </tr>`).join('');

  mudarEscalaPartida();
}

// A escala escolhida preenche a ETD/ATD que já tiver
function mudarEscalaPartida() {
  const e = escalaPorId($('escalaPartida').value);
  $('etdNova').value = paraCampo(e?.etd);
  $('atdNova').value = paraCampo(e?.atd);
  avisarNova();
}

function embarcados() {
  return [...$('tripulacaoNova').querySelectorAll('tr[data-tripulante]')]
    .filter((linha) => linha.querySelector('.embarca').checked)
    .map((linha) => ({
      id_tripulante: Number(linha.dataset.tripulante),
      id_posto: Number(linha.querySelector('.posto').value),
    }));
}

function avisarNova() {
  const nv = dados.nova_viagem;
  const agora = agoraUtc();
  const e = escalaPorId($('escalaPartida').value);
  const etd = doCampo('etdNova');
  const atd = doCampo('atdNova');
  const tripulacao = embarcados();
  const postos = tripulacao.map((t) => postoPorId(t.id_posto)?.designacao);
  const comandantes = postos.filter((p) => p === 'Captain').length;

  const recusa = [];   // a BD vai recusar
  if (nv.ultima?.em_curso) recusa.push(`a Viagem ${nv.ultima.num_viagem} ainda está em curso: feche-a primeiro (RN34)`);
  if (!e) recusa.push('escolha a escala de partida');
  if (comandantes > 1) recusa.push(`há ${comandantes} comandantes (Captain): só pode haver um por viagem (RN10)`);
  if (atd && atd > agora) recusa.push(`a ATD (${dataPt(atd)}) é depois da hora atual (${dataPt(agora)} UTC) (RN32)`);
  if (e?.ata && atd && atd <= e.ata) recusa.push(`a ATD tem de ser depois da chegada a esta escala (${dataPt(e.ata)})`);
  if (e?.eta && etd && etd <= e.eta) recusa.push(`a ETD tem de ser depois da ETA desta escala (${dataPt(e.eta)})`);

  const atencao = [];  // a BD aceita, mas a viagem fica incompleta
  if (tripulacao.length === 0) atencao.push('ninguém embarca');
  else if (comandantes === 0) atencao.push('a viagem fica sem comandante (Captain)');
  if (tripulacao.length && !postos.some((p) => p === 'Factory Manager' || p === '2nd Factory Manager')) {
    atencao.push('sem Factory Manager nem 2nd: não vai ser possível abrir turnos na fábrica (RN28)');
  }
  const ficaram = nv.tripulantes.filter((t) => t.ficou_a_bordo
    && !tripulacao.some((x) => x.id_tripulante === t.id_tripulante));
  if (ficaram.length) {
    atencao.push(`${ficaram.map((t) => t.nome).join(', ')} ficou a bordo no fim da Viagem ${nv.ultima.num_viagem} `
      + 'mas não embarca (RN9)');
  }
  if (e && !e.ata) atencao.push('esta escala ainda não tem a chegada real (ATA) registada');
  if (e && !etd && !atd) atencao.push('sem hora de partida (ETD ou ATD): os lances não terão data mínima');

  const partes = [];
  if (recusa.length) partes.push(`<b>A base de dados vai recusar esta viagem:</b> ${esc(recusa.join('; '))}.`);
  if (atencao.length) partes.push(`<b>Atenção (a base de dados aceita):</b> ${esc(atencao.join('; '))}.`);
  $('avisoNova').innerHTML = partes.join('<br>');
  $('avisoNova').classList.toggle('visivel', partes.length > 0);
}

// ---------- histórico ----------

function desenharViagens() {
  $('viagens').innerHTML = dados.viagens.length
    ? dados.viagens.map((v) => `<tr>
        <td>Viagem ${v.num_viagem}</td>
        <td>${esc(v.porto_partida)} ${dataPt(v.partida)}</td>
        <td>${v.porto_chegada ? `${esc(v.porto_chegada)} ${dataPt(v.chegada)}` : '—'}</td>
        <td class="num">${kg(v.n_lances)}</td>
        <td class="num">${v.n_tripulantes}</td>
        <td>${v.porto_chegada ? '<span class="pill">concluída</span>' : '<span class="pill atencao">em curso</span>'}</td>
      </tr>`).join('')
    : '<tr><td colspan="6" class="vazio">Ainda não há viagens.</td></tr>';
}

// ---------- eventos ----------

$('escalas').addEventListener('click', (evento) => {
  const botao = evento.target.closest('[data-editar]');
  if (!botao) return;
  $('escala').value = botao.dataset.editar;
  mudarEscala();
  $('formEscala').scrollIntoView({ behavior: 'smooth' });
});
$('escala').addEventListener('change', mudarEscala);
$('limparEscala').addEventListener('click', () => {
  limparErro();
  $('escala').value = '';
  mudarEscala();
});
for (const campo of ['eta', 'etd', 'ata', 'atd']) {
  $(campo).addEventListener('input', avisarEscala);
  $(campo).addEventListener('change', avisarEscala);
}

$('formEscala').addEventListener('submit', async (evento) => {
  evento.preventDefault();
  limparErro();
  const idEscala = $('escala').value;
  const corpo = {
    cod_porto: $('porto').value,
    eta: $('eta').value,
    etd: $('etd').value,
    ata: $('ata').value,
    atd: $('atd').value,
    calado_m: $('calado').value,
    nivel_seguranca: $('nivel').value,
  };

  $('gravarEscala').disabled = true;
  try {
    const r = idEscala
      ? await api(`/api/viagens/escalas/${idEscala}`, { method: 'PATCH', body: JSON.stringify(corpo) })
      : await api('/api/viagens/escalas', { method: 'POST', body: JSON.stringify(corpo) });
    await carregar(r.id_escala);
    mostrarSucesso(idEscala
      ? `Escala atualizada: ${rotuloEscala(escalaPorId(r.id_escala))}.`
      : `Escala criada: ${rotuloEscala(escalaPorId(r.id_escala))}.`);
  } catch (erro) {
    const prefixo = [409, 422].includes(erro.estado) ? 'A base de dados recusou a escala — nada foi gravado. ' : '';
    mostrarErro(new Error(prefixo + erro.message));
  } finally {
    $('gravarEscala').disabled = false;
  }
});

$('escalaPartida').addEventListener('change', mudarEscalaPartida);
for (const campo of ['etdNova', 'atdNova']) {
  $(campo).addEventListener('input', avisarNova);
  $(campo).addEventListener('change', avisarNova);
}
$('tripulacaoNova').addEventListener('change', avisarNova);

$('formNova').addEventListener('submit', async (evento) => {
  evento.preventDefault();
  limparErro();
  const corpo = {
    id_escala_partida: $('escalaPartida').value,
    etd: $('etdNova').value,
    atd: $('atdNova').value,
    tripulacao: embarcados(),
  };

  $('gravarNova').disabled = true;
  try {
    const r = await api('/api/viagens', { method: 'POST', body: JSON.stringify(corpo) });
    const escala = escalaPorId(corpo.id_escala_partida);
    await carregar();
    await atualizarRodape('comandante');
    mostrarSucesso(`Viagem ${r.num_viagem} aberta: partida de ${escala ? `${escala.porto} (${escala.cod_porto})` : 'escala'}, `
      + `${r.tripulantes} ${r.tripulantes === 1 ? 'tripulante' : 'tripulantes'} a bordo.`);
  } catch (erro) {
    // A transação foi desfeita: nem as horas da escala, nem a viagem, nem a tripulação ficaram gravadas
    const prefixo = [409, 422].includes(erro.estado) ? 'A base de dados recusou a nova viagem — nada foi gravado. ' : '';
    mostrarErro(new Error(prefixo + erro.message));
  } finally {
    $('gravarNova').disabled = false;
  }
});

document.querySelectorAll('input[name="modo"]').forEach((r) => r.addEventListener('change', mudarModo));
$('escalaChegada').addEventListener('change', mudarModo);
$('ataChegada').addEventListener('input', avisarFecho);
$('ataChegada').addEventListener('change', avisarFecho);

$('formFechar').addEventListener('submit', async (evento) => {
  evento.preventDefault();
  limparErro();
  const v = dados?.viagem;
  if (!v) return;

  const desembarcam = [...document.querySelectorAll('.desembarca:checked')].map((c) => Number(c.value));
  const corpo = modo() === 'nova'
    ? {
      cod_porto: $('portoChegada').value,
      ata: $('ataChegada').value,
      calado_m: $('caladoChegada').value,
      nivel_seguranca: $('nivelChegada').value,
      desembarcam,
    }
    : { id_escala: $('escalaChegada').value, ata: $('ataChegada').value, desembarcam };

  $('gravarFechar').disabled = true;
  try {
    const r = await api(`/api/viagens/${v.id_viagem}/fechar`, { method: 'POST', body: JSON.stringify(corpo) });
    const ficam = dados.tripulacao.length - r.desembarcaram;
    await carregar();
    await atualizarRodape('comandante');
    const escala = escalaPorId(r.id_escala);
    mostrarSucesso(`Viagem ${r.viagem} fechada em ${escala ? rotuloEscala(escala) : 'escala'}: `
      + `${r.desembarcaram} ${r.desembarcaram === 1 ? 'tripulante desembarcou' : 'tripulantes desembarcaram'}, `
      + `${ficam} ${ficam === 1 ? 'fica' : 'ficam'} a bordo.`);
  } catch (erro) {
    // A transação foi desfeita: nem a escala nova, nem a ATA, nem os desembarques ficaram gravados
    const prefixo = [409, 422].includes(erro.estado) ? 'A base de dados recusou o fecho — nada foi gravado. ' : '';
    mostrarErro(new Error(prefixo + erro.message));
  } finally {
    $('gravarFechar').disabled = false;
  }
});

// ---------- arranque ----------
// (no fim: assim todas as funções e constantes acima já existem)

try {
  await carregar();
} catch (erro) {
  mostrarErro(erro);
}