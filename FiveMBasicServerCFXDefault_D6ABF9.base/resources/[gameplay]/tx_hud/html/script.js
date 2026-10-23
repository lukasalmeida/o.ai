/* ==========================================================================
   TX HUD — script da NUI
   Recebe mensagens do Lua (SendNUIMessage) e atualiza a interface.
   Fora do FiveM (abrir o index.html no navegador) roda em modo DEMO.
   ========================================================================== */
(function () {
  'use strict';

  var $ = function (sel, ctx) { return (ctx || document).querySelector(sel); };
  var $$ = function (sel, ctx) { return Array.prototype.slice.call((ctx || document).querySelectorAll(sel)); };
  var IS_FIVEM = typeof window.invokeNative !== 'undefined';

  /* ---------------------------------------------------------------------
     Estado
     --------------------------------------------------------------------- */
  var state = {
    money: { cash: 0, bank: 0 },
    name: 'Carregando...',
    level: 1,
    health: 100,
    armor: 0,
    stamina: 100,
    weapon: { name: 'DESARMADO', ammo: 0, reserve: 0, unarmed: true },
    vehicle: {
      active: false,
      speed: 0,
      maxSpeed: 220,
      fuel: 0,
      rpm: 0,
      rpmValue: 0,
      gear: 1,
      engine: false,
      lights: false,
      locked: false,
      seatbelt: false
    },
    server: {
      name: 'TX ROLEPLAY',
      players: 0,
      playerId: 0,
      time: '00:00',
      date: '01/01/2026',
      timeLocked: false
    },
    zone: { safe: false, name: 'DESCONHECIDO', x: 0, y: 0, heading: 0 },
    slots: [],
    activeSlot: 1,
    hudVisible: false  -- HUD inicia oculto, aparece com TAB
  };

  /* ---------------------------------------------------------------------
     Helpers
     --------------------------------------------------------------------- */
  function clamp(v, min, max) { return Math.min(max, Math.max(min, v)); }

  function fmtMoney(v) {
    v = Math.round(Number(v) || 0);
    var neg = v < 0;
    var s = Math.abs(v).toString().replace(/\B(?=(\d{3})+(?!\d))/g, '.');
    return (neg ? '-$ ' : '$ ') + s;
  }

  function fmtNumber(v) {
    return Math.round(Number(v) || 0).toString().replace(/\B(?=(\d{3})+(?!\d))/g, '.');
  }

  function setBar(el, pct) {
    if (!el) return;
    el.style.width = clamp(pct, 0, 100) + '%';
  }

  function setArc(el, pct) {
    if (!el) return;
    el.style.strokeDashoffset = String(100 - clamp(pct, 0, 100));
  }

  function setText(el, text) {
    if (el && el.textContent !== String(text)) el.textContent = String(text);
  }

  /* ---------------------------------------------------------------------
     Renderizadores
     --------------------------------------------------------------------- */
  function renderMoney() {
    setText($('#money-cash'), fmtMoney(state.money.cash));
    setText($('#money-bank'), fmtMoney(state.money.bank));
  }

  function renderVitals() {
    setBar($('#bar-health'), state.health);
    setBar($('#bar-armor'), state.armor);
    setBar($('#bar-stamina'), state.stamina);
    setText($('#val-health'), Math.round(state.health));
    setText($('#val-armor'), Math.round(state.armor));
    setText($('#val-stamina'), Math.round(state.stamina));
  }

  function renderWeapon() {
    setText($('#weapon-name'), state.weapon.name);
    setText($('#weapon-ammo'), state.weapon.ammo + ' / ' + state.weapon.reserve);
    // Mostra/oculta o pill da arma baseado se está armado
    var pill = $('#weapon-pill');
    if (pill) pill.style.display = state.weapon.unarmed ? 'none' : 'flex';
  }

  function renderServer() {
    setText($('#si-name'), state.name);
    setText($('#si-id'), 'ID: ' + state.server.playerId);
    setText($('#si-online'), state.server.players);
    setText($('#si-time'), state.server.time);
    setText($('#si-date'), state.server.date);
  }

  var lastSpeed = null;
  function renderVehicle() {
    var v = state.vehicle;
    var block = $('#vehicle-block');
    if (block) block.classList.toggle('is-hidden', !v.active);

    var speedPct = v.maxSpeed > 0 ? (v.speed / v.maxSpeed) * 100 : 0;
    setArc($('#arc-speed'), speedPct);
    setArc($('#arc-fuel'), v.fuel);
    setArc($('#arc-rpm'), v.rpm);

    var speedEl = $('#speed-value');
    setText(speedEl, Math.round(v.speed));
    if (lastSpeed !== null && Math.round(v.speed) !== lastSpeed && speedEl) {
      speedEl.classList.remove('is-pop');
      void speedEl.offsetWidth; /* reinicia a animacao */
      speedEl.classList.add('is-pop');
    }
    lastSpeed = Math.round(v.speed);

    setText($('#max-speed'), 'MAX ' + Math.round(v.maxSpeed));
    setText($('#rpm-label'), 'RPM ' + (v.rpmValue || Math.round(v.rpm)));
    setText($('#gear-value'), gearLabel(v.gear));

    flag('#flag-engine', v.engine);
    flag('#flag-lights', v.lights);
    flag('#flag-lock', v.locked);
    flag('#flag-belt', v.seatbelt);
  }

  function flag(sel, on) {
    var el = $(sel);
    if (el) el.classList.toggle('is-on', !!on);
  }

  function gearLabel(gear) {
    if (gear === 0) return 'R';
    if (gear === 1) return 'N';
    return String(gear - 1);
  }

  function renderSlots() {
    var slots = $$('#quickbar .qslot');
    for (var i = 0; i < slots.length; i++) {
      var btn = slots[i];
      var key = btn.dataset.slot;
      if (key === 'voice') { btn.style.display = ''; continue; }
      var slot = state.slots[i];
      if (!slot) { btn.style.display = 'none'; continue; }
      btn.style.display = '';
      setText($('.qkey', btn), slot.key);
      setText($('.qlabel', btn), slot.label);
      setText($('.qcount', btn), slot.count);
      var use = $('use', $('.qicon', btn));
      if (use && use.getAttribute('href') !== '#' + slot.icon) {
        use.setAttribute('href', '#' + slot.icon);
      }
      btn.classList.toggle('is-active', Number(key) === Number(state.activeSlot));
    }
  }

  function renderAll() {
    renderMoney();
    renderVitals();
    renderWeapon();
    renderServer();
    renderVehicle();
    renderSlots();
  }

  /* ---------------------------------------------------------------------
     Acoes publicas (chamadas pelo Lua / por outros scripts)
     --------------------------------------------------------------------- */
  function applyState(data) {
    if (!data) return;

    if (data.money) {
      if (typeof data.money.cash === 'number') state.money.cash = data.money.cash;
      if (typeof data.money.bank === 'number') state.money.bank = data.money.bank;
    }
    if (typeof data.name === 'string') state.name = data.name;

    if (typeof data.health === 'number') state.health = data.health;
    if (typeof data.armor === 'number') state.armor = data.armor;
    if (typeof data.stamina === 'number') state.stamina = data.stamina;

    if (data.weapon) {
      state.weapon.name = data.weapon.name || state.weapon.name;
      if (typeof data.weapon.ammo === 'number') state.weapon.ammo = data.weapon.ammo;
      if (typeof data.weapon.reserve === 'number') state.weapon.reserve = data.weapon.reserve;
      if (typeof data.weapon.unarmed === 'boolean') state.weapon.unarmed = data.weapon.unarmed;
    }

    if (data.vehicle) {
      var v = data.vehicle;
      var veh = state.vehicle;
      if (typeof v.active === 'boolean') veh.active = v.active;
      if (typeof v.speed === 'number') veh.speed = v.speed;
      if (typeof v.maxSpeed === 'number') veh.maxSpeed = v.maxSpeed;
      if (typeof v.fuel === 'number') veh.fuel = v.fuel;
      if (typeof v.rpm === 'number') veh.rpm = v.rpm;
      if (typeof v.rpmValue === 'number') veh.rpmValue = v.rpmValue;
      if (typeof v.gear === 'number') veh.gear = v.gear;
      if (typeof v.engine === 'boolean') veh.engine = v.engine;
      if (typeof v.lights === 'boolean') veh.lights = v.lights;
      if (typeof v.locked === 'boolean') veh.locked = v.locked;
      if (typeof v.seatbelt === 'boolean') veh.seatbelt = v.seatbelt;
    }

    if (data.server) {
      var s = data.server;
      if (typeof s.players === 'number') state.server.players = s.players;
      if (typeof s.playerId === 'number') state.server.playerId = s.playerId;
      if (s.time) {
        state.server.time = s.time;
        state.server.timeLocked = true; /* o Lua manda o tempo do jogo */
      }
      if (s.date) state.server.date = s.date;
    }

    if (Array.isArray(data.slots)) {
      for (var i = 0; i < data.slots.length; i++) {
        var src = data.slots[i] || {};
        if (!state.slots[i]) state.slots[i] = { key: String(i + 1), icon: 'i-box', label: '', count: 0 };
        if (src.key) state.slots[i].key = String(src.key);
        if (src.icon) state.slots[i].icon = src.icon;
        if (typeof src.label === 'string') state.slots[i].label = src.label;
        if (typeof src.count === 'number') state.slots[i].count = src.count;
      }
    }

    if (typeof data.activeSlot === 'number') state.activeSlot = data.activeSlot;
    if (typeof data.hudVisible === 'boolean') setHudVisible(data.hudVisible);

    renderAll();
  }

  function setHudVisible(visible) {
    state.hudVisible = !!visible;
    var hud = $('#hud');
    if (hud) hud.classList.toggle('is-off', !state.hudVisible);
  }

  function setSlot(index) {
    state.activeSlot = Number(index);
    renderSlots();
  }

  function showAlert(text, danger) {
    var el = $('#alert');
    if (!el) return;
    setText($('#alert-text'), text);
    el.classList.toggle('is-danger', !!danger);
    el.classList.add('is-visible');
    clearTimeout(el._timer);
    el._timer = setTimeout(function () { el.classList.remove('is-visible'); }, 3200);
  }

  function setTalking(on) {
    var el = $('.qslot-voice');
    if (el) el.classList.toggle('is-talking', !!on);
  }

  function setTaskProgress(index, pct, done) {
    var bar = $('#task-prog-' + index);
    if (bar) bar.style.width = clamp(pct, 0, 100) + '%';
    var card = $('.task-card[data-task="' + index + '"]');
    if (card && done !== undefined) card.classList.toggle('is-done', !!done);
  }

  function setTasks(list) {
    var wrap = $('#tasks');
    if (!wrap || !Array.isArray(list)) return;
    var cards = $$('.task-card', wrap);
    for (var i = 0; i < cards.length; i++) {
      var card = cards[i];
      var t = list[i];
      if (!t) { card.style.display = 'none'; continue; }
      card.style.display = '';
      setText($('.task-title', card), t.title || '');
      setText($('.task-desc', card), t.desc || '');
      setText($('.task-key', card), t.key || '');
      setText($('.task-dist', card), t.dist || '');
      setText($('.task-reward', card), t.reward || '');
      var bar = $('.task-prog i', card);
      if (bar) bar.style.width = clamp(t.progress || 0, 0, 100) + '%';
      card.classList.toggle('is-done', !!t.done);
    }
    setText($('#tasks-count'), list.length);
  }

  /* ---------------------------------------------------------------------
     Ponte NUI <-> Lua
     --------------------------------------------------------------------- */
  window.addEventListener('message', function (event) {
    var data = event.data || {};
    switch (data.action) {
      case 'hud':
      case 'update':
        applyState(data);
        break;
      case 'money':
        state.money.cash = data.cash || 0;
        state.money.bank = data.bank || 0;
        renderMoney();
        break;
      case 'slot':
        setSlot(data.index);
        break;
      case 'slots':
        applyState({ slots: data.slots, activeSlot: data.activeSlot });
        break;
      case 'alert':
        showAlert(data.text || '', data.danger);
        break;
      case 'talking':
        setTalking(data.enabled);
        break;
      case 'taskProgress':
        setTaskProgress(data.index, data.progress, data.done);
        break;
      case 'tasks':
        setTasks(data.tasks);
        break;
      case 'visibility':
        setHudVisible(data.visible);
        break;
      case 'demo':
        applyState(data);
        break;
    }
  });

  /* callbacks usados pelo Lua */
  window.txhud = {
    setState: applyState,
    setSlot: setSlot,
    showAlert: showAlert,
    setTasks: setTasks,
    setTalking: setTalking
  };

  /* ---------------------------------------------------------------------
     Interacoes locais (clique nos slots)
     --------------------------------------------------------------------- */
  document.addEventListener('click', function (e) {
    var btn = e.target.closest ? e.target.closest('.qslot') : null;
    if (!btn) return;
    var key = btn.dataset.slot;
    if (key === 'voice') {
      showAlert('Canal de voz: aperte V novamente para falar', false);
      return;
    }
    setSlot(Number(key));
  });

  document.addEventListener('keydown', function (e) {
    if (e.target && /input|textarea/i.test(e.target.tagName)) return;
    if (e.key >= '1' && e.key <= '6') setSlot(Number(e.key));
    if (e.key === 'v' || e.key === 'V') setTalking(true);
    if (e.key === 'Tab') {
      e.preventDefault();
      setHudVisible(!state.hudVisible);
    }
  });

  document.addEventListener('keyup', function (e) {
    if (e.key === 'v' || e.key === 'V') setTalking(false);
  });

  /* ---------------------------------------------------------------------
     Escala responsiva (o NUI roda em resolucoes diferentes)
     --------------------------------------------------------------------- */
  function fit() {
    var hud = $('#hud');
    if (!hud) return;
    var scale = clamp(window.innerHeight / 1080, 0.72, 1.25);
    hud.style.transform = 'scale(' + scale.toFixed(3) + ')';
  }

  window.addEventListener('resize', fit);

  /* ---------------------------------------------------------------------
     Marcacoes do velocimetro
     --------------------------------------------------------------------- */
  function buildTicks() {
    var g = $('#sp-ticks');
    if (!g) return;
    var cx = 130, cy = 125, r1 = 100, r2 = 91;
    var ns = 'http://www.w3.org/2000/svg';
    for (var i = 0; i <= 10; i++) {
      var ang = Math.PI + (Math.PI * i) / 10; /* 180deg -> 360deg */
      var major = i % 5 === 0;
      var line = document.createElementNS(ns, 'line');
      line.setAttribute('x1', (cx + Math.cos(ang) * r1).toFixed(2));
      line.setAttribute('y1', (cy - Math.sin(ang) * r1).toFixed(2));
      line.setAttribute('x2', (cx + Math.cos(ang) * (major ? r2 - 7 : r2 - 3)).toFixed(2));
      line.setAttribute('y2', (cy - Math.sin(ang) * (major ? r2 - 7 : r2 - 3)).toFixed(2));
      if (major) line.setAttribute('class', 'major');
      g.appendChild(line);
    }
  }

  /* ---------------------------------------------------------------------
     Relogio (fallback quando o Lua nao envia o tempo)
     --------------------------------------------------------------------- */
  function tickClock() {
    if (state.server.timeLocked) return;
    var d = new Date();
    var hh = String(d.getHours()).padStart(2, '0');
    var mm = String(d.getMinutes()).padStart(2, '0');
    state.server.time = hh + ':' + mm;
    renderServer();
  }

  /* ---------------------------------------------------------------------
     Modo DEMO (preview no navegador)
     --------------------------------------------------------------------- */
  function startDemo() {
    var t = 0;
    setInterval(function () {
      t += 1;
      var inCar = Math.floor(t / 22) % 3 !== 0;
      state.vehicle.active = inCar;
      if (inCar) {
        state.vehicle.speed = clamp(70 + Math.sin(t / 6) * 55, 0, 220);
        state.vehicle.rpm = clamp(1800 + Math.sin(t / 4) * 1400, 800, 6800) / 68;
        state.vehicle.rpmValue = Math.round((state.vehicle.rpm / 100) * 70) / 10;
        state.vehicle.fuel = clamp(68 - t / 220, 5, 100);
        state.vehicle.gear = Math.min(6, Math.max(1, Math.round(state.vehicle.speed / 34) + 1));
        state.vehicle.engine = true;
        state.vehicle.lights = Math.floor(t / 12) % 2 === 0;
        state.vehicle.locked = true;
        state.vehicle.seatbelt = true;
      }
      state.health = clamp(100 - (t % 40), 20, 100);
      state.armor = 60;
      state.stamina = clamp(60 + Math.sin(t / 3) * 40, 0, 100);
      state.server.players = 34 + (t % 5);
      renderAll();
    }, 120);

    setInterval(tickClock, 1000);
  }

  /* ---------------------------------------------------------------------
     Boot
     --------------------------------------------------------------------- */
  document.addEventListener('DOMContentLoaded', function () {
    buildTicks();
    renderAll();
    fit();
    if (!IS_FIVEM && !/[?&]nodemo/.test(window.location.search)) startDemo();
  });
})();
