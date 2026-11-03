# Visão Geral do App-Fut: Arquitetura, Produto e Funcionamento

> **Documento de referência para Product Owner (PO) e Entendimento do Sistema**  
> **Versão:** 1.0 (Atualizado pós Fase 1 e Fase 1b — Novembro/2026)  
> **Público-alvo:** Enzo (PO / Gestor do Produto) e novos desenvolvedores

---

## 1. Visão de Produto e Estratégia de Arquitetura

O **App-Fut** nasceu como um gerenciador de peladas de futsal e futebol society, focado em resolver os problemas reais de quem organiza uma partida: lista de presença por ordem de chegada, sorteio de times realmente equilibrados, cronômetro com prorrogação, registro de gols/assistências e rankings com notas dinâmicas.

### A Estratégia dos Três Sabores ("Flavors")
O projeto foi estruturado com o princípio **"Um código, três produtos"**:
1. **Personal (App atual do Enzo):** Conectado à nuvem (Supabase), multiusuário, com controle de administradores, tema escuro exclusivo (inspirado em *Blue Lock* / *Sofascore*), envio de pacote para site externo e backup contínuo.
2. **Web Read-Only (Fase 2):** Versão Flutter Web para iPhone ou navegadores comuns, acessada por link seguro com token (sem precisar de login). Permite aos jogadores acompanharem a tabela, artilharia e notas sem permissão de alteração.
3. **Public Offline (Fase 3):** Aplicativo distribuído na loja para qualquer pessoa usar no celular sem login e sem custos de servidor. Usa banco de dados local SQLite (drift) com botões de "Exportar/Importar Banco (.db)".

---

## 2. Como o Código é Organizado (Arquitetura em Camadas)

Para permitir que a mesma interface gráfica funcione tanto com o banco na nuvem (Supabase) quanto com o banco no celular (SQLite), o app adota uma **Arquitetura em Camadas com Injeção de Dependência**:

```
┌─────────────────────────────────────────────────────────────┐
│                 Interface Gráfica (UI)                      │
│     Telas (Screens), Componentes (Widgets) e Temas          │
└──────────────────────────────┬──────────────────────────────┘
                               │ Usa apenas Contratos e Serviços
                               ▼
┌─────────────────────────────────────────────────────────────┐
│                 Camada de Domínio (Domain)                  │
│  Interfaces abstratas: PlayersRepository, MatchesRepository, │
│  AuthService, PermissionService, MatchOutbox, etc.          │
└───────────────┬──────────────────────────────┬──────────────┘
                │ Implementa                   │ Implementa
                ▼                              ▼
┌──────────────────────────────┐ ┌────────────────────────────┐
│      Data / Supabase         │ │        Data / Prefs        │
│  Implementações que falam    │ │  Armazenamento local rápido│
│  com a nuvem (Supabase*)     │ │  (SharedPreferences/Cache) │
└──────────────────────────────┘ └────────────────────────────┘
```

### O que o PO precisa saber dessa estrutura:
- **Telas não sabem onde os dados estão salvos:** Uma tela como a `MatchScreen` (onde a partida acontece) só pede: *"outbox, guarde esta partida"* ou *"players, me dê a lista de jogadores"*. Ela não se importa se o dado vai para o Supabase pela internet ou se está gravando na memória do celular.
- **Isolamento de Segurança:** Nenhuma tela tem acesso direto ao Supabase. Todo o acesso a banco e chaves de API fica trancado dentro da pasta `lib/data/supabase/`.
- **`AppServices` e `AppFeatures`:**
  - `AppServices`: É a "caixa de ferramentas" central. Quando o app liga, ele preenche essa caixa com as ferramentas certas daquele produto.
  - `AppFeatures`: É a lista de interruptores de recursos (*feature flags*). Exemplo: o app Personal tem `hasMembershipManagement = true` (gestão de membros), enquanto a versão Web tem `isReadOnly = true` (tudo em modo somente leitura) e desliga botões de edição automaticamente.

---

