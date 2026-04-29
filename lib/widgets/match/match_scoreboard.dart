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
      color: const Color(0xff001c55), // Header Blue
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
                    color: isMatchRunning ? Colors.greenAccent : Colors.grey,
                    size: 30,
                  ),
                  const SizedBox(height: 5),
                  Text(
                    timeString,
                    style: TextStyle(
                      color: isOvertime
                          ? Colors.redAccent
                          : (isMatchRunning ? Colors.greenAccent : Colors.grey),
                      fontSize: 28,
                      fontFamily: 'Courier',
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (isOvertime)
                    const Text(
                      "ACRÉSCIMO",
                      style: TextStyle(
                        color: Colors.redAccent,
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
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.remove, color: Colors.white24),
                        onPressed: () => onUpdateScore(false, -1),
                      ),
                      Text(
                        "$scoreWhite",
                        style: TextStyle(
                          color: AppColors.textWhite,
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      IconButton(
                        icon: Icon(Icons.add, color: AppColors.accentBlue),
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
                    ? Colors.green
                    : Colors.grey.withOpacity(0.3),
                shape: BoxShape.circle,
                boxShadow: isReadyToStart
                    ? [
                        BoxShadow(
                          color: Colors.green.withOpacity(0.4),
                          blurRadius: 10,
                          spreadRadius: 2,
                        ),
                      ]
                    : [],
              ),
              child: IconButton(
                iconSize: 40,
                icon: Icon(
                  Icons.play_arrow,
                  color: isReadyToStart ? Colors.white : Colors.white38,
                ),
                onPressed: isReadyToStart ? onStart : null,
              ),
            )
          else
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildCircleBtn(Colors.orangeAccent, Icons.pause, onPause),
                const SizedBox(width: 40),
                _buildCircleBtn(Colors.redAccent, Icons.stop, onStop),
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
