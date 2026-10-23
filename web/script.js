const $ = (s) => document.querySelector(s);
const $$ = (s) => document.querySelectorAll(s);

let currentCharId = null;
let selectedSex = 'M';
let identityData = null;
let skin = null;
let currentView = 'face';

function post(name, data) {
  fetch(`https://${GetParentResourceName()}/${name}`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(data || {})
  }).then(r => r.json()).catch(() => {});
}

function show(id) { const el = $(id); if (el) el.classList.remove('hidden'); }
function hide(id) { const el = $(id); if (el) el.classList.add('hidden'); }

function toast(msg, type = 'success') {
  const c = $('#toast-container');
  const t = document.createElement('div');
  t.className = 'toast ' + type;
  t.textContent = msg;
  c.appendChild(t);
  setTimeout(() => t.remove(), 3000);
}

function loading(showFlag, text) {
  const el = $('#loading-overlay');
  if (showFlag) { if (text) $('#loading-text').textContent = text; show('#loading-overlay'); }
  else hide('#loading-overlay');
}

function clamp(v, min, max) { return Math.max(min, Math.min(max, v)); }

// ---------- APP SHOW/HIDE ----------
window.addEventListener('message', (e) => {
  const d = e.data;
  if (!d) return;
  loading(false);
  if (d.action === 'show') {
    $('#app').classList.remove('hidden');
    if (d.data && d.data.type === 'selection') {
      renderSelection(d.data.characters || [], d.data.maxSlots || 3);
      show('#selection-screen');
      hide('#creation-screen');
      hide('#customization-screen');
      hide('#clothing-screen');
    } else if (d.data && d.data.type === 'creation') {
      hide('#selection-screen');
      if (d.data.step === 'identity') { show('#creation-screen'); hide('#customization-screen'); hide('#clothing-screen'); }
      else if (d.data.step === 'customization') { show('#customization-screen'); hide('#creation-screen'); }
      else if (d.data.step === 'clothing') { show('#clothing-screen'); }
    }
  } else if (d.action === 'hide') {
    $('#app').classList.add('hidden');
  } else if (d.action === 'creationError') {
    $('#identity-validation').textContent = d.message || '';
  } else if (d.action === 'deletionResponse') {
    if (d.success) { toast('Personagem excluído'); post('selectCharacter' in {} ? 'x' : 'x', {}); }
  }
});

// ---------- SELECTION ----------
function renderSelection(chars, maxSlots) {
  const grid = $('#characters-grid');
  grid.innerHTML = '';
  let available = 0;
  for (let i = 0; i < maxSlots; i++) {
    const ch = chars[i];
    const card = document.createElement('div');
    if (ch) {
      card.className = 'char-card';
      card.innerHTML = `<div class="card-name">${ch.fullname || (ch.firstname+' '+ch.lastname)}</div><div class="card-sub">${ch.job || 'Desempregado'} • $${ch.bank || 0}</div><div class="card-sub">${ch.last_location || 'Desconhecido'}</div>`;
      card.addEventListener('click', () => {
        $$('.char-card').forEach(c => c.classList.remove('selected'));
        card.classList.add('selected');
        currentCharId = ch.id;
        showDetails(ch);
      });
    } else {
      card.className = 'char-card empty';
      card.innerHTML = `<div class="card-name">SLOT ${i+1}</div><div class="card-sub">Vazio</div>`;
      available++;
    }
    grid.appendChild(card);
  }
  $('#available-slots').textContent = available;
}

function showDetails(ch) {
  hide('#details-placeholder');
  show('#details-content');
  $('#detail-name').textContent = ch.fullname || (ch.firstname+' '+ch.lastname);
  $('#detail-slot').textContent = 'Slot ' + (ch.slot || '');
  $('#detail-age').textContent = ch.age || '--';
  $('#detail-bank').textContent = '$' + (ch.bank || 0);
  $('#detail-job').textContent = ch.job || 'Desempregado';
  $('#detail-location').textContent = ch.last_location || 'Desconhecido';
  $('#btn-enter-city').onclick = () => { if (currentCharId) post('selectCharacter', { charId: currentCharId }); };
  $('#btn-delete-char').onclick = () => {
    $('#delete-char-name').textContent = ch.fullname || (ch.firstname+' '+ch.lastname);
    show('#delete-modal');
    $('#btn-confirm-delete').onclick = () => { post('deleteCharacter', { charId: currentCharId }); hide('#delete-modal'); };
  };
}

$('#btn-cancel-delete').addEventListener('click', () => hide('#delete-modal'));

$('#btn-create-new').addEventListener('click', () => {
  post('createNewCharacter', { sex: selectedSex });
});

