# Ajustes pós-validação (Fase 9)

Como usar: uma sessão por grupo. Prompt padrão:
> Leia CLAUDE.md, docs/mapa_do_codigo.md e os itens do grupo Gx de docs/ajustes.md. Corrija só esses. Rode flutter analyze e marque o status no arquivo.

Modelo/esforço: G1 Sonnet médio (se a 1ª tentativa falhar, plano com o modelo mais forte); G2 Sonnet médio; G3 Sonnet baixo.
Faça `git commit` antes de cada sessão.

---

## G1 — Cartas não renderizam (alta) · ordem: primeiro

### A1 — O widget da carta não aparece (Elenco, campo tático e fila de Próximos)
- Vejo: o card não é desenhado em nenhuma tela que o usa. Elenco sem cards; Sessão > Campo > Partida sem cards no campo; Sessão > Campo > Próximos sem a fila.
- Esperava: cartas visíveis nos três lugares.
- Hipótese: causa única no widget compartilhado (`widgets/player/fifa_card.dart` / `player_card.dart`) ou no que ele carrega (asset `assets/card_patterns/swirl.png` ou fontes não declarados no `pubspec.yaml`, tamanho zero/`Expanded` sem restrição).
- Como investigar (barato): `git diff <commit antes da Fase 4> -- lib/widgets/player/`; conferir `pubspec.yaml` (assets e fontes); rodar em debug e ler o **primeiro** erro vermelho.
- Print: docs/screens/a1-elenco.png, a1-partida.png, a1-proximos.png
- Status: [x] corrigido (falta confirmar no app). Causa: `FifaCard` usava `AspectRatio` sem restrição quando dentro de `FittedBox` (`tactical_pitch`, `waiting_player_card`) e ficava com tamanho zero. Agora `LayoutBuilder` usa o tamanho natural se não há limite.

### A2 — Erro ao trocar a carta para Prata com atributos
- Vejo: ao adicionar atributos e forçar a carta a virar Prata, estoura exceção.
- Erro (colar aqui a **primeira** exceção do console, com ~20 linhas de stack): 
  ```
  Failed assertion: framework.dart line 6268: '_dependents.isEmpty': is not true
  Tried to build dirty widget in the wrong build scope
  ```
- Esperava: trocar de tier sem exceção.
- Hipótese: provável mesma causa de A1 (mudança de árvore/estado durante o build ao trocar de tier, por exemplo `setState`/provider disparado dentro de `build`, ou `GlobalKey` duplicada). Resolver A1 antes e ver se some.
- Status: [~] (re-checado: `flutter analyze lib` sem avisos em fifa_card/tactical_pitch/waiting_player_card; `test/fifa_card_test.dart` passa) não reproduzido; a causa provável era a mesma de A1. Confirmar no app; se persistir, colar a stack completa.

---

## G2 — Tiers e swirl (média)

### A3 — Novas faixas de tier e carta Lendária
- Vejo: a cor de elite (Platina) está boa, mas queria algo mais próximo do FIFA para os mais altos.
- Esperava: Bronze e Prata como estão; **Ouro 75–79**; **Platina atual 80–84**; **Lendária 85–99** (branca/pérola, estilo Icon).
- Spec: `docs/design/01-cores-e-tipografia.md` (seção 2.5). Função única `tierForOverall()` com limites como constantes.
- Antes de codar: contar quantos jogadores caem em cada faixa e me mostrar.
- Pronto quando: cada faixa renderiza o tier certo (incluindo Lendária) em carta cheia, L, M e S; sem lacuna entre Prata e Ouro.
- Status: [x] implementado (falta confirmar no app). `tierForOverall()` + constantes `kSilverMin/kGoldMin/kPlatinumMin/kLegendaryMin` em `overall_calculator.dart`; `CardTier.legendary` (pérola, linha interna 2dp); filtro "Lendária" no Elenco. **Contagem por faixa NÃO feita**: os dados ficam no Supabase/snapshot do app, sem acesso daqui; conferir o Elenco (filtros por faixa). `team_balancer` segue com elite ≥ 85 (= Lendária).

