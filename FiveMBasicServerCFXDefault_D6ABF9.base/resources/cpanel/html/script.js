// cpanel | NUI
const RES = (typeof GetParentResourceName === 'function') ? GetParentResourceName() : 'cpanel';

const post = (name, data = {}) =>
  fetch(`https://${RES}/${name}`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json; charset=UTF-8' },
    body: JSON.stringify(data),
  }).then((r) => r.json()).catch((err) => {
    console.error(`[cpanel] callback "${name}" falhou:`, err);
    return { ok: false };
  });

// Envia uma acao para o servidor (via client)
const exec = (action, data = {}) => post('execute', { action, data });

// ---------- Estado ----------
let players = [];
let myCoords = null;
let myId = null;
let selectedId = null;
let status = { god: false, noclip: false, invis: false };

const $ = (sel) => document.querySelector(sel);
const $$ = (sel) => document.querySelectorAll(sel);

// ---------- Paginas ----------
const TITLES = {
  dashboard: 'Dashboard',
  jogadores: 'Jogadores',
  gerador: 'Garagem & Armas',
  comandos: 'Comandos',
};

$$('.nav-item').forEach((btn) => {
  btn.addEventListener('click', () => {
    $$('.nav-item').forEach((b) => b.classList.remove('active'));
    $$('.page').forEach((p) => p.classList.remove('active'));
    btn.classList.add('active');
    const page = btn.dataset.page;
    $(`#page-${page}`).classList.add('active');
    $('#page-title').textContent = TITLES[page];
    if (page === 'jogadores') refreshPlayers();
  });
});

// ---------- Fechar ----------
let isOpen = false;

const close = () => {
  if (!isOpen) return; // evita fechar duas vezes (keydown + keyup)
  isOpen = false;
  $('#backdrop').classList.add('hidden');
  post('close');
};
$('#close-btn').addEventListener('click', close);

// ESC em keydown (reacao imediata) e em keyup (garantia caso o keydown
// seja consumido pelo jogo/pause menu antes de chegar aqui).
const onEsc = (e) => {
  if (e.key !== 'Escape' && e.keyCode !== 27) return;
  e.preventDefault();
  e.stopPropagation();
  close();
};
window.addEventListener('keydown', onEsc);
window.addEventListener('keyup', onEsc);

// ---------- Toasts ----------
function toast(message, type = 'info') {
  const el = document.createElement('div');
  el.className = `toast ${type}`;
  el.textContent = message;
  $('#toasts').appendChild(el);
  setTimeout(() => {
    el.style.opacity = '0';
    el.style.transition = 'opacity .3s';
    setTimeout(() => el.remove(), 320);
  }, 4200);
}

// ---------- Mensagens do client ----------
window.addEventListener('message', (e) => {
  const d = e.data || {};
  switch (d.action) {
    case 'open':
      myId = d.myId;
      status = d.status || status;
      $('#my-id').textContent = `ID ${myId}`;
      $('#stat-id').textContent = myId;
      isOpen = true;
      $('#backdrop').classList.remove('hidden');
      renderStatus();
      refreshPlayers();
      break;
    case 'hide':
      isOpen = false;
      $('#backdrop').classList.add('hidden');
      break;
    case 'players':
      players = d.list || [];
      myCoords = d.my || null;
      renderPlayers();
      break;
    case 'status':
      status = { god: !!d.god, noclip: !!d.noclip, invis: !!d.invis };
      renderStatus();
      break;
    case 'notify':
      toast(d.message, d.ntype);
      break;
  }
});

// ---------- Status ----------
function renderStatus() {
  const set = (id, on) => {
    const el = $(id);
    el.textContent = on ? 'ON' : 'OFF';
    el.classList.toggle('on', on);
    el.classList.toggle('off', !on);
  };
  set('#stat-god', status.god);
  set('#stat-noclip', status.noclip);

  const chip = (id, label, on) => {
    const el = $(id);
    el.textContent = `${label}: ${on ? 'on' : 'off'}`;
    el.classList.toggle('on', on);
  };
  chip('#chip-god', 'god', status.god);
  chip('#chip-noclip', 'noclip', status.noclip);
  chip('#chip-invis', 'invisível', status.invis);
}

