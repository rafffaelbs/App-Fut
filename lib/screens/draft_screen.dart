import 'package:app_do_fut/constants/app_colors.dart';
import 'package:flutter/material.dart';
import '../utils/rating_calculator.dart';
import '../utils/player_identity.dart';

/// ============================================================
/// draft_screen.dart
/// ============================================================
/// Tela de Draft com Capitães.
///
/// Fluxo:
///  1. Os [numTeams] jogadores com maior nota histórica viram capitães.
///  2. Os capitães escolhem em ordem CRESCENTE de nota (pior capitão escolhe
///     primeiro), alternando em snake draft até que todos os times estejam
///     completos.
///  3. Ao finalizar, retorna List<List<Map<String,dynamic>>> (os times).
/// ============================================================

class DraftScreen extends StatefulWidget {
  /// Todos os jogadores presentes (já ordenados por chegada, mas serão
  /// reordenados internamente).
  final List<Map<String, dynamic>> presentPlayers;

  /// Quantos jogadores por time.
  final int playersPerTeam;

  const DraftScreen({
    super.key,
    required this.presentPlayers,
    required this.playersPerTeam,
  });

  @override
  State<DraftScreen> createState() => _DraftScreenState();
}

class _DraftScreenState extends State<DraftScreen> {
  // ─── Estado central ───────────────────────────────────────
  late int numTeams;
  late List<Map<String, dynamic>> captains;
  late List<List<Map<String, dynamic>>> teams;
  late List<Map<String, dynamic>> available;

  // índice do capitão que está escolhendo agora
  int _currentPickIndex = 0;

  // snake draft: direção atual (true = crescente, false = decrescente)
  bool _pickDirectionForward = true;

  // fase: 'picking' ou 'done'
  String _phase = 'picking';

  String _pid(Map<String, dynamic> p) => playerIdFromObject(p);

  @override
  void initState() {
    super.initState();
    _setupDraft();
  }

  void _setupDraft() {
    final int totalPlayers = widget.presentPlayers.length;
    numTeams = totalPlayers ~/ widget.playersPerTeam;
    if (numTeams < 2) numTeams = 2;

    // Ordena por nota decrescente para pegar os top numTeams como capitães
    final sorted = List<Map<String, dynamic>>.from(widget.presentPlayers)
      ..sort((a, b) {
        final double ra = (a['rating'] ?? kRatingBase).toDouble();
        final double rb = (b['rating'] ?? kRatingBase).toDouble();
        return rb.compareTo(ra);
      });

    // Os numTeams melhores são capitães; ordena capitães por nota ASCENDENTE
    // (pior capitão escolhe primeiro)
    captains = sorted.take(numTeams).toList()
      ..sort((a, b) {
        final double ra = (a['rating'] ?? kRatingBase).toDouble();
        final double rb = (b['rating'] ?? kRatingBase).toDouble();
        return ra.compareTo(rb); // ascendente
      });

    // Cria os times com os capitães já incluídos
    teams = List.generate(numTeams, (i) => [captains[i]]);

    // Jogadores disponíveis = todos menos os capitães
    final captainIds = captains.map(_pid).toSet();
    available = sorted.where((p) => !captainIds.contains(_pid(p))).toList();

    // A ordem de picking começa pelo 1º capitão (pior nota)
    _currentPickIndex = 0;
    _pickDirectionForward = true;
    _phase = available.isEmpty ? 'done' : 'picking';
  }

  void _pick(Map<String, dynamic> player) {
    if (_phase != 'picking') return;

    setState(() {
      teams[_currentPickIndex].add(player);
      available.removeWhere((p) => _pid(p) == _pid(player));

      if (available.isEmpty) {
        _phase = 'done';
        return;
      }

      // Snake draft: avança ou inverte direção
      if (_pickDirectionForward) {
        if (_currentPickIndex < numTeams - 1) {
          _currentPickIndex++;
        } else {
          // chegou ao último — inverte
          _pickDirectionForward = false;
          // não muda o índice, o último escolhe de volta
        }
      } else {
        if (_currentPickIndex > 0) {
          _currentPickIndex--;
        } else {
          // chegou ao primeiro — inverte
          _pickDirectionForward = true;
        }
      }

      // Se o time atual já está cheio, avança para o próximo que ainda precisa
      int safety = 0;
      while (teams[_currentPickIndex].length >= widget.playersPerTeam && available.isNotEmpty) {
        if (_pickDirectionForward) {
          _currentPickIndex = (_currentPickIndex + 1) % numTeams;
        } else {
          _currentPickIndex = (_currentPickIndex - 1 + numTeams) % numTeams;
        }
        safety++;
        if (safety > numTeams * 2) break;
      }

      if (available.isEmpty) _phase = 'done';
    });
  }

  void _confirmDraft() {
    // Retorna a lista de times: [time0, time1, ...]
    Navigator.pop(context, teams);
  }

  // ─── Helpers visuais ──────────────────────────────────────

  Color _teamColor(int index) {
    const colors = [Colors.redAccent, Colors.white, Colors.blueAccent, Colors.greenAccent, Colors.orangeAccent];
    return colors[index % colors.length];
  }

  String _teamName(int index) {
    const names = ['Vermelho', 'Branco', 'Azul', 'Verde', 'Laranja'];
    return names[index % names.length];
  }

