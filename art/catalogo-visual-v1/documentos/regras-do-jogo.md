# Proposta do jogo — versão 1

Documento de concepção. As regras abaixo são propostas para um jogo original; ainda não representam funcionalidades implementadas. As três imagens em conceitos-v1 são referências de direção visual. Custos, tempos, capacidades, distâncias e força das unidades precisam de balanceamento em protótipos.

Definições confirmadas pelo usuário: incluir a vinícola; manter todos os civis autônomos, sem direcionamento ou alocação individual; iniciar obras automaticamente com construtores e serventes disponíveis; avisar quando faltarem profissionais disponíveis; permitir esperar ou formar mais profissionais no centro de treinamento. Apenas o exército recebe ordens de destino e objetivos.

## Identidade e papel do jogador

Jogo de construção de vilas, economia e guerra em tempo real para celular na horizontal. O jogador governa: escolhe construções, estradas, formação de profissionais no centro de treinamento e objetivos militares. Os civis encontram e assumem suas tarefas automaticamente, sem que o jogador precise selecionar pessoas, atribuir funcionários a prédios ou determinar destinos. Prioridades econômicas são ajustes opcionais. Os habitantes trabalham, transportam, comem e descansam autonomamente. O exército recebe objetivos e organiza sua execução conforme os limites de risco.

A experiência deve tornar agradável observar a vila: árvores sendo cortadas, carrinhos nas estradas, trigo colhido, moinhos girando, pão saindo do forno e soldados marchando até seus pontos de reunião. Construções e ocupações precisam ser reconhecíveis pela silhueta, ferramentas e animações.

O ciclo principal é: estabelecer alimentos e materiais → ampliar moradores e ofícios → gerar excedentes e equipamentos → explorar e proteger território → acessar recursos e novos desafios.

## Catálogo de construções

Os insumos abaixo são de funcionamento. Erguer e melhorar cada edifício exige materiais entregues ao canteiro e trabalho de construtores. Existem 32 tipos principais; estradas, pontes, campos, parreirais e elementos decorativos são estruturas complementares.

### Administração e logística

| Nº | Construção | Aparência e função | Funcionários |
|---|---|---|---|
| 1 | Centro da vila | Paço com relógio, bandeiras e praça. Reúne prioridades, população, progresso e avisos. Começa como sede modesta. | Administrador |
| 2 | Casas | Moradias de madeira, depois pedra, com jardins. Oferecem vagas e descanso; precisam ser acessíveis. | Sem funcionário exclusivo |
| 3 | Armazém | Galpão com caixas, sacos e pátio. Guarda recursos físicos, aceita filtros e mantém estoques reservados. | Transportadores |
| 4 | Centro de treinamento | Oficina de aprendizagem com bancadas. O jogador solicita a profissão e a quantidade, inclusive construtores e serventes. O centro seleciona moradores disponíveis e forma os profissionais; ao concluir, eles procuram trabalho automaticamente. | Instrutor |
| 5 | Mercado | Praça com barracas e chegada de carroças. Troca excedentes por recursos de parceiros comerciais; a entrega depende da viagem. | Mercador |

### Madeira, pedra e metal

| Nº | Construção | Produção e identidade visual | Funcionários |
|---|---|---|---|
| 6 | Cabana do lenhador | Área de trabalho entre árvores. Corta árvores maduras para obter troncos e replanta dentro da zona definida. | Lenhador |
| 7 | Serraria | Serra, bancada e pilhas de madeira. Transforma troncos em tábuas. | Serrador |
| 8 | Pedreira | Frente de corte junto a uma jazida. Extrai blocos de pedra. | Canteiro |
| 9 | Carvoaria | Fornos baixos com fumaça. Transforma troncos em carvão vegetal. | Carvoeiro |
| 10 | Mina de ferro | Entrada escorada, carrinhos e minério aparente. Extrai minério de ferro de uma jazida. | Mineiro |
| 11 | Fundição | Fornalha e metal incandescente. Transforma minério e carvão em barras de ferro. | Fundidor |

### Alimentação

