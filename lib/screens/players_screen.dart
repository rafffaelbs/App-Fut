import 'dart:convert'; // 1. Import for JSON
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart'; // 2. Import for Saving
import '../../constants/app_colors.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart'; // 3. Import for Stars

class PlayersScreen extends StatefulWidget {
  const PlayersScreen({super.key});

  @override
  State<PlayersScreen> createState() => _PlayersScreenState();
}

class _PlayersScreenState extends State<PlayersScreen> {
  // We start with an empty list. The data will come from storage.
  List<Map<String, dynamic>> players = [];

  @override
  void initState() {
    super.initState();
    _loadPlayers(); // 3. Load data when screen starts
  }

  // --- SAVE & LOAD LOGIC ---

  // LOAD: Get the string from storage -> Convert to List -> Update UI
  Future<void> _loadPlayers() async {
    final prefs = await SharedPreferences.getInstance();
    final String? playersString = prefs.getString('players_key');

    if (playersString != null) {
      // Decode the JSON string back into a List
      setState(() {
        players = List<Map<String, dynamic>>.from(jsonDecode(playersString));
      });
    }
  }

  // SAVE: Convert List to String -> Write to storage
  Future<void> _savePlayers() async {
    final prefs = await SharedPreferences.getInstance();
    // Encode the List into a JSON string
    final String encodedData = jsonEncode(players);
    await prefs.setString('players_key', encodedData);
  }

  // -------------------------

  // UPDATED: Now accepts rating
  void _addNewPlayer(String name, double rating) {
    setState(() {
      players.add({
        'name': name, 
        'position': '',
        'rating': rating, // Save the rating!
      });
    });
    _savePlayers(); // 4. Save immediately after adding
  }

  void _removePlayer(int index) {
    setState(() {
      players.removeAt(index);
    });
    _savePlayers(); // 5. Save immediately after removing
  }

  void _showAddPlayerDialog() {
    final TextEditingController controller = TextEditingController();
    double currentRating = 3.0; // Default rating when dialog opens

    showDialog(
      context: context,
      builder: (context) {
        // We use a StatefulBuilder so the stars can update INSIDE the dialog
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              backgroundColor: AppColors.headerBlue,
              title: const Text(
                'Adicionar Jogador',
                style: TextStyle(color: AppColors.textWhite),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min, // Make column wrap its content
                children: [
                  TextField(
                    controller: controller,
                    style: const TextStyle(color: AppColors.textWhite),
                    decoration: const InputDecoration(
                      hintText: "Nome do jogador",
                      hintStyle: TextStyle(color: Colors.white54),
                      enabledBorder: UnderlineInputBorder(
                        borderSide: BorderSide(color: AppColors.accentBlue),
                      ),
                      focusedBorder: UnderlineInputBorder(
                        borderSide: BorderSide(color: AppColors.accentBlue, width: 2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    "Nível do Jogador",
                    style: TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                  const SizedBox(height: 8),
                  // THE INTERACTIVE STARS
                  RatingBar.builder(
                    initialRating: currentRating,
                    minRating: 0.5,
                    direction: Axis.horizontal,
                    allowHalfRating: true,
                    itemCount: 5,
                    itemPadding: const EdgeInsets.symmetric(horizontal: 4.0),
                    itemBuilder: (context, _) => const Icon(
                      Icons.star,
                      color: Colors.amber,
                    ),
                    onRatingUpdate: (rating) {
                      setStateDialog(() {
                        currentRating = rating; // Update rating when clicked
                      });
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text(
                    'Cancelar',
                    style: TextStyle(color: Colors.redAccent),
                  ),
                ),
                TextButton(
                  onPressed: () {
                    if (controller.text.isNotEmpty) {
                      _addNewPlayer(controller.text, currentRating); // Pass rating here
                      Navigator.pop(context);
                    }
                  },
                  child: const Text(
                    'Salvar',
                    style: TextStyle(
                      color: AppColors.accentBlue,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.deepBlue,
      appBar: AppBar(
        backgroundColor: AppColors.headerBlue,
        elevation: 0,
        iconTheme: const IconThemeData(
          color: AppColors.textWhite,
        ), // Ensures back arrow is white
        title: const Text(
          'Jogadores',
          style: TextStyle(
            color: AppColors.textWhite,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: players.isEmpty
          ? const Center(
              child: Text(
                "Nenhum jogador cadastrado",
                style: TextStyle(color: Colors.white54),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: players.length,
              itemBuilder: (context, index) {
                final player = players[index];
                final String initial = player['name']!.substring(0, 1).toUpperCase();

                // Safely get rating (in case older saved players don't have it)
                final double playerRating = player['rating'] != null 
                    ? (player['rating'] as num).toDouble() 
                    : 0.0;

                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: AppColors.headerBlue,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    leading: CircleAvatar(
                      backgroundColor: AppColors.accentBlue,
                      foregroundColor: AppColors.textWhite,
                      child: Text(
                        initial,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    title: Text(
                      player['name'],
                      style: const TextStyle(
                        color: AppColors.textWhite,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
 
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 6),
                        if (playerRating > 0)
                          RatingBarIndicator(
                            rating: playerRating,
                            itemBuilder: (context, index) => const Icon(
                              Icons.star,
                              color: Colors.amber,
                            ),
                            itemCount: 5,
                            itemSize: 16.0,
                            unratedColor: Colors.white24,
                          ),
                      ],
                    ),
                    trailing: IconButton(
                      icon: const Icon(
                        Icons.delete_outline,
                        color: Colors.redAccent,
                      ),
                      onPressed: () => _removePlayer(index),
                    ),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.accentBlue,
        onPressed: _showAddPlayerDialog,
        child: const Icon(Icons.person_add, color: AppColors.textWhite),
      ),
    );
  }
}