// ---------- Acoes rapidas ----------
$$('[data-self]').forEach((btn) => {
  btn.addEventListener('click', () => exec('self', { action: btn.dataset.self }));
});

$('#announce-btn').addEventListener('click', () => {
  const input = $('#announce-input');
  const msg = input.value.trim();
  if (!msg) return toast('Escreva uma mensagem para o anuncio.', 'error');
  exec('announce', { message: msg });
  input.value = '';
});
$('#announce-input').addEventListener('keydown', (e) => {
  if (e.key === 'Enter') $('#announce-btn').click();
});

// ---------- Jogadores ----------
function refreshPlayers() { post('refreshPlayers'); }
$('#refresh-btn').addEventListener('click', refreshPlayers);
$('#player-search').addEventListener('input', renderPlayers);

// auto-atualizar a cada 5s enquanto a aba estiver aberta
setInterval(() => {
  if (!$('#backdrop').classList.contains('hidden') &&
      $('#page-jogadores').classList.contains('active')) {
    refreshPlayers();
  }
}, 5000);

function dist(p) {
  if (!myCoords || !p.coords) return null;
  const dx = p.coords.x - myCoords.x;
  const dy = p.coords.y - myCoords.y;
  const dz = p.coords.z - myCoords.z;
  return Math.sqrt(dx * dx + dy * dy + dz * dz);
}

function renderPlayers() {
  const q = ($('#player-search').value || '').toLowerCase().trim();
  const list = $('#player-list');
  $('#nav-count').textContent = players.length;
  $('#stat-players').textContent = players.length;

  const shown = players
    .slice()
    .sort((a, b) => a.id - b.id)
    .filter((p) => !q || p.name.toLowerCase().includes(q) || String(p.id).includes(q));

  if (!shown.length) {
    list.innerHTML = '<div class="empty">Nenhum jogador encontrado.</div>';
    return;
  }

  list.innerHTML = shown.map((p) => {
    const d = dist(p);
    return `
      <div class="player-row ${p.id === myId ? 'me' : ''} ${p.id === selectedId ? 'selected' : ''}" data-id="${p.id}">
        <span class="pid">#${p.id}</span>
        <span class="pname">${escapeHtml(p.name)}</span>
        <span class="pping">${p.ping}ms</span>
        <span class="pdist">${d === null ? '—' : Math.round(d) + 'm'}</span>
      </div>`;
  }).join('');

  list.querySelectorAll('.player-row').forEach((row) => {
    row.addEventListener('click', () => {
      selectedId = parseInt(row.dataset.id, 10);
      renderPlayers();
      renderDetail();
    });
  });

  if (selectedId !== null) renderDetail();
}

function escapeHtml(s) {
  return String(s).replace(/[&<>"']/g, (c) => ({
    '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;',
  }[c]));
}

