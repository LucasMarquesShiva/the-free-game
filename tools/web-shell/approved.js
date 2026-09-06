(() => {
  'use strict';
  const byId = id => document.getElementById(id);
  const overlay = byId('status');
  const label = byId('status-label');
  const detail = byId('status-detail');
  const progress = byId('status-progress');
  const percent = byId('status-percent');
  const retry = byId('retry');
  let finished = false;
  let failed = false;
  let lastProgress = Date.now();
  let received = 0;
  const mb = bytes => (bytes / 1000000).toLocaleString('pt-BR', {maximumFractionDigits:1});
  retry.addEventListener('click', () => window.location.reload());

  function fail(message, error) {
    if (finished || failed) return;
    failed = true;
    clearInterval(stallTimer);
    byId('loading-state').hidden = true;
    byId('failure-state').hidden = false;
    byId('loading-tip').hidden = true;
    byId('failure-message').textContent = message;
    const text = error instanceof Error ? error.message : String(error || '');
    byId('failure-detail').textContent = text;
    byId('technical-details').hidden = !text;
    retry.hidden = false;
    byId('failure-title').focus({preventScroll:true});
    if (error) console.error('Vale dos Vinhedos: falha ao iniciar.', error);
  }

  const stallTimer = setInterval(() => {
    if (finished || failed || Date.now() - lastProgress < 45000) return;
    detail.textContent = navigator.onLine === false
      ? 'Você está sem conexão. Reconecte-se e tente novamente.'
      : 'Está levando mais tempo que o esperado. Você pode aguardar ou tentar novamente.';
    retry.hidden = false;
  }, 5000);

  async function start() {
    if (typeof Engine !== 'function') {
      fail('Não conseguimos carregar o jogo. Confira sua conexão e tente novamente.');
      return;
    }
    try {
      const missing = Engine.getMissingFeatures({threads:GODOT_THREADS_ENABLED});
      if (missing.length) {
        fail('Este navegador não disponibilizou os recursos gráficos necessários. Tente um navegador atualizado e confira se a aceleração gráfica está ativada.', missing.join('\n'));
        return;
      }
      const engine = new Engine(GODOT_CONFIG);
      label.textContent = 'Carregando a vila…';
      await engine.startGame({onProgress(current, total) {
        if (finished || failed) return;
        if (current > received) {lastProgress = Date.now();received = current;retry.hidden = true;}
        if (current >= 0 && total > 0) {
          progress.max = total;
          progress.value = Math.min(current, total);
          percent.textContent = `${Math.floor(Math.min(current / total, 1) * 100)}%`;
          if (current >= total) {
            label.textContent = 'Preparando o cenário…';
            detail.textContent = 'Arquivos recebidos. A vila já vai aparecer.';
          } else {
            label.textContent = 'Baixando o jogo…';
            detail.textContent = `${mb(current)} de ${mb(total)} MB recebidos`;
          }
        } else {
          progress.removeAttribute('value');
          percent.textContent = '';
          detail.textContent = 'O primeiro carregamento pode levar um pouco mais de tempo.';
        }
      }});
      if (failed) return;
      finished = true;
      clearInterval(stallTimer);
      overlay.remove();
      byId('canvas').focus({preventScroll:true});
      updateScreenHint();
    } catch (error) {
      fail('Não conseguimos iniciar a vila. Confira sua conexão, feche outras abas pesadas e tente novamente.', error);
    }
  }

  let hintDismissed = false;
  function updateScreenHint() {
    byId('screen-hint').hidden = !finished || hintDismissed || (window.innerWidth > 720 && window.innerHeight > 340);
  }
  window.addEventListener('resize', updateScreenHint);
  byId('dismiss-hint').addEventListener('click', () => {hintDismissed = true;updateScreenHint();byId('canvas').focus({preventScroll:true});});
  byId('fullscreen').addEventListener('click', async () => {
    try {
      const root = document.documentElement;
      const request = root.requestFullscreen || root.webkitRequestFullscreen;
      if (!request) throw new Error('Tela cheia indisponível.');
      await request.call(root);
      updateScreenHint();
      byId('canvas').focus({preventScroll:true});
    } catch (_) {
      byId('screen-status').textContent = 'A tela cheia não está disponível aqui. Amplie a janela ou feche este aviso para continuar.';
    }
  });
  const script = document.createElement('script');
  script.src = `${GODOT_CONFIG.executable}.js`;
  script.onload = start;
  script.onerror = () => fail('Não conseguimos baixar o jogo. Confira sua conexão e tente novamente.');
  document.head.appendChild(script);
})();
