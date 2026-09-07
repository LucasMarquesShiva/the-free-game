(() => {
  'use strict';
  const SHELL = {
    pt: {
      htmlLang: 'pt-BR',
      numberLocale: 'pt-BR',
      canvasAria: 'The Free Game, cenário da vila',
      canvasFallback: 'Seu navegador não consegue exibir o jogo. Tente abrir o link em um navegador atualizado.',
      versionBadge: 'VERSÃO DE TESTES',
      intro: 'Você planeja a vila.<br>Seus moradores dão vida a ela.',
      preparingGame: 'Preparando o jogo…',
      downloadAria: 'Download do jogo',
      firstLoad: 'O primeiro carregamento pode levar um pouco mais de tempo.',
      failureTitle: 'Não foi possível abrir a vila',
      checkConnection: 'Confira sua conexão e tente novamente.',
      errorDetails: 'Detalhes do erro',
      retry: 'Tentar novamente',
      loadingTip: 'Seu primeiro caminho: ligue a praça à escola com uma estrada.',
      villageArtAria: 'Modelos 3D usados no jogo',
      hallAlt: 'Prédio principal de pedra e madeira, com telhados de barro e uma torre de relógio',
      footerLink: 'Código e artes · construa sua versão ↗',
      screenHintAria: 'Tamanho da janela',
      enlargeWindow: 'Amplie a janela para ver todos os controles.',
      fullscreen: 'Tela cheia',
      dismissHint: 'Fechar aviso',
      noscriptTitle: 'Ative o JavaScript para jogar',
      noscriptBody: 'O The Free Game precisa dele para abrir a vila. Ative-o neste site e recarregue a página.',
      offline: 'Você está sem conexão. Reconecte-se e tente novamente.',
      takingLonger: 'Está levando mais tempo que o esperado. Você pode aguardar ou tentar novamente.',
      loadFailed: 'Não conseguimos carregar o jogo. Confira sua conexão e tente novamente.',
      missingFeatures: 'Este navegador não disponibilizou os recursos gráficos necessários. Tente um navegador atualizado e confira se a aceleração gráfica está ativada.',
      loadingVillage: 'Carregando a vila…',
      preparingScene: 'Preparando o cenário…',
      filesReceived: 'Arquivos recebidos. A vila já vai aparecer.',
      downloading: 'Baixando o jogo…',
      receivedMb: '{current} de {total} MB recebidos',
      startFailed: 'Não conseguimos iniciar a vila. Confira sua conexão, feche outras abas pesadas e tente novamente.',
      fullscreenUnavailable: 'Tela cheia indisponível.',
      fullscreenBlocked: 'A tela cheia não está disponível aqui. Amplie a janela ou feche este aviso para continuar.',
      downloadFailed: 'Não conseguimos baixar o jogo. Confira sua conexão e tente novamente.',
      consoleFail: 'Vale dos Vinhedos: falha ao iniciar.'
    },
    en: {
      htmlLang: 'en',
      numberLocale: 'en',
      canvasAria: 'The Free Game, village scene',
      canvasFallback: 'Your browser cannot display the game. Try opening the link in an up-to-date browser.',
      versionBadge: 'TEST BUILD',
      intro: 'You plan the village.<br>Your residents bring it to life.',
      preparingGame: 'Preparing the game…',
      downloadAria: 'Game download',
      firstLoad: 'The first load can take a little longer.',
      failureTitle: 'Could not open the village',
      checkConnection: 'Check your connection and try again.',
      errorDetails: 'Error details',
      retry: 'Try again',
      loadingTip: 'Your first path: connect the plaza to the school with a road.',
      villageArtAria: '3D models used in the game',
      hallAlt: 'Main building of stone and wood, with clay roofs and a clock tower',
      footerLink: 'Code and art · build your own version ↗',
      screenHintAria: 'Window size',
      enlargeWindow: 'Enlarge the window to see every control.',
      fullscreen: 'Full screen',
      dismissHint: 'Dismiss notice',
      noscriptTitle: 'Turn on JavaScript to play',
      noscriptBody: 'The Free Game needs it to open the village. Enable it on this site and reload the page.',
      offline: 'You are offline. Reconnect and try again.',
      takingLonger: 'This is taking longer than expected. You can wait or try again.',
      loadFailed: 'We could not load the game. Check your connection and try again.',
      missingFeatures: 'This browser did not provide the required graphics features. Try an up-to-date browser and check that hardware acceleration is on.',
      loadingVillage: 'Loading the village…',
      preparingScene: 'Preparing the scene…',
      filesReceived: 'Files received. The village will appear shortly.',
      downloading: 'Downloading the game…',
      receivedMb: '{current} of {total} MB received',
      startFailed: 'We could not start the village. Check your connection, close other heavy tabs and try again.',
      fullscreenUnavailable: 'Full screen unavailable.',
      fullscreenBlocked: 'Full screen is not available here. Enlarge the window or dismiss this notice to continue.',
      downloadFailed: 'We could not download the game. Check your connection and try again.',
      consoleFail: 'Vale dos Vinhedos: failed to start.'
    },
    zh: {
      htmlLang: 'zh-CN',
      numberLocale: 'zh-CN',
      canvasAria: 'The Free Game，村庄场景',
      canvasFallback: '当前浏览器无法显示游戏。请用较新的浏览器打开这个链接。',
      versionBadge: '测试版',
      intro: '你规划村庄。<br>村民让它运转起来。',
      preparingGame: '正在准备游戏…',
      downloadAria: '游戏下载',
      firstLoad: '首次加载可能需要更长时间。',
      failureTitle: '无法打开村庄',
      checkConnection: '请检查网络后重试。',
      errorDetails: '错误详情',
      retry: '重试',
      loadingTip: '第一条路：用道路把广场接到学校。',
      villageArtAria: '游戏中的 3D 模型',
      hallAlt: '石木结构的主楼，陶瓦屋顶和一座钟楼',
      footerLink: '代码与原画 · 打造你的版本 ↗',
      screenHintAria: '窗口大小',
      enlargeWindow: '放大窗口才能看到全部控件。',
      fullscreen: '全屏',
      dismissHint: '关闭提示',
      noscriptTitle: '请开启 JavaScript 再游玩',
      noscriptBody: 'The Free Game 需要 JavaScript 才能打开村庄。请在本站启用后刷新页面。',
      offline: '当前没有网络。请重新连接后再试。',
      takingLonger: '用时比预期更长。你可以继续等待，或再试一次。',
      loadFailed: '无法加载游戏。请检查网络后重试。',
      missingFeatures: '这个浏览器没有提供所需的图形功能。请换用较新的浏览器，并确认已开启硬件加速。',
      loadingVillage: '正在加载村庄…',
      preparingScene: '正在准备场景…',
      filesReceived: '文件已接收。村庄马上就会出现。',
      downloading: '正在下载游戏…',
      receivedMb: '已接收 {current} / {total} MB',
      startFailed: '无法启动村庄。请检查网络，关掉其他占用较高的标签页后再试。',
      fullscreenUnavailable: '无法全屏。',
      fullscreenBlocked: '这里无法使用全屏。请放大窗口，或关闭这条提示后继续。',
      downloadFailed: '无法下载游戏。请检查网络后重试。',
      consoleFail: 'Vale dos Vinhedos：启动失败。'
    }
  };
  const nav = String(navigator.language || '').toLowerCase();
  const lang = nav.startsWith('zh') ? 'zh' : nav.startsWith('en') ? 'en' : 'pt';
  const t = SHELL[lang];
  document.documentElement.lang = t.htmlLang;
  document.querySelectorAll('[data-i18n]').forEach(el => {
    const key = el.getAttribute('data-i18n');
    if (t[key]) el.textContent = t[key];
  });
  document.querySelectorAll('[data-i18n-html]').forEach(el => {
    const key = el.getAttribute('data-i18n-html');
    if (t[key]) el.innerHTML = t[key];
  });
  document.querySelectorAll('[data-i18n-aria]').forEach(el => {
    const key = el.getAttribute('data-i18n-aria');
    if (t[key]) el.setAttribute('aria-label', t[key]);
  });
  document.querySelectorAll('[data-i18n-alt]').forEach(el => {
    const key = el.getAttribute('data-i18n-alt');
    if (t[key]) el.setAttribute('alt', t[key]);
  });
  const canvas = document.getElementById('canvas');
  if (canvas && t.canvasFallback) canvas.textContent = t.canvasFallback;

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
  const mb = bytes => (bytes / 1000000).toLocaleString(t.numberLocale, {maximumFractionDigits:1});
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
    if (error) console.error(t.consoleFail, error);
  }

  const stallTimer = setInterval(() => {
    if (finished || failed || Date.now() - lastProgress < 45000) return;
    detail.textContent = navigator.onLine === false ? t.offline : t.takingLonger;
    retry.hidden = false;
  }, 5000);

  async function start() {
    if (typeof Engine !== 'function') {
      fail(t.loadFailed);
      return;
    }
    try {
      const missing = Engine.getMissingFeatures({threads:GODOT_THREADS_ENABLED});
      if (missing.length) {
        fail(t.missingFeatures, missing.join('\n'));
        return;
      }
      const engine = new Engine(GODOT_CONFIG);
      label.textContent = t.loadingVillage;
      await engine.startGame({onProgress(current, total) {
        if (finished || failed) return;
        if (current > received) {lastProgress = Date.now();received = current;retry.hidden = true;}
        if (current >= 0 && total > 0) {
          progress.max = total;
          progress.value = Math.min(current, total);
          percent.textContent = `${Math.floor(Math.min(current / total, 1) * 100)}%`;
          if (current >= total) {
            label.textContent = t.preparingScene;
            detail.textContent = t.filesReceived;
          } else {
            label.textContent = t.downloading;
            detail.textContent = t.receivedMb.replace('{current}', mb(current)).replace('{total}', mb(total));
          }
        } else {
          progress.removeAttribute('value');
          percent.textContent = '';
          detail.textContent = t.firstLoad;
        }
      }});
      if (failed) return;
      finished = true;
      clearInterval(stallTimer);
      overlay.remove();
      byId('canvas').focus({preventScroll:true});
      updateScreenHint();
    } catch (error) {
      fail(t.startFailed, error);
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
      if (!request) throw new Error(t.fullscreenUnavailable);
      await request.call(root);
      updateScreenHint();
      byId('canvas').focus({preventScroll:true});
    } catch (_) {
      byId('screen-status').textContent = t.fullscreenBlocked;
    }
  });
  const script = document.createElement('script');
  script.src = `${GODOT_CONFIG.executable}.js`;
  script.onload = start;
  script.onerror = () => fail(t.downloadFailed);
  document.head.appendChild(script);
})();