## 3. O que foi feito na Fase 0, Fase 1 e Fase 1b

Para transformar um app legado monolítico em um sistema robusto e preparado para os três produtos, o desenvolvimento foi dividido em etapas graduais:

### Fase 0 — Limpeza e Rede de Segurança
*Objetivo: Criar testes e limpar código velho antes de mexer na estrutura, garantindo que nada quebrasse.*
- **Testes de Caracterização dos Cálculos:** Criação de baterias de testes fixando os resultados matemáticos das notas, estatísticas e Overall. Isso garantiu que futuras melhorias não alterassem as pontuações históricas dos jogadores.
- **Limpeza de Scripts Legados:** Scripts de migração antigos movidos para `tool/legacy/`.
- **Remoção de Código Morto e Telas Órfãs:** Identificação e exclusão de 4 telas que estavam no código mas ninguém conseguia acessar (`ExpandedRankingScreen`, `GroupRankingScreen`, `TournamentScreen` e `BlankScreen`), além de fluxos de importação/exportação abandonados.
- **Inventários Técnicos:** Mapeamento minucioso de todas as tabelas do Supabase, de todas as chaves gravadas no celular (`SharedPreferences`) e de métodos sem chamadores.

### Fase 1 — Criação das Interfaces e Desacoplamento
*Objetivo: Separar contratos de implementações sem mudar uma única vírgula no comportamento do app.*
- **Interfaces de Domínio (`lib/domain/`):** Criação dos contratos (`PlayersRepository`, `MatchesRepository`, `GroupsRepository`, `SeasonsRepository`, etc.).
- **Serviços de Autenticação e Permissão:** Criação do `AuthService` (isolando o login do Supabase) e do `PermissionService` (centralizando a regra: *"é o criador do grupo ou tem papel de admin?"*).
- **Camada de Dados (`lib/data/supabase/`):** Todos os repositórios foram renomeados e movidos, implementando as interfaces do domínio.
- **Orquestrador `AppServices`:** Substituição de chamadas globais antigas por injeção via `AppServices.instance`.
- **Camada Local (`lib/data/prefs/`):** Criação de adaptadores para histórico local de partidas e catálogo de insígnias personalizadas.
- **Fila Outbox e Serviços de Diagnóstico:** Abstração da fila de envio de partidas e do sincronizador do site externo.
- **Divisão em Flavors:** Criação do ponto de entrada `bootstrap_personal.dart` e `main_personal.dart`.

### Fase 1b — Correção e Blindagem de Bugs
*Objetivo: Resolver falhas críticas mapeadas na transição e blindar o app contra instabilidades.*
- **Criação de Grupos e Temporadas (B1 / B1b):** O app gerava erro no banco porque tentava criar temporadas sem ID. Passou a gerar identificadores únicos no cliente (`Uuid().v4()`), com proteção de *rollback* reverso caso a internet caísse no meio do processo.
- **Sincronização de Elenco e Nomes (B2 / B3):** Jogadores recém-criados agora entram no cache na hora; a edição de nomes foi conectada ao banco com checagem de permissão (admin ou o próprio jogador); telas de histórico e comparação nunca mais mostram o texto "Desconhecido".
- **Estatísticas Avançadas (B4):** Correção nos cálculos de percentual de derrotas e histórico mútuo entre jogadores.
- **Isolamento de Erros Permanentes na Fila (B5):** Se uma partida contiver dados que o banco rejeita definitivamente (ex: violação de integridade), ela não trava mais o envio das partidas seguintes. O app separa erros de rede de erros definitivos e exibe uma tela amigável para copiar os dados ou descartar.
- **Inicialização 100% Offline (B6 / B6b / B6c):** Se o usuário abrir o app no vestiário sem sinal de internet:
  - Não fica mais preso em telas de carregamento ou "Completar Perfil".
  - A tela inicial (`HomePage`) abre imediatamente com os grupos salvos no cache do celular, avisando que está offline.
  - Um ícone no topo mostra quantas partidas estão pendentes para subir assim que a conexão voltar.

