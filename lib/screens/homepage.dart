import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:convert';
import 'dart:typed_data';
import '../services/recommendation_service.dart';
import '../model/recommendation_model.dart';
import '../services/firebase_user_service.dart';
import '../model/user_action_model.dart';
import 'dart:async';
import 'matches_screen.dart';
import '../widgets/notification_overlay.dart';
import 'updateprofile.dart'; // Add this import

class Homepage extends StatefulWidget {
  const Homepage({Key? key}) : super(key: key);

  @override
  State<Homepage> createState() => _HomepageState();
}

class _HomepageState extends State<Homepage> with TickerProviderStateMixin {
  int _selectedIndex = 0;
  late AnimationController _cardController;
  late AnimationController _flashController;
  late AnimationController _passButtonController;
  late AnimationController _likeButtonController;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _scaleAnimation;
  late Animation<double> _flashAnimation;
  late Animation<double> _passButtonScaleAnimation;
  late Animation<double> _likeButtonScaleAnimation;

  // Recommendation system
  final RecommendationService _recommendationService = RecommendationService();
  List<RecommendedUser> _recommendedUsers = [];
  int _currentProfileIndex = 0;
  bool _isLoading = true;
  String? _errorMessage;

  Color _flashColor = Colors.transparent;
  bool _isFlashing = false;

