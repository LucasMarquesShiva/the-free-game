/* Download the unchanged Godot binaries as independently cached gzip parts. */
window.ValeDownloads = (() => {
  'use strict';
  const manifest = __VALE_MANIFEST__;
  const nativeFetch = window.fetch.bind(window);
  const hex = bytes => Array.from(new Uint8Array(bytes), n => n.toString(16).padStart(2, '0')).join('');
  async function verify(bytes, expected) {
    if (hex(await crypto.subtle.digest('SHA-256', bytes)) !== expected) {
      throw new Error('Um arquivo do jogo chegou incompleto. Tente novamente.');
    }
  }
  async function start(engine, onProgress) {
    if (typeof DecompressionStream !== 'function') {
      throw new Error('Atualize seu navegador para abrir esta versão do jogo.');
    }
    const progress = new Map();
    const total = Object.values(manifest).flatMap(file => file.parts).reduce((sum, part) => sum + part.downloadSize, 0);
    const report = () => onProgress(Array.from(progress.values()).reduce((sum, size) => sum + size, 0), total);
    const files = new Map(Object.entries(manifest).map(([name, file]) => [new URL(name, document.baseURI).href, file]));
    const pending = new Map();
    const aborter = new AbortController();
    async function download(file) {
      const output = new Uint8Array(file.size);
      let offset = 0;
      for (const part of file.parts) {
        const response = await nativeFetch(new URL(part.url, document.baseURI), {signal:aborter.signal});
        if (!response.ok || !response.body) throw new Error('Não foi possível baixar os arquivos do jogo. Confira sua conexão e tente novamente.');
        const zipped = new Uint8Array(part.downloadSize);
        const reader = response.body.getReader();
        let received = 0;
        while (true) {
          const {value, done} = await reader.read();
          if (done) break;
          if (received + value.length > zipped.length) {await reader.cancel();throw new Error('Arquivo de jogo inválido.');}
          zipped.set(value, received);
          received += value.length;
          progress.set(part.url, received);
          report();
        }
        if (received !== zipped.length) throw new Error('Download interrompido. Tente novamente.');
        await verify(zipped, part.downloadSha256);
        const decoded = new Uint8Array(await new Response(new Blob([zipped]).stream().pipeThrough(new DecompressionStream('gzip'))).arrayBuffer());
        if (decoded.length !== part.size) throw new Error('Tamanho do arquivo de jogo inválido.');
        output.set(decoded, offset);
        offset += decoded.length;
      }
      await verify(output, file.sha256);
      return output;
    }
    const wrappedFetch = async (input, options) => {
      const href = new URL(input instanceof Request ? input.url : input, document.baseURI).href;
      const file = files.get(href);
      if (!file) return nativeFetch(input, options);
      if (!pending.has(href)) pending.set(href, download(file));
      const bytes = await pending.get(href);
      return new Response(bytes, {headers:{'Content-Type':file.type,'Content-Length':String(file.size)}});
    };
    window.fetch = wrappedFetch;
    report();
    try {
      await engine.startGame();
    } finally {
      if (window.fetch === wrappedFetch) window.fetch = nativeFetch;
      aborter.abort();
      pending.clear();
    }
  }
  return {start};
})();
