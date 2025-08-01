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
import 'updateprofile.dart';

class Homepage extends StatefulWidget {
  const Homepage({super.key});

  @override
  State<Homepage> createState() => _HomepageState();
}

class _HomepageState extends State<Homepage> with TickerProviderStateMixin {
  int _selectedIndex = 0;
  late AnimationController _cardController;
  late AnimationController _flashController;
  late AnimationController _passButtonController;
  late AnimationController _likeButtonController;
  late AnimationController _slideController;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;
  late Animation<double> _flashAnimation;
  late Animation<double> _passButtonScaleAnimation;
  late Animation<double> _likeButtonScaleAnimation;

  final RecommendationService _recommendationService = RecommendationService();
  List<RecommendedUser> _recommendedUsers = [];
  int _currentProfileIndex = 0;
  bool _isLoading = true;
  String? _errorMessage;

  Color _flashColor = Colors.transparent;
  bool _isFlashing = false;
  bool _isAnimating = false;

  final FirebaseUserService _firebaseUserService = FirebaseUserService();
  StreamSubscription<List<UserAction>>? _matchSubscription;
  final Set<String> _processedMatchIds = {};
  final Set<String> _shownMatchUserIds = {}; // Track users who already had match dialog shown
  final List<UserAction> _matches = [];
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
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );

    _slideController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );

    _flashController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );

    _passButtonController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _likeButtonController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.03),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _slideController,
        curve: Curves.easeOutQuart,
      ),
    );

    _scaleAnimation = Tween<double>(
      begin: 0.99,
      end: 1.0,
    ).animate(
      CurvedAnimation(
        parent: _cardController,
        curve: Curves.easeOutCubic,
      ),
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(
      CurvedAnimation(
        parent: _cardController,
        curve: const Interval(0.0, 0.8, curve: Curves.easeOut),
      ),
    );

    _flashAnimation = Tween<double>(
      begin: 0.0,
      end: 0.3,
    ).animate(
      CurvedAnimation(
        parent: _flashController,
        curve: Curves.easeInOutCubic,
      ),
    );

    _passButtonScaleAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.0, end: 0.95),
        weight: 40,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.95, end: 1.05),
        weight: 30,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.05, end: 1.0),
        weight: 30,
      ),
    ]).animate(
      CurvedAnimation(
        parent: _passButtonController,
        curve: Curves.easeOutCubic,
      ),
    );

    _likeButtonScaleAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.0, end: 0.95),
        weight: 40,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.95, end: 1.05),
        weight: 30,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.05, end: 1.0),
        weight: 30,
      ),
    ]).animate(
      CurvedAnimation(
        parent: _likeButtonController,
        curve: Curves.easeOutCubic,
      ),
    );
  }

  Future<void> _loadRecommendedUsers() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      print('Loading recommended users...');

      final recommendedUsers = await _recommendationService.getRecommendedUsers(
        limit: 20,
      );

      print('Loaded ${recommendedUsers.length} recommended users');

      if (mounted) {
        setState(() {
          _recommendedUsers = recommendedUsers;
          _currentProfileIndex = 0;
          _isLoading = false;
        });

        if (_recommendedUsers.isNotEmpty) {
          _cardController.forward();
          _slideController.forward();
        }
      }
    } catch (e) {
      print('Error loading recommended users: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = e.toString();
        });
      }
    }
  }

  void _listenForMatches() {
    final userId = _firebaseUserService.currentUserId;
    if (userId == null) {
      print('Error: Current user ID is null, cannot listen for matches');
      return;
    }

    print('Starting to listen for matches for user: $userId');

    _matchSubscription = _firebaseUserService
        .getActionsTargetingUserStream(userId: userId)
        .listen(
          (actions) async {
            print('Received ${actions.length} actions targeting user $userId');

            for (final action in actions) {
              print(
                'Processing action: ${action.actionId}, type: ${action.actionType}, '
                'matchStatus: ${action.matchStatus}, actorUserId: ${action.actorUserId}',
              );

              if (action.actionType == 'like' && action.matchStatus == true) {
                await _handleNewMatch(action);
              }
            }
          },
          onError: (error) {
            print('Error listening for matches: $error');
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'Connection error: Unable to receive match notifications',
                  ),
                  backgroundColor: Colors.orange,
                  duration: const Duration(seconds: 3),
                ),
              );
            }
          },
          cancelOnError: false,
        );
  }

  Future<void> _handleNewMatch(UserAction action) async {
    try {
      if (_processedMatchIds.contains(action.actionId)) {
        print('Match already processed for action ID: ${action.actionId}');
        return;
      }

      // Check if we've already shown a match dialog for this user
      if (_shownMatchUserIds.contains(action.actorUserId)) {
        print('Match dialog already shown for user: ${action.actorUserId}');
        return;
      }

      print('New match detected! Action ID: ${action.actionId}');
      _processedMatchIds.add(action.actionId);
      _shownMatchUserIds.add(action.actorUserId); // Mark this user as shown

      await _loadMatchedUserProfilePicture(action.actorUserId);

      String matchedUserName = _getMatchedUserNameFromRecommendations(
        action.actorUserId,
      );

      if (matchedUserName == 'Someone') {
        matchedUserName = await _getMatchedUserNameFromFirebase(
          action.actorUserId,
        );
      }

      if (mounted) {
        setState(() {
          _matches.add(action);
          _showMatchDialog = true;
          _matchedUserName = matchedUserName;
        });

        print('Match dialog displayed for user: $matchedUserName');

        try {
          HapticFeedback.heavyImpact();
        } catch (e) {
          print('Haptic feedback not available: $e');
        }
      }
    } catch (e) {
      print('Error handling new match: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Error processing match notification'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  String _getMatchedUserNameFromRecommendations(String userId) {
    try {
      final matchedUser = _recommendedUsers.firstWhere(
        (u) => u.userId == userId,
        orElse: () => RecommendedUser(
          userId: userId,
          name: 'Someone',
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

  @override
  void dispose() {
    print('Disposing homepage resources...');

    _cardController.dispose();
    _slideController.dispose();
    _flashController.dispose();
    _passButtonController.dispose();
    _likeButtonController.dispose();
    _pulseController?.dispose();

    _matchSubscription?.cancel().then((_) {
      print('Match subscription cancelled successfully');
    }).catchError((error) {
      print('Error cancelling match subscription: $error');
    });

    super.dispose();
  }

  Future<void> _initCurrentUserProfilePicture() async {
    final userId = _firebaseUserService.currentUserId;
    if (userId != null) {
      final pic = await _firebaseUserService.getUserProfilePicture(userId);
      if (mounted) {
        setState(() {
          _currentUserProfilePicture = pic;
        });
      }
    }
  }

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
      if (mounted) {
        setState(() {
          _matchedUserProfilePicture = null;
        });
      }
    }
  }

  void _onItemTapped(int index) {
    if (index == 3) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const UpdateProfilePage()),
      );
      return;
    }

    setState(() {
      _selectedIndex = index;
    });
  }

  Future<void> _nextProfile() async {
    if (_isAnimating) return;
    
    setState(() {
      _isAnimating = true;
    });

    await _cardController.reverse();
    await _slideController.reverse();

    if (_currentProfileIndex < _recommendedUsers.length - 1) {
      setState(() {
        _currentProfileIndex++;
      });
    } else {
      await _loadMoreRecommendations();
    }

    if (mounted && _recommendedUsers.isNotEmpty) {
      await _cardController.forward();
      await _slideController.forward();
    }

    setState(() {
      _isAnimating = false;
    });
  }

  Future<void> _loadMoreRecommendations() async {
    try {
      final moreUsers = await _recommendationService.getRecommendedUsers(
        limit: 10,
        excludeUserIds: _recommendedUsers.map((u) => u.userId).toList(),
      );

      if (mounted) {
        setState(() {
          _recommendedUsers.addAll(moreUsers);
          if (_recommendedUsers.isNotEmpty &&
              _currentProfileIndex < _recommendedUsers.length - 1) {
            _currentProfileIndex++;
          }
        });
      }
    } catch (e) {
      print('Error loading more recommendations: $e');
    }
  }

  void _showFlash(Color color) {
    if (_isFlashing) return;

    setState(() {
      _flashColor = color;
      _isFlashing = true;
    });

    _flashController.forward().then((_) {
      _flashController.reverse().then((_) {
        if (mounted) {
          setState(() {
            _isFlashing = false;
          });
        }
      });
    });
  }

  Future<void> _handleAction(String actionType) async {
    if (_recommendedUsers.isEmpty || _isAnimating) return;

    final targetUserId = _recommendedUsers[_currentProfileIndex].userId;
    final targetUserName = _recommendedUsers[_currentProfileIndex].name;

    try {
      print('Handling $actionType action for user: $targetUserId');

      final result = await _firebaseUserService.recordUserAction(
        targetUserId: targetUserId,
        actionType: actionType,
      );

      if (actionType == 'like' && result == true) {
        print('Immediate match detected!');

        // Check if we've already shown dialog for this user
        if (!_shownMatchUserIds.contains(targetUserId)) {
          _shownMatchUserIds.add(targetUserId); // Mark as shown
          
          await _loadMatchedUserProfilePicture(targetUserId);

          if (mounted) {
            setState(() {
              _showMatchDialog = true;
              _matchedUserName = targetUserName;
            });
          }
        }
      }
    } catch (e) {
      print('Error recording user action: $e');
    }
  }

  void _likeAction() {
    if (_isAnimating) return;

    _likeButtonController.reset();
    _likeButtonController.forward().then((_) async {
      _showFlash(Colors.green);
      await _handleAction('like');
      await Future.delayed(const Duration(milliseconds: 200));
      await _nextProfile();
    });
  }

  void _passAction() {
    if (_isAnimating) return;

    _passButtonController.reset();
    _passButtonController.forward().then((_) async {
      _showFlash(Colors.red);
      await _handleAction('pass');
      await Future.delayed(const Duration(milliseconds: 200));
      await _nextProfile();
    });
  }

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
            filterQuality: FilterQuality.high,
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
    final screenWidth = MediaQuery.of(context).size.width;
    
    return RepaintBoundary(
      child: Stack(
        children: [
          Scaffold(
            backgroundColor: const Color(0xFFFAFAFA),
            appBar: AppBar(
              title: Text(
                'Discover',
                style: TextStyle(
                  fontSize: screenWidth * 0.07,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF2C2C2C),
                ),
              ),
              centerTitle: true,
              backgroundColor: Colors.transparent,
              elevation: 0,
              actions: [
                IconButton(
                  icon: Icon(
                    Icons.refresh, 
                    color: const Color(0xFF2C2C2C),
                    size: screenWidth * 0.06,
                  ),
                  onPressed: _isAnimating ? null : _loadRecommendedUsers,
                ),
                IconButton(
                  icon: Icon(
                    Icons.tune, 
                    color: const Color(0xFF2C2C2C),
                    size: screenWidth * 0.06,
                  ),
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
                selectedFontSize: screenWidth * 0.03,
                unselectedFontSize: screenWidth * 0.03,
                selectedItemColor: const Color(0xFFFF4458),
                unselectedItemColor: const Color(0xFF9E9E9E),
                currentIndex: _selectedIndex,
                onTap: _onItemTapped,
                elevation: 0,
                items: [
                  BottomNavigationBarItem(
                    icon: Icon(
                      Icons.explore_outlined, 
                      size: screenWidth * 0.06
                    ),
                    activeIcon: Icon(
                      Icons.explore, 
                      size: screenWidth * 0.06
                    ),
                    label: "Explore",
                  ),
                  BottomNavigationBarItem(
                    icon: Icon(
                      Icons.favorite_outline, 
                      size: screenWidth * 0.06
                    ),
                    activeIcon: Icon(
                      Icons.favorite, 
                      size: screenWidth * 0.06
                    ),
                    label: 'Matches',
                  ),
                  BottomNavigationBarItem(
                    icon: Icon(
                      Icons.chat_bubble_outline, 
                      size: screenWidth * 0.06
                    ),
                    activeIcon: Icon(
                      Icons.chat_bubble, 
                      size: screenWidth * 0.06
                    ),
                    label: "Chat",
                  ),
                  BottomNavigationBarItem(
                    icon: Icon(
                      Icons.person_outline, 
                      size: screenWidth * 0.06
                    ),
                    activeIcon: Icon(
                      Icons.person, 
                      size: screenWidth * 0.06
                    ),
                    label: "Profile",
                  ),
                ],
              ),
            ),
          ),
          if (_showMatchDialog && _matchedUserName != null)
            _buildMatchDialog(_matchedUserName!),
        ],
      ),
    );
  }

  Widget _buildDiscoverPage() {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    
    if (_isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(
              color: const Color(0xFFFF4458),
              strokeWidth: 2,
            ),
            SizedBox(height: screenHeight * 0.02),
            Text(
              'Finding your perfect matches...',
              style: TextStyle(
                fontSize: screenWidth * 0.04, 
                color: const Color(0xFF2C2C2C)
              ),
            ),
          ],
        ),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: EdgeInsets.all(screenWidth * 0.08),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.error_outline, 
                size: screenWidth * 0.16, 
                color: Colors.grey.shade400
              ),
              SizedBox(height: screenHeight * 0.02),
              Text(
                'Oops! Something went wrong',
                style: TextStyle(
                  fontSize: screenWidth * 0.05,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade600,
                ),
              ),
              SizedBox(height: screenHeight * 0.01),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: screenWidth * 0.035, 
                  color: Colors.grey.shade500
                ),
              ),
              SizedBox(height: screenHeight * 0.03),
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
                    child: Text(
                      'Try Again',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: screenWidth * 0.04,
                      ),
                    ),
                  ),
                  SizedBox(width: screenWidth * 0.03),
                  OutlinedButton(
                    onPressed: () {
                      _recommendationService.createTestUsers();
                    },
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(
                        color: Color(0xFFFF4458),
                        width: 1,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(25),
                      ),
                    ),
                    child: Text(
                      'Create Test Data',
                      style: TextStyle(
                        color: const Color(0xFFFF4458),
                        fontSize: screenWidth * 0.04,
                      ),
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
            Icon(
              Icons.favorite_outline, 
              size: screenWidth * 0.16, 
              color: Colors.grey.shade400
            ),
            SizedBox(height: screenHeight * 0.02),
            Text(
              'No matches found',
              style: TextStyle(
                fontSize: screenWidth * 0.05,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade600,
              ),
            ),
            SizedBox(height: screenHeight * 0.01),
            Text(
              'Try updating your preferences or check back later',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: screenWidth * 0.035, 
                color: Colors.grey
              ),
            ),
            SizedBox(height: screenHeight * 0.03),
            ElevatedButton(
              onPressed: _loadRecommendedUsers,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF4458),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(25),
                ),
              ),
              child: Text(
                'Refresh',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: screenWidth * 0.04,
                ),
              ),
            ),
          ],
        ),
      );
    }

    final currentUser = _recommendedUsers[_currentProfileIndex];

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.05),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: screenWidth * 0.04,
                  vertical: screenHeight * 0.01,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFFF4458).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.stars, 
                      size: screenWidth * 0.04, 
                      color: const Color(0xFFFF4458)
                    ),
                    SizedBox(width: screenWidth * 0.01),
                    Text(
                      'Match: ${currentUser.matchScore}',
                      style: TextStyle(
                        fontSize: screenWidth * 0.035,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFFFF4458),
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
          Expanded(
            child: Center(
              child: RepaintBoundary(
                child: AnimatedBuilder(
                  animation: Listenable.merge([_slideAnimation, _scaleAnimation, _fadeAnimation]),
                  builder: (context, child) {
                    return Transform.translate(
                      offset: _slideAnimation.value * screenHeight * 0.1,
                      child: Transform.scale(
                        scale: _scaleAnimation.value,
                        child: Opacity(
                          opacity: _fadeAnimation.value,
                          child: GestureDetector(
                            onTap: () => _openDetailedProfile(currentUser),
                            child: Container(
                              width: double.infinity,
                              height: screenHeight * 0.65,
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
                                    _buildProfileImage(currentUser.profilePicture),
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
                                            _buildAboutMeSection(currentUser),
                                            const SizedBox(height: 16),
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
                                    Positioned(
                                      top: 16,
                                      left: 16,
                                      right: 16,
                                      child: Row(
                                        children: List.generate(
                                          _recommendedUsers.length.clamp(0, 5),
                                          (index) => Expanded(
                                            child: AnimatedContainer(
                                              duration: const Duration(milliseconds: 300),
                                              curve: Curves.easeInOut,
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
                    );
                  },
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                AnimatedBuilder(
                  animation: _passButtonScaleAnimation,
                  builder: (context, child) {
                    return Transform.scale(
                      scale: _passButtonScaleAnimation.value,
                      child: _buildActionButton(
                        icon: Icons.close,
                        color: const Color(0xFFFF4458),
                        onTap: _passAction,
                        size: 90,
                        isEnabled: !_isAnimating,
                      ),
                    );
                  },
                ),
                AnimatedBuilder(
                  animation: _likeButtonScaleAnimation,
                  builder: (context, child) {
                    return Transform.scale(
                      scale: _likeButtonScaleAnimation.value,
                      child: _buildActionButton(
                        icon: Icons.favorite,
                        color: const Color(0xFFFF4458),
                        onTap: _likeAction,
                        size: 90,
                        isEnabled: !_isAnimating,
                      ),
                    );
                  },
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
    bool isEnabled = true,
  }) {
    return GestureDetector(
      onTap: isEnabled ? onTap : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: isEnabled ? Colors.white : Colors.white.withOpacity(0.7),
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isEnabled ? 0.1 : 0.05),
              blurRadius: 10,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Icon(
          icon,
          color: isEnabled ? color : color.withOpacity(0.5),
          size: size * 0.4,
        ),
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
    return Material(
      color: Colors.black.withOpacity(0.7),
      child: Center(
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 20),
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.9,
            maxHeight: MediaQuery.of(context).size.height * 0.8,
          ),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
          ),
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Profile pictures section
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Current user picture
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.grey.shade300, width: 3),
                        ),
                        child: ClipOval(
                          child: _currentUserProfilePicture != null
                              ? _buildCircularProfilePicture(_currentUserProfilePicture!)
                              : Container(
                                  color: const Color(0xFFFF4458).withOpacity(0.1),
                                  child: const Icon(
                                    Icons.person,
                                    size: 40,
                                    color: Color(0xFFFF4458),
                                  ),
                                ),
                        ),
                      ),
                      const SizedBox(width: 20),
                      // Heart icon
                      Container(
                        width: 50,
                        height: 50,
                        decoration: const BoxDecoration(
                          color: Color(0xFFFF4458),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.favorite,
                          color: Colors.white,
                          size: 25,
                        ),
                      ),
                      const SizedBox(width: 20),
                      // Matched user picture
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.grey.shade300, width: 3),
                        ),
                        child: ClipOval(
                          child: _matchedUserProfilePicture != null
                              ? _buildCircularProfilePicture(_matchedUserProfilePicture!)
                              : Container(
                                  color: const Color(0xFFFF4458).withOpacity(0.1),
                                  child: const Icon(
                                    Icons.person,
                                    size: 40,
                                    color: Color(0xFFFF4458),
                                  ),
                                ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 30),
                  // Title
                  const Text(
                    "It's a Match!",
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFFFF4458),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Description
                  Text(
                    'You and $matchedUserName liked each other.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 16,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 30),
                  // Buttons
                  Column(
                    children: [
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          onPressed: () {
                            setState(() {
                              _showMatchDialog = false;
                              _matchedUserName = null;
                              _matchedUserProfilePicture = null;
                            });
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFFF4458),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(25),
                            ),
                          ),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.chat, color: Colors.white),
                              SizedBox(width: 8),
                              Text(
                                'Start Chatting',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: OutlinedButton(
                          onPressed: () {
                            setState(() {
                              _showMatchDialog = false;
                              _matchedUserName = null;
                              _matchedUserProfilePicture = null;
                            });
                            try {
                              HapticFeedback.lightImpact();
                            } catch (e) {
                              print('Haptic feedback not available: $e');
                            }
                          },
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Color(0xFFFF4458)),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(25),
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
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCircularProfilePicture(String base64Image) {
    try {
      final Uint8List imageBytes = base64Decode(base64Image);
      return Image.memory(
        imageBytes,
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
      );
    } catch (e) {
      return Container(
        color: const Color(0xFFFF4458).withOpacity(0.1),
        child: const Icon(
          Icons.person,
          size: 40,
          color: Color(0xFFFF4458),
        ),
      );
    }
  }
}

class DetailedProfilePage extends StatefulWidget {
  final RecommendedUser user;
  final VoidCallback onLike;
  final VoidCallback onPass;

  const DetailedProfilePage({
    super.key,
    required this.user,
    required this.onLike,
    required this.onPass,
  });

  @override
  State<DetailedProfilePage> createState() => _DetailedProfilePageState();
}

class _DetailedProfilePageState extends State<DetailedProfilePage>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
      ),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.1),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.3, 1.0, curve: Curves.easeOutCubic),
      ),
    );

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

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
            filterQuality: FilterQuality.high,
          ),
        ),
      );
    } catch (e) {
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
    return SlideTransition(
      position: _slideAnimation,
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: Container(
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
        ),
      ),
    );
  }

  Widget _buildHobbiesSection() {
    if (widget.user.hobbies.isEmpty) return const SizedBox.shrink();

    return SlideTransition(
      position: _slideAnimation,
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: Container(
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
                children: widget.user.hobbies
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
        ),
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
              onPressed: () {},
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            FadeTransition(
              opacity: _fadeAnimation,
              child: Stack(
                children: [
                  _buildProfileImage(widget.user.profilePicture, height: 500),
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
                  Positioned(
                    bottom: 20,
                    left: 20,
                    right: 20,
                    child: SlideTransition(
                      position: _slideAnimation,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  widget.user.name,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 36,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              Text(
                                '${widget.user.age}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 32,
                                  fontWeight: FontWeight.w300,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
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
                                  '${widget.user.matchScore}% Match',
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
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (widget.user.aboutMe != null && widget.user.aboutMe!.isNotEmpty)
                    _buildInfoCard(
                      icon: Icons.person_outline,
                      title: 'About Me',
                      content: widget.user.aboutMe!,
                    ),
                  if (widget.user.targetRelation.isNotEmpty)
                    _buildInfoCard(
                      icon: Icons.favorite_outline,
                      title: 'Looking For',
                      content: widget.user.targetRelation,
                    ),
                  if (widget.user.distanceKm != null)
                    _buildInfoCard(
                      icon: Icons.location_on_outlined,
                      title: 'Distance',
                      content: '${widget.user.distanceKm!.toStringAsFixed(1)} km away',
                    ),
                  _buildHobbiesSection(),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 1),
          end: Offset.zero,
        ).animate(
          CurvedAnimation(
            parent: _controller,
            curve: const Interval(0.6, 1.0, curve: Curves.easeOutCubic),
          ),
        ),
        child: Container(
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
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      Navigator.pop(context);
                      widget.onPass();
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
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      Navigator.pop(context);
                      widget.onLike();
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
      ),
    );
  }
}