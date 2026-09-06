import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../../application/controller/checkpoint_controller.dart';
import '../../../data/models/checkpoint_destination.dart';

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
  final String? initialDestinationId;

  const CheckpointScreen({
    super.key,
    this.initialDestinationId,
  });

  @override
  State<CheckpointScreen> createState() => _CheckpointScreenState();
}

class _CheckpointScreenState
    extends State<CheckpointScreen> {
  // ===========================================================================
  // UI COLORS
  // ===========================================================================

  bool _initialDestinationFocused = false;

  static const Color skyBlue = Color(0xFF0284C7);
  static const Color teal = Color(0xFF0D9488);

  static const Color darkText =
  Color(0xFF0F172A);

  static const Color greyText =
  Color(0xFF64748B);

  static const Color pageBackground =
  Color(0xFFF8FAFC);

  // ---------------------------------------------------------------------------
  // MAP LEGEND COLORS
  // ---------------------------------------------------------------------------

  static const Color completedColor =
  Color(0xFF10B981);

  static const Color hiddenGemColor =
  Color(0xFFF59E0B);

  static const Color blindBoxColor =
  Color(0xFF7C3AED);

  static const Color userColor =
  Color(0xFF2196F3);

  // ===========================================================================
  // UI CONSTANTS
  // ===========================================================================

  static const double checkpointRadiusMeters =
  5000.0;

  static const LatLng fallbackLocation =
  LatLng(
    3.1390,
    101.6869,
  );

  // ===========================================================================
  // CONTROLLER
  // ===========================================================================

  late final CheckpointController _controller;

  GoogleMapController? _mapController;

  // ===========================================================================
  // INIT
  // ===========================================================================

  @override
  void initState() {
    super.initState();

    _controller =
        CheckpointController.production();

    _controller.addListener(
      _onControllerChanged,
    );

    _controller.initialize();
  }

  void _onControllerChanged() {
    if (!mounted) {
      return;
    }

    setState(() {});

    if (_controller.isLoading) {
      return;
    }

    // Only auto-focus when the screen was opened
    // from Blind Box History with a specific destination.
    if (widget.initialDestinationId != null &&
        !_initialDestinationFocused) {
      WidgetsBinding.instance.addPostFrameCallback(
            (_) async {
          if (!mounted) {
            return;
          }

          await _focusInitialDestination();
        },
      );
    }

    // IMPORTANT:
    // Do NOT call _moveToUser() here.
    //
    // selectDestination() also triggers notifyListeners(),
    // so calling _moveToUser() here makes the map jump back
    // to the user's GPS every time a pin is tapped.
  }

  @override
  void dispose() {
    _controller.removeListener(
      _onControllerChanged,
    );

    _controller.dispose();

    _mapController?.dispose();

    super.dispose();
  }

  // ===========================================================================
  // MARKER DISPLAY
  // ===========================================================================

  double _checkpointMarkerHue(
      CheckpointDestination destination,
      ) {
    // Completed has highest priority.
    if (_controller.isCompleted(
      destination,
    )) {
      return BitmapDescriptor.hueGreen;
    }

    // GOOGLE = Blind Box.
    if (_controller.isBlindBoxDestination(
      destination,
    )) {
      return BitmapDescriptor.hueViolet;
    }

    // CURATED = Hidden Gem.
    return BitmapDescriptor.hueOrange;
  }

  Color _checkpointSourceColor(
      CheckpointDestination destination,
      ) {
    if (_controller.isBlindBoxDestination(
      destination,
    )) {
      return blindBoxColor;
    }

    return hiddenGemColor;
  }

  // ===========================================================================
  // OPEN CHECKPOINT MISSION
  // ===========================================================================

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

    // User may have completed the mission.
    await _controller.refreshCompleted();
  }

  // ===========================================================================
  // OPEN PUZZLE
  // ===========================================================================

  void _openPuzzle(
      CheckpointDestination destination,
      ) {
    final MissionCheckpoint checkpoint =
    MissionCheckpoint(
      id: destination.destinationId,
      title: destination.name,
      imageUrl: destination.imageUrl,
      locationName: destination.address,
      category:
      destination.category ??
          'Checkpoint',
    );

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PuzzleScreen(
          mission: checkpoint,
          initialLocationSource:
          PuzzleLocationSource.checkpoint,
        ),
      ),
    );
  }

  void _openPuzzleFromTab() {
    final CheckpointDestination? destination =
        _controller.selectedDestination;

    // ============================================================
    // IF USER ALREADY SELECTED A PIN
    // → open Puzzle with that exact checkpoint
    // ============================================================

    if (destination != null) {
      _openPuzzle(
        destination,
      );

      return;
    }

    // ============================================================
    // NO PIN SELECTED
    // → still allow user to enter Puzzle module
    // → PuzzleScreen will let user choose a checkpoint location
    // ============================================================

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const PuzzleScreen(
          initialLocationSource:
          PuzzleLocationSource.checkpoint,
        ),
      ),
    );
  }

  // ===========================================================================
  // MAP MARKERS
  // ===========================================================================

  Set<Marker> _buildMarkers() {
    return _controller.nearbyDestinations
        .map(
          (
          CheckpointDestination destination,
          ) {
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
            _controller.selectDestination(
              destination,
            );
          },
        );
      },
    ).toSet();
  }

  // ===========================================================================
  // 5 KM CIRCLE
  // ===========================================================================

  Set<Circle> _buildCircles() {
    final double? latitude =
        _controller.currentLatitude;

    final double? longitude =
        _controller.currentLongitude;

    if (latitude == null ||
        longitude == null) {
      return {};
    }

    return {
      Circle(
        circleId: const CircleId(
          'checkpoint_5km_radius',
        ),

        center: LatLng(
          latitude,
          longitude,
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

  // ===========================================================================
  // MOVE MAP TO USER
  // ===========================================================================

  Future<void> _moveToUser() async {
    final double? latitude =
        _controller.currentLatitude;

    final double? longitude =
        _controller.currentLongitude;

    final GoogleMapController? controller =
        _mapController;

    if (latitude == null ||
        longitude == null ||
        controller == null) {
      return;
    }

    await controller.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(
          target: LatLng(
            latitude,
            longitude,
          ),
          zoom: 12.5,
        ),
      ),
    );
  }

  Future<void> _focusInitialDestination() async {
    if (_initialDestinationFocused) {
      return;
    }

    final String destinationId =
        widget.initialDestinationId?.trim() ?? '';

    if (destinationId.isEmpty) {
      return;
    }

    if (_controller.isLoading) {
      return;
    }

    CheckpointDestination? target;

    for (final destination
    in _controller.nearbyDestinations) {
      if (destination.destinationId ==
          destinationId) {
        target = destination;
        break;
      }
    }

    if (target == null) {
      debugPrint(
        '[CHECKPOINT MAP] Requested destination '
            'not found: $destinationId',
      );
      return;
    }

    _initialDestinationFocused = true;

    // ============================================================
    // 1. SELECT DESTINATION FIRST
    // ============================================================

    _controller.selectDestination(
      target,
    );

    debugPrint(
      '[CHECKPOINT MAP] Focusing: ${target.name}',
    );

    // ============================================================
    // 2. WAIT FOR BOTTOM CARD + GOOGLE MAP PADDING TO REBUILD
    // ============================================================

    await Future<void>.delayed(
      const Duration(
        milliseconds: 350,
      ),
    );

    if (!mounted) {
      return;
    }

    final GoogleMapController? mapController =
        _mapController;

    if (mapController == null) {
      return;
    }

    // ============================================================
    // 3. MOVE CAMERA AFTER UI IS READY
    // ============================================================

    await mapController.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(
          target: LatLng(
            target.latitude,
            target.longitude,
          ),
          zoom: 16.0,
        ),
      ),
    );
  }

  // ===========================================================================
  // HEADER NAVIGATION
  // ===========================================================================

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

    // Profile picture may have changed.
    await _controller.loadHeaderProfile();
  }

  // ===========================================================================
  // BOTTOM NAVIGATION
  // ===========================================================================

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

  // ===========================================================================
  // MESSAGE
  // ===========================================================================

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

  // ===========================================================================
  // MAIN BUILD
  // ===========================================================================

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

  // ===========================================================================
  // TOP APP BAR
  // ===========================================================================

  PreferredSizeWidget _buildTopAppBar() {
    return AppBar(
      automaticallyImplyLeading: false,

      toolbarHeight: 68,

      elevation: 0,

      scrolledUnderElevation: 2,

      backgroundColor: Colors.white.withValues(
        alpha: 0.97,
      ),

      surfaceTintColor: Colors.white,

      // Reduce a little horizontal space
      titleSpacing: 12,

      title: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: _openHome,

        child: Padding(
          padding: const EdgeInsets.symmetric(
            vertical: 6,
          ),

          child: Row(
            children: [
              // =====================================================
              // LOGO
              // =====================================================
              const _MysteryLaneLogo(),

              const SizedBox(width: 8),

              // =====================================================
              // RESPONSIVE TITLE
              // =====================================================
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,

                  child: const Text(
                    'MYSTERYLANE',
                    maxLines: 1,

                    style: TextStyle(
                      color: darkText,
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.5,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),

      actions: [
        _TopActionButton(
          tooltip: 'Leaderboard',
          icon: Icons.emoji_events_rounded,
          background: const Color(0xFFFFFBEB),
          foreground: const Color(0xFFD97706),
          onTap: _openLeaderboard,
        ),

        const SizedBox(width: 4),

        _TopActionButton(
          tooltip: 'Chat',
          icon: Icons.chat_bubble_outline_rounded,
          background: const Color(0xFFF0F9FF),
          foreground: skyBlue,
          onTap: _openChat,
        ),

        const SizedBox(width: 4),

        _ProfileButton(
          onTap: _openProfile,
          imageUrl:
          _controller.headerProfilePictureUrl,
        ),

        const SizedBox(width: 8),
      ],

      bottom: const PreferredSize(
        preferredSize: Size.fromHeight(1),

        child: Divider(
          height: 1,
          thickness: 1,
          color: Color(0xFFE2E8F0),
        ),
      ),
    );
  }

  // ===========================================================================
  // CHECKPOINT / PUZZLE HEADER
  // ===========================================================================

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

      child: Row(
        children: [
          Expanded(
            child: Container(
              height: 48,

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

                  width: 1.4,
                ),
              ),

              child: Row(
                children: [
                  // ---------------------------------------------------------
                  // CHECKPOINT TAB
                  // ---------------------------------------------------------

                  Expanded(
                    child: Container(
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

                  // ---------------------------------------------------------
                  // PUZZLE TAB
                  // ---------------------------------------------------------

                  Expanded(
                    child: InkWell(
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

                        child: Center(
                          child: Text(
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

          // -----------------------------------------------------------------
          // REFRESH
          // -----------------------------------------------------------------

          IconButton(
            tooltip:
            'Refresh checkpoints',

            onPressed:
            _controller.isLoading
                ? null
                : _controller.reload,

            icon:
            _controller.isLoading
                ? const SizedBox(
              width: 22,
              height: 22,

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

  // ===========================================================================
  // CHECKPOINT COUNT
  // ===========================================================================

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

      child: Row(
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
            child: Text(
              _controller.isLoading
                  ? 'Finding checkpoints near you...'
                  : '${_controller.nearbyDestinations.length} '
                  'checkpoints available',

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

  // ===========================================================================
  // MAP SECTION
  // ===========================================================================

  Widget _buildMapSection() {
    final double? latitude =
        _controller.currentLatitude;

    final double? longitude =
        _controller.currentLongitude;

    // -------------------------------------------------------------------------
    // INITIAL LOADING
    // -------------------------------------------------------------------------

    if (_controller.isLoading &&
        latitude == null &&
        longitude == null) {
      return const Center(
        child: Column(
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

    // -------------------------------------------------------------------------
    // ERROR
    // -------------------------------------------------------------------------

    if (_controller.errorMessage != null &&
        latitude == null &&
        longitude == null) {
      return Center(
        child: Padding(
          padding:
          const EdgeInsets.all(24),

          child: Column(
            mainAxisSize:
            MainAxisSize.min,

            children: [
              const Icon(
                Icons.location_off_outlined,

                size: 58,

                color:
                Color(
                  0xFF94A3B8,
                ),
              ),

              const SizedBox(height: 14),

              Text(
                _controller.errorMessage!,

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
                _controller.reload,

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

    final LatLng initialTarget =
    latitude != null &&
        longitude != null
        ? LatLng(
      latitude,
      longitude,
    )
        : fallbackLocation;

    return Stack(
      children: [
        // ---------------------------------------------------------------------
        // GOOGLE MAP
        // ---------------------------------------------------------------------

        GoogleMap(
          initialCameraPosition: CameraPosition(
            target: initialTarget,
            zoom: 12.5,
          ),

          markers: _buildMarkers(),
          circles: _buildCircles(),

          myLocationEnabled:
          latitude != null &&
              longitude != null,

          myLocationButtonEnabled: false,
          zoomControlsEnabled: false,
          mapToolbarEnabled: false,
          compassEnabled: true,

          padding: EdgeInsets.only(
            top: 65,

            bottom:
            _controller.selectedDestination != null
                ? 300
                : 50,
          ),

          onMapCreated:
              (GoogleMapController controller) {
            _mapController = controller;

            // Opened from Blind Box History.
            if (widget.initialDestinationId != null) {
              _focusInitialDestination();
            }

            // Normal Missions page.
            else {
              _moveToUser();
            }
          },
        ),

        // ---------------------------------------------------------------------
        // LEGEND
        // ---------------------------------------------------------------------

        Positioned(
          top: 10,
          left: 12,
          right: 12,

          child:
          _buildLegend(),
        ),

        // ---------------------------------------------------------------------
        // CURRENT LOCATION BUTTON
        // ---------------------------------------------------------------------

        Positioned(
          top: 64,
          right: 14,

          child: Material(
            color:
            Colors.white,

            elevation: 5,

            shape:
            const CircleBorder(),

            child: InkWell(
              customBorder:
              const CircleBorder(),

              onTap:
              _moveToUser,

              child:
              const SizedBox(
                width: 52,
                height: 52,

                child: Icon(
                  Icons
                      .my_location_rounded,

                  color:
                  skyBlue,

                  size: 27,
                ),
              ),
            ),
          ),
        ),

        // ---------------------------------------------------------------------
        // NO CHECKPOINTS
        // ---------------------------------------------------------------------

        if (!_controller.isLoading &&
            _controller
                .nearbyDestinations
                .isEmpty)
          Positioned(
            left: 20,
            right: 20,
            bottom: 70,

            child: Container(
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
                    Icons
                        .location_off_outlined,

                    color:
                    greyText,

                    size: 32,
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

        // ---------------------------------------------------------------------
        // SELECTED DESTINATION
        // ---------------------------------------------------------------------

        if (_controller.selectedDestination !=
            null)
          Positioned(
            left: 14,
            right: 14,
            bottom: 42,

            child:
            _buildSelectedDestinationCard(
              _controller
                  .selectedDestination!,
            ),
          ),
      ],
    );
  }

  // ===========================================================================
  // LEGEND
  // ===========================================================================

  Widget _buildLegend() {
    return Container(
      padding:
      const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 9,
      ),

      decoration:
      BoxDecoration(
        color:
        Colors.white.withValues(
          alpha: 0.96,
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

      child: const Wrap(
        alignment: WrapAlignment.center,

        spacing: 14,

        runSpacing: 5,

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

  // ===========================================================================
  // SELECTED DESTINATION CARD
  // ===========================================================================

  Widget _buildSelectedDestinationCard(
      CheckpointDestination destination,
      ) {
    final bool completed =
    _controller.isCompleted(
      destination,
    );

    final double distanceKm =
    _controller.distanceKm(
      destination,
    );

    final int reward =
    _controller.rewardPoints(
      destination,
    );

    final String sourceLabel =
    _controller.sourceLabel(
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

      decoration: BoxDecoration(
        color: Colors.white,

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

        boxShadow: const [
          BoxShadow(
            color: Color(0x260F172A),

            blurRadius:
            22,

            offset: Offset(0, 8),
          ),
        ],
      ),

      child: Column(
        mainAxisSize:
        MainAxisSize.min,

        crossAxisAlignment: CrossAxisAlignment.start,

        children: [
          // -----------------------------------------------------------------
          // NAME + REWARD
          // -----------------------------------------------------------------

          Row(
            crossAxisAlignment: CrossAxisAlignment.start,

            children: [
              Container(
                width: 42,
                height: 42,

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

                child: Icon(
                  Icons
                      .location_on_rounded,

                  color:
                  sourceColor,

                  size: 24,
                ),
              ),

              const SizedBox(width: 12),

              Expanded(
                child: Column(
                  crossAxisAlignment:
                  CrossAxisAlignment.start,

                  children: [
                    Text(
                      destination.name,

                      maxLines: 2,

                      overflow:
                      TextOverflow
                          .ellipsis,

                      style:
                      const TextStyle(
                        color:
                        darkText,

                        fontSize:
                        17,

                        fontWeight: FontWeight.w900,
                      ),
                    ),

                    const SizedBox(
                      height: 4,
                    ),

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
                const EdgeInsets
                    .symmetric(
                  horizontal: 10,
                  vertical: 6,
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

                child: Text(
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

          // -----------------------------------------------------------------
          // STATUS
          // -----------------------------------------------------------------

          Row(
            children: [
              Icon(
                completed
                    ? Icons
                    .check_circle_rounded
                    : Icons
                    .outlined_flag_rounded,

                size: 17,

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

                  fontSize: 12,

                  fontWeight:
                  FontWeight.w800,
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),

          // -----------------------------------------------------------------
          // DESCRIPTION
          // -----------------------------------------------------------------

          Text(
            description,

            maxLines: 3,

            overflow: TextOverflow.ellipsis,

            style:
            const TextStyle(
              color:
              greyText,

              fontSize:
              12.5,

              height: 1.45,
            ),
          ),

          const SizedBox(height: 15),

          // -----------------------------------------------------------------
          // ACTIONS
          // -----------------------------------------------------------------

          Row(
            children: [
              // -------------------------------------------------------------
              // VIEW MISSION
              // -------------------------------------------------------------

              Expanded(
                child: SizedBox(
                  height: 52,

                  child:
                  FilledButton.icon(
                    onPressed: () {
                      _openMission(
                        destination,
                      );
                    },

                    style:
                    FilledButton
                        .styleFrom(
                      backgroundColor:
                      skyBlue,

                      disabledBackgroundColor: const Color(0xFFCBD5E1),

                      shape:
                      RoundedRectangleBorder(
                        borderRadius:
                        BorderRadius
                            .circular(
                          28,
                        ),
                      ),
                    ),

                    icon:
                    const Icon(
                      Icons
                          .visibility_outlined,

                      size: 19,
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

              // -------------------------------------------------------------
              // VIEW PUZZLE
              // -------------------------------------------------------------

              Expanded(
                child: SizedBox(
                  height: 52,

                  child:
                  OutlinedButton.icon(
                    onPressed: () {
                      _openPuzzle(
                        destination,
                      );
                    },

                    style:
                    OutlinedButton
                        .styleFrom(
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
                        BorderRadius
                            .circular(
                          28,
                        ),
                      ),
                    ),

                    icon:
                    const Icon(
                      Icons
                          .extension_rounded,

                      size: 19,
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

  // ===========================================================================
  // BOTTOM BAR
  // ===========================================================================

  Widget _buildBottomBar() {
    return BottomAppBar(
      height: 78,

      padding:
      EdgeInsets.zero,

      color:
      Colors.white.withValues(
        alpha: 0.98,
      ),

      elevation: 18,

      shadowColor:
      const Color(
        0x330284C7,
      ),

      shape:
      const CircularNotchedRectangle(),

      notchMargin: 8,

      child: SafeArea(
        top: false,

        child: Row(
          children: [
            Expanded(
              child: _BottomItem(
                icon:
                Icons
                    .inventory_2_outlined,

                label:
                'BLIND BOX',

                active:
                false,

                onTap:
                _openBlindBox,
              ),
            ),

            Expanded(
              child: _BottomItem(
                icon:
                Icons
                    .assignment_outlined,

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
              child: _BottomItem(
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
              child: _BottomItem(
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

  // ===========================================================================
  // HOME BUTTON
  // ===========================================================================

  Widget _buildHomeButton() {
    return Padding(
      padding: const EdgeInsets.only(
        top: 10,
      ),
      child: InkWell(
        customBorder: const CircleBorder(),

        onTap: _openHome,

        child: Container(
          width: 62,
          height: 62,

          decoration: BoxDecoration(
            shape: BoxShape.circle,

            gradient: const LinearGradient(
              colors: [
                skyBlue,
                teal,
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),

            border: Border.all(
              color: Colors.white,
              width: 4,
            ),

            boxShadow: const [
              BoxShadow(
                color: Color(0x3D0284C7),
                blurRadius: 16,
                offset: Offset(
                  0,
                  7,
                ),
              ),
            ],
          ),

          child: const Column(
            mainAxisAlignment:
            MainAxisAlignment.center,

            children: [
              Icon(
                Icons.home_rounded,
                color: Color(
                  0xFFFDE68A,
                ),
                size: 27,
              ),

              Text(
                'HOME',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 8,
                  fontWeight:
                  FontWeight.w900,
                  letterSpacing: 0.8,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// MYSTERYLANE LOGO
// =============================================================================

class _MysteryLaneLogo
    extends StatelessWidget {
  const _MysteryLaneLogo();

  @override
  Widget build(
      BuildContext context,
      ) {
    return Container(
      width: 38,
      height: 38,

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

// =============================================================================
// TOP ACTION BUTTON
// =============================================================================

class _TopActionButton
    extends StatelessWidget {
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

      child: InkWell(
        borderRadius:
        BorderRadius.circular(
          99,
        ),

        onTap:
        onTap,

        child: Container(
          width: 38,
          height: 38,

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

          child: Icon(
            icon,

            color:
            foreground,

            size: 20,
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// PROFILE BUTTON
// =============================================================================

class _ProfileButton
    extends StatelessWidget {
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
        ? NetworkImage(
      cleanUrl,
    )
        : null;

    return Tooltip(
      message:
      'Profile',

      child: InkWell(
        customBorder:
        const CircleBorder(),

        onTap:
        onTap,

        child: Container(
          width: 38,
          height: 38,

          padding:
          const EdgeInsets.all(3),

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

              width: 1.4,
            ),
          ),

          child: CircleAvatar(
            backgroundColor:
            const Color(
              0xFFE0F2FE,
            ),

            backgroundImage:
            provider,

            child:
            provider == null
                ? const Icon(
              Icons
                  .person_rounded,

              size: 20,

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

// =============================================================================
// LEGEND ITEM
// =============================================================================

class _LegendItem
    extends StatelessWidget {
  final Color color;
  final String label;

  const _LegendItem({
    required this.color,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize:
      MainAxisSize.min,

      children: [
        Container(
          width: 8,
          height: 8,

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

            fontSize: 10,

            fontWeight:
            FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

// =============================================================================
// BOTTOM ITEM
// =============================================================================

class _BottomItem
    extends StatelessWidget {
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
      onTap: onTap,

      child: Padding(
        padding:
        const EdgeInsets.only(
          top: 10,
          bottom: 4,
        ),

        child: Column(
          mainAxisAlignment:
          MainAxisAlignment.center,

          children: [
            AnimatedContainer(
              duration:
              const Duration(
                milliseconds:
                160,
              ),

              width: 42,
              height: 29,

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

              child: Icon(
                icon,

                size: 21,

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

                fontSize: 8,

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