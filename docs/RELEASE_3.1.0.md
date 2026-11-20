# Fut v3.1.0

## 🚀 Novidades

### 👥 Estatísticas de Times & Parcerias
- **Nova aba "Times & Parcerias"** na tela de Estatísticas da Temporada (`SeasonStatsScreen`).
- **Rankings Coletivos:** Veja os times mais vitoriosos (% de vitórias), mais goleadores (média de gols), mais sólidos defensivamente (menos gols sofridos) e com maior saldo de gols da temporada.
- **Filtro Flexível por Formato:** Filtre os rankings por Todas as formações, Duplas, Trios, Quartetos ou 5+ jogadores.

### 🏟️ Validador Tático no Campo
- **Simulador de Formações:** Escolha livremente de 2 a 11 jogadores e valide na hora se essa combinação já jogou junta.
- **Métricas em Tempo Real:** Aproveitamento, vitórias, empates, derrotas, gols pró/contra e histórico completo de partidas disputadas pela formação.
- **Cards FIFA vs Chips com Foto:** Escolha nas Configurações do App ou no botão de alternância rápida do campinho entre cards estilizados (Overall, foto e escudo) ou chips circulares com foto do atleta.

### 🏆 Melhor Time da Pelada
- **Nova aba "Melhor Time"** na tela de Ranking da Pelada (`RankingScreen`).
- Destaca a formação de linha que mais venceu aquela pelada específica, exibindo mini campo tático com os atletas posicionados, aproveitamento, gols e saldo.

### ⚔️ Top Rivalidades e Troféus da Resenha
- **Maiores Duelos:** Mapeamento automático dos confrontos diretos mais frequentes entre jogadores rivais na temporada.
- **Troféus Cômicos da Resenha:**
  - *Inimigo do Gol:* Atleta de linha com a maior sequência de partidas sem balançar as redes.
  - *Pé Torto / Traidor:* Atleta com mais gols contra marcados.
  - *Açougueiro / Xerife:* Atleta com maior acúmulo de cartões amarelos e vermelhos.

### ⚡ Correção dos Gols da Virada & Conquistas
- **Cálculo Corrigido:** Detecção matemática aprimorada em `findSpecialGoals` — o gol que coloca a equipe em vantagem após ter estado atrás no placar agora é pontuado corretamente como Gol da Virada.
- **Novas Insígnias:** Conquistas automáticas na carta do jogador (`PlayerDetailScreen`): **Poder de Reação** (1+ virada) e **Rei da Virada** (3+ viradas), além do pódio na temporada.

### 📐 Formações Táticas Padrão & Gerenciador
- **Presets Expandidos:** Suporte tático ampliado para formações de 4x4 até 11x11 (além de 3x3).
- **Tela de Gerenciamento:** Nova opção em *Configurações > Formações Táticas Padrão* para definir a formação preferida do grupo por tamanho de equipe.

### 🔐 Segurança do Administrador
- **Confirmação Biométrica / Senha:** Ações críticas e destrutivas (limpar histórico, editar partida, editar ou excluir grupo/pelada) agora exigem autenticação do dispositivo (digital/PIN/padrão) ou senha do app.
- **Senha Segura:** Hash SHA-256 com sal e proteção contra força bruta (espera de 30s após 5 tentativas).
- **Remoção da senha antiga "0101".**

---

## 🛠️ Melhorias e Correções
- **Renderização de Avatares:** Correção do carregamento de fotos nos cards e chips, suportando assets locais (`assets/icons/...`) e URLs remotas com fallback para iniciais estilizadas.
- **Permissões de Admin:** Ações de edição do histórico e menu ⋮ do grupo ficam visíveis apenas para quem é administrador.
- **Nota Histórica:** A avaliação da nota do atleta considera todo o histórico com fórmula de decaimento ponderada.
- **Testes Unitários:** Cobertura de testes ampliada para 354 testes automatizados aprovados.
