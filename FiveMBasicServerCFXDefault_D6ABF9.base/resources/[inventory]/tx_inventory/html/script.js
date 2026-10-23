/* ==========================================================
   TX_INVENTORY | NUI - Lógica da interface
   ========================================================== */

const RESOURCE = (typeof GetParentResourceName === 'function') ? GetParentResourceName() : 'tx_inventory';

/* ----------------------------------------------------------
   ESTADO
   ---------------------------------------------------------- */
let state = {
    items: [],
    weight: { current: 0, max: 30 },
    slots: { backpack: 30, hotbar: 5, base: 30 },
    ground: [],
    player: { name: 'Jogador', job: '—', money: 0 }
};

let catalog = {};
let config = { hotbarHud: true };

/* ----------------------------------------------------------
   HELPERS DOM
   ---------------------------------------------------------- */
const $ = (id) => document.getElementById(id);

const elInventory = $('inventory');
const elHud       = $('hud');
const elGrid      = $('grid');
const elHotbar    = $('hotbar');
const elHudHotbar = $('hud-hotbar');
const elGround    = $('ground-list');
const elTrash     = $('trash');
const elMenu      = $('context-menu');
const elTooltip   = $('tooltip');
const elModal     = $('amount-modal');

/* ----------------------------------------------------------
   COMUNICAÇÃO COM O LUA
   ---------------------------------------------------------- */
async function post(action, data = {}) {
    try {
        const res = await fetch(`https://${RESOURCE}/${action}`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json; charset=UTF-8' },
            body: JSON.stringify(data)
        });
        const text = await res.text();
        if (!text) return null;
        try {
            return JSON.parse(text);
        } catch (parseErr) {
            console.warn(`[tx_inventory] resposta nao-JSON em "${action}":`, text.slice(0, 120));
            return null;
        }
    } catch (err) {
        console.error('[tx_inventory] falha na comunicação:', err);
        return null;
    }
}

/* ----------------------------------------------------------
   CATÁLOGO DE ITENS
   ---------------------------------------------------------- */
function def(name) {
    return catalog[name] || { label: name, glyph: '📦', weight: 0, type: 'unknown', desc: '' };
}

function iconMarkup(d) {
    if (d.image) {
        return `<img src="img/${d.image}" data-fallback="${d.glyph || '📦'}" alt="">`;
    }
    return `<span class="glyph">${d.glyph || '📦'}</span>`;
}

/** Aplica o fallback (emoji) quando a imagem do item não existe */
function applyImageFallback(root) {
    root.querySelectorAll('img[data-fallback]').forEach((img) => {
        const handle = () => {
            if (!img.isConnected) return;
            const span = document.createElement('span');
            span.className = 'glyph';
            span.textContent = img.dataset.fallback || '📦';
            img.replaceWith(span);
        };
        img.addEventListener('error', handle);
        if (img.complete && img.naturalWidth === 0) handle();
    });
}

/* ----------------------------------------------------------
   CONSULTAS
   ---------------------------------------------------------- */
function itemById(id) {
    return state.items.find((i) => String(i.id) === String(id)) || null;
}

function itemBySlot(slot) {
    return state.items.find((i) => Number(i.slot) === Number(slot)) || null;
}

function baseSlots() { return state.slots.base || 30; }
function hotbarSlots() { return state.slots.hotbar || 5; }

/** IDs de slot da mochila (base + extras das mochilas equipadas) */
function bagSlotIds() {
    const base = baseSlots();
    const hot = hotbarSlots();
    const extra = Math.max(0, (state.slots.backpack || base) - base);
    const ids = [];
    for (let i = 1; i <= base; i++) ids.push(i);
    for (let i = 0; i < extra; i++) ids.push(base + hot + 1 + i);
    return ids;
}

function hotbarSlotId(index) { return baseSlots() + index; }

/* ----------------------------------------------------------
   RENDER
   ---------------------------------------------------------- */