// ---------- IDENTITY ----------
$('#firstname').addEventListener('input', () => { $('#firstname-count').textContent = $('#firstname').value.length; });
$('#lastname').addEventListener('input', () => { $('#lastname-count').textContent = $('#lastname').value.length; });

$$('.sex-option').forEach(btn => {
  btn.addEventListener('click', () => {
    $$('.sex-option').forEach(b => b.classList.remove('active'));
    btn.classList.add('active');
    selectedSex = btn.getAttribute('data-sex');
  });
});

$('#btn-back-selection').addEventListener('click', () => { post('closeUI', {}); });

$('#btn-next-appearance').addEventListener('click', () => {
  const data = {
    firstname: $('#firstname').value.trim(),
    lastname: $('#lastname').value.trim(),
    age: parseInt($('#age').value),
    sex: selectedSex
  };
  post('submitIdentity', data);
});

// ---------- CUSTOMIZATION ----------
function setView(mode) {
  currentView = mode;
  $$('.camera-btn').forEach(b => b.classList.toggle('active', b.getAttribute('data-view') === mode));
  post('changeViewMode', { mode: mode === 'rotate' ? 'body' : mode });
  if (mode === 'rotate') {
    // trigger rotation animation via repeated rotate
    let steps = 0;
    const iv = setInterval(() => {
      post('rotatePed', { direction: 'right' });
      steps++;
      if (steps >= 24) clearInterval(iv);
    }, 60);
  }
}
$$('.camera-btn').forEach(btn => {
  btn.addEventListener('click', () => setView(btn.getAttribute('data-view')));
});

// tabs
function switchTab(containerId, tabName) {
  const container = $(containerId);
  // highlight
  const tabs = container.parentElement.querySelectorAll('.tab-btn');
  tabs.forEach(t => t.classList.toggle('active', t.getAttribute('data-tab') === tabName));
}

$$('.tab-btn').forEach(btn => {
  btn.addEventListener('click', () => {
    const tab = btn.getAttribute('data-tab');
    const parent = btn.closest('.customization-container') || btn.closest('.creation-container');
    if (parent) {
      parent.querySelectorAll('.tab-btn').forEach(t => t.classList.toggle('active', t === btn));
    }
    renderTabContent(tab);
  });
});

function initSkin() {
  const model = selectedSex === 'F' ? 'mp_f_freemode_01' : 'mp_m_freemode_01';
  skin = {
    model: model,
    face: { mom: 21, dad: 23, shapeMix: 0.5, skinMix: 0.5, eyes: 0 },
    hair: { style: 0, color: 0, highlight: 0 },
    facialHair: { style: 0, opacity: 0.0, color: 0 },
    eyebrows: { style: 0, opacity: 1.0, color: 0 },
    makeup: { blush: 0, lipstick: 0, eyeshadow: 0 },
    clothes: {},
    props: {}
  };
}

function sendSkin() {
  post('updateSkin', { skin: JSON.stringify(skin) });
}

function makeAdjuster(container, label, get, set, min, max, step) {
  const row = document.createElement('div');
  row.className = 'adjuster';
  const valSpan = document.createElement('span');
  valSpan.className = 'val';
  valSpan.textContent = get();
  row.innerHTML = `<span>${label}</span>`;
  const minus = document.createElement('button'); minus.textContent = '-';
  const plus = document.createElement('button'); plus.textContent = '+';
  minus.onclick = () => { set(clamp(get() - step, min, max)); valSpan.textContent = get(); sendSkin(); };
  plus.onclick = () => { set(clamp(get() + step, min, max)); valSpan.textContent = get(); sendSkin(); };
  row.appendChild(minus); row.appendChild(valSpan); row.appendChild(plus);
  container.appendChild(row);
}

