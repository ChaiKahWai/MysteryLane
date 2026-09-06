import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../data/models/checkpoint_destination.dart';
import '../../../data/repositories/checkpoint_repository.dart';

import '../Blindbox/BlindBox_Screen.dart';
import '../group/chat_list_screen.dart';
import '../group/group_screen.dart';
import '../home/home_screen.dart';
import '../plan/plan_screen.dart';
import '../profile/leaderboard_screen.dart';
import '../profile/profile_screen.dart';
import '../puzzle/puzzle_screen.dart';

import 'checkpoint_mission_screen.dart';

class CheckpointScreen extends StatefulWidget {
  const CheckpointScreen({super.key});

  @override
  State<CheckpointScreen> createState() =>
      _CheckpointScreenState();
}

class _CheckpointScreenState extends State<CheckpointScreen> {
  // ============================================================
  // COLORS
  // ============================================================

  static const Color skyBlue = Color(0xFF0284C7);
  static const Color teal = Color(0xFF0D9488);
  static const Color darkText = Color(0xFF0F172A);
  static const Color greyText = Color(0xFF64748B);
  static const Color pageBackground = Color(0xFFF8FAFC);

  // ============================================================
  // MAP LEGEND COLORS
  // ============================================================

  // Completed checkpoint.
  static const Color completedColor = Color(0xFF10B981);

  // Curated Hidden Gem.
  static const Color hiddenGemColor = Color(0xFFF59E0B);

  // Blind Box / Google generated.
  static const Color blindBoxColor = Color(0xFF7C3AED);

  // Current user location + 5 km radius.
  static const Color userColor = Color(0xFF2196F3);

  // ============================================================
  // CONSTANTS
  // ============================================================

  static const double checkpointRadiusMeters = 5000.0;

  static const LatLng fallbackLocation = LatLng(
    3.1390,
    101.6869,
  );

  // ============================================================
  // DATA
  // ============================================================

  final CheckpointRepository _repository =
  CheckpointRepository();

  GoogleMapController? _mapController;

  Position? _currentPosition;

  List<CheckpointDestination> _nearbyDestinations = [];

  Set<String> _completedDestinationIds = {};

  final Map<String, double> _distanceKmByDestinationId = {};

  final Map<String, int> _rewardPointsByDestinationId = {};

  CheckpointDestination? _selectedDestination;

  bool _isLoading = true;

  String? _errorMessage;

  String? _headerProfilePictureUrl;

  // ============================================================
  // INIT
  // ============================================================

  @override
  void initState() {
    super.initState();

    _loadHeaderProfile();
    _reloadCheckpoints();
  }

  @override
  void dispose() {
    _mapController?.dispose();
    super.dispose();
  }

  // ============================================================
  // HEADER PROFILE
  // ============================================================

  Future<void> _loadHeaderProfile() async {
    try {
      final user =
          Supabase.instance.client.auth.currentUser;

      if (user == null) {
        return;
      }

      final profile =
      await Supabase.instance.client
          .from('profiles')
          .select('profile_picture_url')
          .eq('id', user.id)
          .maybeSingle();

      if (!mounted) {
        return;
      }

      final String? picture =
      profile?['profile_picture_url']
          ?.toString()
          .trim();

      setState(() {
        _headerProfilePictureUrl =
        picture != null && picture.isNotEmpty
            ? picture
            : null;
      });
    } catch (error) {
      debugPrint(
        'Checkpoint header profile error: $error',
      );
    }
  }

  // ============================================================
  // LOCATION
  // ============================================================

