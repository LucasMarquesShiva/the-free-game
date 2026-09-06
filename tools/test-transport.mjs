import assert from 'node:assert/strict';
import fs from 'node:fs';
import vm from 'node:vm';
import {gzipSync} from 'node:zlib';
import {webcrypto, createHash} from 'node:crypto';

const hash = data => createHash('sha256').update(data).digest('hex');
const plain = new TextEncoder().encode('A mesma vila, sem alterar os arquivos originais.');
const chunks = [plain.slice(0,17),plain.slice(17)];
const packed = chunks.map(data=>gzipSync(data));
const manifest = {'index.wasm':{size:plain.length,sha256:hash(plain),type:'application/wasm',parts:chunks.map((part,i)=>({url:`part-${i}.gz`,size:part.length,downloadSize:packed[i].length,downloadSha256:hash(packed[i])}))}};
const source = fs.readFileSync(new URL('transport.js',import.meta.url),'utf8').replace('__VALE_MANIFEST__',JSON.stringify(manifest));

async function run(corrupt = false, missing = false) {
  const original = async input => {
    const url = String(input);
    const match = /part-(\d).gz$/.exec(url);
    if (!match) return new Response('passthrough');
    if (missing) return new Response('missing',{status:404});
    const bytes = Uint8Array.from(packed[Number(match[1])]);
    if (corrupt) bytes[bytes.length-1] ^= 1;
    return new Response(bytes);
  };
  const window = {fetch:original};
  vm.runInNewContext(source,{window,document:{baseURI:'https://test.invalid/'},URL,Request,Response,Blob,DecompressionStream,AbortController,crypto:webcrypto,Uint8Array});
  let received = 0, total = 0;
  const engine = {async startGame(){
    assert.equal(await (await window.fetch('other')).text(),'passthrough');
    const response = await window.fetch('index.wasm');
    assert.equal(response.headers.get('content-type'),'application/wasm');
    assert.deepEqual(new Uint8Array(await response.arrayBuffer()),plain);
  }};
  try {
    await window.ValeDownloads.start(engine,(value,expected)=>{assert.ok(value>=received);received=value;total=expected;});
    assert.equal(received,total);
  } finally {
    assert.notEqual(window.fetch,undefined);
    assert.equal(await (await window.fetch('other')).text(),'passthrough');
  }
}
await run();
await assert.rejects(run(true),/incompleto/);
await assert.rejects(run(false,true),/baixar/);
console.log('PASS: restored bytes, real progress, unrelated fetch, corrupted download, missing download.');