| Nº | Construção | Produção e identidade visual | Funcionários |
|---|---|---|---|
| 12 | Horta | Canteiros próximos à casa do trabalhador. Produz legumes em ciclos curtos. | Horticultor |
| 13 | Fazenda de cereais | Celeiro e campos anexos. Semeia, cultiva e colhe trigo; área maior exige mais trabalho e transporte. | Agricultor |
| 14 | Moinho | Construção alta com pás em movimento. Transforma trigo em farinha. | Moleiro |
| 15 | Padaria | Forno, chaminé e cestos na porta. Consome farinha e madeira como combustível para produzir pão. | Padeiro |
| 16 | Cabana do pescador | Pequeno cais com redes. Produz peixe em áreas de pesca, com reposição limitada do estoque natural. | Pescador |
| 17 | Criação de porcos | Chiqueiros e cochos. Consome trigo para criar animais destinados ao açougue. | Criador |
| 18 | Açougue | Bancadas e depósito coberto. Recebe animais e produz carne e peles. | Açougueiro |
| 19 | Taverna | Salão com mesas e cozinha visível. Serve alimentos e prepara peixe e carne; produz rações transportáveis para viagens e guerra. Recebe vinho da vinícola para servir como bebida. | Cozinheiro |
| 20 | Vinícola | Casa de pedra com prensa, adega e barris, ligada a parreirais desenhados no terreno. O vinhateiro cultiva e colhe uvas, depois as transforma em vinho. Serventes retiram a produção e abastecem a taverna, o armazém ou o mercado. | Vinhateiro |

### Manufatura e recuperação

| Nº | Construção | Produção e identidade visual | Funcionários |
|---|---|---|---|
| 21 | Curtume | Tanques e peles estendidas. Transforma peles em couro. | Curtidor |
| 22 | Carpintaria | Bancadas, rodas e armas de madeira. Fabrica bastões, arcos, escudos simples e carroças; receitas avançadas de bestas e caixas de munição usam ferro e/ou couro além de tábuas. | Carpinteiro |
| 23 | Forja de armas | Bigorna e forja aberta. Fabrica lanças e espadas com ferro, carvão e componentes de madeira conforme a receita. | Ferreiro |
| 24 | Oficina de armaduras | Bancadas e suportes com equipamentos. Produz proteção leve com couro e proteção pesada com ferro, carvão e couro. | Armeiro |
| 25 | Enfermaria | Edifício claro com jardim e leitos. Usa alimentação, atendimento e tempo para recuperar feridos. | Curandeiro |

### Exército e defesa

| Nº | Construção | Função e identidade visual | Funcionários |
|---|---|---|---|
| 26 | Quartel | Alojamento e pequeno pátio. Recebe moradores, alimentos e equipamento; treina soldados e organiza as primeiras companhias. | Instrutor militar |
| 27 | Estábulo | Baias e cercado. Cria e treina cavalos; consome trigo como alimentação. | Tratador |
| 28 | Oficina de cerco | Pátio largo com estruturas em montagem. Fabrica aríetes e catapultas usando tábuas, ferro e couro; catapultas usam pedra como munição. | Engenheiro militar |
| 29 | Posto de comando | Tenda ou torre com mesa de mapas. Ajuda a organizar operações com várias companhias, pontos de reunião e reservas militares. As ordens básicas já existem no quartel. | Oficial |
| 30 | Acampamento avançado | Tendas e depósito protegido fora da vila. Recebe rações, munição e equipamentos; oferece descanso e reabastecimento próximos ao objetivo. Não produz recursos. | Intendentes |
| 31 | Torre de vigia | Torre de madeira ou pedra com plataforma elevada. Amplia a observação e protege acessos quando ocupada por soldados. | Guarnição destacada do exército |
| 32 | Fortificações | Família de paliçadas, muralhas e portões. Cria barreiras físicas e passagens controladas; exige reparos após danos. | Construtores e engenheiros nos reparos |

Estruturas complementares: caminhos de terra, estradas de pedra, pontes, campos agrícolas, parreirais, cercas e decoração. Estradas melhores aumentam a capacidade de transporte. Pontes têm acesso e capacidade limitados. Campos, parreirais e zonas de corte/replantio são desenhados no terreno. Jardins, bancos e bandeiras dão identidade visual sem criar uma obrigação econômica adicional.

## Personagens civis

Cada profissional listado nas construções é uma pessoa visível com nome, ocupação, destino, fome, energia, saúde e experiência no ofício. Variações de aparência dão identidade sem transformar todos em personagens que exigem gerenciamento individual.

