# Plano de produção visual — versão 1

Plano proposto para transformar a direção visual do jogo em um catálogo consistente e em recursos reutilizáveis na implementação. Este documento não indica que modelos, animações ou sprites de produção já existam. A escolha da engine e da técnica de renderização permanece aberta.

Preferência posterior confirmada pelo usuário: produzir todo o catálogo de desenhos em uma única rodada, sem limitar esta entrega ao lote piloto nem interromper entre categorias para aprovação. A produção conceitual completa está organizada em catalogo-visual-v1. A validação técnica continua sendo uma etapa posterior para modelos e animações de produção.

## Base atual

- 32 tipos de construção descritos em proposta-do-jogo-v1.md, incluindo a vinícola e o centro de treinamento.
- Civis autônomos: ao colocar uma obra, construtores e serventes disponíveis assumem as tarefas. Na falta deles, a obra aguarda com aviso; novos profissionais formados encontram trabalho automaticamente.
- Exército controlado por objetivos.
- Três telas em conceitos-v1 como referência visual. São ilustrações de conceito, não cenas 3D, modelos editáveis ou capturas de uma implementação.

## Ordem recomendada

1. Definir o guia visual e as convenções técnicas.
2. Inventariar todas as peças e suas necessidades de animação e interação.
3. Criar conceitos padronizados de todas as construções e profissões, em grupos pequenos revisados em conjunto.
4. Produzir um pequeno lote de recursos finais e importá-lo em uma cena de teste.
5. Ajustar escala, câmera, animações, materiais e desempenho a partir desse teste.
6. Produzir o restante do catálogo conforme o padrão validado.

O catálogo conceitual pode anteceder o desenvolvimento principal. Finalizar todos os modelos e todas as animações antes de testar a integração aumenta o risco de retrabalho. A cena piloto existe para validar os arquivos e sua apresentação, sem exigir o jogo completo.

## Escolha de representação

Recomendação inicial: modelos 3D estilizados, leves, vistos por uma câmera isométrica com orientação inicial fixa. Personagens compartilham bases e animações quando suas proporções permitem. Edifícios usam componentes separados quando precisam se mover, mudar de estado ou permitir acesso.

Alternativa: imagens 2D renderizadas de modelos 3D, chamadas sprites, com câmera e direções fixas. Nesse caso, as animações e os ângulos são exportados em sequências padronizadas. Alterar a câmera pode exigir novas renderizações, e o conjunto de quadros precisa ser avaliado em memória e legibilidade.

A modelagem 3D como fonte permite avaliar ambas as saídas, mas a mudança entre renderização 3D e sprites ainda exige adaptação e testes. A decisão deve ocorrer antes da produção final em escala.

## Guia visual

Registrar em uma única referência:

- Câmera: projeção, inclinação, orientação e intervalo de aproximação.
- Escala: relação entre morador, porta, carroça, casa e construção grande.
- Linguagem visual: medieval estilizado, telhados terracota, madeira, pedra, vegetação e cores de facção.
- Materiais: grau de detalhe e contraste visíveis no celular.
- Iluminação de apresentação e regras de iluminação da cena do jogo.
- Silhuetas: identificação dos prédios pela função e dos trabalhadores pela roupa, ferramenta e carga.
- Legibilidade: distinguir profissão, equipe e estado também por forma, evitando depender apenas de cor.
- Regras de variação: o que pode mudar em roupas, rostos, fachadas e melhorias sem perder identidade.

A imagem mais bonita isoladamente não define sozinha o padrão. As peças precisam parecer pertencer ao mesmo lugar quando aparecem juntas.

## Inventário de peças

Cada recurso recebe identificador estável, nome, categoria, função, dependências, origem e estado de produção: planejado, conceito, fonte de produção, exportado ou validado na engine. Esses estados não equivalem a autorização de publicação.

Exemplos de identificadores: bld_house, bld_winery, char_servant, char_builder, prop_wine_barrel.

O inventário inclui:

- As 32 famílias de construções, suas melhorias previstas e estados necessários.
- Profissões civis, tropas, apoio militar e variações de aparência.
- Cavalos, porcos e elementos visuais de pesca.
- Ferramentas, armas, escudos, sacos, cestos, barris, carroças e mercadorias.
- Árvores, campos, parreirais, rochas, rios, caminhos, pontes e fortificações modulares.
- Efeitos reutilizáveis: poeira, fumaça, fogo de forno, impactos e indicadores de produção.
- Ícones de construção e profissão, produzidos separadamente da interface e do cenário.

Uma família de construção pode exigir várias peças. Portanto, 32 tipos de construção não significam apenas 32 arquivos.

## Ficha de cada construção

Entregáveis de conceito:

- Vista isométrica principal e vistas de apoio suficientes para esclarecer volumes.
- Tamanho no terreno e relação de escala com um morador.
- Posição da entrada, pontos de entrega, retirada, trabalho e espera.
- Partes móveis ou destacáveis, como pás, portas, prensa e bandeiras.
- Materiais, cores e detalhes que identificam sua função.
- Estados previstos: terreno marcado, obra por etapas, concluída, funcionando e danificada.
- Melhorias previstas e ícone para o menu.