---

## 4. O Caminho dos Dados (Data Flow)

Entender como um dado nasce, viaja e é guardado no app é vital para o gerenciamento do produto:

```
[Organizador no Campo]
        │
        │ Marca gol / assist / falta
        ▼
[Estado Efêmero em Memória + SharedPreferences]
(A cada segundo, cronômetro e placar são salvos localmente. 
 Se o celular descarregar, ao religar o jogo continua de onde parou)
        │
        │ Toca em "Finalizar Partida"
        ▼
[Súmula Local Gravada Instantaneamente]
(Gera ID único da partida e salva no histórico do celular. 
 A tela do app libera na hora para o próximo jogo, sem esperar a internet)
        │
        ▼
[Fila de Envio: MatchOutbox] ──── (Se estiver SEM internet) ───► Aguarda em segundo plano
        │
        │ (Com internet)
        ▼
[Supabase / Nuvem]
(Grava nas tabelas: matches -> match_lineups -> match_events)
```

### Leitura e Exibição de Dados:
1. Ao abrir o app, ele primeiro tenta ler as informações atualizadas da nuvem.
2. Se houver falha de rede ou lentidão, o mecanismo de **Cache de Resgate (`CacheStore` e `GroupBootstrap`)** entra em ação automaticamente, fornecendo os dados da última sincronização. O usuário nunca se depara com uma tela em branco.

---

## 5. O Caminho dos Erros (Error Handling e Resiliência)

O app foi projetado com a filosofia **Offline-First**: uma pelada em andamento não pode ser prejudicada por instabilidade de 4G/Wi-Fi da quadra.

### 1. Erros Transitórios (Falta de Internet, Timeout, Sinal Fraco)
- **Como o app reage:** Trata como algo temporário. A partida fica na fila local (`pending_matches_v1`).
- **Retentativas automáticas:** O app tenta reenviar em 2 segundos. Se falhar, tenta com intervalos progressivos (5s, 10s, 20s, 40s, 60s). Além disso, sempre que o organizador abre o app ou volta de outro aplicativo (ex: WhatsApp), o app tenta enviar novamente em segundo plano.

### 2. Erros Permanentes (Regra de Banco Quebrada)
- Se o banco responder com erros definitivos do PostgreSQL (ex: código `23503` de chave inexistente ou `23514` de checagem inválida):
- Na 2ª tentativa falha consecutiva, a partida é marcada com `status: 'failed'`.
- **Ela sai do início da fila:** Isso garante que a partida com problema **não bloqueie** as partidas seguintes que estão saudáveis.
- **Interface de Recuperação:** O app exibe um alerta de partida com problema. O organizador pode abrir os detalhes, **copiar o JSON completo dos dados** (para não perder a contagem dos gols) ou descartar.

### 3. Permissões de Acesso
- Ações administrativas (adicionar administradores, apagar grupos, criar temporadas) passam pelo `PermissionService`. Se um jogador comum tentar forçar uma alteração, o app barra a ação e exibe uma mensagem amigável sem fechar ou travar a tela.

---

## 6. Sorteio de Times e Algoritmo de Balanceamento

Um dos grandes diferenciais do app é o seu sistema inteligente de divisão de equipes, implementado no arquivo `lib/utils/team_balancer.dart`.

### A Força do Jogador: O "Overall FIFA" (0 a 99)
Todo jogador possui um Overall unificado que define sua força em campo:
$$\text{Overall} = (\text{Nota do App} \times 10 \times 0.30) + (\text{Nota da Comunidade} \times 0.70)$$

1. **Nota do App (Peso 30% — Escala 0 a 10):**
   - Calculada com base na **forma recente** (últimas 12 partidas jogadas), evitando que partidas do ano passado afetem a fase atual.
   - Pesa: vitória (+0.8), derrota (-0.5), gols (+1.5), assistências (+1.0), gol contra (-1.0), cartões, bônus de *clean sheet* (não levar gol) e sequência de vitórias.
   - **Retorno decrescente:** Fazer 4 gols não dá 4x a nota de 1 gol; cada gol adicional tem peso reduzido (decaimento de 60%) para não descalibrar a nota numa única goleada.