  // Match notification system
  final FirebaseUserService _firebaseUserService = FirebaseUserService();
  StreamSubscription<List<UserAction>>? _matchSubscription;
  List<UserAction> _matches = [];
  bool _showMatchDialog = false;
  String? _matchedUserName;
  String? _currentUserProfilePicture;
  String? _matchedUserProfilePicture;
  AnimationController? _pulseController;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _loadRecommendedUsers();
    _listenForMatches();
    _initCurrentUserProfilePicture();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
  }

  void _initializeAnimations() {
    _cardController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );

    _flashController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _passButtonController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );

    _likeButtonController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );

    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.1), end: Offset.zero).animate(
          CurvedAnimation(parent: _cardController, curve: Curves.easeOutCubic),
        );

    _scaleAnimation = Tween<double>(begin: 0.95, end: 1.0).animate(
      CurvedAnimation(parent: _cardController, curve: Curves.easeOutBack),
    );

    _flashAnimation = Tween<double>(begin: 0.0, end: 0.4).animate(
      CurvedAnimation(parent: _flashController, curve: Curves.easeInOut),
    );

    _passButtonScaleAnimation =
        TweenSequence<double>([
          TweenSequenceItem(
            tween: Tween<double>(begin: 1.0, end: 0.8),
            weight: 50,
          ),
          TweenSequenceItem(
            tween: Tween<double>(begin: 0.8, end: 1.1),
            weight: 30,
          ),
          TweenSequenceItem(
            tween: Tween<double>(begin: 1.1, end: 1.0),
            weight: 20,
          ),
        ]).animate(
          CurvedAnimation(parent: _passButtonController, curve: Curves.easeOut),
        );

    _likeButtonScaleAnimation =
        TweenSequence<double>([
          TweenSequenceItem(
            tween: Tween<double>(begin: 1.0, end: 0.8),
            weight: 50,
          ),
          TweenSequenceItem(
            tween: Tween<double>(begin: 0.8, end: 1.1),
            weight: 30,
          ),
          TweenSequenceItem(
            tween: Tween<double>(begin: 1.1, end: 1.0),
            weight: 20,
          ),
        ]).animate(
          CurvedAnimation(parent: _likeButtonController, curve: Curves.easeOut),
        );
  }

  Future<void> _loadRecommendedUsers() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      print('Loading recommended users...'); // Debug log

      final recommendedUsers = await _recommendationService.getRecommendedUsers(
        limit: 20,
      );

      print('Loaded ${recommendedUsers.length} recommended users'); // Debug log

      setState(() {
        _recommendedUsers = recommendedUsers;
        _currentProfileIndex = 0;
        _isLoading = false;
      });

      if (_recommendedUsers.isNotEmpty) {
        _cardController.forward();
      }
    } catch (e) {
      print('Error loading recommended users: $e'); // Debug log
      setState(() {
        _isLoading = false;
        _errorMessage = e.toString();
      });
    }
  }

  // Enhanced _listenForMatches method
  void _listenForMatches() {
    final userId = _firebaseUserService.currentUserId;
    if (userId == null) {
      print('Error: Current user ID is null, cannot listen for matches');
      return;
    }

    print('Starting to listen for matches for user: $userId');

    // Listen for actions targeting current user with real-time updates
    _matchSubscription = _firebaseUserService
        .getActionsTargetingUserStream(userId: userId)
        .listen(
          (actions) async {
            print('Received ${actions.length} actions targeting user $userId');

            // Process each action
            for (final action in actions) {
              print(
                'Processing action: ${action.actionId}, type: ${action.actionType}, '
                'matchStatus: ${action.matchStatus}, actorUserId: ${action.actorUserId}',
              );

              // Check for newly matched likes (matchStatus became true)
              if (action.actionType == 'like' && action.matchStatus == true) {
                await _handleNewMatch(action);
              }
            }
          },
          onError: (error) {
            print('Error listening for matches: $error');
            // Optionally show a snackbar or toast to the user
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'Connection error: Unable to receive match notifications',
                  ),
                  backgroundColor: Colors.orange,
                  duration: Duration(seconds: 3),
                ),
              );
            }
          },
          cancelOnError: false, // Keep listening even if there's an error
        );
  }

  // Separate method to handle new matches for better organization
  Future<void> _handleNewMatch(UserAction action) async {
    try {
      // Check if we've already shown this match
      if (_matches.any((m) => m.actionId == action.actionId)) {
        print('Match already processed for action ID: ${action.actionId}');
        return;
      }

      print('New match detected! Action ID: ${action.actionId}');

      // Load the matched user's profile picture
      await _loadMatchedUserProfilePicture(action.actorUserId);

      // Get the matched user's name - first try from current recommendations
      String matchedUserName = _getMatchedUserNameFromRecommendations(
        action.actorUserId,
      );

      // If not found in recommendations, fetch from Firebase
      if (matchedUserName == 'Someone') {
        matchedUserName = await _getMatchedUserNameFromFirebase(
          action.actorUserId,
        );
      }

      // Show the match dialog
      if (mounted) {
        setState(() {
          _matches.add(action);
          _showMatchDialog = true;
          _matchedUserName = matchedUserName;
        });

        print('Match dialog displayed for user: $matchedUserName');

        // Optional: Add haptic feedback for better UX
        try {
          HapticFeedback.heavyImpact();
        } catch (e) {
          print('Haptic feedback not available: $e');
        }
      }
    } catch (e) {
      print('Error handling new match: $e');
      // Optionally show error to user
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error processing match notification'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 2),
          ),
        );
      }
    }
  }

  // Helper method to get matched user name from current recommendations
  String _getMatchedUserNameFromRecommendations(String userId) {
    try {
      final matchedUser = _recommendedUsers.firstWhere(
        (u) => u.userId == userId,
        orElse: () => RecommendedUser(
          userId: userId,
          name: 'Someone', // Default name if user not found
          age: 0,
          gender: [],
          interests: [],
          hobbies: [],
          targetRelation: '',
          matchScore: 0,
          ageCompatibilityScore: 0,
          genderCompatibilityScore: 0,
          hobbyMatchScore: 0,
          targetRelationScore: 0,
        ),
      );

      return matchedUser.name;
    } catch (e) {
      print('Error getting matched user from recommendations: $e');
      return 'Someone';
    }
  }

  // Helper method to get matched user name from Firebase
  Future<String> _getMatchedUserNameFromFirebase(String userId) async {
    try {
      print('Fetching user data from Firebase for userId: $userId');
      final userData = await _firebaseUserService.getUserInterests(userId);

      final name = userData?['name']?.toString() ?? 'Someone';
      print('Retrieved name from Firebase: $name');

      return name;
    } catch (e) {
      print('Error getting matched user name from Firebase: $e');
      return 'Someone';
    }
  }

  // Enhanced dispose method to ensure proper cleanup
  @override
  void dispose() {
    print('Disposing homepage resources...');

    _cardController.dispose();
    _flashController.dispose();
    _passButtonController.dispose();
    _likeButtonController.dispose();
    _pulseController?.dispose();

    // Cancel match subscription with proper error handling
    _matchSubscription
        ?.cancel()
        .then((_) {
          print('Match subscription cancelled successfully');
        })
        .catchError((error) {
          print('Error cancelling match subscription: $error');
        });

    super.dispose();
  }

  Future<void> _initCurrentUserProfilePicture() async {
    final userId = _firebaseUserService.currentUserId;
    if (userId != null) {
      final pic = await _firebaseUserService.getUserProfilePicture(userId);
      setState(() {
        _currentUserProfilePicture = pic;
      });
    }
  }

  // Enhanced method to load matched user profile picture with error handling
  Future<void> _loadMatchedUserProfilePicture(String matchedUserId) async {
    try {
      print('Loading profile picture for matched user: $matchedUserId');
      final pic = await _firebaseUserService.getUserProfilePicture(
        matchedUserId,
      );

      if (mounted) {
        setState(() {
          _matchedUserProfilePicture = pic;
        });
      }

      print('Profile picture loaded successfully');
    } catch (e) {
      print('Error loading matched user profile picture: $e');
      // Set to null so the UI can handle the missing image gracefully
      if (mounted) {
        setState(() {
          _matchedUserProfilePicture = null;
        });
      }
    }
  }

  void _onItemTapped(int index) {
    // Handle profile tab navigation
    if (index == 3) {
      // Profile tab index
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const UpdateProfilePage()),
      );
      return; // Don't update _selectedIndex, keep user on current tab
    }

    setState(() {
      _selectedIndex = index;
    });
  }

  void _nextProfile() {
    if (_currentProfileIndex < _recommendedUsers.length - 1) {
      setState(() {
        _currentProfileIndex++;
      });
      _cardController.reset();
      _cardController.forward();
    } else {
      // Load more recommendations when we reach the end
      _loadMoreRecommendations();
    }
  }

  Future<void> _loadMoreRecommendations() async {
    try {
      final moreUsers = await _recommendationService.getRecommendedUsers(
        limit: 10,
        excludeUserIds: _recommendedUsers.map((u) => u.userId).toList(),
      );

      setState(() {
        _recommendedUsers.addAll(moreUsers);
        if (_recommendedUsers.isNotEmpty &&
            _currentProfileIndex < _recommendedUsers.length - 1) {
          _currentProfileIndex++;
          _cardController.reset();
          _cardController.forward();
        }
      });
    } catch (e) {
      print('Error loading more recommendations: $e');
    }
  }

  void _showFlash(Color color) {
    setState(() {
      _flashColor = color;
      _isFlashing = true;
    });

    _flashController.forward().then((_) {
      _flashController.reverse().then((_) {
        setState(() {
          _isFlashing = false;
        });
      });
    });
  }

  Future<void> _handleAction(String actionType) async {
    if (_recommendedUsers.isEmpty) return;

    final targetUserId = _recommendedUsers[_currentProfileIndex].userId;
    final targetUserName = _recommendedUsers[_currentProfileIndex].name;

    try {
      print('Handling $actionType action for user: $targetUserId');

      final result = await _firebaseUserService.recordUserAction(
        targetUserId: targetUserId,
        actionType: actionType,
      );

      // If it's a like action and result is true (immediate match)
      if (actionType == 'like' && result == true) {
        print('Immediate match detected!');

        await _loadMatchedUserProfilePicture(targetUserId);

        setState(() {
          _showMatchDialog = true;
          _matchedUserName = targetUserName;
        });
      }
    } catch (e) {
      print('Error recording user action: $e');
    }
  }

  void _likeAction() {
    _likeButtonController.reset();
    _likeButtonController.forward().then((_) async {
      _showFlash(Colors.green);
      await _handleAction('like');
      Future.delayed(const Duration(milliseconds: 150), () {
        _nextProfile();
      });
    });
  }

  void _passAction() {
    _passButtonController.reset();
    _passButtonController.forward().then((_) async {
      _showFlash(Colors.red);
      await _handleAction('pass');
      Future.delayed(const Duration(milliseconds: 150), () {
        _nextProfile();
      });
    });
  }

  // Navigate to detailed profile page
  void _openDetailedProfile(RecommendedUser user) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => DetailedProfilePage(
          user: user,
          onLike: () => _likeAction(),
          onPass: () => _passAction(),
        ),
      ),
    );
  }

  // Safely decode base64 image
  Widget _buildProfileImage(String? base64Image) {
    if (base64Image == null || base64Image.isEmpty) {
      return Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFFF6B9D), Color(0xFFFF8E53)],
          ),
        ),
        child: const Center(
          child: Icon(Icons.person, size: 100, color: Colors.white70),
        ),
      );
    }

    try {
      final Uint8List imageBytes = base64Decode(base64Image);
      return Container(
        decoration: BoxDecoration(
          image: DecorationImage(
            image: MemoryImage(imageBytes),
            fit: BoxFit.cover,
          ),
        ),
      );
    } catch (e) {
      print('Error decoding base64 image: $e');
      return Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFFF6B9D), Color(0xFFFF8E53)],
          ),
        ),
        child: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.broken_image, size: 60, color: Colors.white70),
              SizedBox(height: 8),
              Text(
                'Image Error',
                style: TextStyle(color: Colors.white70, fontSize: 14),
              ),
            ],
          ),
        ),
      );
    }
  }

  // Build simple about me section with "Read more" button
  Widget _buildAboutMeSection(RecommendedUser user) {
    if (user.aboutMe == null || user.aboutMe!.isEmpty) {
      return const SizedBox.shrink();
    }

    final aboutMeText = user.aboutMe!;
    final isLongText = aboutMeText.length > 100;

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            aboutMeText,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 14,
              fontWeight: FontWeight.w400,
              height: 1.4,
            ),
          ),
          if (isLongText)
            GestureDetector(
              onTap: () => _openDetailedProfile(user),
              child: Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  'Read more',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.9),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Scaffold(
          backgroundColor: const Color(0xFFFAFAFA),
          appBar: AppBar(
            title: const Text(
              'Discover',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w700,
                color: Color(0xFF2C2C2C),
              ),
            ),
            centerTitle: true,
            backgroundColor: Colors.transparent,
            elevation: 0,
            actions: [
              IconButton(
                icon: const Icon(Icons.refresh, color: Color(0xFF2C2C2C)),
                onPressed: _loadRecommendedUsers,
              ),
              IconButton(
                icon: const Icon(Icons.tune, color: Color(0xFF2C2C2C)),
                onPressed: () {},
              ),
            ],
          ),
          body: _selectedIndex == 0 ? _buildDiscoverPage() : _buildOtherPages(),
          bottomNavigationBar: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 20,
                  offset: const Offset(0, -5),
                ),
              ],
            ),
            child: BottomNavigationBar(
              type: BottomNavigationBarType.fixed,
              backgroundColor: Colors.transparent,
              selectedFontSize: 12,
              unselectedFontSize: 12,
              selectedItemColor: const Color(0xFFFF4458),
              unselectedItemColor: const Color(0xFF9E9E9E),
              currentIndex: _selectedIndex,
              onTap: _onItemTapped,
              elevation: 0,
              items: const [
                BottomNavigationBarItem(
                  icon: Icon(Icons.explore_outlined, size: 24),
                  activeIcon: Icon(Icons.explore, size: 24),
                  label: "Explore",
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.favorite_outline, size: 24),
                  activeIcon: Icon(Icons.favorite, size: 24),
                  label: 'Matches',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.chat_bubble_outline, size: 24),
                  activeIcon: Icon(Icons.chat_bubble, size: 24),
                  label: "Chat",
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.person_outline, size: 24),
                  activeIcon: Icon(Icons.person, size: 24),
                  label: "Profile",
                ),
              ],
            ),
          ),
        ),
        if (_showMatchDialog && _matchedUserName != null)
          _buildMatchDialog(_matchedUserName!),
      ],
    );
  }

  Widget _buildDiscoverPage() {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: Color(0xFFFF4458)),
            SizedBox(height: 16),
            Text(
              'Finding your perfect matches...',
              style: TextStyle(fontSize: 16, color: Color(0xFF2C2C2C)),
            ),
          ],
        ),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 64, color: Colors.grey.shade400),
              const SizedBox(height: 16),
              Text(
                'Oops! Something went wrong',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade600,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ElevatedButton(
                    onPressed: _loadRecommendedUsers,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFF4458),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(25),
                      ),
                    ),
                    child: const Text(
                      'Try Again',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                  const SizedBox(width: 12),
                  OutlinedButton(
                    onPressed: () {
                      // Create test users for debugging
                      _recommendationService.createTestUsers();
                    },
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Color(0xFFFF4458)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(25),
                      ),
                    ),
                    child: const Text(
                      'Create Test Data',
                      style: TextStyle(color: Color(0xFFFF4458)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    }

    if (_recommendedUsers.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.favorite_outline, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(
              'No matches found',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Try updating your preferences or check back later',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _loadRecommendedUsers,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF4458),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(25),
                ),
              ),
              child: const Text(
                'Refresh',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
      );
    }

    final currentUser = _recommendedUsers[_currentProfileIndex];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0),
      child: Column(
        children: [
          // Match score and profile counter
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFFF4458).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.stars, size: 16, color: Color(0xFFFF4458)),
                    const SizedBox(width: 4),
                    Text(
                      'Match: ${currentUser.matchScore}',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFFFF4458),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Text(
                  '${_currentProfileIndex + 1} of ${_recommendedUsers.length}',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),

          // Card Stack
          Expanded(
            child: Center(
              child: SlideTransition(
                position: _slideAnimation,
                child: ScaleTransition(
                  scale: _scaleAnimation,
                  child: GestureDetector(
                    onTap: () => _openDetailedProfile(currentUser),
                    child: Container(
                      width: double.infinity,
                      height: MediaQuery.of(context).size.height * 0.65,
                      margin: const EdgeInsets.symmetric(vertical: 20),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.15),
                            blurRadius: 30,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(24),
                        child: Stack(
                          children: [
                            // Background Image or Profile Picture
                            _buildProfileImage(currentUser.profilePicture),

                            // Flash overlay
                            if (_isFlashing)
                              AnimatedBuilder(
                                animation: _flashAnimation,
                                builder: (context, child) {
                                  return Container(
                                    decoration: BoxDecoration(
                                      color: _flashColor.withOpacity(
                                        _flashAnimation.value,
                                      ),
                                    ),
                                  );
                                },
                              ),

                            // Profile Info Overlay
                            Positioned(
                              bottom: 0,
                              left: 0,
                              right: 0,
                              child: Container(
                                padding: const EdgeInsets.all(24),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors: [
                                      Colors.transparent,
                                      Colors.black.withOpacity(0.8),
                                    ],
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            currentUser.name,
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 32,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          '${currentUser.age}',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 28,
                                            fontWeight: FontWeight.w300,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    if (currentUser.targetRelation.isNotEmpty)
                                      Row(
                                        children: [
                                          const Icon(
                                            Icons.favorite_outline,
                                            color: Colors.white70,
                                            size: 18,
                                          ),
                                          const SizedBox(width: 6),
                                          Text(
                                            currentUser.targetRelation,
                                            style: const TextStyle(
                                              color: Colors.white70,
                                              fontSize: 16,
                                              fontWeight: FontWeight.w400,
                                            ),
                                          ),
                                        ],
                                      ),
                                    if (currentUser.distanceKm != null)
                                      Padding(
                                        padding: const EdgeInsets.only(top: 4),
                                        child: Row(
                                          children: [
                                            const Icon(
                                              Icons.location_on_outlined,
                                              color: Colors.white70,
                                              size: 18,
                                            ),
                                            const SizedBox(width: 6),
                                            Text(
                                              '${currentUser.distanceKm!.toStringAsFixed(1)} km away',
                                              style: const TextStyle(
                                                color: Colors.white70,
                                                fontSize: 16,
                                                fontWeight: FontWeight.w400,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),

                                    // About Me Section with Read More
                                    _buildAboutMeSection(currentUser),

                                    const SizedBox(height: 16),
                                    // Hobby tags
                                    if (currentUser.hobbies.isNotEmpty)
                                      Wrap(
                                        spacing: 8,
                                        runSpacing: 4,
                                        children: currentUser.hobbies
                                            .take(3)
                                            .map((hobby) => _buildTag(hobby))
                                            .toList(),
                                      ),
                                  ],
                                ),
                              ),
                            ),

                            // Top indicators
                            Positioned(
                              top: 16,
                              left: 16,
                              right: 16,
                              child: Row(
                                children: List.generate(
                                  _recommendedUsers.length.clamp(0, 5),
                                  (index) => Expanded(
                                    child: Container(
                                      height: 4,
                                      margin: EdgeInsets.only(
                                        right: index < 4 ? 6 : 0,
                                      ),
                                      decoration: BoxDecoration(
                                        color: index <= _currentProfileIndex
                                            ? Colors.white
                                            : Colors.white.withOpacity(0.3),
                                        borderRadius: BorderRadius.circular(2),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),

                            // Tap hint overlay
                            Positioned(
                              top: 50,
                              right: 16,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.black.withOpacity(0.6),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.touch_app,
                                      size: 14,
                                      color: Colors.white70,
                                    ),
                                    SizedBox(width: 4),
                                    Text(
                                      'Tap for details',
                                      style: TextStyle(
                                        color: Colors.white70,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),

          // Action Buttons
          Padding(
            padding: const EdgeInsets.only(bottom: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ScaleTransition(
                  scale: _passButtonScaleAnimation,
                  child: _buildActionButton(
                    icon: Icons.close,
                    color: const Color(0xFFFF4458),
                    onTap: _passAction,
                    size: 90,
                  ),
                ),
                ScaleTransition(
                  scale: _likeButtonScaleAnimation,
                  child: _buildActionButton(
                    icon: Icons.favorite,
                    color: const Color(0xFFFF4458),
                    onTap: _likeAction,
                    size: 90,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTag(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.3)),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
    required double size,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Icon(icon, color: color, size: size * 0.4),
      ),
    );
  }

  Widget _buildOtherPages() {
    switch (_selectedIndex) {
      case 1:
        return MatchesScreen(
          onChat: (matchUserId, matchUserName) {
            // TODO: Navigate to chat screen with matchUserId
          },
        );
      case 2:
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(_getPageIcon(), size: 64, color: const Color(0xFFFF4458)),
              const SizedBox(height: 16),
              Text(
                _getPageTitle(),
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2C2C2C),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Coming soon...',
                style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
              ),
            ],
          ),
        );
      case 3:
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(_getPageIcon(), size: 64, color: const Color(0xFFFF4458)),
              const SizedBox(height: 16),
              Text(
                _getPageTitle(),
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2C2C2C),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Coming soon...',
                style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
              ),
            ],
          ),
        );
      default:
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(_getPageIcon(), size: 64, color: const Color(0xFFFF4458)),
              const SizedBox(height: 16),
              Text(
                _getPageTitle(),
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2C2C2C),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Coming soon...',
                style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
              ),
            ],
          ),
        );
    }
  }

  IconData _getPageIcon() {
    switch (_selectedIndex) {
      case 1:
        return Icons.favorite;
      case 2:
        return Icons.chat_bubble;
      case 3:
        return Icons.person;
      default:
        return Icons.explore;
    }
  }

  String _getPageTitle() {
    switch (_selectedIndex) {
      case 1:
        return 'Matches';
      case 2:
        return 'Chat';
      case 3:
        return 'Profile';
      default:
        return 'Explore';
    }
  }

  Widget _buildMatchDialog(String matchedUserName) {
    return MatchNotificationOverlay(
      currentUserProfilePicture: _currentUserProfilePicture,
      matchedUserProfilePicture: _matchedUserProfilePicture,
      matchedUserName: matchedUserName,
      onChat: () {
        setState(() {
          _showMatchDialog = false;
        });
        // TODO: Navigate to chat screen with the matched user
        // Navigator.push(context, MaterialPageRoute(
        //   builder: (context) => ChatScreen(
        //     matchedUserId: _matches.first.actorUserId,
        //     matchedUserName: matchedUserName,
        //   ),
        // ));
      },
      onContinue: () {
        setState(() {
          _showMatchDialog = false;
        });
        // Optionally, you can add haptic feedback
        try {
          HapticFeedback.lightImpact();
        } catch (e) {
          print('Haptic feedback not available: $e');
        }
      },
    );
  }
}

// Detailed Profile Page
class DetailedProfilePage extends StatelessWidget {
  final RecommendedUser user;
  final VoidCallback onLike;
  final VoidCallback onPass;

  const DetailedProfilePage({
    Key? key,
    required this.user,
    required this.onLike,
    required this.onPass,
  }) : super(key: key);

  // Safely decode base64 image
  Widget _buildProfileImage(String? base64Image, {double? height}) {
    if (base64Image == null || base64Image.isEmpty) {
      return Container(
        height: height ?? 400,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFFF6B9D), Color(0xFFFF8E53)],
          ),
        ),
        child: const Center(
          child: Icon(Icons.person, size: 100, color: Colors.white70),
        ),
      );
    }

    try {
      final Uint8List imageBytes = base64Decode(base64Image);
      return Container(
        height: height ?? 400,
        decoration: BoxDecoration(
          image: DecorationImage(
            image: MemoryImage(imageBytes),
            fit: BoxFit.cover,
          ),
        ),
      );
    } catch (e) {
      print('Error decoding base64 image: $e');
      return Container(
        height: height ?? 400,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFFF6B9D), Color(0xFFFF8E53)],
          ),
        ),
        child: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.broken_image, size: 60, color: Colors.white70),
              SizedBox(height: 8),
              Text(
                'Image Error',
                style: TextStyle(color: Colors.white70, fontSize: 14),
              ),
            ],
          ),
        ),
      );
    }
  }

  Widget _buildInfoCard({
    required IconData icon,
    required String title,
    required String content,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFFF4458).withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: const Color(0xFFFF4458), size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2C2C2C),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  content,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Color(0xFF666666),
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHobbiesSection() {
    if (user.hobbies.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFF4458).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.interests,
                  color: Color(0xFFFF4458),
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              const Text(
                'Interests & Hobbies',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2C2C2C),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: user.hobbies
                .map(
                  (hobby) => Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFF4458).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: const Color(0xFFFF4458).withOpacity(0.3),
                      ),
                    ),
                    child: Text(
                      hobby,
                      style: const TextStyle(
                        color: Color(0xFFFF4458),
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: Container(
          margin: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.3),
            borderRadius: BorderRadius.circular(12),
          ),
          child: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        actions: [
          Container(
            margin: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.3),
              borderRadius: BorderRadius.circular(12),
            ),
            child: IconButton(
              icon: const Icon(Icons.share, color: Colors.white),
              onPressed: () {
                // Handle share functionality
              },
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Hero Image Section
            Stack(
              children: [
                _buildProfileImage(user.profilePicture, height: 500),

                // Gradient overlay
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    height: 150,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withOpacity(0.7),
                        ],
                      ),
                    ),
                  ),
                ),

                // Basic Info Overlay
                Positioned(
                  bottom: 20,
                  left: 20,
                  right: 20,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              user.name,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 36,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          Text(
                            '${user.age}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 32,
                              fontWeight: FontWeight.w300,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),

                      // Match Score
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.3),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.stars,
                              size: 18,
                              color: Colors.white,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              '${user.matchScore}% Match',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            // Content Section
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // About Me Section
                  if (user.aboutMe != null && user.aboutMe!.isNotEmpty)
                    _buildInfoCard(
                      icon: Icons.person_outline,
                      title: 'About Me',
                      content: user.aboutMe!,
                    ),

                  // Looking For Section
                  if (user.targetRelation.isNotEmpty)
                    _buildInfoCard(
                      icon: Icons.favorite_outline,
                      title: 'Looking For',
                      content: user.targetRelation,
                    ),

                  // Distance Section
                  if (user.distanceKm != null)
                    _buildInfoCard(
                      icon: Icons.location_on_outlined,
                      title: 'Distance',
                      content: '${user.distanceKm!.toStringAsFixed(1)} km away',
                    ),

                  // Hobbies Section
                  _buildHobbiesSection(),

                  const SizedBox(height: 20),
                ],
              ),
            ),
          ],
        ),
      ),

      // Bottom Action Bar
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 20,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: SafeArea(
          child: Row(
            children: [
              // Pass Button
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    Navigator.pop(context);
                    onPass();
                  },
                  child: Container(
                    height: 56,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(28),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.close, color: Colors.grey, size: 24),
                        SizedBox(width: 8),
                        Text(
                          'Pass',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              const SizedBox(width: 16),

              // Like Button
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    Navigator.pop(context);
                    onLike();
                  },
                  child: Container(
                    height: 56,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFF4458),
                      borderRadius: BorderRadius.circular(28),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFFF4458).withOpacity(0.3),
                          blurRadius: 10,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.favorite, color: Colors.white, size: 24),
                        SizedBox(width: 8),
                        Text(
                          'Like',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
  