- Morador disponível: ocupa uma casa e pode assumir um ofício ou ser recrutado.
- Transportador, equivalente ao servente: busca e entrega mercadorias entre construções, obras e depósitos. É uma profissão compartilhada pela vila.
- Carroceiro: especialização de transporte para cargas maiores e rotas apropriadas. Usa carroças produzidas na carpintaria; carroças de mão atendem trajetos curtos, e rotas de carga maiores podem usar cavalos.
- Construtor: integra a equipe compartilhada que prepara terrenos, ergue, melhora e repara edifícios.
- Produtores e artesãos: os lenhadores, serradores, canteiros, carvoeiros, mineiros, fundidores, horticultores, agricultores, moleiros, padeiros, pescadores, criadores, açougueiros, cozinheiros, vinhateiros, curtidores, carpinteiros, ferreiros e armeiros das tabelas.
- Serviços: administrador, instrutor, mercador, curandeiro, instrutor militar e tratador.

O jogador solicita formação por profissão e quantidade no centro de treinamento, por exemplo, “Formar 2 construtores” ou “Formar 3 serventes”. Não escolhe quais moradores estudarão nem a obra ou prédio a que cada profissional será destinado. O centro seleciona candidatos disponíveis; ao terminar a formação, cada profissional entra automaticamente no conjunto de trabalhadores disponíveis de seu ofício. Experiência melhora eficiência de forma moderada.

Cada construção tem sua capacidade de funcionários definida pelo tipo e pela melhoria. Ao ficar pronta, um profissional compatível disponível assume o trabalho automaticamente. Construtores e serventes atendem a vila inteira por uma fila de tarefas. Se faltar um especialista, o prédio aguarda e informa qual profissão precisa ser formada. Inspecionar um civil apenas mostra sua situação; não oferece comandos individuais de deslocamento ou trabalho.

## Personagens militares

| Unidade | Equipamento e função | Decisões autônomas típicas |
|---|---|---|
| Miliciano | Bastão e escudo simples. Defesa inicial barata, com treinamento básico. | Protege acessos e apoia a linha; busca abrigo quando superado. |
| Lanceiro | Lança e proteção leve. Contém cavalaria e segura passagens. | Forma linha e cobre tropas de alcance. |
| Espadachim | Espada, escudo e armadura. Infantaria resistente para tomar e manter posições. | Sustenta o combate e protege flancos. |
| Arqueiro | Arco e munição. Apoio de longo alcance, vulnerável de perto. | Procura distância de tiro e recua atrás da infantaria. |
| Besteiro | Besta, proteção e munição. Disparo mais lento e forte contra alvos protegidos. | Prioriza ameaças adequadas e busca tempo seguro para recarregar. |
| Cavaleiro | Cavalo treinado, arma e armadura. Mobilidade, perseguição e flanqueamento. | Explora flancos expostos e evita cargas contra lanças preparadas. |
| Batedor | Equipamento simples, pouca proteção. Exploração e reconhecimento. | Observa, avisa e evita confrontos desfavoráveis. |
| Engenheiro militar | Ferramentas e acesso a equipamento de cerco. Monta, opera e repara máquinas e posições. | Trabalha sob proteção e recolhe-se diante de ameaças próximas. |
| Socorrista | Formação na enfermaria. Retira e atende feridos. | Só se aproxima quando existe acesso suficientemente seguro e encaminha feridos aos leitos. |
| Intendente | Carroça e carga. Liga armazéns, acampamentos e companhias. | Busca suprimentos disponíveis, avisa sobre rotas interrompidas e solicita escolta. |

Capitão é uma função de um soldado experiente dentro da companhia. Oficial é a função de coordenação no posto de comando. Não são unidades que criam recursos ou garantem decisões perfeitas.

Recrutas deixam suas atividades civis e precisam receber o equipamento fisicamente. Feridos continuam ocupando população. Desmobilização permite retornar à economia após o deslocamento e a devolução do equipamento. Mortes são permanentes; armas abandonadas só retornam ao estoque quando recuperadas.

## Economia e transporte

As principais cadeias são:

- Árvores → troncos → tábuas → construções, carroças e equipamentos.
- Troncos → carvão; minério + carvão → ferro → armas e armaduras.
- Trigo → farinha → pão → alimentação e rações.
- Trigo → porcos → carne + peles → alimentação + couro.
- Couro → proteção leve e componentes de equipamentos.
- Trigo → cavalos → cavalaria e transporte.
- Parreirais → uvas → vinho → taverna ou comércio, com armazenamento quando necessário.
- Tábuas + ferro → caixas de munição; pedra → munição de catapultas.

Cada prédio mantém estoques pequenos de entrada e saída. A produção depende de funcionário, matéria-prima e espaço livre. Mercadorias podem ir diretamente do produtor ao consumidor. O armazém é um local de reserva, não uma parada obrigatória.

