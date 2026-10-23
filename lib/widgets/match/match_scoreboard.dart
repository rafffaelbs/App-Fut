import 'package:app_do_fut/constants/app_colors.dart';
import 'package:flutter/material.dart';
import 'team_logo.dart'; // Import the widget we just created

class MatchScoreboard extends StatelessWidget {
  // Data needed for display
  final int scoreRed;
  final int scoreWhite;
  final double redTeamRating;
  final double whiteTeamRating;
  final String timeString;
  final bool isMatchRunning;
  final bool isOvertime;
  final bool isReadyToStart;

  // Actions (Callbacks) that the Main Screen will handle
  final Function(bool isRed, int delta) onUpdateScore;
  final VoidCallback onStart;
  final VoidCallback onPause;
  final VoidCallback onStop;

  const MatchScoreboard({
    super.key,
    required this.scoreRed,
    required this.scoreWhite,
    required this.redTeamRating,
    required this.whiteTeamRating,
    required this.timeString,
    required this.isMatchRunning,
    required this.isOvertime,
    required this.isReadyToStart,
    required this.onUpdateScore,
    required this.onStart,
    required this.onPause,
    required this.onStop,
  });

  @override
  Widget build(BuildContext context) {
    final ratingColor = Colors.amber.withOpacity(0.86);

    return Container(
      padding: const EdgeInsets.fromLTRB(0, 10, 0, 20),
      color: AppColors.headerBlue,
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              // --- RED TEAM ---
              Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.star, color: ratingColor, size: 14),
                      const SizedBox(width: 4),
                      Text(
                        redTeamRating.toStringAsFixed(
                          1,
                        ), // Rounds to 1 decimal (e.g., 4.2)
                        style: TextStyle(
                          color: ratingColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  const TeamLogo(
                    label: "Barcelona",
                    assetPath: "assets/images/vermelho.png",
                  ),
                  Container(
                    margin: const EdgeInsets.only(top: 2, bottom: 2),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.redAccent.withValues(alpha: 0.20),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.redAccent.withValues(alpha: 0.6), width: 1),
                    ),
                    child: const Text(
                      "🔴 CIMA",
                      style: TextStyle(
                        color: Colors.redAccent,
                        fontSize: 9,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ),
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.remove, color: Colors.white24),
                        onPressed: () => onUpdateScore(true, -1),
                      ),
                      Text(
                        "$scoreRed",
                        style: TextStyle(
                          color: AppColors.textWhite,
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      IconButton(
                        icon: Icon(Icons.add, color: AppColors.accentBlue),
                        onPressed: () => onUpdateScore(true, 1),
                      ),
                    ],
                  ),
                ],
              ),

              // --- TIMER ---
              Column(
                children: [
                  Icon(
                    Icons.sports_soccer,
                    color: isMatchRunning ? AppColors.highlightGreen : AppColors.textDim,
                    size: 28,
                  ),
                  const SizedBox(height: 5),
                  Text(
                    timeString,
                    style: TextStyle(
                      color: isOvertime
                          ? AppColors.redTeam
                          : (isMatchRunning ? AppColors.highlightGreen : AppColors.textMuted),
                      fontSize: 28,
                      fontFamily: 'Courier',
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (isOvertime)
                    const Text(
                      "ACRÉSCIMO",
                      style: TextStyle(
                        color: AppColors.redTeam,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                ],
              ),

              // --- WHITE TEAM ---
              Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.star, color: ratingColor, size: 14),
                      const SizedBox(width: 4),
                      Text(
                        whiteTeamRating.toStringAsFixed(
                          1,
                        ), // Rounds to 1 decimal (e.g., 4.2)
                        style: TextStyle(
                          color: ratingColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  const TeamLogo(
                    label: "Real Madrid",
                    assetPath: "assets/images/branco.png",
                  ),
                  Container(
                    margin: const EdgeInsets.only(top: 2, bottom: 2),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.whiteTeamBorder, width: 1),
                    ),
                    child: const Text(
                      "⚪ BAIXO",
                      style: TextStyle(
                        color: AppColors.whiteTeam,
                        fontSize: 9,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ),
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.remove, color: Colors.white24),
                        onPressed: () => onUpdateScore(false, -1),
                      ),
                      Text(
                        "$scoreWhite",
                        style: const TextStyle(
                          color: AppColors.textWhite,
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.add, color: AppColors.accentBlue),
                        onPressed: () => onUpdateScore(false, 1),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 10),

          // --- BUTTONS LOGIC ---
          if (!isMatchRunning)
            Container(
              decoration: BoxDecoration(
                color: isReadyToStart
                    ? AppColors.highlightGreen
                    : AppColors.surfaceSubtle,
                shape: BoxShape.circle,
                boxShadow: isReadyToStart
                    ? [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.4),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ]
                    : [],
              ),
              child: IconButton(
                iconSize: 40,
                icon: Icon(
                  Icons.play_arrow,
                  color: isReadyToStart ? Colors.white : AppColors.textDim,
                ),
                onPressed: isReadyToStart ? onStart : null,
              ),
            )
          else
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildCircleBtn(AppColors.orangeStreak, Icons.pause, onPause),
                const SizedBox(width: 40),
                _buildCircleBtn(AppColors.redTeam, Icons.stop, onStop),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildCircleBtn(Color color, IconData icon, VoidCallback onPressed) {
    return Container(
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      child: IconButton(
        iconSize: 32,
        icon: Icon(icon, color: Colors.white),
        onPressed: onPressed,
      ),
    );
  }
}
