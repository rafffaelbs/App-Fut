# Plano de Ação - App-Fut

## 1. Correção de Bugs
- [x] Botão de desistir: O app de fato tira o jogador da fila, coloca ele como cinza, tem o botão de reativar funciona, no entanto, os jogadores ainda aparecem na hora que o proximo time entra. Então ele some da fila de proximos, mas ainda aparece no jogo quando o time dele entra, vamos dizer assim.
- [ ] Estatisticas Avançadas: Na tela de detalhes do jogador, a parte de estatisticas avançadas está bugada. Muitos numeros nao fazem sentido, como um jogador ter 10 derrotas e o jogador com quem ele mais perdeu esteve presente em 3 derrotas mas fala que isso representa cerca de 70% das derrotas dele, onde deveria ser 30%.

## 2. Segurança e Permissões (Apenas Admin)
- [ ] Revisar políticas de segurança (RLS - Row Level Security) do Supabase para prevenir abusos.
- [ ] Criar tabela/sistema de logs de ações no Supabase.
- [ ] Implementar mecanismo/alerta mensal para exportação e limpeza de logs.
- [ ] Tirar acesso de telas e opções de escritas para jogadores que não são admins. Esse tipo de jogador não pode editar nada, mesmo que o banco não permita, ainda aparece a opção no App. Depois de um tempo, podemos ir habilitando as telas de pouco em pouco.

## 3. Nova Feature: Versão Web & Autenticação
- [ ] Validar compilação e responsividade para versão Web.
- [ ] Assegurar funcionamento do login por e-mail no Web.
- [ ] Investigar/Implementar login via SSO (Google/Apple, por exemplo).

## 4. Customização Avançada (Apenas Admin)
- [ ] Dê sugestões de moldura do icone nos jogos e ranking. Temos algumas formas de diferenciar os jogadores: Ganhador da bola de ouro (somente 1 por enqt), ganhador do premio do mes (temos 6, alguns que ja ganharam 2 vezes), artilheiro da temporada e podemos criar outros no futuro.
- [ ] Aplicar visualmente os efeitos escolhidos na tela do jogo e placar.

## 5. Notas
- [ ] Adicionar a opção de nota do admin nos jogadores. Atualmente temos uma nota que é baseada em somente numeros, no entanto, iremos rodar uma votação e teremos 2 notas: A nota do app e a nota dada pela comunidade. Essa nota da comunidade iremos buscar esse numero por fora e colocaremos no app. A nova nota do jogador deve ser um calculo entre as nota do app e a nota da comunidade, sendo que a nota da comunidade deve ter um peso maior. Posso adicionar essa nota da comunidade via tela de detalhes do jogador.
- [ ] Melhorar a questão de nota e atualizar de nota como 0-10 para um rating de 0-100, similar ao Fifa. E esse rating é baseado tanto na nota do app tanto na nota da comunidade. So que agora preciso que tenha diferença entre os aspectos, ou seja, teremos a nota do app que será somente baseada nos numeros e a nota da comunidade que irá levar em conta as mesmas coisas do fifa, mas que a comunidade irá decidir.

## 6. Atualização de Design
- [ ] Alterar o tema do app para "Dark Mode" inspirado no Sofascore (tons escuros, verdes, destaques limpos).
- [ ] Revisar telas principais para garantir contraste e legibilidade no novo tema.