Entregáveis de produção:

- Modelo editável, materiais e texturas.
- Partes móveis separadas e pontos de origem adequados à animação.
- Região ocupada e colisão simples, compatíveis com o acesso de trabalhadores.
- Pontos de interação identificados; os dados do jogo associam esses pontos às tarefas.
- Exportação compatível com a engine escolhida.
- Registro do que foi testado e imagem de comparação no ângulo real do jogo.

Andaimes, danos, cargas e fumaça podem ser componentes compartilhados. Um prédio parado pode usar o mesmo modelo com seus movimentos e efeitos suspensos.

## Ficha de cada personagem

Entregáveis de conceito:

- Frente, lado e costas coerentes entre si.
- Proporções e escala em relação aos outros personagens.
- Roupa e silhueta que identifiquem a profissão.
- Ferramentas, armas e cargas desenhadas separadamente.
- Poses que esclareçam ações características.

Entregáveis de produção:

- Modelo editável, materiais, texturas e preparação para animação.
- Esqueleto de animação compartilhável entre personagens compatíveis.
- Pontos para prender ferramenta, arma, escudo, cesto ou saco.
- Animações comuns: esperar, caminhar, pegar, carregar e depositar.
- Animações profissionais: construir, cortar, semear, colher, assar, forjar ou prensar.
- Animações militares: deslocar, atacar, reagir a impactos, retirar-se e cair, conforme a unidade.
- Estados e transições que evitem mudança brusca de roupa, carga ou posição.

Formação militar e procura de caminho são comportamentos programados; seus movimentos usam animações de locomoção. A animação não decide para onde o personagem vai. Velocidade de caminhada, contato dos pés e pontos de entrega precisam funcionar em conjunto com a simulação.

## Exemplo: vinícola

A vinícola deve ser um conjunto reaproveitável:

- Edificação principal com entrada de serviço.
- Prensa e componentes móveis.
- Fileiras de parreiras modulares, com estados de crescimento e colheita.
- Uvas, cestos e barris separados.
- Posições de trabalho para colher e prensar.
- Ponto de retirada de vinho para serventes.
- Vinhateiro com ações de cultivo, colheita e produção.
- Ícone para o menu e aparência das etapas de obra.

Uma cena de apresentação pode reunir essas peças, mas os arquivos de produção preservam sua separação. Assim, o jogo consegue mudar a quantidade de parreiras, retirar um barril ou mostrar uma colheita acontecendo.

## Convenções e arquivos

Definir antes da produção final: unidade de escala, orientação, posição de origem, tamanho das células do terreno, nomes, organização de materiais, resolução das texturas, convenção de animações e formatos de exportação.

Para uma rota com Blender e Godot, uma possibilidade documentada é manter a fonte editável em .blend e exportar .glb. Godot recomenda glTF 2.0 e aceita .gltf e .glb. Isso é uma opção de fluxo, não uma engine já escolhida.

Se a saída for 2D, preservar também a fonte editável e entregar PNGs com transparência, pontos de ancoragem, dimensões padronizadas e metadados de animação. Sombras e elementos de interface precisam ser tratados de acordo com o padrão visual escolhido.

Separar referências, fontes editáveis, exportações e documentação. Guardar prompts e imagens de referência para rastreabilidade, sem tratar um prompt como substituto do arquivo editável nem como garantia de reprodução idêntica. Registrar origem e condições de uso de qualquer material externo. Manter versões anteriores ao revisar peças.

## Lote piloto e critérios de aceitação

Lote inicial sugerido:

- Casa, armazém e vinícola.
- Servente, construtor e vinhateiro.
- Lanceiro e arqueiro.
- Estrada, árvores, parreiras, madeira, cestos e barris.

A cena piloto deve demonstrar:

- Uma casa recebendo materiais e avançando nas etapas de construção.
- Serventes caminhando, pegando e depositando cargas.
- Um profissional chegando ao prédio e executando seu ofício.
- Crescimento e colheita de uvas, operação da prensa e retirada de vinho.
- Locomoção e ataques das duas tropas.
- Escala e iluminação consistentes em todas as peças.

Verificar em aparelho representativo: reconhecimento no tamanho real da tela, leitura durante movimento, ausência de cargas atravessando corpos, entradas acessíveis, encaixe no terreno, transições de animação e desempenho com quantidade representativa de entidades.

Custos de geometria, texturas e efeitos serão definidos com essas medições. O visual apresentado deve ser comparado ao resultado dentro da engine, e não somente ao render de apresentação.

## Papel das imagens geradas por IA

Podem acelerar a exploração visual e o desenho de referências. Algumas imagens preparadas podem ser aproveitadas como ícones, texturas ou sprites, dependendo da técnica escolhida e da revisão necessária.

Uma imagem de personagem não contém automaticamente um modelo tridimensional, um esqueleto ou animações consistentes. Vistas geradas separadamente também precisam ser conferidas. A produção de modelos, preparação para animação, exportação e validação é uma etapa própria.

## Referência técnica consultada

- Godot, Available 3D formats: https://docs.godotengine.org/en/stable/tutorials/assets_pipeline/importing_3d_scenes/available_formats.html