function renderTabContent(tab) {
  let container = null;
  if ($('#customization-content')) container = $('#customization-content');
  if (!container) return;
  container.innerHTML = '';
  if (!skin) initSkin();

  if (tab === 'face') {
    makeAdjuster(container, 'Mãe (forma)', () => skin.face.mom, v => skin.face.mom = v, 0, 45, 1);
    makeAdjuster(container, 'Pai (forma)', () => skin.face.dad, v => skin.face.dad = v, 0, 45, 1);
    makeAdjuster(container, 'Mistura forma', () => skin.face.shapeMix, v => skin.face.shapeMix = v, 0, 1, 0.05);
    makeAdjuster(container, 'Mistura pele', () => skin.face.skinMix, v => skin.face.skinMix = v, 0, 1, 0.05);
    makeAdjuster(container, 'Olhos', () => skin.face.eyes, v => skin.face.eyes = v, 0, 30, 1);
  } else if (tab === 'hair') {
    makeAdjuster(container, 'Estilo', () => skin.hair.style, v => skin.hair.style = v, 0, 70, 1);
    makeAdjuster(container, 'Cor', () => skin.hair.color, v => skin.hair.color = v, 0, 63, 1);
    makeAdjuster(container, 'Destaque', () => skin.hair.highlight, v => skin.hair.highlight = v, 0, 63, 1);
  } else if (tab === 'facialhair') {
    makeAdjuster(container, 'Estilo', () => skin.facialHair.style, v => skin.facialHair.style = v, 0, 28, 1);
    makeAdjuster(container, 'Opacidade', () => skin.facialHair.opacity, v => skin.facialHair.opacity = v, 0, 1, 0.1);
    makeAdjuster(container, 'Cor', () => skin.facialHair.color, v => skin.facialHair.color = v, 0, 63, 1);
  } else if (tab === 'eyebrows') {
    makeAdjuster(container, 'Estilo', () => skin.eyebrows.style, v => skin.eyebrows.style = v, 0, 33, 1);
    makeAdjuster(container, 'Opacidade', () => skin.eyebrows.opacity, v => skin.eyebrows.opacity = v, 0, 1, 0.1);
    makeAdjuster(container, 'Cor', () => skin.eyebrows.color, v => skin.eyebrows.color = v, 0, 63, 1);
  } else if (tab === 'makeup') {
    makeAdjuster(container, 'Blush', () => skin.makeup.blush, v => skin.makeup.blush = v, 0, 10, 1);
    makeAdjuster(container, 'Batom', () => skin.makeup.lipstick, v => skin.makeup.lipstick = v, 0, 10, 1);
    makeAdjuster(container, 'Sombra', () => skin.makeup.eyeshadow, v => skin.makeup.eyeshadow = v, 0, 10, 1);
  }
}

function renderClothingTab(tab) {
  const container = $('#clothing-content');
  if (!container) return;
  container.innerHTML = '';
  if (!skin) initSkin();
  if (!skin.clothes) skin.clothes = {};

  const nameMap = { tops: 'tops', pants: 'legs', shoes: 'shoes', accessories: 'accessories' };
  const cname = nameMap[tab] || 'tops';

  makeAdjuster(container, 'Estilo', () => (skin.clothes[cname] || {}).drawable || 0,
    v => { skin.clothes[cname] = skin.clothes[cname] || {}; skin.clothes[cname].drawable = v; }, 0, 200, 1);
  makeAdjuster(container, 'Textura', () => (skin.clothes[cname] || {}).texture || 0,
    v => { skin.clothes[cname] = skin.clothes[cname] || {}; skin.clothes[cname].texture = v; }, 0, 20, 1);
}

// tab click handling for both customization and clothing
document.addEventListener('click', (e) => {
  const btn = e.target.closest('.tab-btn');
  if (!btn) return;
  const tab = btn.getAttribute('data-tab');
  const isClothing = btn.closest('#clothing-tabs');
  if (isClothing) {
    renderClothingTab(tab);
  } else {
    renderTabContent(tab);
  }
});

// ---------- BUTTONS ----------
$('#btn-back-identity').addEventListener('click', () => { post('closeUI', {}); });
$('#btn-next-clothes').addEventListener('click', () => {
  // switch to clothing screen visually
  hide('#customization-screen');
  show('#clothing-screen');
});
$('#btn-back-appearance').addEventListener('click', () => {
  hide('#clothing-screen');
  show('#customization-screen');
});
document.addEventListener('click', (e) => {
  if (!e.target.closest('#btn-finish-creation')) return;
  if (!identityData) {
    identityData = {
      firstname: ($('#firstname') ? $('#firstname').value.trim() : ''),
      lastname: ($('#lastname') ? $('#lastname').value.trim() : ''),
      age: parseInt(($('#age') ? $('#age').value : '18')),
      sex: selectedSex
    };
  }
  if (!skin) initSkin();
  loading(true, 'Criando personagem...');
  post('finishCreation', { skin: JSON.stringify(skin), identity: identityData });
});
// direct listener removed to avoid duplicate; delegated handler above covers it

// capture identity data when next clicked
$('#btn-next-appearance').addEventListener('click', () => {
  identityData = {
    firstname: $('#firstname').value.trim(),
    lastname: $('#lastname').value.trim(),
    age: parseInt($('#age').value),
    sex: selectedSex
  };
  initSkin();
  skin.model = selectedSex === 'F' ? 'mp_f_freemode_01' : 'mp_m_freemode_01';
  renderTabContent('face');
});

// camera controls in customization
document.addEventListener('click', (e) => {
  const btn = e.target.closest('.camera-btn');
  if (!btn) return;
  const view = btn.getAttribute('data-view');
  setView(view);
});

// delete modal
$('#btn-cancel-delete').addEventListener('click', () => hide('#delete-modal'));

// initial render
renderTabContent('face');