Pedidos de transporte reservam a carga e a vaga de destino para evitar entregas duplicadas. A escolha do serviço considera urgência, distância, capacidade do veículo e acesso. Trabalhadores contornam obstáculos e filas; se não houver caminho, o jogo informa o bloqueio.

Limites de produção, prioridades, estoques mínimos e cotas para exportação ou guerra são ajustes opcionais sobre regras automáticas de funcionamento. Eles não exigem escolher, alocar ou dirigir civis. A interface mostra recursos locais, reservados e em trânsito. Um número total alto não garante que a mercadoria esteja perto da construção que precisa dela.

Para esta proposta, água e desgaste de ferramentas não são cadeias econômicas separadas. Materiais de atendimento médico são abstraídos no funcionamento da enfermaria. A munição é controlada em caixas e reservas das companhias, sem exigir gerenciamento de cada flecha. O comércio funciona por troca de mercadorias.

## Construção, população e rotina

A partida começa com moradores, construtores e serventes já formados, os profissionais essenciais, uma sede, um depósito, alojamento e um centro de treinamento provisório funcional. Há reservas suficientes para iniciar madeira, pedra e alimentação. Assim, formar novos construtores ou serventes nunca depende de primeiro formar alguém da mesma profissão para construir ou ativar o centro.

Uma obra passa por marcação, acesso, entrega de materiais e trabalho visível de construção. Edificações básicas utilizam madeira; as mais robustas também exigem pedra e componentes avançados. Melhorias modificam o modelo e aumentam capacidade ou opções. Prédios danificados podem ser reparados.

### Autonomia civil e fila de obras

1. O jogador coloca uma casa ou outra construção no mapa. A colocação já cria a obra e os pedidos de trabalho; não há uma etapa de selecionar trabalhadores.
2. Construtores livres assumem as etapas de preparação e construção. Serventes livres buscam e entregam os materiais. Cada um se desloca sozinho, e a construção respeita as dependências de materiais e preparação.
3. Se todos os profissionais de uma categoria estiverem ocupados, a obra fica pendente com um aviso, como “Todos os construtores estão ocupados” ou “Aguardando serventes disponíveis”. Se não houver profissionais formados da categoria, o aviso explica essa falta.
4. O jogador pode esperar ou solicitar mais construtores ou serventes no centro de treinamento. Esperar é uma opção válida: a obra permanece na fila, sem exigir confirmação para retomar.
5. Quando profissionais terminam tarefas anteriores ou concluem treinamento, assumem automaticamente os serviços pendentes compatíveis. A ordem de colocação é o padrão da fila; uma obra bloqueada por falta de materiais ou acesso não impede o atendimento das demais.
6. Falta de recursos, acesso bloqueado e indisponibilidade de trabalhadores têm avisos distintos. Avisos persistentes são agrupados para não repetir a mesma interrupção a cada tentativa.

Esse princípio também vale para abastecimento, reparos, cultivo, colheita e operação dos prédios. O jogador cria a necessidade construindo e forma mais profissionais quando desejar; a distribuição do trabalho é automática.

Os habitantes alternam trabalho, refeições e descanso. Pão ou legumes garantem alimentação básica, inclusive pelo armazém em uma emergência. A taverna amplia as opções, cozinha carnes e peixes e prepara rações. Variedade melhora satisfação e recuperação.

Moradia livre, segurança e excedente alimentar sustentado atraem novos moradores. Solicitações no centro de treinamento dependem de candidatos disponíveis e tempo de formação. Se faltarem candidatos, a fila informa o motivo. Recrutar muitos soldados reduz produção e transporte.

O jogador vê o motivo de qualquer interrupção: falta de funcionário, falta de farinha, estoque cheio, estrada bloqueada ou descanso. Ao inspecionar uma pessoa, vê sua tarefa e destino.

## Comando militar por objetivos

As companhias agrupam tropas e apoio. O jogador define a composição desejada, o objetivo no mapa e a postura:

- Preservar tropas: menor tolerância ao risco e retirada mais cedo.
- Equilibrada: combina avanço, proteção e conservação de reservas.
- Pressionar: aceita mais desgaste para cumprir o objetivo.

Ordens disponíveis: conquistar, defender, patrulhar, escoltar, interromper abastecimento, reagrupar e recuar. Uma ordem pertence à companhia ou operação; o usuário não precisa dirigir soldados um por um.