### A4 — Swirl na carta toda
- Vejo: o padrão swirl só aparece atrás da foto.
- Esperava: cobrindo a carta inteira, até o contorno do escudo.
- Spec: `docs/design/06-carta-do-jogador.md` (camada 3): recorte pelo escudo, 45–60% atrás da foto e 10–18% no corpo, `precacheImage`, sem swirl no chip S.
- Pronto quando: nome e atributos mantêm contraste ≥ 4.5:1 em Bronze, Prata e Lendária.
- Status: [~] swirl numa camada só, 14% uniforme na carta toda (recortado pelo escudo; sem reforço atrás da foto), `precacheImage` no `MaterialApp.builder`, sem swirl no chip S. **Contraste ≥ 4.5:1 não atendido no Bronze**: texto `#2D1F17` sobre `#664A3D` dá ~2:1 mesmo sem swirl (cores da spec). Prata (~5.8:1) e Lendária (nome ~8.9:1; OVR `#7A6A3A` ~3:1 na base) — OVR/posição da Lendária também abaixo de 4.5 na base. Decisão pendente: clarear o texto do Bronze / escurecer o OVR da Lendária.

### BUG
- Status: [~] não reproduzido nem corrigido com certeza (ver conversa). Possível efeito em cascata do erro de TextEditingController descartado cedo no diálogo de atributos (corrigido). Se repetir, colar a **primeira** exceção do console, não a de `referenceBox.attached`.

══╡ EXCEPTION CAUGHT BY RENDERING LIBRARY ╞═════════════════════════════════════════════════════════
The following assertion was thrown during paint():
'package:flutter/src/material/material.dart': Failed assertion: line 768 pos 12:
'referenceBox.attached': is not true.

Either the assertion indicates an error in the framework itself, or we should provide substantially
more information in this error message to help you determine and fix the underlying cause.
In either case, please report this assertion by filing a bug on GitHub:
  https://github.com/flutter/flutter/issues/new?template=02_bug.yml

The relevant error-causing widget was:
  AppBar
  AppBar:file:///mnt/files-linux/Documents/github/App-Fut/lib/screens/player_detail.dart:3479:15