function renderDetail() {
  const el = $('#player-detail');
  const p = players.find((x) => x.id === selectedId);
  if (!p) {
    el.innerHTML = '<div class="empty">Selecione um jogador na lista</div>';
    return;
  }

  el.innerHTML = `
    <h3>${escapeHtml(p.name)}</h3>
    <div class="detail-meta">
      <span class="chip">ID #${p.id}</span>
      <span class="chip">${p.ping}ms</span>
      <span class="chip">${Math.round(dist(p) ?? 0)}m de você</span>
    </div>
    <div class="action-stack">
      <button class="btn" data-act="goto">Ir até o jogador</button>
      <button class="btn" data-act="bring">Trazer até mim</button>
      <button class="btn" data-act="god">Godmode (toggle)</button>
      <button class="btn" data-act="freeze">Congelar / descongelar</button>
      <button class="btn" data-act="heal">Curar</button>
      <button class="btn danger" data-act="kill">Matar</button>

      <div class="action-label">Spawnar veículo para ele</div>
      <div class="input-row">
        <input type="text" id="d-veh" placeholder="modelo (ex: sultan)" />
        <button class="btn primary" data-act="car">Spawnar</button>
      </div>

      <div class="action-label">Dar arma para ele</div>
      <div class="input-row">
        <input type="text" id="d-wep" placeholder="arma (ex: pistol)" />
        <input type="number" id="d-ammo" class="narrow" value="250" min="1" max="9999" />
        <button class="btn primary" data-act="weapon">Dar</button>
      </div>
    </div>
  `;

  el.querySelectorAll('[data-act]').forEach((btn) => {
    btn.addEventListener('click', () => {
      const act = btn.dataset.act;
      const data = { target: selectedId };
      if (act === 'car') {
        data.model = ($('#d-veh').value || '').trim();
        if (!data.model) return toast('Informe o modelo do veículo.', 'error');
      }
      if (act === 'weapon') {
        data.weapon = ($('#d-wep').value || '').trim();
        data.ammo = parseInt($('#d-ammo').value, 10) || 250;
        if (!data.weapon) return toast('Informe a arma.', 'error');
      }
      exec(act, data);
    });
  });
}

// ---------- Garagem & Armas ----------
const VEHICLES = ['adder', 'sultan', 'kuruma', 'faggio', 'bati', 'police', 'police2', 'ambulance', 'firetruk', 'buzzard', 'cargobob', 'dinghy'];
const WEAPONS = ['pistol', 'smg', 'assaultrifle', 'carbinerifle', 'pumpshotgun', 'sniperrifle', 'rpg', 'grenade'];

function fillChips(container, items, inputSel) {
  const el = $(container);
  el.innerHTML = items.map((i) => `<span class="chip">${i}</span>`).join('');
  el.querySelectorAll('.chip').forEach((chip) => {
    chip.addEventListener('click', () => { $(inputSel).value = chip.textContent; });
  });
}
fillChips('#veh-chips', VEHICLES, '#veh-input');
fillChips('#wep-chips', WEAPONS, '#wep-input');

$('#veh-btn').addEventListener('click', () => {
  const model = ($('#veh-input').value || '').trim();
  if (!model) return toast('Informe o modelo do veículo.', 'error');
  exec('self', { action: 'spawnCar', model });
});

$('#wep-btn').addEventListener('click', () => {
  const weapon = ($('#wep-input').value || '').trim();
  if (!weapon) return toast('Informe a arma.', 'error');
  const ammo = parseInt($('#wep-ammo').value, 10) || 250;
  exec('self', { action: 'giveWeapon', weapon, ammo });
});

// ---------- Comandos ----------
const COMMANDS = [
  ['/cpanel', 'Abrir/fechar este painel admin'],
  ['/car <modelo>', 'Spawnar um veículo ex: /car adder'],
  ['/god', 'Ativar/desativar godmode'],
  ['/arma <arma> [munição]', 'Receber uma arma ex: /arma ak 500 — use /arma all para o kit'],
  ['/hp', 'Restaurar vida e colete'],
  ['/kill [id]', 'Matar a si mesmo ou a outro jogador'],
  ['/tp <id>', 'Teleportar até um jogador'],
  ['/bring <id>', 'Trazer um jogador até você'],
  ['/freeze <id>', 'Congelar/descongelar um jogador'],
  ['/invis', 'Ativar/desativar invisibilidade'],
  ['/noclip', 'Ativar/desativar noclip (W/A/S/D, E/Q, Shift)'],
  ['/fix', 'Consertar o veículo atual'],
  ['/dv', 'Remover o veículo mais próximo (até 10m)'],
  ['/dvall <raio>', 'Remover todos os veículos num raio ex: /dvall 100'],
  ['/police', 'Ligar/desligar o bloqueio da polícia NPC'],
  ['/anuncio <mensagem>', 'Enviar um anúncio para todo o servidor'],
];

$('#cmd-table').innerHTML = COMMANDS
  .map(([cmd, desc]) => `<tr><td><code>${cmd}</code></td><td>${desc}</td></tr>`)
  .join('');
