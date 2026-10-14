// UI01 — Registar lance e capturas (FR05)
//
// Regras em duas camadas (relatório 2.2):
//  - o ecrã mostra a quota restante e avisa antes de gravar;
//  - a BD decide: o trigger trg_captura_quota recusa capturas sem quota
//    ou acima da quota, e o lance inteiro é desfeito.
// O aviso não bloqueia o botão, para se poder ver a própria BD a recusar.

import { montarLayout, api, mostrarErro, mostrarSucesso, limparErro, esc, kg, dataPt } from './comum.js';

await montarLayout({ ativo: 'lances', papel: 'pesca' });

const $ = (id) => document.getElementById(id);
const form = $('formulario');

let dados = null;        // viagem em curso, zonas, espécies
let quotas = new Map();  // cod_fao -> { quota_kg, restante_kg } da zona/ano escolhidos

try {
  await carregarFormulario();
  await carregarLances();
} catch (erro) {
  mostrarErro(erro);
  $('gravar').disabled = true;
}

async function carregarFormulario() {
  dados = await api('/api/lances/formulario');
  const v = dados.viagem;

  if (!v) {
    $('gravar').disabled = true;
    throw new Error('Não há nenhuma viagem em curso: não é possível registar lances.');
  }

  $('subtitulo').textContent = `Viagem ${v.num_viagem} · ${v.navio} · mestre de pesca`;
  $('viagem').value = `Viagem ${v.num_viagem} (partida ${v.porto_partida} ${dataPt(v.partida)})`;
  $('numero').value = `${dados.proximo_lance} (automático)`;
  $('tituloLista').textContent = `Lances da Viagem ${v.num_viagem}`;
  // Sem hora de partida registada na escala (nem ATD nem ETD): sem mínimo
  $('inicio').min = (v.partida ?? '').replace(' ', 'T');
  $('fim').min = (v.partida ?? '').replace(' ', 'T');

  if (!$('zona').options.length) {
    $('zona').innerHTML = '<option value="">Escolha a zona…</option>' + dados.zonas
      .map((z) => `<option value="${z.id_zona}">${esc(z.codigo_ices)} — ${esc(z.jurisdicao)}</option>`)
      .join('');
  }

  if (!$('capturas').rows.length) {
    $('capturas').innerHTML = dados.especies.map((e) => `
      <tr data-especie="${esc(e.cod_fao)}">
        <td>${esc(e.cod_fao)} — ${esc(e.nome_comum)}</td>
        <td class="num"><input class="in peso" type="number" min="0" step="0.01" placeholder="0"
              aria-label="Peso vivo de ${esc(e.nome_comum)} (kg)"></td>
        <td class="num restante">—</td>
        <td class="num depois">—</td>
        <td class="estado"></td>
      </tr>`).join('');
  }
}

// Ano da quota = ano do início do lance (ou da partida, se ainda vazio)
function anoDoLance() {
  const texto = $('inicio').value || dados?.viagem?.partida || '';
  return Number(texto.slice(0, 4)) || null;
}

async function carregarQuotas() {
  quotas = new Map();
  const zona = $('zona').value;
  const ano = anoDoLance();
  if (zona && ano) {
    const linhas = await api(`/api/lances/quotas?zona=${zona}&ano=${ano}`);
    for (const q of linhas) quotas.set(q.cod_fao, q);
  }
  atualizarCapturas();
}

