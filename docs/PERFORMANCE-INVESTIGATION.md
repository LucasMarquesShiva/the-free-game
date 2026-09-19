# Investigação da queda progressiva de FPS — 2026-09-18

Reprodução em uma cópia do autosave: 35 moradores (16 serventes), 41 trechos de
estrada, 8 construções, velocidade 4×. O salvamento original não foi alterado.

## Gargalo confirmado

`VillageSim._assign_export()` consultava `_incoming()` e `_outgoing()` para
cada recurso de cada prédio, mesmo quando a saída estava vazia ou o estoque já
atingira a meta. Cada consulta percorre todos os trabalhadores. Serventes sem
entregas repetem essas buscas em todos os passos; a rotina de atribuição pode
procurar exportações duas vezes por servente. O custo cresce com serventes ×
prédios × recursos × trabalhadores. Mais serventes ociosos podem, portanto,
piorar o desempenho sem aumentar o trabalho útil.

Em 60 passos do autosave, a instrumentação contou 169.200 consultas de entrada
e 120.960 de saída. Após a correção: 7.920 de entrada e nenhuma de saída nesse
intervalo, redução de 97,27%. Os totais dependem do estado da vila.

A correção verifica primeiro quantidade física de saída e meta de estoque,
antes das consultas de reservas. Aplica o mesmo descarte de saídas vazias à
recuperação de obras canceladas, coleta especial de alimentos e detecção de
trabalho para serventes estacionados. Não introduz cache que possa ficar
inválido após uma entrega, nem altera frequência da simulação.

## Comparação controlada

Godot 4.7.2, headless; versões anterior e corrigida alternadas no mesmo processo,
a partir do mesmo autosave, por 120 passos cada:

| Tempo por passo | Anterior | Corrigido |
| --- | ---: | ---: |
| Mediana | 133,254 ms | 12,558 ms |
| Percentil 95 | 262,792 ms | 27,574 ms |

O snapshot completo ao final foi idêntico e a conservação de recursos não
apresentou erros. O ganho mediano nessa comparação foi de 10,6×.

Em 4×, o relógio solicita 16 passos por segundo (4 × CIVIL_PACE 0,4 × 10).
Um passo de 133 ms ultrapassa sozinho esse orçamento. Frames lentos acumulam
mais passos a executar, agravando a queda. Isso explica o colapso observado
com o crescimento da vila, sem depender de um vazamento de memória.

Medições isoladas exploratórias no mesmo ambiente encontraram mediana de
8,6 ms por atualização de HUD (normalmente 5 vezes/s) e 16,3 ms por sincronização
do mundo. A criação inicial de modelos causou picos; esses números não medem
GPU e não demonstram ausência de outros gargalos. Tempos absolutos variam com
a carga da máquina. Não converter este benchmark em promessa de FPS final:
renderização, câmera, sombras e animação ainda têm seus próprios custos.

## Reproduzir

Na pasta `game`, com o executável Godot disponível:

```sh
godot --headless --path . --script res://tests/benchmark_saved_sim.gd -- --save="/caminho/para/vale-approved-autosave-v1.json" --ticks=120
```

O benchmark apenas lê o arquivo e avança uma simulação independente em memória.
`test_idle_delivery_cost.gd` evita regressão contando consultas, sem um limite
de tempo dependente da máquina. Também verifica reserva de produtos, meta de
estoque e recuperação de materiais. Ele faz parte de `tools/dev.py test`.
