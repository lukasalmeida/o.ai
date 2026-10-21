const overlay = document.getElementById('faint');
const waitMsg = document.getElementById('waitMsg');
const giveBtn = document.getElementById('giveup');

let timerId = null;

function format(total) {
    const m = Math.floor(total / 60);
    const s = total % 60;
    return String(m).padStart(2, '0') + ':' + String(s).padStart(2, '0');
}

// Tela de desmaiado com a contagem regressiva ("Aguarde 04:59")
function showFaint(seconds) {
    clearInterval(timerId);

    overlay.classList.remove('hidden');
    giveBtn.classList.add('hidden');

    let left = Math.max(0, Math.floor(seconds));
    waitMsg.textContent = 'Aguarde ' + format(left);

    timerId = setInterval(function () {
        left -= 1;
        waitMsg.textContent = 'Aguarde ' + format(Math.max(0, left));

        if (left <= 0) {
            clearInterval(timerId);
        }
    }, 1000);
}

// Tempo esgotado: libera o botão DESISTIR
function showGiveUp() {
    clearInterval(timerId);

    waitMsg.textContent = 'Você já pode reviver';
    giveBtn.classList.remove('hidden');
}

function hide() {
    clearInterval(timerId);
    overlay.classList.add('hidden');
}

function applyState(data) {
    if (!data || !data.action) {
        return;
    }

    if (data.action === 'faint') {
        showFaint(data.seconds || 0);
    } else if (data.action === 'ready') {
        showFaint(0);
        showGiveUp();
    } else if (data.action === 'hide') {
        hide();
    }
}

function post(name, data) {
    return fetch('https://' + GetParentResourceName() + '/' + name, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json; charset=UTF-8' },
        body: JSON.stringify(data || {})
    });
}

// Ao carregar a página, pergunta ao client se já existe um desmaiado ativo
// (importante quando o recurso é reiniciado com o jogador morto)
function requestState(retries) {
    post('state')
        .then(function (res) { return res.json(); })
        .then(applyState)
        .catch(function () {
            if (retries > 0) {
                setTimeout(function () { requestState(retries - 1); }, 400);
            }
        });
}

window.addEventListener('load', function () {
    requestState(8);
});

window.addEventListener('message', function (event) {
    applyState(event.data || {});
});

// Botão DESISTIR → avisa o client (client.lua: RegisterNUICallback('giveup'))
giveBtn.addEventListener('click', function () {
    post('giveup');
});