  Widget _playerAvatar(Map<String, dynamic> p, {double radius = 18}) {
    return CircleAvatar(
      radius: radius,
      backgroundColor: AppColors.deepBlue,
      backgroundImage: p['icon'] != null ? AssetImage(p['icon']) : null,
      child: p['icon'] == null
          ? Text(
              (p['name'] as String).isNotEmpty ? (p['name'] as String)[0].toUpperCase() : '?',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: radius * 0.8),
            )
          : null,
    );
  }

  // ─── Build ────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.deepBlue,
      appBar: AppBar(
        backgroundColor: AppColors.headerBlue,
        iconTheme: const IconThemeData(color: AppColors.textWhite),
        title: const Text('Draft — Escolha dos Times', style: TextStyle(color: AppColors.textWhite)),
        centerTitle: true,
        elevation: 0,
      ),
      body: Column(
        children: [
          // ── Cabeçalho: quem está escolhendo ──────────────
          if (_phase == 'picking') _buildPickingHeader(),
          // ── Times formados ───────────────────────────────
          _buildTeamsSummary(),
          const Divider(color: Colors.white12, height: 1),
          // ── Jogadores disponíveis ────────────────────────
          Expanded(child: _phase == 'picking' ? _buildAvailablePlayers() : _buildDoneView()),
        ],
      ),
      bottomNavigationBar: _phase == 'done'
          ? SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    minimumSize: const Size.fromHeight(52),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: const Icon(Icons.sports_soccer, color: Colors.white),
                  label: const Text('Sortear Confronto e Iniciar', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                  onPressed: _confirmDraft,
                ),
              ),
            )
          : null,
    );
  }

  Widget _buildPickingHeader() {
    final cap = captains[_currentPickIndex];
    final color = _teamColor(_currentPickIndex);
    final teamName = _teamName(_currentPickIndex);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      color: color.withValues(alpha: 0.15),
      child: Row(
        children: [
          _playerAvatar(cap, radius: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'VEZ DE ${cap['name'].toUpperCase()}',
                  style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 15),
                ),
                Text(
                  'Capitão do time $teamName — toque em um jogador para escolher',
                  style: const TextStyle(color: Colors.white54, fontSize: 12),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(color: color.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(8)),
            child: Text(
              '${teams[_currentPickIndex].length}/${widget.playersPerTeam}',
              style: TextStyle(color: color, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTeamsSummary() {
    return Container(
      color: AppColors.headerBlue.withValues(alpha: 0.5),
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: List.generate(numTeams, (i) {
          final color = _teamColor(i);
          final isActive = _phase == 'picking' && _currentPickIndex == i;
          return Expanded(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.symmetric(horizontal: 4),
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isActive ? color.withValues(alpha: 0.18) : Colors.transparent,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: isActive ? color : Colors.white12, width: isActive ? 1.5 : 0.5),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _teamName(i),
                    style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                  const SizedBox(height: 4),
                  ...teams[i].map((p) {
                    final bool isCap = _pid(p) == _pid(captains[i]);
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Row(
                        children: [
                          _playerAvatar(p, radius: 10),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              p['name'],
                              style: TextStyle(
                                color: isCap ? color : Colors.white70,
                                fontSize: 11,
                                fontWeight: isCap ? FontWeight.bold : FontWeight.normal,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (isCap) ...[
                            const SizedBox(width: 2),
                            Icon(Icons.star, color: color, size: 10),
                          ],
                        ],
                      ),
                    );
                  }),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildAvailablePlayers() {
    if (available.isEmpty) {
      return const Center(child: Text('Todos escolhidos!', style: TextStyle(color: Colors.white54)));
    }
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: available.length,
      itemBuilder: (context, index) {
        final player = available[index];
        final double rating = (player['rating'] ?? kRatingBase).toDouble();
        final color = _teamColor(_currentPickIndex);
        return Card(
          color: AppColors.headerBlue,
          margin: const EdgeInsets.only(bottom: 8),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          child: ListTile(
            leading: _playerAvatar(player, radius: 20),
            title: Text(player['name'], style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  rating.toStringAsFixed(1),
                  style: TextStyle(color: getRatingColor(rating), fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(width: 12),
                Icon(Icons.add_circle, color: color, size: 28),
              ],
            ),
            onTap: () => _pick(player),
          ),
        );
      },
    );
  }

  Widget _buildDoneView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Center(
            child: Text(
              '✅ Draft Concluído!',
              style: TextStyle(color: Colors.greenAccent, fontSize: 20, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(height: 16),
          ...List.generate(numTeams, (i) {
            final color = _teamColor(i);
            return Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: color.withValues(alpha: 0.4)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Time ${_teamName(i)}',
                    style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 8),
                  ...teams[i].map((p) {
                    final bool isCap = _pid(p) == _pid(captains[i]);
                    final double rating = (p['rating'] ?? kRatingBase).toDouble();
                    return ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      leading: _playerAvatar(p, radius: 16),
                      title: Text(
                        p['name'] + (isCap ? ' ★' : ''),
                        style: TextStyle(
                          color: isCap ? color : Colors.white,
                          fontWeight: isCap ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                      trailing: Text(
                        rating.toStringAsFixed(1),
                        style: TextStyle(color: getRatingColor(rating), fontWeight: FontWeight.bold),
                      ),
                    );
                  }),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