  Future<Position> _determineCurrentPosition() async {
    final bool serviceEnabled =
    await Geolocator.isLocationServiceEnabled();

    if (!serviceEnabled) {
      throw Exception(
        'Location services are disabled. '
            'Please enable GPS and try again.',
      );
    }

    LocationPermission permission =
    await Geolocator.checkPermission();

    if (permission == LocationPermission.denied) {
      permission =
      await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied) {
      throw Exception(
        'Location permission is required '
            'to display checkpoints near you.',
      );
    }

    if (permission ==
        LocationPermission.deniedForever) {
      throw Exception(
        'Location permission is permanently denied. '
            'Please enable it from your device settings.',
      );
    }

    return Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
      ),
    );
  }

  // ============================================================
  // LOAD CHECKPOINTS
  // ============================================================

  Future<void> _reloadCheckpoints() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }

    try {
      // =========================================================
      // 1. GET USER GPS
      // =========================================================

      final Position position =
      await _determineCurrentPosition();

      // =========================================================
      // 2. LOAD CHECKPOINT DESTINATIONS
      // =========================================================

      final _CheckpointLoadResult loaded =
      await _loadActiveCheckpointDestinations();

      // =========================================================
      // 3. LOAD COMPLETED CHECKPOINTS
      // =========================================================

      final completed =
      await _repository.getCompletedDestinationIds();

      final Set<String> completedIds =
      Set<String>.from(completed);

      // =========================================================
      // 4. FILTER TO 5 KM
      // =========================================================

      final Map<String, double> distanceMap = {};

      final List<CheckpointDestination> nearby = [];

      for (final destination
      in loaded.destinations) {
        final double distanceMeters =
        Geolocator.distanceBetween(
          position.latitude,
          position.longitude,
          destination.latitude,
          destination.longitude,
        );

        final double distanceKm =
            distanceMeters / 1000.0;

        if (distanceMeters <=
            checkpointRadiusMeters) {
          distanceMap[destination.destinationId] =
              distanceKm;

          nearby.add(destination);
        }
      }

      // =========================================================
      // 5. SORT NEAREST FIRST
      // =========================================================

      nearby.sort(
            (
            CheckpointDestination a,
            CheckpointDestination b,
            ) {
          final double distanceA =
              distanceMap[a.destinationId] ??
                  double.infinity;

          final double distanceB =
              distanceMap[b.destinationId] ??
                  double.infinity;

          return distanceA.compareTo(distanceB);
        },
      );

      // =========================================================
      // 6. KEEP SELECTED DESTINATION
      // =========================================================

      CheckpointDestination? nextSelected;

      if (_selectedDestination != null) {
        for (final destination in nearby) {
          if (destination.destinationId ==
              _selectedDestination!.destinationId) {
            nextSelected = destination;
            break;
          }
        }
      }

      if (nextSelected == null &&
          nearby.isNotEmpty) {
        nextSelected = nearby.first;
      }

      if (!mounted) {
        return;
      }

      setState(() {
        _currentPosition = position;

        _nearbyDestinations = nearby;

        _completedDestinationIds =
            completedIds;

        _distanceKmByDestinationId
          ..clear()
          ..addAll(distanceMap);

        _rewardPointsByDestinationId
          ..clear()
          ..addAll(loaded.rewardPoints);

        _selectedDestination =
            nextSelected;

        _isLoading = false;
      });

      WidgetsBinding.instance.addPostFrameCallback(
            (_) {
          _moveToUser();
        },
      );
    } catch (error) {
      debugPrint(
        'CHECKPOINT LOAD ERROR: $error',
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _isLoading = false;

        _errorMessage = error
            .toString()
            .replaceFirst(
          'Exception: ',
          '',
        );
      });
    }
  }

  // ============================================================
  // LOAD ACTIVE CHECKPOINT DESTINATIONS
  // ============================================================

  Future<_CheckpointLoadResult>
  _loadActiveCheckpointDestinations() async {
    final SupabaseClient client =
        Supabase.instance.client;

    // ===========================================================
    // LOAD ACTIVE MISSIONS
    // ===========================================================

    final missionRows =
    await client
        .from('checkpoint_missions')
        .select(
      '''
              destination_id,
              reward_points
              ''',
    )
        .eq(
      'is_active',
      true,
    );

    final Set<String> destinationIds = {};

    final Map<String, int> rewards = {};

    for (final raw in missionRows) {
      final Map<String, dynamic> row =
      Map<String, dynamic>.from(raw);

      final String destinationId =
          row['destination_id']
              ?.toString() ??
              '';

      if (destinationId.isEmpty) {
        continue;
      }

      destinationIds.add(destinationId);

      final dynamic rewardRaw =
      row['reward_points'];

      final int reward =
      rewardRaw is num
          ? rewardRaw.toInt()
          : int.tryParse(
        rewardRaw?.toString() ??
            '',
      ) ??
          0;

      rewards.putIfAbsent(
        destinationId,
            () => reward,
      );
    }

    if (destinationIds.isEmpty) {
      return const _CheckpointLoadResult(
        destinations: [],
        rewardPoints: {},
      );
    }

    // ===========================================================
    // LOAD DESTINATION DATA
    // ===========================================================

    final destinationRows =
    await client
        .from('blind_box_destinations')
        .select()
        .inFilter(
      'destination_id',
      destinationIds.toList(),
    );

    final List<CheckpointDestination>
    destinations = [];

    for (final raw in destinationRows) {
      try {
        destinations.add(
          CheckpointDestination.fromJson(
            Map<String, dynamic>.from(raw),
          ),
        );
      } catch (error) {
        debugPrint(
          'Unable to parse checkpoint destination: '
              '$error',
        );
      }
    }

    return _CheckpointLoadResult(
      destinations: destinations,
      rewardPoints: rewards,
    );
  }

  // ============================================================
  // REFRESH COMPLETED CHECKPOINTS
  // ============================================================

  Future<void> _refreshCompletedCheckpoints() async {
    try {
      final completed =
      await _repository
          .getCompletedDestinationIds();

      if (!mounted) {
        return;
      }

      setState(() {
        _completedDestinationIds =
        Set<String>.from(completed);
      });
    } catch (error) {
      debugPrint(
        'COMPLETED CHECKPOINT REFRESH ERROR: '
            '$error',
      );
    }
  }

  // ============================================================
  // SOURCE HELPERS
  // ============================================================

  bool _isBlindBoxDestination(
      CheckpointDestination destination,
      ) {
    final String source =
        destination.destinationSource
            ?.trim()
            .toUpperCase() ??
            '';

    return source == 'GOOGLE';
  }

  String _checkpointSourceLabel(
      CheckpointDestination destination,
      ) {
    if (_isBlindBoxDestination(destination)) {
      return 'BLIND BOX';
    }

    return 'HIDDEN GEM';
  }

  Color _checkpointSourceColor(
      CheckpointDestination destination,
      ) {
    if (_isBlindBoxDestination(destination)) {
      return blindBoxColor;
    }

    return hiddenGemColor;
  }

  bool _isCompleted(
      CheckpointDestination destination,
      ) {
    return _completedDestinationIds.contains(
      destination.destinationId,
    );
  }

  // ============================================================
  // MARKER COLOR
  // ============================================================

  double _checkpointMarkerHue(
      CheckpointDestination destination,
      ) {
    // COMPLETED = GREEN
    if (_isCompleted(destination)) {
      return BitmapDescriptor.hueGreen;
    }

    // BLIND BOX / GOOGLE = PURPLE
    if (_isBlindBoxDestination(destination)) {
      return BitmapDescriptor.hueViolet;
    }

    // CURATED HIDDEN GEM = ORANGE
    return BitmapDescriptor.hueOrange;
  }

  // ============================================================
  // SELECT CHECKPOINT
  // ============================================================

  void _selectDestination(
      CheckpointDestination destination,
      ) {
    setState(() {
      _selectedDestination = destination;
    });
  }

  // ============================================================
  // OPEN CHECKPOINT MISSION
  // ============================================================

  Future<void> _openMission(
      CheckpointDestination destination,
      ) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            CheckpointMissionScreen(
              destination: destination,
            ),
      ),
    );

    await _refreshCompletedCheckpoints();
  }

  // ============================================================
  // OPEN PUZZLE
  //
  // REAL CONNECTION:
  //
  // CheckpointDestination
  //        ↓
  // MissionCheckpoint
  //        ↓
  // PuzzleScreen
  // ============================================================

  void _openPuzzle(
      CheckpointDestination destination,
      ) {
    final MissionCheckpoint checkpoint =
    MissionCheckpoint(
      // Same Supabase destination ID.
      id: destination.destinationId,

      // Destination name.
      title: destination.name,

      // Destination image.
      imageUrl: destination.imageUrl,

      // Address/location.
      locationName: destination.address,

      // Destination category.
      category:
      destination.category ?? 'Checkpoint',
    );

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PuzzleScreen(
          // Pass selected checkpoint.
          mission: checkpoint,

          // Tell Puzzle page that this location
          // came from Checkpoint Mission.
          initialLocationSource:
          PuzzleLocationSource.checkpoint,
        ),
      ),
    );
  }

  // ============================================================
  // PUZZLE TAB
  // ============================================================

  void _openPuzzleFromTab() {
    final destination =
        _selectedDestination;

    if (destination == null) {
      _showMessage(
        'Select a checkpoint first.',
      );

      return;
    }

    _openPuzzle(destination);
  }

  // ============================================================
  // BUILD MARKERS
  // ============================================================

  Set<Marker> _buildMarkers() {
    return _nearbyDestinations.map(
          (CheckpointDestination destination) {
        return Marker(
          markerId: MarkerId(
            destination.destinationId,
          ),

          position: LatLng(
            destination.latitude,
            destination.longitude,
          ),

          icon:
          BitmapDescriptor.defaultMarkerWithHue(
            _checkpointMarkerHue(
              destination,
            ),
          ),

          infoWindow:
          InfoWindow.noText,

          onTap: () {
            _selectDestination(
              destination,
            );
          },
        );
      },
    ).toSet();
  }

  // ============================================================
  // BUILD 5 KM CIRCLE
  // ============================================================

  Set<Circle> _buildCircles() {
    final Position? position =
        _currentPosition;

    if (position == null) {
      return {};
    }

    return {
      Circle(
        circleId: const CircleId(
          'checkpoint_5km_radius',
        ),

        center: LatLng(
          position.latitude,
          position.longitude,
        ),

        radius:
        checkpointRadiusMeters,

        fillColor:
        userColor.withValues(
          alpha: 0.05,
        ),

        strokeColor:
        userColor.withValues(
          alpha: 0.38,
        ),

        strokeWidth: 2,
      ),
    };
  }

  // ============================================================
  // MOVE MAP TO USER
  // ============================================================

  Future<void> _moveToUser() async {
    final Position? position =
        _currentPosition;

    final GoogleMapController? controller =
        _mapController;

    if (position == null ||
        controller == null) {
      return;
    }

    await controller.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(
          target: LatLng(
            position.latitude,
            position.longitude,
          ),
          zoom: 12.5,
        ),
      ),
    );
  }

  // ============================================================
  // HEADER NAVIGATION
  // ============================================================

  void _openHome() {
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(
        builder: (_) =>
        const HomeScreen(),
      ),
          (route) => false,
    );
  }

  void _openLeaderboard() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
        const LeaderboardScreen(),
      ),
    );
  }

  void _openChat() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
        const ChatListScreen(),
      ),
    );
  }

  Future<void> _openProfile() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
        const ProfileScreen(),
      ),
    );

    _loadHeaderProfile();
  }

  // ============================================================
  // BOTTOM NAVIGATION
  // ============================================================

  void _openBlindBox() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) =>
        const BlindBoxPage(),
      ),
    );
  }

  void _openPlan() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) =>
        const PlanScreen(),
      ),
    );
  }

  void _openTeams() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) =>
        const GroupScreen(),
      ),
    );
  }

  // ============================================================
  // MESSAGE
  // ============================================================

  void _showMessage(
      String message,
      ) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior:
          SnackBarBehavior.floating,

          margin:
          const EdgeInsets.fromLTRB(
            16,
            0,
            16,
            100,
          ),

          content:
          Text(message),
        ),
      );
  }

  // ============================================================
  // MAIN BUILD
  // ============================================================

  @override
  Widget build(
      BuildContext context,
      ) {
    return Scaffold(
      backgroundColor:
      pageBackground,

      appBar:
      _buildTopAppBar(),

      body: SafeArea(
        top: false,
        bottom: false,
        child: Column(
          children: [
            _buildModeHeader(),

            _buildCheckpointCount(),

            Expanded(
              child:
              _buildMapSection(),
            ),
          ],
        ),
      ),

      floatingActionButtonLocation:
      FloatingActionButtonLocation
          .centerDocked,

      floatingActionButton:
      _buildHomeButton(),

      bottomNavigationBar:
      _buildBottomBar(),
    );
  }

  // ============================================================
  // TOP APP BAR
  // ============================================================

  PreferredSizeWidget _buildTopAppBar() {
    return AppBar(
      automaticallyImplyLeading:
      false,

      toolbarHeight:
      68,

      elevation:
      0,

      scrolledUnderElevation:
      2,

      backgroundColor:
      Colors.white.withValues(
        alpha: 0.97,
      ),

      surfaceTintColor:
      Colors.white,

      titleSpacing:
      16,

      title: InkWell(
        borderRadius:
        BorderRadius.circular(14),

        onTap:
        _openHome,

        child:
        const Padding(
          padding:
          EdgeInsets.symmetric(
            vertical: 6,
          ),

          child:
          Row(
            mainAxisSize:
            MainAxisSize.min,

            children: [
              _MysteryLaneLogo(),

              SizedBox(width: 10),

              Text(
                'MYSTERYLANE',

                style:
                TextStyle(
                  color:
                  darkText,

                  fontSize:
                  20,

                  fontWeight:
                  FontWeight.w900,

                  letterSpacing:
                  -0.5,
                ),
              ),
            ],
          ),
        ),
      ),

      actions: [
        _TopActionButton(
          tooltip:
          'Leaderboard',

          icon:
          Icons.emoji_events_rounded,

          background:
          const Color(
            0xFFFFFBEB,
          ),

          foreground:
          const Color(
            0xFFD97706,
          ),

          onTap:
          _openLeaderboard,
        ),

        const SizedBox(width: 6),

        _TopActionButton(
          tooltip:
          'Chat',

          icon:
          Icons.chat_bubble_outline_rounded,

          background:
          const Color(
            0xFFF0F9FF,
          ),

          foreground:
          skyBlue,

          onTap:
          _openChat,
        ),

        const SizedBox(width: 6),

        _ProfileButton(
          onTap:
          _openProfile,

          imageUrl:
          _headerProfilePictureUrl,
        ),

        const SizedBox(width: 12),
      ],

      bottom:
      const PreferredSize(
        preferredSize:
        Size.fromHeight(1),

        child:
        Divider(
          height:
          1,

          thickness:
          1,

          color:
          Color(
            0xFFE2E8F0,
          ),
        ),
      ),
    );
  }

  // ============================================================
  // CHECKPOINT / PUZZLE HEADER
  // ============================================================

  Widget _buildModeHeader() {
    return Container(
      color:
      Colors.white,

      padding:
      const EdgeInsets.fromLTRB(
        16,
        10,
        12,
        7,
      ),

      child:
      Row(
        children: [
          Expanded(
            child:
            Container(
              height:
              48,

              padding:
              const EdgeInsets.all(4),

              decoration:
              BoxDecoration(
                color:
                const Color(
                  0xFFF0F9FF,
                ),

                borderRadius:
                BorderRadius.circular(
                  25,
                ),

                border:
                Border.all(
                  color:
                  const Color(
                    0xFFBAE6FD,
                  ),

                  width:
                  1.4,
                ),
              ),

              child:
              Row(
                children: [
                  // ==============================================
                  // CHECKPOINT ACTIVE TAB
                  // ==============================================

                  Expanded(
                    child:
                    Container(
                      height:
                      double.infinity,

                      alignment:
                      Alignment.center,

                      decoration:
                      BoxDecoration(
                        color:
                        skyBlue,

                        borderRadius:
                        BorderRadius.circular(
                          21,
                        ),
                      ),

                      child:
                      const Text(
                        'Checkpoint Mission',

                        style:
                        TextStyle(
                          color:
                          Colors.white,

                          fontSize:
                          12,

                          fontWeight:
                          FontWeight.w800,
                        ),
                      ),
                    ),
                  ),

                  // ==============================================
                  // PUZZLE TAB
                  // ==============================================

                  Expanded(
                    child:
                    InkWell(
                      borderRadius:
                      BorderRadius.circular(
                        21,
                      ),

                      onTap:
                      _openPuzzleFromTab,

                      child:
                      const SizedBox(
                        height:
                        double.infinity,

                        child:
                        Center(
                          child:
                          Text(
                            'Puzzle Challenge',

                            style:
                            TextStyle(
                              color:
                              Color(
                                0xFF475569,
                              ),

                              fontSize:
                              11.5,

                              fontWeight:
                              FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(width: 8),

          // ======================================================
          // REFRESH
          // ======================================================

          IconButton(
            tooltip:
            'Refresh checkpoints',

            onPressed:
            _isLoading
                ? null
                : _reloadCheckpoints,

            icon:
            _isLoading
                ? const SizedBox(
              width:
              22,

              height:
              22,

              child:
              CircularProgressIndicator(
                strokeWidth:
                2.3,
              ),
            )
                : const Icon(
              Icons.refresh_rounded,

              color:
              skyBlue,

              size:
              29,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // CHECKPOINT COUNT
  // ============================================================

  Widget _buildCheckpointCount() {
    return Container(
      width:
      double.infinity,

      color:
      Colors.white,

      padding:
      const EdgeInsets.fromLTRB(
        18,
        4,
        18,
        10,
      ),

      child:
      Row(
        children: [
          const Icon(
            Icons.explore_outlined,

            color:
            skyBlue,

            size:
            17,
          ),

          const SizedBox(width: 7),

          Expanded(
            child:
            Text(
              _isLoading
                  ? 'Finding checkpoints near you...'
                  : '${_nearbyDestinations.length} '
                  'checkpoints available within '
                  '5 km of your location',

              style:
              const TextStyle(
                color:
                greyText,

                fontSize:
                13.5,

                fontWeight:
                FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // MAP SECTION
  // ============================================================

  Widget _buildMapSection() {
    if (_isLoading &&
        _currentPosition == null) {
      return const Center(
        child:
        Column(
          mainAxisSize:
          MainAxisSize.min,

          children: [
            CircularProgressIndicator(),

            SizedBox(height: 14),

            Text(
              'Finding nearby checkpoints...',

              style:
              TextStyle(
                color:
                greyText,
              ),
            ),
          ],
        ),
      );
    }

    // ===========================================================
    // ERROR
    // ===========================================================

    if (_errorMessage != null &&
        _currentPosition == null) {
      return Center(
        child:
        Padding(
          padding:
          const EdgeInsets.all(24),

          child:
          Column(
            mainAxisSize:
            MainAxisSize.min,

            children: [
              const Icon(
                Icons.location_off_outlined,

                size:
                58,

                color:
                Color(
                  0xFF94A3B8,
                ),
              ),

              const SizedBox(height: 14),

              Text(
                _errorMessage!,

                textAlign:
                TextAlign.center,

                style:
                const TextStyle(
                  color:
                  greyText,

                  fontSize:
                  14,
                ),
              ),

              const SizedBox(height: 18),

              FilledButton.icon(
                onPressed:
                _reloadCheckpoints,

                icon:
                const Icon(
                  Icons.refresh_rounded,
                ),

                label:
                const Text(
                  'Try Again',
                ),
              ),
            ],
          ),
        ),
      );
    }

    final Position? position =
        _currentPosition;

    final LatLng initialTarget =
    position != null
        ? LatLng(
      position.latitude,
      position.longitude,
    )
        : fallbackLocation;

    return Stack(
      children: [
        // ========================================================
        // GOOGLE MAP
        // ========================================================

        GoogleMap(
          initialCameraPosition:
          CameraPosition(
            target:
            initialTarget,

            zoom:
            12.5,
          ),

          markers:
          _buildMarkers(),

          circles:
          _buildCircles(),

          myLocationEnabled:
          position != null,

          myLocationButtonEnabled:
          false,

          zoomControlsEnabled:
          false,

          mapToolbarEnabled:
          false,

          compassEnabled:
          true,

          padding:
          EdgeInsets.only(
            top:
            65,

            bottom:
            _selectedDestination != null
                ? 260
                : 50,
          ),

          onMapCreated:
              (
              GoogleMapController controller,
              ) {
            _mapController =
                controller;

            _moveToUser();
          },

          onTap: (_) {
            // Keep selected checkpoint displayed.
          },
        ),

        // ========================================================
        // LEGEND
        // ========================================================

        Positioned(
          top:
          10,

          left:
          12,

          right:
          12,

          child:
          _buildLegend(),
        ),

        // ========================================================
        // CURRENT LOCATION BUTTON
        // ========================================================

        Positioned(
          top:
          64,

          right:
          14,

          child:
          Material(
            color:
            Colors.white,

            elevation:
            5,

            shape:
            const CircleBorder(),

            child:
            InkWell(
              customBorder:
              const CircleBorder(),

              onTap:
              _moveToUser,

              child:
              const SizedBox(
                width:
                52,

                height:
                52,

                child:
                Icon(
                  Icons.my_location_rounded,

                  color:
                  skyBlue,

                  size:
                  27,
                ),
              ),
            ),
          ),
        ),

        // ========================================================
        // NO CHECKPOINTS
        // ========================================================

        if (!_isLoading &&
            _nearbyDestinations.isEmpty)
          Positioned(
            left:
            20,

            right:
            20,

            bottom:
            70,

            child:
            Container(
              padding:
              const EdgeInsets.all(
                16,
              ),

              decoration:
              BoxDecoration(
                color:
                Colors.white,

                borderRadius:
                BorderRadius.circular(
                  18,
                ),

                boxShadow:
                const [
                  BoxShadow(
                    color:
                    Color(
                      0x1A000000,
                    ),

                    blurRadius:
                    16,

                    offset:
                    Offset(
                      0,
                      5,
                    ),
                  ),
                ],
              ),

              child:
              const Column(
                mainAxisSize:
                MainAxisSize.min,

                children: [
                  Icon(
                    Icons.location_off_outlined,

                    color:
                    greyText,

                    size:
                    32,
                  ),

                  SizedBox(height: 8),

                  Text(
                    'No checkpoint missions found '
                        'within 5 km.',

                    textAlign:
                    TextAlign.center,

                    style:
                    TextStyle(
                      color:
                      darkText,

                      fontWeight:
                      FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),

        // ========================================================
        // SELECTED CHECKPOINT CARD
        // ========================================================

        if (_selectedDestination != null)
          Positioned(
            left:
            14,

            right:
            14,

            bottom:
            42,

            child:
            _buildSelectedDestinationCard(
              _selectedDestination!,
            ),
          ),
      ],
    );
  }

  // ============================================================
  // LEGEND
  // ============================================================

  Widget _buildLegend() {
    return Container(
      padding:
      const EdgeInsets.symmetric(
        horizontal:
        12,

        vertical:
        9,
      ),

      decoration:
      BoxDecoration(
        color:
        Colors.white.withValues(
          alpha:
          0.96,
        ),

        borderRadius:
        BorderRadius.circular(
          18,
        ),

        border:
        Border.all(
          color:
          const Color(
            0xFFE2E8F0,
          ),
        ),

        boxShadow:
        const [
          BoxShadow(
            color:
            Color(
              0x14000000,
            ),

            blurRadius:
            8,

            offset:
            Offset(
              0,
              3,
            ),
          ),
        ],
      ),

      child:
      const Wrap(
        alignment:
        WrapAlignment.center,

        spacing:
        14,

        runSpacing:
        5,

        children: [
          _LegendItem(
            color:
            completedColor,

            label:
            'Completed',
          ),

          _LegendItem(
            color:
            hiddenGemColor,

            label:
            'Hidden Gem',
          ),

          _LegendItem(
            color:
            blindBoxColor,

            label:
            'Blind Box',
          ),

          _LegendItem(
            color:
            userColor,

            label:
            'You (5km)',
          ),
        ],
      ),
    );
  }

  // ============================================================
  // SELECTED DESTINATION CARD
  // ============================================================

  Widget _buildSelectedDestinationCard(
      CheckpointDestination destination,
      ) {
    final bool completed =
    _isCompleted(destination);

    final double distanceKm =
        _distanceKmByDestinationId[
        destination.destinationId] ??
            0;

    final int reward =
        _rewardPointsByDestinationId[
        destination.destinationId] ??
            0;

    final String sourceLabel =
    _checkpointSourceLabel(
      destination,
    );

    final Color sourceColor =
    _checkpointSourceColor(
      destination,
    );

    final String? descriptionRaw =
    destination.description?.trim();

    final String description =
    descriptionRaw != null &&
        descriptionRaw.isNotEmpty
        ? descriptionRaw
        : 'Explore this checkpoint and '
        'complete its challenge to earn '
        'Exploration Points.';

    return Container(
      padding:
      const EdgeInsets.fromLTRB(
        18,
        16,
        18,
        15,
      ),

      decoration:
      BoxDecoration(
        color:
        Colors.white,

        borderRadius:
        BorderRadius.circular(
          26,
        ),

        border:
        Border.all(
          color:
          const Color(
            0xFFE2E8F0,
          ),
        ),

        boxShadow:
        const [
          BoxShadow(
            color:
            Color(
              0x260F172A,
            ),

            blurRadius:
            22,

            offset:
            Offset(
              0,
              8,
            ),
          ),
        ],
      ),

      child:
      Column(
        mainAxisSize:
        MainAxisSize.min,

        crossAxisAlignment:
        CrossAxisAlignment.start,

        children: [
          // ======================================================
          // NAME + REWARD
          // ======================================================

          Row(
            crossAxisAlignment:
            CrossAxisAlignment.start,

            children: [
              Container(
                width:
                42,

                height:
                42,

                decoration:
                BoxDecoration(
                  color:
                  sourceColor.withValues(
                    alpha:
                    0.12,
                  ),

                  borderRadius:
                  BorderRadius.circular(
                    13,
                  ),
                ),

                child:
                Icon(
                  Icons.location_on_rounded,

                  color:
                  sourceColor,

                  size:
                  24,
                ),
              ),

              const SizedBox(width: 12),

              Expanded(
                child:
                Column(
                  crossAxisAlignment:
                  CrossAxisAlignment.start,

                  children: [
                    Text(
                      destination.name,

                      maxLines:
                      2,

                      overflow:
                      TextOverflow.ellipsis,

                      style:
                      const TextStyle(
                        color:
                        darkText,

                        fontSize:
                        17,

                        fontWeight:
                        FontWeight.w900,
                      ),
                    ),

                    const SizedBox(height: 4),

                    Text(
                      '${distanceKm.toStringAsFixed(2)} '
                          'km away · $sourceLabel',

                      style:
                      TextStyle(
                        color:
                        sourceColor,

                        fontSize:
                        11.5,

                        fontWeight:
                        FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 8),

              Container(
                padding:
                const EdgeInsets.symmetric(
                  horizontal:
                  10,

                  vertical:
                  6,
                ),

                decoration:
                BoxDecoration(
                  color:
                  const Color(
                    0xFFF0F9FF,
                  ),

                  borderRadius:
                  BorderRadius.circular(
                    99,
                  ),
                ),

                child:
                Text(
                  '+$reward',

                  style:
                  const TextStyle(
                    color:
                    skyBlue,

                    fontSize:
                    12,

                    fontWeight:
                    FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 11),

          // ======================================================
          // STATUS
          // ======================================================

          Row(
            children: [
              Icon(
                completed
                    ? Icons.check_circle_rounded
                    : Icons.outlined_flag_rounded,

                size:
                17,

                color:
                completed
                    ? completedColor
                    : skyBlue,
              ),

              const SizedBox(width: 7),

              Text(
                completed
                    ? 'Checkpoint completed'
                    : 'Checkpoint available',

                style:
                TextStyle(
                  color:
                  completed
                      ? completedColor
                      : skyBlue,

                  fontSize:
                  12,

                  fontWeight:
                  FontWeight.w800,
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),

          // ======================================================
          // DESCRIPTION
          // ======================================================

          Text(
            description,

            maxLines:
            3,

            overflow:
            TextOverflow.ellipsis,

            style:
            const TextStyle(
              color:
              greyText,

              fontSize:
              12.5,

              height:
              1.45,
            ),
          ),

          const SizedBox(height: 15),

          // ======================================================
          // MISSION + PUZZLE BUTTONS
          // ======================================================

          Row(
            children: [
              // ==================================================
              // VIEW MISSION
              // ==================================================

              Expanded(
                child:
                SizedBox(
                  height:
                  52,

                  child:
                  FilledButton.icon(
                    onPressed: () {
                      _openMission(
                        destination,
                      );
                    },

                    style:
                    FilledButton.styleFrom(
                      backgroundColor:
                      skyBlue,

                      foregroundColor:
                      Colors.white,

                      shape:
                      RoundedRectangleBorder(
                        borderRadius:
                        BorderRadius.circular(
                          28,
                        ),
                      ),
                    ),

                    icon:
                    const Icon(
                      Icons.visibility_outlined,

                      size:
                      19,
                    ),

                    label:
                    const Text(
                      'VIEW MISSION',

                      style:
                      TextStyle(
                        fontSize:
                        10.5,

                        fontWeight:
                        FontWeight.w900,

                        letterSpacing:
                        0.3,
                      ),
                    ),
                  ),
                ),
              ),

              const SizedBox(width: 10),

              // ==================================================
              // VIEW PUZZLE
              // ==================================================

              Expanded(
                child:
                SizedBox(
                  height:
                  52,

                  child:
                  OutlinedButton.icon(
                    // THIS NOW REALLY OPENS PUZZLE SCREEN.
                    onPressed: () {
                      _openPuzzle(
                        destination,
                      );
                    },

                    style:
                    OutlinedButton.styleFrom(
                      foregroundColor:
                      blindBoxColor,

                      side:
                      const BorderSide(
                        color:
                        blindBoxColor,

                        width:
                        1.5,
                      ),

                      shape:
                      RoundedRectangleBorder(
                        borderRadius:
                        BorderRadius.circular(
                          28,
                        ),
                      ),
                    ),

                    icon:
                    const Icon(
                      Icons.extension_rounded,

                      size:
                      19,
                    ),

                    label:
                    const Text(
                      'VIEW PUZZLE',

                      style:
                      TextStyle(
                        fontSize:
                        10.5,

                        fontWeight:
                        FontWeight.w900,

                        letterSpacing:
                        0.3,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ============================================================
  // BOTTOM BAR
  // ============================================================

  Widget _buildBottomBar() {
    return BottomAppBar(
      height:
      78,

      padding:
      EdgeInsets.zero,

      color:
      Colors.white.withValues(
        alpha:
        0.98,
      ),

      elevation:
      18,

      shadowColor:
      const Color(
        0x330284C7,
      ),

      shape:
      const CircularNotchedRectangle(),

      notchMargin:
      8,

      child:
      SafeArea(
        top:
        false,

        child:
        Row(
          children: [
            Expanded(
              child:
              _BottomItem(
                icon:
                Icons.inventory_2_outlined,

                label:
                'BLIND BOX',

                active:
                false,

                onTap:
                _openBlindBox,
              ),
            ),

            Expanded(
              child:
              _BottomItem(
                icon:
                Icons.assignment_outlined,

                label:
                'MISSIONS',

                active:
                true,

                onTap:
                    () {},
              ),
            ),

            const SizedBox(width: 74),

            Expanded(
              child:
              _BottomItem(
                icon:
                Icons.map_outlined,

                label:
                'PLAN',

                active:
                false,

                onTap:
                _openPlan,
              ),
            ),

            Expanded(
              child:
              _BottomItem(
                icon:
                Icons.groups_2_outlined,

                label:
                'TEAMS',

                active:
                false,

                onTap:
                _openTeams,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // HOME BUTTON
  // ============================================================

  Widget _buildHomeButton() {
    return Padding(
      padding:
      const EdgeInsets.only(
        top: 10,
      ),

      child:
      InkWell(
        customBorder:
        const CircleBorder(),

        onTap:
        _openHome,

        child:
        Container(
          width:
          62,

          height:
          62,

          decoration:
          BoxDecoration(
            shape:
            BoxShape.circle,

            gradient:
            const LinearGradient(
              colors: [
                skyBlue,
                teal,
              ],

              begin:
              Alignment.topLeft,

              end:
              Alignment.bottomRight,
            ),

            border:
            Border.all(
              color:
              Colors.white,

              width:
              4,
            ),

            boxShadow:
            const [
              BoxShadow(
                color:
                Color(
                  0x3D0284C7,
                ),

                blurRadius:
                16,

                offset:
                Offset(
                  0,
                  7,
                ),
              ),
            ],
          ),

          child:
          const Column(
            mainAxisAlignment:
            MainAxisAlignment.center,

            children: [
              Icon(
                Icons.home_rounded,

                color:
                Color(
                  0xFFFDE68A,
                ),

                size:
                27,
              ),

              Text(
                'HOME',

                style:
                TextStyle(
                  color:
                  Colors.white,

                  fontSize:
                  8,

                  fontWeight:
                  FontWeight.w900,

                  letterSpacing:
                  0.8,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================
// CHECKPOINT LOAD RESULT
// ============================================================

class _CheckpointLoadResult {
  final List<CheckpointDestination>
  destinations;

  final Map<String, int>
  rewardPoints;

  const _CheckpointLoadResult({
    required this.destinations,
    required this.rewardPoints,
  });
}

// ============================================================
// MYSTERYLANE LOGO
// ============================================================

class _MysteryLaneLogo extends StatelessWidget {
  const _MysteryLaneLogo();

  @override
  Widget build(
      BuildContext context,
      ) {
    return Container(
      width:
      38,

      height:
      38,

      decoration:
      const BoxDecoration(
        shape:
        BoxShape.circle,

        gradient:
        LinearGradient(
          colors: [
            Color(
              0xFF0284C7,
            ),
            Color(
              0xFF0D9488,
            ),
          ],

          begin:
          Alignment.topLeft,

          end:
          Alignment.bottomRight,
        ),

        boxShadow: [
          BoxShadow(
            color:
            Color(
              0x300284C7,
            ),

            blurRadius:
            10,

            offset:
            Offset(
              0,
              4,
            ),
          ),
        ],
      ),

      child:
      const Icon(
        Icons.explore_rounded,

        color:
        Colors.white,

        size:
        23,
      ),
    );
  }
}

// ============================================================
// TOP ACTION BUTTON
// ============================================================

class _TopActionButton extends StatelessWidget {
  final String tooltip;
  final IconData icon;
  final Color background;
  final Color foreground;
  final VoidCallback onTap;

  const _TopActionButton({
    required this.tooltip,
    required this.icon,
    required this.background,
    required this.foreground,
    required this.onTap,
  });

  @override
  Widget build(
      BuildContext context,
      ) {
    return Tooltip(
      message:
      tooltip,

      child:
      InkWell(
        borderRadius:
        BorderRadius.circular(
          99,
        ),

        onTap:
        onTap,

        child:
        Container(
          width:
          38,

          height:
          38,

          decoration:
          BoxDecoration(
            color:
            background,

            shape:
            BoxShape.circle,

            border:
            Border.all(
              color:
              foreground.withValues(
                alpha:
                0.20,
              ),
            ),
          ),

          child:
          Icon(
            icon,

            color:
            foreground,

            size:
            20,
          ),
        ),
      ),
    );
  }
}

// ============================================================
// PROFILE BUTTON
// ============================================================

class _ProfileButton extends StatelessWidget {
  final VoidCallback onTap;
  final String? imageUrl;

  const _ProfileButton({
    required this.onTap,
    required this.imageUrl,
  });

  @override
  Widget build(
      BuildContext context,
      ) {
    final String? cleanUrl =
    imageUrl?.trim();

    final ImageProvider? provider =
    cleanUrl != null &&
        cleanUrl.isNotEmpty
        ? NetworkImage(cleanUrl)
        : null;

    return Tooltip(
      message:
      'Profile',

      child:
      InkWell(
        customBorder:
        const CircleBorder(),

        onTap:
        onTap,

        child:
        Container(
          width:
          38,

          height:
          38,

          padding:
          const EdgeInsets.all(
            3,
          ),

          decoration:
          BoxDecoration(
            color:
            Colors.white,

            shape:
            BoxShape.circle,

            border:
            Border.all(
              color:
              const Color(
                0xFFBAE6FD,
              ),

              width:
              1.4,
            ),
          ),

          child:
          CircleAvatar(
            backgroundColor:
            const Color(
              0xFFE0F2FE,
            ),

            backgroundImage:
            provider,

            child:
            provider == null
                ? const Icon(
              Icons.person_rounded,

              size:
              20,

              color:
              Color(
                0xFF0284C7,
              ),
            )
                : null,
          ),
        ),
      ),
    );
  }
}

// ============================================================
// LEGEND ITEM
// ============================================================

class _LegendItem extends StatelessWidget {
  final Color color;
  final String label;

  const _LegendItem({
    required this.color,
    required this.label,
  });

  @override
  Widget build(
      BuildContext context,
      ) {
    return Row(
      mainAxisSize:
      MainAxisSize.min,

      children: [
        Container(
          width:
          8,

          height:
          8,

          decoration:
          BoxDecoration(
            color:
            color,

            shape:
            BoxShape.circle,
          ),
        ),

        const SizedBox(width: 5),

        Text(
          label,

          style:
          const TextStyle(
            color:
            Color(
              0xFF475569,
            ),

            fontSize:
            10,

            fontWeight:
            FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

// ============================================================
// BOTTOM ITEM
// ============================================================

class _BottomItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _BottomItem({
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(
      BuildContext context,
      ) {
    const Color skyBlue =
    Color(
      0xFF0284C7,
    );

    return InkWell(
      onTap:
      onTap,

      child:
      Padding(
        padding:
        const EdgeInsets.only(
          top:
          10,

          bottom:
          4,
        ),

        child:
        Column(
          mainAxisAlignment:
          MainAxisAlignment.center,

          children: [
            AnimatedContainer(
              duration:
              const Duration(
                milliseconds:
                160,
              ),

              width:
              42,

              height:
              29,

              decoration:
              BoxDecoration(
                color:
                active
                    ? skyBlue
                    : Colors.transparent,

                borderRadius:
                BorderRadius.circular(
                  12,
                ),
              ),

              child:
              Icon(
                icon,

                size:
                21,

                color:
                active
                    ? Colors.white
                    : const Color(
                  0xFF64748B,
                ),
              ),
            ),

            const SizedBox(height: 3),

            Text(
              label,

              style:
              TextStyle(
                color:
                active
                    ? skyBlue
                    : const Color(
                  0xFF64748B,
                ),

                fontSize:
                8,

                fontWeight:
                active
                    ? FontWeight.w900
                    : FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}