2. **Nota da Comunidade (Peso 70% — Escala 0 a 100):**
   - Votação do grupo nos 6 atributos estilo FIFA: **PAC** (Velocidade), **SHO** (Finalização), **PAS** (Passe), **DRI** (Drible/Controle), **DEF** (Marcação) e **PHY** (Físico/Fôlego).
   - Se o jogador ainda não tiver nota votada, o sistema assume 50 (neutro).

### Como Funciona o Sorteio (`TeamBalancer`)
Quando o organizador toca em "Sortear":

1. **Enumeração Exata (Até 20 jogadores no sorteio):**
   - Para um jogo de 5v5 (10 jogadores) ou até 10v10 (20 jogadores), o algoritmo calcula **todas as combinações matemáticas possíveis** (ex: 10v10 gera 92.378 combinações, processadas em menos de 0,1 segundo no celular).
2. **Cálculo da Nota de Desequilíbrio (*Penalty Score*):**
   Cada divisão possível recebe uma pontuação de penalidade com base em 4 critérios:
   - **Diferença de Média Geral:** Quão distantes estão as médias de Overall dos dois times.
   - **Diferença de Craques (*Top Player*):** Evita que o jogador nota 90 jogue contra um time onde o melhor é nota 75.
   - **Dispersão (*Spread*):** Evita que um time seja composto só por notas 80 medianos enquanto o outro tem notas 95 misturados com notas 65.
   - **Distribuição de Jogadores Elite:** Jogadores com Overall $\ge 85$ são distribuídos igualmente entre os lados (peso 1.5).
3. **Variabilidade Inteligente ("Quase-Ótimo"):**
   - Se o app sempre escolhesse a divisão nº 1 matematicamente perfeita, os times seriam sempre exatamente os mesmos todas as semanas.
   - Por isso, o algoritmo localiza as divisões que estão dentro de uma pequena margem de tolerância da melhor (quase tão boas quanto a perfeita) e **apresenta 3 opções super equilibradas**, garantindo que não repita a divisão da rodada anterior.
4. **Preenchimento Dinâmico durante a Pelada (`fill`):**
   - Quando um time perde e sai, ou quando há empate e entram novos jogadores da fila de espera, o balanceador distribui quem está entrando de forma a equilibrar quem já estava em campo.

---

## 7. Resumo Prático para o Product Owner (PO)

| Aspecto | Como funciona no App-Fut | Benefício para o Usuário / Negócio |
|---|---|---|
| **Conexão Offline** | Offline-First com fila local (`MatchOutbox`) e recuperação em cache | O organizador nunca perde dados ou tempo se o 4G da quadra oscilar. |
| **Sorteio de Times** | Análise combinatória ponderada por Overall estilo FIFA | Jogos equilibrados, sem discussões de "time de panelinha". |
| **Notas dos Jogadores** | 30% estatísticas recentes + 70% atributos da comunidade | Engajamento alto do grupo (cartas estilo FIFA) e justiça nos números. |
| **Multiusuário** | Permissões no banco (Admin vs Membro) | Somente admins alteram configurações estruturais; membros apenas jogam e votam. |
| **Multi-App** | Arquitetura pronta para Web e App Público | Permite lançar produtos novos rapidamente reaproveitando todo o código. |

---

## 8. Próximos Passos no Roadmap

1. **Fase 2 — Site Web Somente Leitura:**
   - Permitir que os participantes da pelada (especialmente usuários de iPhone) acessem um link web sem login para ver classificações, artilharia e cartas dos jogadores em tempo real.
2. **Fase 3 — App Público Offline:**
   - Versão standalone para publicação nas lojas de aplicativos, usando banco SQLite local, permitindo a qualquer pelada do país organizar seus jogos com o mesmo motor do App-Fut.
