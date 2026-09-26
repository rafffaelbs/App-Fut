# Plano de Ação - App-Fut

## 1. Correção de Bugs: Troféus e Prêmios Especiais
- [x] Investigar e corrigir lógica de carregamento/atualização de troféus no perfil do jogador (bug do nome antigo).
- [x] Melhorar a tela de gerenciamento de troféus especiais (renomeada para "Customizações" com abas).
- [x] Impedir entrega de troféus repetidos (troféus já resgatados ficam cinza com texto "Resgatado por [Nome]").
- [x] Corrigir nome da coluna no Supabase (era `badges`, correto é `manual_badges`).
- [x] Corrigir remoção de troféu (agora remove por ID, não por índice).
- [x] Restringir ações de escrita (dar/remover troféus) somente para Admins.
- [x] Limpar troféus fantasmas no banco de dados via SQL (troféu "Craque de Janeiro de 2026" aparecendo em todos).

## 2. Segurança e Permissões (Apenas Admin)
- [ ] Revisar políticas de segurança (RLS - Row Level Security) do Supabase para prevenir abusos.
- [ ] Criar tabela/sistema de logs de ações no Supabase.
- [ ] Implementar mecanismo/alerta mensal para exportação e limpeza de logs.

## 3. Nova Feature: Versão Web & Autenticação
- [ ] Validar compilação e responsividade para versão Web.
- [ ] Assegurar funcionamento do login por e-mail no Web.
- [ ] Investigar/Implementar login via SSO (Google/Apple, por exemplo).

## 4. Customização Avançada (Apenas Admin)
- [ ] Criar interface na nova aba "Efeitos" da tela de Customizações para admin escolher efeitos especiais (destaque no nome/ícone).
- [ ] Dê sugestões e crie efeitos de nome (nome dourado por exemplo) e de moldura do icone nos jogos e ranking. Temos algumas formas de diferenciar os jogadores: Ganhador da bola de ouro (somente 1 por enqt), ganhador do premio do mes (temos 6, alguns que ja ganharam 2 vezes), artilheiro da temporada e podemos criar outros no futuro.
- [x] Criar interface na nova aba "Áudios" da tela de Customizações para admin fazer upload/escolher áudios de comemoração de gols.
- [ ] Bug na parte de aúdio: Parece que uma vez que eu coloco o aúdio para alguém, esse aúdio fica pra sempre (acho que não está sendo atualizado o banco de dados).
- [ ] Bug na parte de aúdio: Na versão chrome, todos os aúdios tocam, enqt na versão mobile, 2 aúdios especificos (acredito que os primeiros adicionados), não estão tocando
- [ ] Integrar áudios ao Storage do Supabase (tocar som customizado se existir, caso contrário, genérico).
- [ ] Aplicar visualmente os efeitos escolhidos na tela do jogo e placar.

## 6. Atualização de Design
- [ ] Alterar o tema do app para "Dark Mode" inspirado no Sofascore (tons escuros, verdes, destaques limpos).
- [ ] Revisar telas principais para garantir contraste e legibilidade no novo tema.
