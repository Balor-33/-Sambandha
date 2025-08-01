import 'package:flutter/material.dart';
import 'dart:convert';
import 'dart:typed_data';

class MatchNotificationOverlay extends StatefulWidget {
  final String? currentUserProfilePicture;
  final String? matchedUserProfilePicture;
  final String matchedUserName;
  final VoidCallback onChat;
  final VoidCallback onContinue;

  const MatchNotificationOverlay({
    Key? key,
    required this.currentUserProfilePicture,
    required this.matchedUserProfilePicture,
    required this.matchedUserName,
    required this.onChat,
    required this.onContinue,
  }) : super(key: key);

  @override
  State<MatchNotificationOverlay> createState() =>
      _MatchNotificationOverlayState();
}

class _MatchNotificationOverlayState extends State<MatchNotificationOverlay>
    with TickerProviderStateMixin {
  late AnimationController _slideController;
  late AnimationController _heartController;
  late AnimationController _textController;
  late AnimationController _particleController;
  late AnimationController _buttonController;

  late Animation<Offset> _slideAnimation;
  late Animation<double> _heartScaleAnimation;
  late Animation<double> _heartRotationAnimation;
  late Animation<double> _textScaleAnimation;
  late Animation<double> _textOpacityAnimation;
  late Animation<double> _particleAnimation;
  late Animation<double> _buttonScaleAnimation;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _startAnimationSequence();
  }

  void _initializeAnimations() {
    // Slide animation for profile pictures
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    // Heart animation
    _heartController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );

    // Text animation
    _textController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    // Particle animation
    _particleController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );

    // Button animation
    _buttonController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );

    // Define animations
    _slideAnimation =
        Tween<Offset>(begin: const Offset(-2.0, 0.0), end: Offset.zero).animate(
          CurvedAnimation(parent: _slideController, curve: Curves.elasticOut),
        );

    _heartScaleAnimation =
        TweenSequence<double>([
          TweenSequenceItem(
            tween: Tween<double>(begin: 0.0, end: 1.5),
            weight: 60,
          ),
          TweenSequenceItem(
            tween: Tween<double>(begin: 1.5, end: 1.0),
            weight: 40,
          ),
        ]).animate(
          CurvedAnimation(parent: _heartController, curve: Curves.elasticOut),
        );

    _heartRotationAnimation = Tween<double>(begin: 0.0, end: 0.2).animate(
      CurvedAnimation(parent: _heartController, curve: Curves.easeInOut),
    );

    _textScaleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _textController, curve: Curves.bounceOut),
    );

    _textOpacityAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _textController, curve: Curves.easeIn));

    _particleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _particleController, curve: Curves.easeOut),
    );

    _buttonScaleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _buttonController, curve: Curves.bounceOut),
    );
  }

  void _startAnimationSequence() async {
    // Start slide animation immediately
    _slideController.forward();

    // Start particle animation
    _particleController.forward();

    // Wait a bit, then start heart animation
    await Future.delayed(const Duration(milliseconds: 400));
    _heartController.forward();

    // Wait a bit more, then start text animation
    await Future.delayed(const Duration(milliseconds: 300));
    _textController.forward();

    // Finally, show buttons
    await Future.delayed(const Duration(milliseconds: 400));
    _buttonController.forward();
  }

  @override
  void dispose() {
    _slideController.dispose();
    _heartController.dispose();
    _textController.dispose();
    _particleController.dispose();
    _buttonController.dispose();
    super.dispose();
  }

  Widget _buildProfileImage(String? base64Image, {bool isLeft = false}) {
    if (base64Image == null || base64Image.isEmpty) {
      return Container(
        width: 100,
        height: 100,
        decoration: BoxDecoration(
          color: const Color(0xFFE8E8E8),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 4),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.15),
              blurRadius: 15,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: const Icon(Icons.person, size: 50, color: Color(0xFFBDBDBD)),
      );
    }

    try {
      final Uint8List imageBytes = base64Decode(base64Image);
      return Container(
        width: 100,
        height: 100,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 4),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.15),
              blurRadius: 15,
              offset: const Offset(0, 8),
            ),
          ],
          image: DecorationImage(
            image: MemoryImage(imageBytes),
            fit: BoxFit.cover,
          ),
        ),
      );
    } catch (e) {
      return Container(
        width: 100,
        height: 100,
        decoration: BoxDecoration(
          color: const Color(0xFFE8E8E8),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 4),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.15),
              blurRadius: 15,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: const Icon(Icons.error, size: 50, color: Colors.red),
      );
    }
  }

  Widget _buildFloatingHeart(double size, Offset position, double delay) {
    return AnimatedBuilder(
      animation: _particleController,
      builder: (context, child) {
        final progress = (_particleController.value - delay).clamp(0.0, 1.0);
        final opacity = progress > 0.8 ? (1.0 - progress) * 5 : progress * 2;

        return Positioned(
          left: position.dx,
          top: position.dy - (progress * 100),
          child: Opacity(
            opacity: opacity.clamp(0.0, 1.0),
            child: Transform.rotate(
              angle: progress * 2,
              child: Icon(
                Icons.favorite,
                color: const Color(0xFFFF4458),
                size: size,
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black54,
      child: Stack(
        children: [
          // Floating hearts background
          ...[
            _buildFloatingHeart(20, const Offset(50, 400), 0.0),
            _buildFloatingHeart(15, const Offset(320, 450), 0.1),
            _buildFloatingHeart(25, const Offset(150, 420), 0.2),
            _buildFloatingHeart(18, const Offset(280, 380), 0.3),
            _buildFloatingHeart(22, const Offset(80, 350), 0.4),
            _buildFloatingHeart(16, const Offset(250, 500), 0.5),
          ],

          // Main content
          Center(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 32),
              padding: const EdgeInsets.all(40),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(32),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFFF4458).withOpacity(0.3),
                    blurRadius: 40,
                    spreadRadius: 10,
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Profile pictures with slide animation
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Left profile (current user)
                      SlideTransition(
                        position: _slideAnimation,
                        child: _buildProfileImage(
                          widget.currentUserProfilePicture,
                          isLeft: true,
                        ),
                      ),

                      const SizedBox(width: 20),

                      // Heart in the middle with scale and rotation animation
                      AnimatedBuilder(
                        animation: _heartController,
                        builder: (context, child) {
                          return Transform.scale(
                            scale: _heartScaleAnimation.value,
                            child: Transform.rotate(
                              angle: _heartRotationAnimation.value,
                              child: Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFF4458),
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(
                                        0xFFFF4458,
                                      ).withOpacity(0.4),
                                      blurRadius: 20,
                                      spreadRadius: 2,
                                    ),
                                  ],
                                ),
                                child: const Icon(
                                  Icons.favorite,
                                  color: Colors.white,
                                  size: 32,
                                ),
                              ),
                            ),
                          );
                        },
                      ),

                      const SizedBox(width: 20),

                      // Right profile (matched user) with opposite slide
                      SlideTransition(
                        position:
                            Tween<Offset>(
                              begin: const Offset(2.0, 0.0),
                              end: Offset.zero,
                            ).animate(
                              CurvedAnimation(
                                parent: _slideController,
                                curve: Curves.elasticOut,
                              ),
                            ),
                        child: _buildProfileImage(
                          widget.matchedUserProfilePicture,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 32),

                  // "It's a Match!" text with animation
                  AnimatedBuilder(
                    animation: _textController,
                    builder: (context, child) {
                      return Transform.scale(
                        scale: _textScaleAnimation.value,
                        child: Opacity(
                          opacity: _textOpacityAnimation.value,
                          child: Column(
                            children: [
                              ShaderMask(
                                shaderCallback: (bounds) =>
                                    const LinearGradient(
                                      colors: [
                                        Color(0xFFFF4458),
                                        Color(0xFFFF6B9D),
                                      ],
                                    ).createShader(bounds),
                                child: const Text(
                                  "It's a Match!",
                                  style: TextStyle(
                                    fontSize: 36,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'You and ${widget.matchedUserName} liked each other.',
                                style: const TextStyle(
                                  fontSize: 18,
                                  color: Color(0xFF2C2C2C),
                                  fontWeight: FontWeight.w500,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),

                  const SizedBox(height: 40),

                  // Buttons with scale animation
                  ScaleTransition(
                    scale: _buttonScaleAnimation,
                    child: Column(
                      children: [
                        // Start Chatting button
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: widget.onChat,
                            icon: const Icon(
                              Icons.chat_bubble_rounded,
                              size: 20,
                            ),
                            label: const Text(
                              'Start Chatting',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFFF4458),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(30),
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 32,
                                vertical: 16,
                              ),
                              elevation: 8,
                              shadowColor: const Color(
                                0xFFFF4458,
                              ).withOpacity(0.4),
                            ),
                          ),
                        ),

                        const SizedBox(height: 16),

                        // Continue Browsing button
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton(
                            onPressed: widget.onContinue,
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(
                                color: Color(0xFFFF4458),
                                width: 2,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(30),
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 32,
                                vertical: 16,
                              ),
                            ),
                            child: const Text(
                              'Continue Browsing',
                              style: TextStyle(
                                color: Color(0xFFFF4458),
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
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
