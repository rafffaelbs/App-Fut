/// Regras de "quem está valendo" na pelada. Funções puras (sem Flutter) para
/// serem testáveis: a tela da partida usa estas mesmas funções em todo lugar
/// que precisa saber quem pode jogar, entrar num sorteio ou ir pra fila.

/// O jogador foi marcado como desistente?
bool hasGivenUp(Map<String, dynamic> player) => player['desistiu'] == true;

/// Presentes que ainda estão na pelada (não desistiram), na ordem de chegada.
List<Map<String, dynamic>> activePlayers(List<Map<String, dynamic>> present) =>
    present.where((p) => !hasGivenUp(p)).toList();

/// Presentes ativos que NÃO estão em nenhum dos dois times (a fila).
List<Map<String, dynamic>> waitingPlayers(
  List<Map<String, dynamic>> present,
  List<Map<String, dynamic>> teamRed,
  List<Map<String, dynamic>> teamWhite,
  String Function(Map<String, dynamic>) idOf,
) {
  final playing = <String>{
    ...teamRed.map(idOf),
    ...teamWhite.map(idOf),
  };
  return present
      .where((p) => !hasGivenUp(p) && !playing.contains(idOf(p)))
      .toList();
}
