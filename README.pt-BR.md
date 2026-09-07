# The Free Game

**Lucas Marques, from Shiva**

Jogo aberto de construção de uma vila medieval. Você planeja estradas e
construções e forma profissionais; os moradores trabalham de forma autônoma.

[Jogar no navegador](https://vale-dos-vinhedos.lucas579686.chatgpt.site/) ·
[English](README.md) · [简体中文](README.zh-CN.md) · [Como contribuir](CONTRIBUTING.md)

## Abrir no seu computador

1. Clique em **Code → Download ZIP** neste repositório e extraia a pasta.
2. Instale o **Godot 4.7.2**, versão padrão, pela
   [página oficial](https://github.com/godotengine/godot-builds/releases/tag/4.7.2-stable).
3. No Godot, clique em **Importar** e selecione `game/project.godot`.
4. Aguarde a importação dos recursos e pressione **F5**.

O código, as imagens usadas no jogo, os modelos procedurais, as artes originais
e os testes estão aqui. Não é necessário contratar serviço, gerar novas imagens,
conectar uma conta ou usar uma chave de inteligência artificial para jogar ou editar.

## Rodar e exportar por comandos

Instale Python 3.10 ou superior para usar os atalhos opcionais abaixo.
No Windows, pode usar `py` no lugar de `python`; no macOS/Linux, `python3`.

```sh
python tools/dev.py doctor
python tools/dev.py run
python tools/dev.py test
python tools/dev.py export-web
python tools/dev.py serve --port 8000
```

Se o Godot não for encontrado, acrescente `--godot "caminho/do/Godot"` ao comando.
Para exportar, instale os modelos de exportação 4.7.2 no próprio editor.
O jogo para navegador será gerado em `builds/web/`. Depois de iniciar o servidor,
abra `http://127.0.0.1:8000/`.

Para publicar sua versão, envie **todo o conteúdo** de `builds/web/` para uma
hospedagem estática HTTPS compatível com o tamanho dos arquivos.
[Instruções de publicação](docs/WEB.md).

## O que esta versão oferece

A beta começa com o prédio principal, a escola de instrutores, uma praça e
moradores. Há estradas construídas pelo jogador, entrega autônoma de materiais,
formação de profissionais, horta com crescimento visível, vinhedos e vinícola.
Todas as construções precisam de madeira e pedra. Moradores desocupados voltam
à praça. O progresso é salvo localmente no navegador ou no aplicativo.

Esta versão foi feita para computador. Ainda não tem exército, multijogador,
salvamento na nuvem ou suporte completo a controles de celular. As artes
conceituais também mostram ideias que ainda não foram implementadas.

## Onde mexer

- `game/simulation/`: economia, estradas e comportamento dos moradores.
- `game/presentation/`: cenário, modelos 3D, personagens e animação.
- `game/ui/`: interface, formação e menus.
- `game/assets/`: imagens, texturas e recursos usados no jogo.
- `art/`: desenhos originais, referências e especificações visuais.
- `docs/ARCHITECTURE.md`: mapa do código.
- `docs/CUSTOMIZING.md`: primeiros exemplos de alteração.

## Liberdade para criar

Código, ferramentas e documentação estão sob **MIT**. Artes originais estão
sob **CC BY 4.0**. É permitido modificar, distribuir e usar comercialmente,
respeitando essas licenças. Preserve o aviso MIT no código e dê às artes o crédito
**Lucas Marques, from Shiva**, com link da CC BY 4.0 e indicação das alterações.

Veja [LICENSE](LICENSE), [LICENSE-ASSETS.md](LICENSE-ASSETS.md) e
[avisos de dependências](THIRD_PARTY_NOTICES.md). Parte das artes foi gerada com IA.

[Browse the original art catalog / Abrir o catálogo de artes](art/catalogo-visual-v1/catalogo.html) — download the repository and open this HTML locally.
