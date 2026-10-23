const $ = (sel) => document.querySelector(sel);
const $$ = (sel) => document.querySelectorAll(sel);

let currentCharId = null;
let selectedSex = 'male';
let appearance = null;

function showScreen(name) {
  document.querySelectorAll('.screen').forEach(s => s.classList.add('hidden'));
  const el = document.getElementById(name);
  if (el) el.classList.remove('hidden');
}

function post(name, data) {
  fetch(`https://${GetParentResourceName()}/${name}`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(data || {})
  }).then(r => r.json()).catch(() => {});
}

// ---------- LOBBY ----------
function renderSlots(chars, maxSlots) {
  const container = $('#slots');
  container.innerHTML = '';
  const list = chars || [];
  // map by slot index
  for (let i = 0; i < maxSlots; i++) {
    const ch = list[i];
    const div = document.createElement('div');
    div.className = 'slot' + (ch ? '' : ' empty');
    if (ch) {
      div.innerHTML = `<div><div class="slot-name">${ch.firstname} ${ch.lastname}</div><div class="slot-sub">${ch.job || 'Desempregado'} • $${ch.bank || 0}</div></div><div class="slot-sub">#${ch.id}</div>`;
      div.addEventListener('mouseenter', () => post('previewCharacter', { id: ch.id }));
      div.addEventListener('click', () => {
        currentCharId = ch.id;
        post('previewCharacter', { id: ch.id });
      });
    } else {
      div.innerHTML = `<div><div class="slot-name">SLOT ${i+1}</div><div class="slot-sub">Vazio - criar personagem</div></div>`;
      div.addEventListener('click', () => post('createNew', {}));
    }
    container.appendChild(div);
  }
}

function renderCharInfo(c) {
  const el = $('#charInfo');
  if (!c) {
    el.classList.add('empty');
    el.innerHTML = '<p>Passe o mouse ou clique em um slot para visualizar.</p>';
    $('#btnEnter').disabled = true;
    return;
  }
  el.classList.remove('empty');
  const pos = c.position ? `${(c.position.x||0).toFixed(1)}, ${(c.position.y||0).toFixed(1)}` : 'Desconhecida';
  el.innerHTML = `
    <div class="ci-row"><span class="k">Nome</span><span class="v">${c.firstname} ${c.lastname}</span></div>
    <div class="ci-row"><span class="k">Idade</span><span class="v">${c.age}</span></div>
    <div class="ci-row"><span class="k">Emprego</span><span class="v">${c.job || 'Desempregado'}</span></div>
    <div class="ci-row"><span class="k">Banco</span><span class="v">$${c.bank || 0}</span></div>
    <div class="ci-row"><span class="k">Dinheiro</span><span class="v">$${c.money || 0}</span></div>
    <div class="ci-row"><span class="k">Ultima Localizacao</span><span class="v">${pos}</span></div>
  `;
  $('#btnEnter').disabled = false;
  currentCharId = c.id;
}

// ---------- STEPPERS ----------
function makeStepper(part, delta) {
  const wrap = document.querySelector(`.stepper[data-part="${part}"]`);
  if (!wrap) return;
  const d = delta || (wrap.getAttribute('data-delta') ? parseFloat(wrap.getAttribute('data-delta')) : 1);
  wrap.setAttribute('data-delta', d);
  wrap.innerHTML = '';
  const minus = document.createElement('button'); minus.textContent = '-';
  const val = document.createElement('span'); val.className = 'val'; val.textContent = '0';
  const plus = document.createElement('button'); plus.textContent = '+';
  minus.addEventListener('click', () => post('appearanceChange', { part, delta: -d }));
  plus.addEventListener('click', () => post('appearanceChange', { part, delta: d }));
  wrap.appendChild(minus); wrap.appendChild(val); wrap.appendChild(plus);
}

function initSteppers() {
  document.querySelectorAll('.stepper').forEach(el => {
    const part = el.getAttribute('data-part');
    const dd = el.getAttribute('data-delta');
    const d = dd ? parseFloat(dd) : 1;
    makeStepper(part, d);
  });
}

// face features
function renderFaceFeatures() {
  const container = $('#faceFeatures');
  container.innerHTML = '';
  for (let i = 0; i < 20; i++) {
    const row = document.createElement('div');
    row.className = 'ff-row';
    row.innerHTML = `<label>Feature ${i+1}</label>`;
    const st = document.createElement('div');
    st.className = 'stepper';
    st.setAttribute('data-part', `ff_${i}`);
    st.setAttribute('data-delta', '0.1');
    row.appendChild(st);
    container.appendChild(row);
    makeStepper(`ff_${i}`, 0.1);
  }
}