When the exception was thrown, this was the stack:
#2      InkFeature._paint (package:flutter/src/material/material.dart:768:12)
#3      _RenderInkFeatures.paint (package:flutter/src/material/material.dart:629:20)
#4      RenderObject._paintWithContext (package:flutter/src/rendering/object.dart:3568:7)
#5      PaintingContext.paintChild (package:flutter/src/rendering/object.dart:265:13)
#6      RenderProxyBoxMixin.paint (package:flutter/src/rendering/proxy_box.dart:143:13)
#7      RenderCustomPaint.paint (package:flutter/src/rendering/custom_paint.dart:644:11)
#8      RenderObject._paintWithContext (package:flutter/src/rendering/object.dart:3568:7)
#9      PaintingContext.paintChild (package:flutter/src/rendering/object.dart:265:13)
#10     RenderProxyBoxMixin.paint (package:flutter/src/rendering/proxy_box.dart:143:13)
#11     RenderPhysicalShape.paint.<anonymous closure> (package:flutter/src/rendering/proxy_box.dart:2357:15)
#12     PaintingContext.pushClipPath (package:flutter/src/rendering/object.dart:727:14)
#13     RenderPhysicalShape.paint (package:flutter/src/rendering/proxy_box.dart:2344:21)
#14     RenderObject._paintWithContext (package:flutter/src/rendering/object.dart:3568:7)
#15     PaintingContext.paintChild (package:flutter/src/rendering/object.dart:265:13)
#16     RenderProxyBoxMixin.paint (package:flutter/src/rendering/proxy_box.dart:143:13)
#17     RenderObject._paintWithContext (package:flutter/src/rendering/object.dart:3568:7)
#18     PaintingContext.paintChild (package:flutter/src/rendering/object.dart:265:13)
#19     RenderShiftedBox.paint (package:flutter/src/rendering/shifted_box.dart:98:15)
#20     RenderObject._paintWithContext (package:flutter/src/rendering/object.dart:3568:7)
#21     PaintingContext.paintChild (package:flutter/src/rendering/object.dart:265:13)
#22     RenderProxyBoxMixin.paint (package:flutter/src/rendering/proxy_box.dart:143:13)
#23     RenderObject._paintWithContext (package:flutter/src/rendering/object.dart:3568:7)
#24     PaintingContext.paintChild (package:flutter/src/rendering/object.dart:265:13)
#25     RenderShiftedBox.paint (package:flutter/src/rendering/shifted_box.dart:98:15)
#26     RenderObject._paintWithContext (package:flutter/src/rendering/object.dart:3568:7)
#27     PaintingContext.paintChild (package:flutter/src/rendering/object.dart:265:13)
#28     RenderProxyBoxMixin.paint (package:flutter/src/rendering/proxy_box.dart:143:13)
#29     RenderObject._paintWithContext (package:flutter/src/rendering/object.dart:3568:7)
#30     PaintingContext.paintChild (package:flutter/src/rendering/object.dart:265:13)
#31     RenderBoxContainerDefaultsMixin.defaultPaint (package:flutter/src/rendering/box.dart:3368:15)
#32     RenderCustomMultiChildLayoutBox.paint (package:flutter/src/rendering/custom_layout.dart:422:5)
#33     RenderObject._paintWithContext (package:flutter/src/rendering/object.dart:3568:7)
#34     PaintingContext.paintChild (package:flutter/src/rendering/object.dart:265:13)
#35     RenderShiftedBox.paint (package:flutter/src/rendering/shifted_box.dart:98:15)
#36     RenderObject._paintWithContext (package:flutter/src/rendering/object.dart:3568:7)
#37     PaintingContext.paintChild (package:flutter/src/rendering/object.dart:265:13)
#38     RenderProxyBoxMixin.paint (package:flutter/src/rendering/proxy_box.dart:143:13)
#39     PaintingContext.pushClipRect.<anonymous closure> (package:flutter/src/rendering/object.dart:592:83)
#40     ClipContext._clipAndPaint (package:flutter/src/painting/clip.dart:33:12)
#41     ClipContext.clipRectAndPaint (package:flutter/src/painting/clip.dart:90:5)
#42     PaintingContext.pushClipRect (package:flutter/src/rendering/object.dart:592:7)
#43     RenderClipRect.paint (package:flutter/src/rendering/proxy_box.dart:1644:25)
#44     RenderObject._paintWithContext (package:flutter/src/rendering/object.dart:3568:7)
#45     PaintingContext.paintChild (package:flutter/src/rendering/object.dart:265:13)
#46     RenderShiftedBox.paint (package:flutter/src/rendering/shifted_box.dart:98:15)
#47     RenderObject._paintWithContext (package:flutter/src/rendering/object.dart:3568:7)
#48     PaintingContext.paintChild (package:flutter/src/rendering/object.dart:265:13)
#49     RenderShiftedBox.paint (package:flutter/src/rendering/shifted_box.dart:98:15)
#50     RenderObject._paintWithContext (package:flutter/src/rendering/object.dart:3568:7)
#51     PaintingContext.paintChild (package:flutter/src/rendering/object.dart:265:13)
#52     RenderProxyBoxMixin.paint (package:flutter/src/rendering/proxy_box.dart:143:13)
#53     RenderObject._paintWithContext (package:flutter/src/rendering/object.dart:3568:7)
#54     PaintingContext.paintChild (package:flutter/src/rendering/object.dart:265:13)
#55     RenderProxyBoxMixin.paint (package:flutter/src/rendering/proxy_box.dart:143:13)
#56     _RenderInkFeatures.paint (package:flutter/src/material/material.dart:634:11)
#57     RenderObject._paintWithContext (package:flutter/src/rendering/object.dart:3568:7)
#58     PaintingContext.paintChild (package:flutter/src/rendering/object.dart:265:13)
#59     RenderProxyBoxMixin.paint (package:flutter/src/rendering/proxy_box.dart:143:13)
#60     RenderPhysicalModel.paint.<anonymous closure> (package:flutter/src/rendering/proxy_box.dart:2252:15)
#61     PaintingContext.pushClipRRect (package:flutter/src/rendering/object.dart:626:14)
#62     RenderPhysicalModel.paint (package:flutter/src/rendering/proxy_box.dart:2239:21)
#63     RenderObject._paintWithContext (package:flutter/src/rendering/object.dart:3568:7)
#64     PaintingContext.paintChild (package:flutter/src/rendering/object.dart:265:13)
#65     RenderProxyBoxMixin.paint (package:flutter/src/rendering/proxy_box.dart:143:13)
#66     PaintingContext.pushLayer (package:flutter/src/rendering/object.dart:522:12)
#67     RenderAnnotatedRegion.paint (package:flutter/src/rendering/proxy_box.dart:4811:13)
#68     RenderObject._paintWithContext (package:flutter/src/rendering/object.dart:3568:7)
#69     PaintingContext.paintChild (package:flutter/src/rendering/object.dart:265:13)
#70     RenderProxyBoxMixin.paint (package:flutter/src/rendering/proxy_box.dart:143:13)
#71     RenderObject._paintWithContext (package:flutter/src/rendering/object.dart:3568:7)
#72     PaintingContext.paintChild (package:flutter/src/rendering/object.dart:265:13)
#73     RenderProxyBoxMixin.paint (package:flutter/src/rendering/proxy_box.dart:143:13)
#74     RenderObject._paintWithContext (package:flutter/src/rendering/object.dart:3568:7)
#75     PaintingContext.paintChild (package:flutter/src/rendering/object.dart:265:13)
#76     RenderBoxContainerDefaultsMixin.defaultPaint (package:flutter/src/rendering/box.dart:3368:15)
#77     RenderCustomMultiChildLayoutBox.paint (package:flutter/src/rendering/custom_layout.dart:422:5)
#78     RenderObject._paintWithContext (package:flutter/src/rendering/object.dart:3568:7)
#79     PaintingContext.paintChild (package:flutter/src/rendering/object.dart:265:13)
#80     RenderProxyBoxMixin.paint (package:flutter/src/rendering/proxy_box.dart:143:13)
#81     _RenderInkFeatures.paint (package:flutter/src/material/material.dart:634:11)
#82     RenderObject._paintWithContext (package:flutter/src/rendering/object.dart:3568:7)
#83     PaintingContext.paintChild (package:flutter/src/rendering/object.dart:265:13)
#84     RenderProxyBoxMixin.paint (package:flutter/src/rendering/proxy_box.dart:143:13)
#85     RenderPhysicalModel.paint.<anonymous closure> (package:flutter/src/rendering/proxy_box.dart:2252:15)
#86     PaintingContext.pushClipRRect (package:flutter/src/rendering/object.dart:626:14)
#87     RenderPhysicalModel.paint (package:flutter/src/rendering/proxy_box.dart:2239:21)
#88     RenderObject._paintWithContext (package:flutter/src/rendering/object.dart:3568:7)
#89     PaintingContext.paintChild (package:flutter/src/rendering/object.dart:265:13)
#90     RenderProxyBoxMixin.paint (package:flutter/src/rendering/proxy_box.dart:143:13)
#91     RenderObject._paintWithContext (package:flutter/src/rendering/object.dart:3568:7)
#92     PaintingContext.paintChild (package:flutter/src/rendering/object.dart:265:13)
#93     RenderProxyBoxMixin.paint (package:flutter/src/rendering/proxy_box.dart:143:13)
#94     RenderObject._paintWithContext (package:flutter/src/rendering/object.dart:3568:7)
#95     PaintingContext._repaintCompositedChild (package:flutter/src/rendering/object.dart:180:11)
#96     PaintingContext.repaintCompositedChild (package:flutter/src/rendering/object.dart:125:5)
#97     PipelineOwner.flushPaint (package:flutter/src/rendering/object.dart:1325:31)
#98     PipelineOwner.flushPaint (package:flutter/src/rendering/object.dart:1335:15)
#99     RendererBinding.drawFrame (package:flutter/src/rendering/binding.dart:645:23)
#100    WidgetsBinding.drawFrame (package:flutter/src/widgets/binding.dart:1573:13)
#101    RendererBinding._handlePersistentFrameCallback (package:flutter/src/rendering/binding.dart:509:5)
#102    SchedulerBinding._invokeFrameCallback (package:flutter/src/scheduler/binding.dart:1430:15)
#103    SchedulerBinding.handleDrawFrame (package:flutter/src/scheduler/binding.dart:1345:9)
#104    SchedulerBinding.scheduleWarmUpFrame.<anonymous closure> (package:flutter/src/scheduler/binding.dart:1055:9)
#105    PlatformDispatcher.scheduleWarmUpFrame.<anonymous closure> (dart:ui/platform_dispatcher.dart:909:16)
#109    _RawReceivePort._handleMessage (dart:isolate-patch/isolate_patch.dart:192:12)
(elided 5 frames from class _AssertionError, class _Timer, and dart:async-patch)

