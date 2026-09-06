# Texturas de produção — direção do catálogo aprovado

Ferramenta: `image_gen.imagegen`, 05/09/2026. Originais preservados sem recorte nem edição por script. Os shaders selecionam as coordenadas UV do atlas no runtime.

## material-atlas.png

Original: o arquivo original de mesmo nome incluído nesta pasta.
Referências: catálogo `construcoes/01-centro_da_vila.png` e `04-centro_de_treinamento.png`.
Brief de geração: atlas quadrado de materiais de jogo medieval estilizado, quatro quadrantes iguais sem borda nem texto. Pedra cinza fria envelhecida sem grade de blocos no superior esquerdo; carvalho escuro de veio vertical no superior direito; superfície terracota sem desenho de telhas no inferior esquerdo; linho teal escuro sem emblemas no inferior direito. Albedo sem iluminação direcional, textura de superfície pictórica detalhada fiel às pranchas; geometria 3D fornece juntas de pedra e telhas.

## meadow-albedo.png

Original: o arquivo original de mesmo nome incluído nesta pasta.
Referências: `kits/01-terreno_e_vegetacao.png` e `art/conceitos-v1/01-vila.png`.
Prompt: Use case: stylized-concept game terrain production texture. Input 1 is the approved terrain/vegetation art direction, input 2 approved game visual. Create a SINGLE full-bleed square seamless meadow ground albedo, pure top-down orthographic, to wrap a 3D high quality medieval strategy game. No perspective, horizon, UI or floating tile. Rich temperate green grass, soft irregular clumps, moss, fine tiny clover, occasional very small flowers/tiny pebbles, short warm brown soil patches. Match artistic materials, organic richness and colors. High-end handpainted PBR, not a uniform synthetic carpet. Patch about 8×8m so SMALL blades/leaves, fine textured carpet with medium clustering. No large bushes, trees, paths, buildings or whole rocks. Uniform midvalue olive/deep green healthy, avoid lime light, gray fog and noisy triangles. Subtle micro AO allowed, NO directional sun or large cast shadows. Tileable, no borders, text, grid or vignette. Prefer 2048 or larger.

## earth-albedo.png

Ferramenta image_gen.imagegen. Original: o arquivo original de mesmo nome incluído nesta pasta. Referência: kit_01_terreno_e_vegetacao, bloco terra batida. Brief: material albedo quadrado contínuo visto de cima, terra compactada marrom média, grão miúdo, pequenos seixos incrustados e raízes discretas; detalhe em escala de 4×4m; pintura de jogo 3D fiel ao catálogo; sem caminho desenhado, objetos, vegetação grande, perspectiva, sombras direcionais, bordas ou texto.

## water-albedo.png

Ferramenta image_gen.imagegen. Original: o arquivo original de mesmo nome incluído nesta pasta. Referência: os dois rios no kit_01_terreno_e_vegetacao. Brief: textura contínua quadrada, superfície de água de rio vista diretamente de cima; 5×5m, teal/turquesa, pequenas ondulações irregulares e linhas curtas de espuma creme esparsas (<8%); pintura detalhada estilizada igual ao kit; sem margens, pedras, objetos, plantas, horizonte ou perspectiva, sombras fortes, faixas brancas longas, reflexo de lente, bordas ou texto. Deslocamento em duas escalas no shader anima a correnteza.

## previews/*.png

Miniaturas dos próprios modelos 3D, capturadas pela Godot com fundo transparente por `tests/render_approved_previews.gd`. Não representam uma imagem externa substituindo a geometria do jogo. Regerar após alterações de geometria e materiais.
