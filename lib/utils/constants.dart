/// ============================================================
/// constants.dart
/// ============================================================
/// Constantes globais do aplicativo.
/// ============================================================

const List<String> availablePlayerIcons = [
  'assets/players_icons/adriano.png',
'assets/players_icons/arrascaeta.png',
'assets/players_icons/balota.png',
'assets/players_icons/beckham.png',
'assets/players_icons/bellingham.webp',
'assets/players_icons/bruyne.png',
'assets/players_icons/calleri.png',
'assets/players_icons/courtois.png',
'assets/players_icons/cr7.png',
'assets/players_icons/cruyff.png',
'assets/players_icons/dembele.png',
'assets/players_icons/depay.png',
'assets/players_icons/drogba.png',
'assets/players_icons/dybala.png',
'assets/players_icons/endrick.png',
'assets/players_icons/gabigol.png',
'assets/players_icons/garro.png',
'assets/players_icons/gerson.png',
'assets/players_icons/gomez.png',
'assets/players_icons/gullit.png',
'assets/players_icons/haaland.png',
'assets/players_icons/henry.png',
'assets/players_icons/ibra.png',
'assets/players_icons/iniesta.png',
'assets/players_icons/jardim.png',
'assets/players_icons/jorginho.png',
'assets/players_icons/kaka.png',
'assets/players_icons/kane.png',
'assets/players_icons/kroos.png',
'assets/players_icons/lahm.png',
'assets/players_icons/love.png',
'assets/players_icons/luciano.png',
'assets/players_icons/maldini.png',
'assets/players_icons/maradona.png',
'assets/players_icons/mbappe.png',
'assets/players_icons/messi.png',
'assets/players_icons/modric.png',
'assets/players_icons/mouse_hunter.png',
'assets/players_icons/neneca.png',
'assets/players_icons/neuer.png',
'assets/players_icons/neymar.png',
'assets/players_icons/ortiz.png',
'assets/players_icons/ozil.png',
'assets/players_icons/palmer.webp',
'assets/players_icons/paqueta.png',
'assets/players_icons/pedro.png',
'assets/players_icons/pele.png',
'assets/players_icons/pique.png',
'assets/players_icons/pirlo.png',
'assets/players_icons/plata.png',
'assets/players_icons/pogba.webp',
'assets/players_icons/puma.png',
'assets/players_icons/puyol.png',
'assets/players_icons/ramos.png',
'assets/players_icons/raphinha.webp',
'assets/players_icons/rayan.png',
'assets/players_icons/ribery.png',
'assets/players_icons/riquelme.png',
'assets/players_icons/robben.png',
'assets/players_icons/ronaldinho.png',
'assets/players_icons/ronaldo.png',
'assets/players_icons/rooney.png',
'assets/players_icons/roque.png',
'assets/players_icons/sch.png',
'assets/players_icons/seedorf.png',
'assets/players_icons/socrates.webp',
'assets/players_icons/torres.png',
'assets/players_icons/totti.png',
'assets/players_icons/valverde.png',
'assets/players_icons/vanpersie.png',
'assets/players_icons/varela.png',
'assets/players_icons/vegetti.png',
'assets/players_icons/vini.png',
'assets/players_icons/xavi.png',
'assets/players_icons/yamal.png',
'assets/players_icons/yashin.png',
'assets/players_icons/yuri.png',
];

/// ============================================================
/// Áudios customizados de gol disponíveis em assets/audio/
/// ============================================================
/// 'file': nome do arquivo na pasta assets/audio/
/// 'label': nome legível para exibição (se não definido, usa o nome do arquivo)
const List<Map<String, String>> availableGoalAudios = [
  {
    'file': 'arroganti_montagem.mp3',
    'label': 'Arroganti Montagem',
  },
{
  'file': 'default_goal.mp3',
  'label': 'Gol Padrão',
},
{
  'file': 'dictator.mp3',
  'label': 'El Ditator',
},
{
  'file': 'end.mp3',
  'label': 'Fim de Jogo',
},
{
  'file': 'farmo_aura.mp3',
  'label': 'Farmo Aura 67',
},
{
  'file': 'flamengoogogo.mp3',
  'label': 'Flamengo Ô Ô Ô',
},
{
  'file': 'gol_fox_sport.mp3',
  'label': 'Gol Fox Sports',
},
{
  'file': 'hino_vasco.mp3',
  'label': 'Hino do Vasco',
},
{
  'file': 'paysandu.mp3',
  'label': 'Paysandu',
},
{
  'file': 'quero_todos.mp3',
  'label': 'Quero Todos',
},
{
  'file': 'ratinho.mp3',
  'label': 'Ratinho Gol',
},
{
  'file': 'sai_todo_mundo.mp3',
  'label': 'Sai Todo Mundo',
},
{
  'file': 'siuuuuu.mp3',
  'label': 'Siuuuuu',
},
{
  'file': 'toma_dormindo_67.mp3',
  'label': 'Toma Dormindo 67',
},
{
  'file': 'yan_yeah.mp3',
  'label': 'Yan Yeah',
},
{
  'file': 'zapzap.mp3',
  'label': 'Zap Zap',
},
];

/// Extrai a lista de áudios de gol configurados a partir de uma string separada por vírgula.
List<String> parseGoalSounds(String? raw) {
  if (raw == null || raw.trim().isEmpty) return <String>[];
  return raw
      .split(',')
      .map((s) => s.trim())
      .where((s) => s.isNotEmpty)
      .toList();
}

/// Converte uma lista de áudios de volta para string delimitada por vírgula (ou null se vazia).
String? formatGoalSounds(List<String> sounds) {
  final clean = sounds.map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
  if (clean.isEmpty) return null;
  return clean.join(',');
}

/// Helper para obter o label amigável de um arquivo de áudio ou loop de áudios.
String getGoalAudioLabel(String? filename) {
  final sounds = parseGoalSounds(filename);
  if (sounds.isEmpty) return 'Padrão';
  if (sounds.length == 1) {
    final s = sounds.first;
    final found = availableGoalAudios.firstWhere(
      (item) => item['file'] == s,
      orElse: () => {'file': s, 'label': s},
    );
    return found['label'] ?? s;
  }

  final labels = sounds.map((s) {
    final found = availableGoalAudios.firstWhere(
      (item) => item['file'] == s,
      orElse: () => {'file': s, 'label': s},
    );
    return found['label'] ?? s;
  }).join(' ➔ ');
  return 'Loop (${sounds.length}): $labels';
}