function buildItemElement(item) {
    const d = def(item.name);
    const el = document.createElement('div');
    el.className = 'item';
    el.dataset.itemId = item.id;
    el.innerHTML = `
        <div class="icon">${iconMarkup(d)}</div>
        ${item.amount > 1 ? `<span class="amount">${item.amount}</span>` : ''}
        ${item.equipped ? '<span class="equipped"></span>' : ''}
        ${item.metadata && item.metadata.serial ? `<span class="serial">#${item.metadata.serial}</span>` : ''}
    `;
    return el;
}

function renderGrid() {
    const ids = bagSlotIds();
    elGrid.innerHTML = '';

    ids.forEach((slotId) => {
        const slot = document.createElement('div');
        slot.className = 'slot';
        slot.dataset.slot = slotId;

        const item = itemBySlot(slotId);
        if (item) {
            slot.dataset.itemId = item.id;
            slot.appendChild(buildItemElement(item));
        }
        elGrid.appendChild(slot);
    });

    applyImageFallback(elGrid);

    const used = state.items.filter((i) => bagSlotIds().includes(Number(i.slot))).length;
    $('bag-count').textContent = `${used} / ${state.slots.backpack || baseSlots()}`;
}

function renderHotbar() {
    elHotbar.innerHTML = '';
    for (let i = 1; i <= hotbarSlots(); i++) {
        const slotId = hotbarSlotId(i);
        const slot = document.createElement('div');
        slot.className = 'slot hotbar-slot';
        slot.dataset.slot = slotId;
        slot.dataset.key = i;

        const item = itemBySlot(slotId);
        if (item) {
            slot.dataset.itemId = item.id;
            slot.appendChild(buildItemElement(item));
        }
        elHotbar.appendChild(slot);
    }
    applyImageFallback(elHotbar);
}

function renderHud() {
    elHudHotbar.innerHTML = '';
    for (let i = 1; i <= hotbarSlots(); i++) {
        const item = itemBySlot(hotbarSlotId(i));
        const slot = document.createElement('div');
        slot.className = 'hud-slot' + (item ? ' filled' : '');
        slot.innerHTML = `<span class="key">${i}</span>`;
        if (item) {
            const d = def(item.name);
            slot.innerHTML += `<div class="icon">${iconMarkup(d)}</div>`;
            if (item.amount > 1) slot.innerHTML += `<span class="amount">${item.amount}</span>`;
        }
        elHudHotbar.appendChild(slot);
    }
    applyImageFallback(elHudHotbar);

    const pct = state.weight.max > 0 ? (state.weight.current / state.weight.max) * 100 : 0;
    $('hud-weight-fill').style.width = `${Math.min(100, pct)}%`;
    $('hud-weight-text').textContent = `${fmt(state.weight.current)} / ${fmt(state.weight.max)} kg`;
}

function renderGround() {
    elGround.innerHTML = '';

    if (!state.ground || state.ground.length === 0) {
        elGround.innerHTML = '<div class="empty-ground">Nenhum item por perto</div>';
    } else {
        state.ground.forEach((g) => {
            const d = def(g.name);
            const row = document.createElement('div');
            row.className = 'ground-item';
            row.dataset.instance = g.instance;
            row.innerHTML = `
                <div class="icon">${iconMarkup(d)}</div>
                <div class="g-name">${escapeHtml(d.label)}</div>
                <div class="g-amt">x${g.amount}</div>
                <div class="g-dist">${g.distance ? g.distance.toFixed(1) + 'm' : ''}</div>
            `;
            elGround.appendChild(row);
        });
        applyImageFallback(elGround);
    }

    $('ground-count').textContent = state.ground ? state.ground.length : 0;
}

function renderWeight() {
    const cur = state.weight.current || 0;
    const max = state.weight.max || 1;
    const pct = Math.min(100, (cur / max) * 100);

    const fill = $('weight-fill');
    fill.style.width = `${pct}%`;
    fill.className = pct >= 90 ? 'danger' : (pct >= 70 ? 'warn' : '');

    $('weight-text').textContent = `${fmt(cur)} / ${fmt(max)} kg`;
    $('weight-percent').textContent = `${Math.round(pct)}%`;

    const used = state.items.filter((i) => bagSlotIds().includes(Number(i.slot))).length;
    $('slots-text').textContent = `${used} / ${state.slots.backpack || baseSlots()} slots`;
}

function renderPlayer() {
    $('p-name').textContent = state.player.name || 'Jogador';
    $('p-job').textContent = state.player.job || '—';
    $('p-money').textContent = `$${Number(state.player.money || 0).toLocaleString('pt-BR')}`;
}

function render() {
    renderGrid();
    renderHotbar();
    renderHud();
    renderGround();
    renderWeight();
    renderPlayer();
}

function fmt(n) {
    const v = Number(n) || 0;
    return (Math.round(v * 100) / 100).toFixed(1);
}

function escapeHtml(str) {
    return String(str).replace(/[&<>"']/g, (c) => ({
        '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;'
    })[c]);
}

/* ==========================================================
   DRAG & DROP
   ========================================================== */
let drag = null;

document.addEventListener('pointerdown', (e) => {
    if (e.button !== 0) return;
    hideMenu();
    hideTooltip();

    const groundItem = e.target.closest('.ground-item');
    if (groundItem) {
        drag = { kind: 'ground', instance: groundItem.dataset.instance, x: e.clientX, y: e.clientY, active: false };
        return;
    }

    const slot = e.target.closest('.slot');
    if (!slot || !slot.dataset.itemId) return;

    const item = itemById(slot.dataset.itemId);
    if (!item) return;

    drag = { kind: 'inv', item, x: e.clientX, y: e.clientY, active: false, ghost: null };
});

window.addEventListener('pointermove', (e) => {
    if (!drag) return;

    if (!drag.active) {
        const dist = Math.hypot(e.clientX - drag.x, e.clientY - drag.y);
        if (dist < 6) return;

        drag.active = true;
        document.body.classList.add('dragging');

        const ghost = document.createElement('div');
        ghost.className = 'drag-ghost';
        if (drag.kind === 'inv') {
            const d = def(drag.item.name);
            ghost.innerHTML = iconMarkup(d);
        } else {
            ghost.innerHTML = '<span class="glyph">📦</span>';
        }
        document.body.appendChild(ghost);
        drag.ghost = ghost;
        applyImageFallback(ghost);
    }

    if (drag.ghost) {
        drag.ghost.style.left = `${e.clientX}px`;
        drag.ghost.style.top = `${e.clientY}px`;
    }

    const target = getDropTarget(e.clientX, e.clientY);
    highlightTarget(target);
});

window.addEventListener('pointerup', (e) => {
    if (!drag) return;

    const d = drag;
    drag = null;

    if (d.ghost) d.ghost.remove();
    document.body.classList.remove('dragging');
    highlightTarget(null);

    if (!d.active) return;

    const target = getDropTarget(e.clientX, e.clientY);

    if (d.kind === 'ground') {
        // Arrastou um item do chão para um slot -> recolhe
        if (target && target.type === 'slot') {
            post('pickup', { instance: d.instance });
        }
        return;
    }

    const item = d.item;

    if (target && target.type === 'slot') {
        if (Number(target.slot) !== Number(item.slot)) {
            post('move', { itemId: item.id, slot: target.slot });
        }
    } else if (target && target.type === 'trash') {
        post('delete', { itemId: item.id });
    } else {
        // Fora do painel (ou na área do chão) -> joga no mundo 3D
        post('drop', { itemId: item.id, amount: item.amount });
    }
});

function getDropTarget(x, y) {
    const el = document.elementFromPoint(x, y);
    if (!el) return null;

    const slot = el.closest('.slot');
    if (slot && slot.dataset.slot) {
        return { type: 'slot', slot: Number(slot.dataset.slot), el: slot };
    }

    const trash = el.closest('#trash');
    if (trash) return { type: 'trash', el: trash };

    const ground = el.closest('#ground-list');
    if (ground) return { type: 'ground', el: ground };

    return null;
}

function highlightTarget(target) {
    document.querySelectorAll('.slot.drag-over, .trash-zone.drag-over').forEach((el) => {
        el.classList.remove('drag-over');
    });
    if (!target) return;
    if (target.el) target.el.classList.add('drag-over');
}

/* ==========================================================
   DUPLO CLIQUE / MENU DE CONTEXTO
   ========================================================== */
document.addEventListener('dblclick', (e) => {
    const slot = e.target.closest('.slot');
    if (!slot || !slot.dataset.itemId) return;
    post('use', { itemId: Number(slot.dataset.itemId) });
});

let ctxItemId = null;

document.addEventListener('contextmenu', (e) => {
    const slot = e.target.closest('.slot');
    if (!slot || !slot.dataset.itemId) return;

    e.preventDefault();
    ctxItemId = Number(slot.dataset.itemId);

    const item = itemById(ctxItemId);
    $('ctx-title').textContent = item ? def(item.name).label : 'Item';

    elMenu.classList.remove('hidden');
    const w = elMenu.offsetWidth;
    const h = elMenu.offsetHeight;
    elMenu.style.left = `${Math.min(e.clientX, window.innerWidth - w - 12)}px`;
    elMenu.style.top = `${Math.min(e.clientY, window.innerHeight - h - 12)}px`;
});

elMenu.addEventListener('click', (e) => {
    const btn = e.target.closest('.ctx-item');
    if (!btn || ctxItemId === null) return;

    const action = btn.dataset.action;
    const item = itemById(ctxItemId);
    hideMenu();

    if (!item) return;

    switch (action) {
        case 'use':
            post('use', { itemId: item.id });
            break;
        case 'give':
            post('give', { itemId: item.id, amount: item.amount });
            break;
        case 'split':
            openAmountModal(item);
            break;
        case 'drop-one':
            post('drop', { itemId: item.id, amount: 1 });
            break;
        case 'drop-all':
            post('drop', { itemId: item.id, amount: item.amount });
            break;
        case 'delete':
            post('delete', { itemId: item.id });
            break;
    }
});

function hideMenu() {
    elMenu.classList.add('hidden');
    ctxItemId = null;
}

/* ==========================================================
   MODAL DE QUANTIDADE
   ========================================================== */
let amountTarget = null;

function openAmountModal(item) {
    amountTarget = item;
    const input = $('amount-input');
    input.max = Math.max(1, item.amount - 1);
    input.value = 1;
    elModal.classList.remove('hidden');
    input.focus();
    input.select();
}

$('amount-cancel').addEventListener('click', () => {
    elModal.classList.add('hidden');
    amountTarget = null;
});

$('amount-confirm').addEventListener('click', () => {
    if (amountTarget) {
        let v = parseInt($('amount-input').value, 10);
        if (!v || v < 1) v = 1;
        if (v > amountTarget.amount - 1) v = amountTarget.amount - 1;
        post('split', { itemId: amountTarget.id, amount: v });
    }
    elModal.classList.add('hidden');
    amountTarget = null;
});

/* ==========================================================
   TOOLTIP
   ========================================================== */
document.addEventListener('mouseover', (e) => {
    const slot = e.target.closest('.slot');
    if (!slot || !slot.dataset.itemId) return;

    const item = itemById(slot.dataset.itemId);
    if (!item) return;

    const d = def(item.name);
    $('tt-name').textContent = d.label;
    $('tt-meta').textContent = `${fmt(d.weight * item.amount)} kg${item.amount > 1 ? ` • ${item.amount} un.` : ''}`;
    $('tt-desc').textContent = d.desc || '';

    elTooltip.classList.remove('hidden');
    moveTooltip(e);
});

document.addEventListener('mousemove', (e) => {
    if (!elTooltip.classList.contains('hidden')) moveTooltip(e);
});

function moveTooltip(e) {
    const pad = 14;
    const w = elTooltip.offsetWidth;
    const h = elTooltip.offsetHeight;
    let x = e.clientX + 16;
    let y = e.clientY + 16;
    if (x + w > window.innerWidth - 8) x = e.clientX - w - 12;
    if (y + h > window.innerHeight - 8) y = e.clientY - h - 12;
    elTooltip.style.left = `${Math.max(8, x)}px`;
    elTooltip.style.top = `${Math.max(8, y)}px`;
}

function hideTooltip() {
    elTooltip.classList.add('hidden');
}

/* ==========================================================
   TECLADO
   ========================================================== */
document.addEventListener('keydown', (e) => {
    if (e.key === 'Escape') {
        if (!elModal.classList.contains('hidden')) {
            elModal.classList.add('hidden');
            amountTarget = null;
            return;
        }
        if (!elMenu.classList.contains('hidden')) {
            hideMenu();
            return;
        }
        post('close');
    }
});

/* ==========================================================
   MENSAGENS DO LUA
   ========================================================== */
window.addEventListener('message', (e) => {
    const { action, data } = e.data || {};

    switch (action) {
        case 'catalog':
            catalog = data || {};
            render();
            break;

        case 'config':
            config = data || {};
            elHud.style.display = config.hotbarHud ? 'flex' : 'none';
            break;

        case 'open':
            if (data) state = data;
            elInventory.classList.remove('hidden');
            elHud.style.display = 'none';
            render();
            break;

        case 'close':
            elInventory.classList.add('hidden');
            elHud.style.display = config.hotbarHud ? 'flex' : 'none';
            hideMenu();
            hideTooltip();
            renderHud();
            break;

        case 'update':
            if (data) state = data;
            render();
            break;

        case 'status':
            break;
    }
});

/* ==========================================================
   INICIALIZAÇÃO
   ========================================================== */
post('ready');
render();