A autonomia usa somente informações observadas. Considera caminhos transitáveis, coesão, composição dos dois lados conhecidos, terreno, distância de tiro, saúde, cansaço, moral, munição e acesso a apoio. Arqueiros procuram proteção, lanceiros seguram acessos e cavaleiros exploram oportunidades de flanco.

O comandante pode aguardar uma formação, mudar a aproximação, pedir apoio ou suspender o avanço. Não muda livremente o objetivo estratégico para perseguir qualquer alvo. Limites de perseguição e tolerância ao risco vêm da ordem.

Mensagens curtas explicam decisões: “Arqueiros dando cobertura”, “Aguardando suprimentos”, “Passagem bloqueada” e “Recuando: perdas elevadas”. Ordens inviáveis permanecem pendentes com um motivo visível. A autonomia deve ser confiável e compreensível, mas pode ser surpreendida por inimigos e emboscadas.

## Combate, perdas e abastecimento

O combate considera alcance, posição, formação, proteção, terreno e condição da tropa. Fortificações bloqueiam acesso; arqueiros precisam de oportunidades de tiro; máquinas de cerco exigem operação e transporte. Superioridade numérica ajuda, mas terreno e suprimentos também contam.

Companhias levam reservas limitadas de rações e munição. Cavalos consomem alimento. Intendentes transportam reposições a partir da vila ou do acampamento avançado. Cortar uma rota enfraquece o exército mesmo quando o armazém distante está cheio.

Fome, cansaço, isolamento e baixas reduzem moral e eficácia. Retirada exige caminho e organização: soldados cobrem a saída enquanto feridos são recolhidos quando possível. Um cerco pode impedir a fuga. Recuperação exige tempo, alimentação, leitos e atendimento.

Exemplo: o jogador ordena tomar uma ponte e preservar tropas. Batedores reconhecem os acessos. A infantaria protege os atiradores; estes apoiam o avanço. A cavalaria só tenta contornar se existir uma rota conhecida viável. Se as baixas ou a falta de suprimentos tornarem a operação inviável, a companhia recua e informa o motivo.

## Mapa, progressão e objetivos

Florestas fornecem madeira e cobertura; campos férteis favorecem agricultura; rios sustentam pesca e limitam passagem; jazidas orientam expansão; elevações influenciam observação e combate. Recursos minerais são finitos; áreas de floresta podem ser replantadas.

A exploração revela terreno e pontos de interesse. Inimigos fora da visão atual podem se mover sem que o jogador saiba. Estradas, pontes, postos e caravanas tornam o controle territorial relevante.

A progressão ocorre por marcos econômicos e missões: estabilizar alimentos, dominar metalurgia, ampliar comércio, organizar tropas e sustentar operações distantes. Cada etapa libera opções gradualmente.

Modos propostos:
- Campanha solo com missões econômicas, defesa, escolta, conquista e reconstrução.
- Construção livre, com configuração de ameaças, incluindo uma opção pacífica.

Cada missão declara sua condição de vitória e derrota. No modo livre, a vila pode reconstruir após perdas enquanto restarem pessoas e meios de recuperação.

No celular: arrastar move a câmera, pinça controla o zoom, toque abre uma construção e arrastar no modo de caminhos desenha estradas. O modo militar permite tocar um alvo e escolher a ordem. Pausa tática deixa planejar sem avanço da simulação; velocidade pode ser ajustada fora dos momentos que a missão restringir. Salvamento automático e manual preservam a partida. Ao fechar o aplicativo, a simulação é suspensa e retorna do ponto salvo.

## Regras para evitar travamentos frustrantes

- Reservar madeira e materiais para obras essenciais e reparos; lenhadores replantam.
- Proteger uma parcela mínima da força de trabalho civil e mostrar o impacto antes do recrutamento.
- Dar prioridade mínima à alimentação, sem permitir que exportações e guerra consumam toda a reserva por padrão.
- Permitir entregas diretas e visualizar gargalos de transporte.
- Começar com construtores, serventes, profissionais essenciais e um centro de treinamento funcional; novos profissionais assumem tarefas automaticamente após a formação.
- Devolver materiais ainda não usados de obras canceladas; demolições recuperam somente uma parte do material incorporado.
- Explicar interrupções e oferecer ações concretas: aguardar profissionais ocupados, solicitar formação no centro de treinamento, conectar estrada ou ajustar a produção. A retomada acontece automaticamente quando o bloqueio termina.

A primeira implementação deve validar alimentação, construção, transporte e uma operação militar simples antes de ampliar para o catálogo completo.
