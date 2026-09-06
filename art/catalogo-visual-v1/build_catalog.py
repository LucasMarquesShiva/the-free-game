from pathlib import Path
import json, html, hashlib, struct, shutil

ROOT = Path(__file__).resolve().parent
MANIFEST = ROOT / 'manifest.json'
LABELS = {'construcoes': 'Construções', 'civis': 'Vida na vila', 'militares': 'Exército', 'kits': 'Mundo e objetos'}

def esc(value):
    return html.escape(str(value), quote=True)

def build():
    manifest = json.loads(MANIFEST.read_text())
    assets = manifest['assets']
    ready = []
    for asset in assets:
        status_path = ROOT / 'status' / (asset['id'] + '.json')
        if status_path.exists():
            status = json.loads(status_path.read_text())
            asset.update({k: v for k, v in status.items() if k != 'id'})
            if status.get('used_prompt'):
                asset['prompt'] = status['used_prompt']
        image_path = ROOT / asset['image']
        if image_path.exists():
            raw = image_path.read_bytes()
            if raw[:8] != b'\x89PNG\r\n\x1a\n':
                raise ValueError(f'Not a PNG: {image_path}')
            asset['width'], asset['height'] = struct.unpack('>II', raw[16:24])
            asset['bytes'] = len(raw)
            asset['sha256'] = hashlib.sha256(raw).hexdigest()
            ready.append(asset)
        asset['sheet'] = 'fichas/' + asset['id'] + '.md'
        task = asset.get('function_pt', asset.get('description', ''))
        md = f"# {asset['name']}\n\nIdentificador: `{asset['id']}` · Categoria: {LABELS[asset['category']]}\n\nPrancha conceitual gerada com a ferramenta nativa de imagens. Não é um modelo 3D, sprite recortado ou animação pronta para a engine.\n\n![{asset['name']}](../{asset['image']})\n\n## Função e referência\n\n{task}\n\n## Arquivos\n\n- [Imagem PNG](../{asset['image']})\n- [Prompt efetivamente utilizado](../{asset['prompt']})\n\n## Uso na produção\n\n"
        if asset['category'] == 'construcoes':
            md += 'Usar a vista principal como referência dominante de aparência. Conferir volumes entre vistas antes de modelar. Definir escala no terreno, colisão, entrada, entrega e pontos de trabalho. Separar mecanismos, andaimes e elementos que mudam de estado. Os construtores e serventes atendem a obra automaticamente; o profissional indicado opera o prédio depois de concluído.\n'
        elif asset['category'] in ('civis', 'militares'):
            md += 'Usar as vistas como referência de roupa, proporção e acessórios. Definir uma malha e esqueleto coerentes antes de animar. Ferramentas e cargas precisam de objetos e pontos de fixação próprios. As poses de ação são referências; não são quadros consecutivos de uma animação.\n'
            if asset['category'] == 'civis':
                md += '\nO personagem recebe tarefas automaticamente conforme sua profissão. O jogador solicita formação no centro de treinamento e não escolhe seu destino individual.\n'
        else:
            md += 'Modelar ou preparar cada componente separadamente. A disposição na prancha organiza referências e não define coordenadas de um atlas de sprites. Padronizar escala, encaixes, pontos de origem e materiais na etapa técnica.\n'
        md += '\n## Revisão visual\n\n' + str(asset.get('qa_notes', 'Revisão em andamento.')) + '\n'
        md += '\n## Limites\n\n' + str(asset.get('limitations', 'Vistas geradas podem conter pequenas diferenças; resolver a geometria e mecanismos na modelagem.')) + '\n'
        (ROOT / asset['sheet']).write_text(md)
    manifest['generated_count'] = len(ready)
    manifest['status'] = 'concept_complete' if len(ready) == len(assets) and all(a.get('status') == 'concept_ready' for a in assets) else 'concept_production'
    MANIFEST.write_text(json.dumps(manifest, ensure_ascii=False, indent=2))
    (ROOT / 'documentos').mkdir(exist_ok=True)
    for source, target in [('proposta-do-jogo-v1.md', 'regras-do-jogo.md'), ('plano-de-producao-visual-v1.md', 'plano-visual.md')]:
        source_path = ROOT.parent / source
        if source_path.exists():
            shutil.copy2(source_path, ROOT / 'documentos' / target)
        elif not (ROOT / 'documentos' / target).exists():
            raise FileNotFoundError(source_path)
    if not (ROOT / 'referencia-vila.png').exists():
        shutil.copy2(ROOT.parent / 'conceitos-v1' / '01-vila.png', ROOT / 'referencia-vila.png')

    cards = []
    for asset in assets:
        image = esc(asset['image'])
        name = esc(asset['name'])
        ident = esc(asset['id'])
        category = asset['category']
        exists = (ROOT / asset['image']).exists()
        media = f'<img src="{image}" alt="Ficha visual de {name}" loading="lazy" decoding="async" width="1536" height="1024">' if exists else '<span class="pending">Prancha em produção</span>'
        cards.append(f'''<article class="card" data-category="{category}" data-name="{name}" data-id="{ident}">
          <button class="preview" type="button" data-image="{image}" data-title="{name}" aria-label="Ampliar {name}" {'disabled' if not exists else ''}>{media}<span class="expand" aria-hidden="true">↗</span></button>
          <div class="card-copy"><span class="eyebrow">{LABELS[category]} · {asset['number']:02d}</span><h3>{name}</h3>
          <div class="card-links"><a href="{image}" download>PNG ↓</a><a href="{esc(asset['sheet'])}">Ficha</a><a href="{esc(asset['prompt'])}">Prompt</a></div></div>
        </article>''')
    buttons = '<button type="button" class="filter active" data-filter="all" aria-pressed="true">Tudo <span>81</span></button>'
    for category, label in LABELS.items():
        count = sum(a['category'] == category for a in assets)
        buttons += f'<button type="button" class="filter" data-filter="{category}" aria-pressed="false">{label} <span>{count}</span></button>'
    page = '''<!doctype html><html lang="pt-BR"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>The Free Game · Catálogo visual</title><style>
    :root{--paper:#f7f3e9;--ink:#193b37;--muted:#69756b;--line:#d8d4c6;--gold:#957643;--white:#fffdf7}*{box-sizing:border-box}body{margin:0;background:var(--paper);color:var(--ink);font-family:system-ui,-apple-system,BlinkMacSystemFont,"Segoe UI",sans-serif}a{color:inherit;text-underline-offset:4px}button,input{font:inherit}button,a,input{touch-action:manipulation}button:focus-visible,a:focus-visible,input:focus-visible{outline:3px solid #a77625;outline-offset:4px}header{padding:26px 5vw 20px;border-bottom:1px solid var(--line);display:flex;align-items:center;justify-content:space-between;gap:24px}.brand{font-size:12px;font-weight:650;letter-spacing:.18em;text-transform:uppercase}.edition{color:var(--muted);font-size:12px;letter-spacing:.1em}main{max-width:1680px;margin:auto;padding:0 5vw}.intro{display:grid;grid-template-columns:1.2fr .8fr;gap:56px;padding:58px 0 44px;align-items:end}h1{font-family:Georgia,"Times New Roman",serif;font-size:clamp(40px,5vw,72px);line-height:1.04;font-weight:400;letter-spacing:-.04em;margin:12px 0 22px}.eyebrow{font-size:10px;font-weight:650;letter-spacing:.14em;text-transform:uppercase;color:var(--muted)}.lede{max-width:610px;font-size:16px;line-height:1.7;color:#50635b}.intro-note{font-size:14px;line-height:1.75;max-width:410px}.intro-note p{margin:0 0 16px}.stat-line{display:flex;gap:25px;border-top:1px solid var(--line);padding-top:20px}.stat-line strong{font-family:Georgia,serif;font-size:32px;font-weight:400;display:block}.stat-line small{font-size:11px;color:var(--muted)}.toolbar{position:sticky;top:0;z-index:2;background:rgba(247,243,233,.97);border-top:1px solid var(--line);border-bottom:1px solid var(--line);display:flex;justify-content:space-between;gap:20px;align-items:center;padding:15px 0;backdrop-filter:blur(8px)}.filters{display:flex;gap:6px;flex-wrap:wrap}.filter{border:0;color:#53675e;background:transparent;padding:11px 13px;cursor:pointer;font-size:12px;border-radius:3px;white-space:nowrap}.filter span{opacity:.6;margin-left:5px;font-size:10px}.filter.active{background:var(--ink);color:var(--white)}.search{position:relative;min-width:210px}.search input{width:100%;background:transparent;border:1px solid #bfc7bd;padding:11px 14px;border-radius:3px;color:var(--ink);font-size:13px}.result-line{display:flex;justify-content:space-between;gap:16px;margin:22px 0;color:var(--muted);font-size:12px}.grid{display:grid;grid-template-columns:repeat(3,minmax(0,1fr));gap:34px 24px;padding-bottom:60px}.card{min-width:0}.card[hidden]{display:none}.preview{display:block;width:100%;padding:0;border:1px solid #e3dccb;background:#fff9ee;cursor:zoom-in;position:relative;aspect-ratio:3/2;overflow:hidden}.preview img{width:100%;height:100%;object-fit:contain;display:block;transition:transform .25s}.preview:hover img{transform:scale(1.025)}.expand{position:absolute;right:10px;bottom:9px;background:var(--white);border:1px solid var(--line);padding:2px 7px;font-size:17px;opacity:0;transition:opacity .2s}.preview:hover .expand,.preview:focus-visible .expand{opacity:1}.card-copy{padding-top:15px}.card h3{font-family:Georgia,serif;font-size:23px;line-height:1.15;font-weight:400;margin:7px 0 14px}.card-links{display:flex;gap:17px;font-size:11px;color:#627265}.card-links a:first-child{color:var(--ink)}.pending{display:grid;place-items:center;height:100%;color:var(--muted)}.empty{padding:80px 0;text-align:center;font-size:17px;color:var(--muted)}footer{padding:26px 5vw;border-top:1px solid var(--line);display:flex;justify-content:space-between;gap:24px;font-size:12px;line-height:1.7;color:var(--muted)}footer nav{display:flex;gap:20px;flex-wrap:wrap}dialog{padding:0;border:0;background:var(--paper);color:var(--ink);width:min(1450px,96vw);max-height:96vh;box-shadow:0 24px 120px #0006}dialog::backdrop{background:#10211fed;backdrop-filter:blur(5px)}.modal-bar{display:flex;align-items:center;justify-content:space-between;padding:14px 20px;border-bottom:1px solid var(--line);gap:18px}.modal-bar h2{font-family:Georgia,serif;font-size:25px;font-weight:400;margin:0}.modal-controls{display:flex;align-items:center;gap:12px}.modal-controls button{background:transparent;border:1px solid #c3cbbf;border-radius:3px;color:var(--ink);width:40px;height:36px;cursor:pointer}.modal-controls a{font-size:12px;white-space:nowrap}.modal-image{display:block;max-width:100%;max-height:calc(96vh - 68px);height:auto;width:auto;margin:auto;object-fit:contain}.sr-only{position:absolute;width:1px;height:1px;padding:0;margin:-1px;overflow:hidden;clip:rect(0,0,0,0);white-space:nowrap;border:0}
    @media(min-width:1700px){.grid{grid-template-columns:repeat(4,minmax(0,1fr))}}@media(max-width:1000px){.toolbar{align-items:stretch;flex-direction:column;gap:10px}.search{max-width:none}.intro{gap:28px}.grid{grid-template-columns:repeat(2,minmax(0,1fr))}}@media(max-width:640px){header{padding-top:20px;padding-bottom:20px}.edition{display:none}.intro{grid-template-columns:1fr;padding:35px 0 25px;gap:12px}.intro-note{max-width:none}.stat-line{gap:28px}h1{font-size:46px}.lede{font-size:14px}.grid{grid-template-columns:1fr;gap:30px}.filter{padding:9px 8px;font-size:11px}.toolbar{position:static}.card h3{font-size:25px}.modal-bar{align-items:flex-start;padding:12px}.modal-bar h2{font-size:19px}.modal-controls{gap:5px}.modal-controls a{display:none}footer{flex-direction:column}}@media(prefers-reduced-motion:reduce){*{transition:none!important}}@media print{header,.toolbar,.intro-note,footer,.card-links,.result-line{display:none}.intro{display:block;padding:0}h1{font-size:30px}.grid{grid-template-columns:repeat(2,1fr);gap:20px}.card{break-inside:avoid}.preview{border:0}.card h3{font-size:16px}.card-copy{padding-top:4px}body{background:white}main{padding:0}}
    </style></head><body><header><div class="brand">Vila medieval · Arquivo visual</div><div class="edition">VOLUME 01 / CONCEITOS</div></header><main><section class="intro"><div><span class="eyebrow">Construções, habitantes e um mundo em movimento</span><h1>The Free Game</h1><p>Lucas Marques, from Shiva</p><p class="lede">O catálogo visual do jogo: casas que crescem, ofícios que dão vida às ruas e um exército que se organiza por objetivos.</p></div><div class="intro-note"><p>Cada prancha reúne referências para a futura modelagem: vistas, poses, etapas de construção ou componentes separados.</p><p>São desenhos conceituais. Modelos 3D, animações e integração ao jogo serão produzidos a partir destas referências.</p><div class="stat-line"><div><strong>32</strong><small>construções</small></div><div><strong>41</strong><small>personagens</small></div><div><strong>8</strong><small>kits de mundo</small></div></div></div></section><section class="toolbar" aria-label="Filtrar catálogo"><div class="filters">__FILTERS__</div><label class="search"><span class="sr-only">Buscar pelo nome</span><input id="search" type="search" placeholder="Buscar vinícola, servente…" autocomplete="off"></label></section><div class="result-line"><span id="results" aria-live="polite">81 pranchas</span><span>Toque em uma imagem para ampliar</span></div><section id="grid" class="grid" aria-label="Pranchas conceituais">__CARDS__</section><p class="empty" id="empty" hidden>Nenhuma prancha encontrada. Tente outro nome.</p></main><footer><span>Catálogo conceitual · Geração de imagens integrada<br>Fontes, prompts e observações preservados por peça.</span><nav><a href="README.md">Guia do catálogo</a><a href="documentos/regras-do-jogo.md">Regras do jogo</a><a href="documentos/plano-visual.md">Plano visual</a><a href="manifest.json">Inventário</a></nav></footer><dialog id="viewer" aria-labelledby="viewer-title"><div class="modal-bar"><h2 id="viewer-title"></h2><div class="modal-controls"><a id="download" href="#" download>Baixar PNG ↓</a><button id="prev" type="button" aria-label="Prancha anterior">←</button><button id="next" type="button" aria-label="Próxima prancha">→</button><button id="close" type="button" aria-label="Fechar ampliação">×</button></div></div><img id="viewer-image" class="modal-image" alt=""></dialog><script>
    const cards=[...document.querySelectorAll('.card')],filters=[...document.querySelectorAll('.filter')],search=document.querySelector('#search'),viewer=document.querySelector('#viewer'),large=document.querySelector('#viewer-image');let category='all',current=null;const normalize=s=>s.normalize('NFD').replace(/[\u0300-\u036f]/g,'').toLowerCase();function apply(){const q=normalize(search.value.trim());let count=0;cards.forEach(card=>{const show=(category==='all'||card.dataset.category===category)&&normalize(card.dataset.name+' '+card.dataset.id).includes(q);card.hidden=!show;if(show)count++});document.querySelector('#results').textContent=count+(count===1?' prancha':' pranchas');document.querySelector('#empty').hidden=count>0}filters.forEach(button=>button.addEventListener('click',()=>{category=button.dataset.filter;filters.forEach(b=>{const selected=b===button;b.classList.toggle('active',selected);b.setAttribute('aria-pressed',String(selected))});apply()}));search.addEventListener('input',apply);function show(button){current=button;large.src=button.dataset.image;large.alt='Prancha de '+button.dataset.title;document.querySelector('#viewer-title').textContent=button.dataset.title;document.querySelector('#download').href=button.dataset.image;if(!viewer.open)viewer.showModal()}document.querySelectorAll('.preview:not([disabled])').forEach(button=>button.addEventListener('click',()=>show(button)));function move(direction){const visible=cards.filter(c=>!c.hidden).map(c=>c.querySelector('.preview')).filter(b=>!b.disabled);if(!visible.length)return;const i=visible.indexOf(current);show(visible[(i+direction+visible.length)%visible.length])}document.querySelector('#prev').addEventListener('click',()=>move(-1));document.querySelector('#next').addEventListener('click',()=>move(1));document.querySelector('#close').addEventListener('click',()=>viewer.close());viewer.addEventListener('click',e=>{if(e.target===viewer)viewer.close()});viewer.addEventListener('keydown',e=>{if(e.key==='ArrowLeft'){e.preventDefault();move(-1)}if(e.key==='ArrowRight'){e.preventDefault();move(1)}});viewer.addEventListener('close',()=>{if(current)current.focus()});apply();
    </script></body></html>'''
    page = page.replace('__FILTERS__', buttons).replace('__CARDS__', '\n'.join(cards))
    (ROOT / 'catalogo.html').write_text(page)
    readme = '# The Free Game — catálogo visual\n\n[ABRIR CATÁLOGO NAVEGÁVEL](catalogo.html)\n\n32 construções, 29 personagens civis, 12 militares e 8 kits de cenário e objetos: 81 pranchas planejadas.\n\nEste pacote contém desenhos conceituais gerados com a ferramenta nativa de imagens, acompanhados de prompts e fichas. Não contém modelos 3D, esqueletos ou animações de produção. As imagens de referência não são arquivos prontos para importação como personagens ou prédios animados.\n\n## Como usar\n\n1. Abra catalogo.html para filtrar, buscar e ampliar as imagens. Funciona localmente, sem serviço externo.\n2. Consulte a ficha de cada peça para sua função e observações.\n3. Use as imagens como referência para modelagem e animação. Resolva eventuais diferenças entre vistas na fonte editável.\n4. Preserve os identificadores do manifest.json para conectar arte, regras e arquivos futuros.\n\nAs funções civis são autônomas: construtores e serventes atendem obras automaticamente; profissionais formados procuram suas tarefas. O centro de treinamento forma novas pessoas por profissão e quantidade.\n\n## Conteúdo\n\n'
    for cat, label in LABELS.items():
        readme += '### ' + label + '\n\n'
        for a in assets:
            if a['category'] == cat:
                readme += f"- [{a['name']}]({a['image']}) · [ficha]({a['sheet']}) · [prompt]({a['prompt']})\n"
        readme += '\n'
    readme += '## Preparação posterior\n\nOs próximos arquivos de produção serão modelos editáveis, texturas, pontos de interação, esqueletos e animações. Dimensões de terreno, desempenho e fidelidade das vistas precisam de validação na engine. Os kits são bibliotecas visuais, não atlas recortados. As poses representam ações e não uma sequência temporal de quadros.\n\nA referência original está em referencia-vila.png. Regras e plano visual estão em documentos/. Os arquivos, revisões e notas de QA estão registrados no manifest.json.\n'
    if manifest['status'] == 'concept_complete':
        readme = readme.replace('81 pranchas planejadas.', '81 pranchas concluídas e revisadas.')
    (ROOT / 'README.md').write_text(readme)
    print(json.dumps({'generated': len(ready), 'expected': len(assets), 'status': manifest['status'], 'bytes': sum(a.get('bytes', 0) for a in assets)}, ensure_ascii=False))

if __name__ == '__main__':
    build()
