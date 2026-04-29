import 'package:app_do_fut/constants/app_colors.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';

class BlankScreen extends StatefulWidget {
  const BlankScreen({super.key});

  @override
  State<BlankScreen> createState() => _BlankScreenState();
}

class _BlankScreenState extends State<BlankScreen> {
  final AudioPlayer _player = AudioPlayer();

  @override
  void initState() {
    super.initState();
    _playAudio();
  }

  Future<void> _playAudio() async {
    await _player.play(AssetSource('audio/whatsapp.mp3'));
    debugPrint('\t -- Audio esta tocando');
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // This property allows the image to go BEHIND the status bar and AppBar
      extendBodyBehindAppBar: true,

      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Container(
            // Adding a small background to the back button so it's visible on any image
            padding: const EdgeInsets.all(8),
            decoration: const BoxDecoration(
              color: Colors.black26,
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.arrow_back, color: AppColors.textWhite),
          ),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Stack(
        children: [
          // LAYER 1: The Full Screen Image
          Positioned.fill(
            child: Image.asset(
              'assets/images/imagem_teste.jpeg',
              fit: BoxFit.cover, // This stretches the image to fill the screen
            ),
          ),

          // LAYER 2: The Dimming Overlay (Optional but recommended for text readability)
          Positioned.fill(
            child: Container(
              color: Colors.black.withOpacity(0.6,
              ), // Adjust 0.6 to make it darker/lighter
            ),
          ),

          // LAYER 3: The Content (Text & Button)
          Center(
            child: Padding(
              padding: const EdgeInsets.all(32.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(height: 200),
                  // The "In Construction" Icon
                  Icon(
                    Icons.handyman_outlined,
                    size: 60,
                    color: AppColors.accentBlue,
                  ),

                  const SizedBox(height: 24),

                  Text(
                    "Calma Chocolate Branco",
                    style: TextStyle(
                      color: AppColors.textWhite,
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.5,
                      shadows: [
                        Shadow(
                          offset: const Offset(0, 2),
                          blurRadius: 4.0,
                          color: Colors.black.withOpacity(0.5),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  Text(
                    "Estamos trabalhando para arrumar essa parte.",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppColors.textWhite.withOpacity(0.9),
                      fontSize: 18,
                      height: 1.5,
                    ),
                  ),

                  const SizedBox(height: 100),

                  Row(
                    children: [
                      SizedBox(width: 163),
                      SizedBox(
                        width: 90,
                        height: 360,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.accentBlue,
                            foregroundColor: AppColors.textWhite,
                            elevation: 5,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          onPressed: () {
                            if (Navigator.canPop(context)) {
                              Navigator.pop(context);
                            }
                          },
                          child: const Text(
                            "Foi Mal",
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