The following RenderObject was being processed when the exception was fired: _RenderInkFeatures#cd78d relayoutBoundary=up6:
  creator: _InkFeatures-[GlobalKey#94dcf ink renderer] ←
    NotificationListener<LayoutChangedNotification> ← CustomPaint ← _ShapeBorderPaint ← PhysicalShape
    ← _MaterialInterior ← Material ← ConstrainedBox ← _InputPadding ← Semantics ← _IconButtonM3 ←
    _SelectableIconButton ← ⋯
  parentData: <none> (can use size)
  constraints: BoxConstraints(40.0<=w<=56.0, 40.0<=h<=56.0)
  size: Size(40.0, 40.0)
This RenderObject had the following descendants (showing up to depth 5):
    child: _RenderLayoutSurrogateProxyBox#5e928 relayoutBoundary=up7 NEEDS-PAINT
      child: RenderSemanticsAnnotations#ac386 relayoutBoundary=up8 NEEDS-PAINT
        child: _RenderExclusiveMouseRegion#400cb relayoutBoundary=up9 NEEDS-PAINT
          child: RenderPointerListener#0d004 relayoutBoundary=up10 NEEDS-PAINT
            child: RenderSemanticsAnnotations#225c0 relayoutBoundary=up11 NEEDS-PAINT
════════════════════════════════════════════════════════════════════════════════════════════════════

Performing hot reload...                                                
Reloaded 0 libraries in 508ms (compile: 40 ms, reload: 0 ms, reassemble: 357 ms).
Another exception was thrown: 'package:flutter/src/material/material.dart': Failed assertion: line 768 pos 12: 'referenceBox.attached': is not true.
Another exception was thrown: 'package:flutter/src/material/material.dart': Failed assertion: line 768 pos 12: 'referenceBox.attached': is not true.


---

## G3 — Ranking (baixa)

### A5 — Ranking da pelada mostra só G+A
- Vejo: o ranking mostra apenas G+A.
- Esperava: **Gols e Assistências** também, separados.
- Spec: `docs/design/05-tela-ranking.md` (pódio e lista: `⚽ 2 · 👟 1`, mínimo 10sp, mesmo com outra ordenação).
- Print: docs/screens/a5-ranking.png
- Status: [x] corrigido (falta confirmar no app). Pódio e lista (4º+) mostram `⚽ G · 👟 A` (12sp, widget `GoalsAssistsText`) para a linha, qualquer que seja a ordenação; Goleiros não mostram. Linha da lista agora tem altura mínima 64dp e quebra em 2 linhas se faltar largura.

### A6 - tactical_pitch
- Vejo: tactical_pitch muito grande em compração com as cartas
- Esperava: Mais destaque para as cartas sem sobrepor nenhuma. Esperava tambem poder mudar a formação nessa tela de acordo com o que foi configurado (4x4 por exemplo, ter 1-2-2 ou 1-1-2-1). Conforme mais jogadores aparecem (5,6,7, 11) as cartas podem ir diminuindo ou virar so chips, como esperado no 11x11.
- Status: [x] implementado (falta confirmar no app). Seletor de formação (chips `2-2`, `1-2-1`, `3-1`…) acima do campo, vindo de `formationPresets(n)` (3 a 7 de linha; a 1ª é o padrão). O campo agora se ajusta às cartas (maior densidade que cabe) em vez de esticar; `PitchLayout.compute/minHeight` aceitam `formation`. Teste de não sobreposição dos presets em `pitch_layout_test.dart`. A escolha de formação NÃO é salva. **Cartas por padrão** (L/M, nunca viram chip por falta de espaço: o campo cresce/rola); chips só no 11×11 (>7 de linha) ou pela chave "Jogadores como chips no campo" em Configurações da Partida (pref. `pitch_use_chips`). **Refino:** cartas do campo ampliadas (escalas 1.55→1.14 sobre a M 60×84; usa a maior que cabe, textos ≥10sp), nome da M com até 12 caracteres, e nome com efeito (ex.: prata) agora vai sobre plaqueta escura também na M (legível na Lendária).

---

## Observação de escopo
- **11×11 é raro e não é foco.** Em times com mais de 7 jogadores o campo usa só chips (bolinha com foto/ícone), automaticamente (`docs/design/03-tela-partida.md`).