// Recalcula as colunas "quota restante" e "depois de gravar" e o aviso
function atualizarCapturas() {
  const zona = $('zona').selectedOptions[0];
  const zonaTexto = zona?.value ? zona.textContent : null;
  const ano = anoDoLance();
  const avisos = [];

  for (const linha of $('capturas').rows) {
    const especie = linha.dataset.especie;
    const peso = Number(linha.querySelector('.peso').value) || 0;
    const quota = quotas.get(especie);
    const celula = (classe) => linha.querySelector(`.${classe}`);

    if (!zonaTexto) {
      celula('restante').textContent = '—';
      celula('depois').textContent = '—';
      celula('estado').innerHTML = '';
      continue;
    }

    if (!quota) {
      celula('restante').textContent = '—';
      celula('depois').textContent = '—';
      celula('estado').innerHTML = peso > 0 ? '<span class="pill sem">sem quota</span>' : '';
      if (peso > 0) {
        avisos.push(`não existe quota de ${especie} para a zona ${zonaTexto} em ${ano} (RN19)`);
      }
      continue;
    }

    const depois = quota.restante_kg - peso;
    celula('restante').textContent = `${kg(quota.restante_kg)} kg`;
    celula('depois').textContent = peso > 0 ? `${kg(depois)} kg` : '—';
    if (peso <= 0) {
      celula('estado').innerHTML = '';
    } else if (depois < 0) {
      celula('estado').innerHTML = '<span class="pill critico">excede</span>';
      avisos.push(`o peso de ${especie} (${kg(peso)} kg) excede a quota restante (${kg(quota.restante_kg)} kg) (RN19)`);
    } else {
      celula('estado').innerHTML = '<span class="pill">OK</span>';
    }
  }

  // Início ou fim depois da hora atual: o trg_lance_datas recusa (RN31). Os campos
  // estão em UTC, por isso compara-se com a hora UTC do browser.
  const agora = new Date().toISOString().slice(0, 16);
  for (const [campo, nome] of [['inicio', 'o início'], ['fim', 'o fim']]) {
    const valor = $(campo).value;
    if (valor && valor > agora) {
      avisos.push(`${nome} do lance (${dataPt(valor.replace('T', ' '))}) é depois da hora atual (${dataPt(agora.replace('T', ' '))} UTC) (RN31)`);
    }
  }

  const aviso = $('aviso');
  if (avisos.length) {
    aviso.innerHTML = `<b>A base de dados vai recusar este lance:</b> ${esc(avisos.join('; '))}. `
      + 'Corrija antes de gravar.';
    aviso.classList.add('visivel');
  } else {
    aviso.classList.remove('visivel');
  }
}

async function carregarLances() {
  const lances = await api('/api/lances');
  const corpo = $('lances');
  if (lances.length === 0) {
    corpo.innerHTML = '<tr><td colspan="6" class="vazio">Ainda não há lances nesta viagem.</td></tr>';
    return;
  }
  corpo.innerHTML = lances.map((l) => {
    const capturas = (l.capturas ?? [])
      .filter((c) => c.cod_fao)
      .map((c) => `${esc(c.cod_fao)} ${kg(c.peso_vivo_kg)} kg`)
      .join(' · ');
    return `<tr>
      <td class="num">${l.num_lance}</td>
      <td>${dataPt(l.inicio)}</td>
      <td>${dataPt(l.fim)}</td>
      <td>${esc(l.codigo_ices)} ${esc(l.jurisdicao)}</td>
      <td>${capturas || '—'}</td>
      <td class="num">${kg(l.total_kg)}</td>
    </tr>`;
  }).join('');
}

// ---------- eventos ----------

$('zona').addEventListener('change', () => carregarQuotas().catch(mostrarErro));
$('inicio').addEventListener('change', () => carregarQuotas().catch(mostrarErro));
$('fim').addEventListener('change', atualizarCapturas);
$('capturas').addEventListener('input', atualizarCapturas);

form.addEventListener('reset', () => {
  limparErro();
  setTimeout(atualizarCapturas);   // depois de o browser limpar os campos
});

form.addEventListener('submit', async (evento) => {
  evento.preventDefault();
  limparErro();

  // Validação do formulário (campos obrigatórios e formatos)
  const capturas = [...$('capturas').rows]
    .map((linha) => ({ cod_fao: linha.dataset.especie, peso_vivo_kg: linha.querySelector('.peso').value }))
    .filter((c) => c.peso_vivo_kg !== '' && Number(c.peso_vivo_kg) !== 0);

  if (!form.checkValidity()) {
    form.reportValidity();
    return;
  }
  if (capturas.length === 0) {
    mostrarErro(new Error('Indique o peso vivo de pelo menos uma espécie.'));
    return;
  }

  const corpo = {
    id_zona_pesca: $('zona').value,
    inicio: $('inicio').value,
    fim: $('fim').value,
    latitude: $('latitude').value,
    longitude: $('longitude').value,
    profundidade_m: $('profundidade').value,
    capturas,
  };

  $('gravar').disabled = true;
  try {
    const r = await api('/api/lances', { method: 'POST', body: JSON.stringify(corpo) });
    form.reset();
    mostrarSucesso(`Lance n.º ${r.num_lance} da Viagem ${r.viagem} gravado com ${r.capturas} `
      + `${r.capturas === 1 ? 'captura' : 'capturas'}.`);
    await carregarFormulario();
    await carregarQuotas();
    await carregarLances();
  } catch (erro) {
    // 422 = regra de negócio recusada pela BD (mensagem do trigger)
    const prefixo = erro.estado === 422 ? 'A base de dados recusou o lance — nada foi gravado. ' : '';
    mostrarErro(new Error(prefixo + erro.message));
  } finally {
    $('gravar').disabled = false;
  }
});