function updateAppearanceState(app) {
  appearance = app;
  // update sex buttons
  const sex = app.sex || 'male';
  $$('.sex-btn').forEach(b => {
    if (b.dataset.sex) {
      b.classList.toggle('active', b.dataset.sex === sex);
    }
  });
  // update stepper values display (best effort)
  // headBlend
  setVal('hb_shapeFirst', app.headBlend.shapeFirst);
  setVal('hb_shapeSecond', app.headBlend.shapeSecond);
  setVal('hb_skinFirst', app.headBlend.skinFirst);
  setVal('hb_skinSecond', app.headBlend.skinSecond);
  setVal('hb_shapeMix', app.headBlend.shapeMix.toFixed(2));
  setVal('hb_skinMix', app.headBlend.skinMix.toFixed(2));
  setVal('hair_style', app.hair.style);
  setVal('hair_color', app.hair.color);
  setVal('hair_highlight', app.hair.highlight);
  setVal('eb_style', app.eyebrows.style);
  setVal('eb_color', app.eyebrows.color);
  setVal('eb_opacity', app.eyebrows.opacity.toFixed(2));
  setVal('beard_style', app.beard.style);
  setVal('beard_color', app.beard.color);
  setVal('beard_opacity', app.beard.opacity.toFixed(2));
  // components
  for (const k in app.components) {
    setVal(`comp_${k}`, app.components[k].drawable);
    setVal(`comp_${k}_tex`, app.components[k].texture);
  }
  for (const k in app.props) {
    setVal(`prop_${k}`, app.props[k].drawable);
  }
  // face features
  for (let i = 0; i < 20; i++) {
    const v = app.faceFeatures && app.faceFeatures[i];
    setVal(`ff_${i}`, (v !== undefined ? (typeof v === 'number' ? v.toFixed(2) : v) : 0));
  }
}

function setVal(part, value) {
  const wrap = document.querySelector(`.stepper[data-part="${part}"]`);
  if (!wrap) return;
  const v = wrap.querySelector('.val');
  if (v) v.textContent = value;
}

// ---------- EVENTS FROM LUA ----------
window.addEventListener('message', (e) => {
  const d = e.data;
  if (!d || !d.action) return;
  switch (d.action) {
    case 'openLobby':
      renderSlots(d.data.characters, d.data.maxSlots);
      showScreen('lobby');
      break;
    case 'characterInfo':
      renderCharInfo(d.data);
      break;
    case 'openRegister':
      showScreen('register');
      break;
    case 'registerError':
      const err = $('#regError');
      err.textContent = d.data;
      err.classList.remove('hidden');
      break;
    case 'openAppearance':
      appearance = d.data.appearance;
      showScreen('appearance');
      initSteppers();
      renderFaceFeatures();
      // re-init steppers after dynamic
      initSteppers();
      updateAppearanceState(appearance);
      break;
    case 'appearanceState':
      updateAppearanceState(d.data);
      break;
    case 'close':
      document.querySelectorAll('.screen').forEach(s => s.classList.add('hidden'));
      break;
  }
});

// ---------- REGISTER ----------
let selectedSexReg = 'male';
$$('.sex-btn').forEach(btn => {
  btn.addEventListener('click', () => {
    if (!btn.dataset.sex) return;
    selectedSexReg = btn.dataset.sex;
    $$('.sex-btn').forEach(b => {
      if (b.dataset.sex) b.classList.toggle('active', b.dataset.sex === selectedSexReg);
    });
  });
});

$('#btnRegSubmit').addEventListener('click', () => {
  const fn = $('#firstName').value.trim();
  const ln = $('#lastName').value.trim();
  const age = parseInt($('#age').value);
  post('submitRegister', { firstname: fn, lastname: ln, age: age, sex: selectedSexReg });
});

$('#btnRegBack').addEventListener('click', () => {
  post('createNew', {}); // noop-ish; just reopen lobby? We'll send close? 
  // Actually go back to lobby screen locally
  showScreen('lobby');
});

// ---------- LOBBY BUTTONS ----------
$('#btnCreate').addEventListener('click', () => post('createNew', {}));
$('#btnEnter').addEventListener('click', () => {
  if (currentCharId) post('enterWorld', { id: currentCharId });
});

// ---------- APPEARANCE BUTTONS ----------
document.addEventListener('click', (e) => {
  const f = e.target.getAttribute && e.target.getAttribute('data-focus');
  if (f) post('appearanceFocus', { focus: f });
});
$('#btnRotL').addEventListener('click', () => post('appearanceRotate', { delta: -15 }));
$('#btnRotR').addEventListener('click', () => post('appearanceRotate', { delta: 15 }));

// sex toggle in appearance
document.addEventListener('click', (e) => {
  const btn = e.target.closest('.sex-btn');
  if (!btn || !btn.dataset.sex) return;
  // only appearance sex buttons have ids sexMale/sexFemale or are inside appearance
  if (btn.id === 'sexMale' || btn.id === 'sexFemale') {
    post('appearanceModel', { sex: btn.dataset.sex });
  }
});

$('#btnAppSave').addEventListener('click', () => post('appearanceSave', {}));

// ESC close not needed

// initial
showScreen('lobby');