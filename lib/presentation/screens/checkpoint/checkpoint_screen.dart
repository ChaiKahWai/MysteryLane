import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../../data/models/checkpoint_destination.dart';
import '../../../data/models/checkpoint_mission.dart';
import '../../../data/datasources/supabase_datasource.dart';
import '../../../data/repositories/checkpoint_repository.dart';

import '../Blindbox/BlindBox_Screen.dart';
import '../home/home_screen.dart';
import '../puzzle/puzzle_screen.dart';

import 'checkpoint_mission_screen.dart';

class CheckpointScreen extends StatefulWidget {
  /// ============================================================
  /// PUZZLE HANDOFF
  ///
  /// Checkpoint module only passes the selected destination.
  ///
  /// Puzzle teammate can later receive:
  /// - destination.destinationId
  /// - destination.name
  /// - destination.latitude
  /// - destination.longitude
  /// - destination.address
  ///
  /// No puzzle logic is implemented here.
  /// ============================================================
  final ValueChanged<CheckpointDestination>? onOpenPuzzle;

  const CheckpointScreen({
    super.key,
    this.onOpenPuzzle,
  });

  @override
  State<CheckpointScreen> createState() =>
      _CheckpointScreenState();
}

class _CheckpointScreenState extends State<CheckpointScreen> {
  final SupabaseDataSource _supabaseDataSource = SupabaseDataSource();
  // ============================================================
  // CONSTANTS
  // ============================================================

  static const double _maximumDistanceMeters = 5000;

  static const Color _primaryBlue = Color(0xFF0284C7);
  static const Color _teal = Color(0xFF0D9488);
  static const Color _darkText = Color(0xFF0F172A);
  static const Color _greyText = Color(0xFF64748B);
  static const Color _pageBackground = Color(0xFFF8FAFC);
  static const Color _purple = Color(0xFF7C3AED);

  // ============================================================
  // REPOSITORY
  // ============================================================

  final CheckpointRepository _repository =
  CheckpointRepository();

  // ============================================================
  // MAP
  // ============================================================

  GoogleMapController? _mapController;

  Position? _currentPosition;

  // ============================================================
  // DESTINATIONS
  // ============================================================

  List<CheckpointDestination> _allDestinations = [];

  List<CheckpointDestination> _nearbyDestinations = [];

  Set<String> _completedDestinationIds = {};

  // ============================================================
  // SELECTED CHECKPOINT
  // ============================================================

  CheckpointDestination? _selectedDestination;

  CheckpointMission? _selectedMission;

  // ============================================================
  // PAGE STATE
  // ============================================================

  bool _isLoading = true;

  bool _isLoadingMission = false;

  String? _errorMessage;

  // ============================================================
  // INIT
  // ============================================================

  @override
  void initState() {
    super.initState();

    _loadCheckpointData();
  }

  // ============================================================
  // LOAD CHECKPOINT DATA
  // ============================================================

  Future<void> _loadCheckpointData({
    String? keepSelectedDestinationId,
  }) async {
    if (!mounted) {
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // --------------------------------------------------------
      // 1. GET CURRENT GPS
      // --------------------------------------------------------

      final Position position =
      await _getCurrentLocation();

      // --------------------------------------------------------
      // 2. GET DESTINATIONS
      // --------------------------------------------------------

      final List<CheckpointDestination> destinations =
      await _repository.getHiddenGemDestinations();

      // --------------------------------------------------------
      // 3. GET COMPLETED DESTINATIONS
      // --------------------------------------------------------

      final completedIds =
      await _repository.getCompletedDestinationIds();

      // --------------------------------------------------------
      // 4. FILTER WITHIN 5 KM
      // --------------------------------------------------------

      final List<CheckpointDestination> nearby =
      destinations.where(
            (CheckpointDestination destination) {
          final double distance =
          Geolocator.distanceBetween(
            position.latitude,
            position.longitude,
            destination.latitude,
            destination.longitude,
          );

          return distance <=
              _maximumDistanceMeters;
        },
      ).toList();

      // --------------------------------------------------------
      // 5. SORT NEAREST FIRST
      // --------------------------------------------------------

      nearby.sort(
            (
            CheckpointDestination a,
            CheckpointDestination b,
            ) {
          final double distanceA =
          Geolocator.distanceBetween(
            position.latitude,
            position.longitude,
            a.latitude,
            a.longitude,
          );

          final double distanceB =
          Geolocator.distanceBetween(
            position.latitude,
            position.longitude,
            b.latitude,
            b.longitude,
          );

          return distanceA.compareTo(
            distanceB,
          );
        },
      );

      if (!mounted) {
        return;
      }

      // --------------------------------------------------------
      // 6. KEEP CURRENT SELECTED PIN AFTER REFRESH
      // --------------------------------------------------------

      CheckpointDestination? selected;

      final String? selectedId =
          keepSelectedDestinationId ??
              _selectedDestination?.destinationId;

      if (selectedId != null) {
        for (final destination in nearby) {
          if (destination.destinationId ==
              selectedId) {
            selected = destination;
            break;
          }
        }
      }

      // If nothing selected yet, automatically select nearest.
      if (selected == null &&
          nearby.isNotEmpty) {
        selected = nearby.first;
      }

      setState(() {
        _currentPosition = position;

        _allDestinations =
            destinations;

        _nearbyDestinations =
            nearby;

        _completedDestinationIds =
        Set<String>.from(
          completedIds,
        );

        _selectedDestination =
            selected;

        _isLoading = false;
      });

      // --------------------------------------------------------
      // 7. LOAD SELECTED MISSION
      // --------------------------------------------------------

      if (selected != null) {
        await _loadMissionForDestination(
          selected,
        );
      }

      // --------------------------------------------------------
      // DEBUG
      // --------------------------------------------------------

      debugPrint(
        'CHECKPOINTS TOTAL: '
            '${_allDestinations.length}',
      );

      debugPrint(
        'CHECKPOINTS WITHIN 5KM: '
            '${_nearbyDestinations.length}',
      );
    } catch (error) {
      debugPrint(
        'CHECKPOINT LOAD ERROR: $error',
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _errorMessage =
            error.toString();

        _isLoading = false;
      });
    }
  }

  // ============================================================
  // LOCATION
  // ============================================================

  Future<Position> _getCurrentLocation() async {
    final bool serviceEnabled =
    await Geolocator
        .isLocationServiceEnabled();

    if (!serviceEnabled) {
      throw Exception(
        'Location services are disabled. '
            'Please enable GPS and try again.',
      );
    }

    LocationPermission permission =
    await Geolocator.checkPermission();

    if (permission ==
        LocationPermission.denied) {
      permission =
      await Geolocator
          .requestPermission();
    }

    if (permission ==
        LocationPermission.denied) {
      throw Exception(
        'Location permission is required '
            'to find nearby checkpoints.',
      );
    }

    if (permission ==
        LocationPermission.deniedForever) {
      throw Exception(
        'Location permission is permanently denied. '
            'Please enable it in device settings.',
      );
    }

    return Geolocator
        .getCurrentPosition(
      desiredAccuracy:
      LocationAccuracy.high,
    );
  }

  // ============================================================
  // SELECT PIN
  // ============================================================

  Future<void> _selectDestination(
      CheckpointDestination destination,
      ) async {
    if (!mounted) {
      return;
    }

    setState(() {
      _selectedDestination =
          destination;

      _selectedMission =
      null;
    });

    await _loadMissionForDestination(
      destination,
    );

    // Move camera slightly to selected pin.
    await _mapController
        ?.animateCamera(
      CameraUpdate.newLatLng(
        LatLng(
          destination.latitude,
          destination.longitude,
        ),
      ),
    );
  }

  // ============================================================
  // LOAD SELECTED MISSION
  // ============================================================

  Future<void> _loadMissionForDestination(
      CheckpointDestination destination,
      ) async {
    if (!mounted) {
      return;
    }

    setState(() {
      _isLoadingMission = true;
    });

    try {
      final CheckpointMission? mission =
      await _repository
          .getMissionByDestinationId(
        destination.destinationId,
      );

      if (!mounted) {
        return;
      }

      // Only update if user still has same pin selected.
      if (_selectedDestination
          ?.destinationId !=
          destination.destinationId) {
        return;
      }

      setState(() {
        _selectedMission =
            mission;

        _isLoadingMission =
        false;
      });
    } catch (error) {
      debugPrint(
        'LOAD CHECKPOINT MISSION ERROR: '
            '$error',
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _selectedMission =
        null;

        _isLoadingMission =
        false;
      });
    }
  }

  // ============================================================
  // DISTANCE
  // ============================================================

  double _distanceMeters(
      CheckpointDestination destination,
      ) {
    final Position? current =
        _currentPosition;

    if (current == null) {
      return 0;
    }

    return Geolocator.distanceBetween(
      current.latitude,
      current.longitude,
      destination.latitude,
      destination.longitude,
    );
  }

  String _distanceText(
      CheckpointDestination destination,
      ) {
    final double metres =
    _distanceMeters(
      destination,
    );

    if (metres < 1000) {
      return '${metres.toStringAsFixed(0)} m away';
    }

    return '${(metres / 1000).toStringAsFixed(2)} km away';
  }

  // ============================================================
  // COMPLETED
  // ============================================================

  bool _isCompleted(
      CheckpointDestination destination,
      ) {
    return _completedDestinationIds
        .contains(
      destination.destinationId,
    );
  }

  // ============================================================
  // POPULAR
  // ============================================================

  bool _isPopular(
      CheckpointDestination destination,
      ) {
    return destination
        .popularityClassification
        ?.toUpperCase() ==
        'POPULAR';
  }

  // ============================================================
  // CLASSIFICATION TEXT
  // ============================================================

  String _classificationText(
      CheckpointDestination destination,
      ) {
    if (_isPopular(destination)) {
      return 'POPULAR';
    }

    return 'HIDDEN GEM';
  }

  // ============================================================
  // MARKER COLOUR
  // ============================================================

  double _markerHue(
      CheckpointDestination destination,
      ) {
    if (_isCompleted(destination)) {
      return BitmapDescriptor.hueGreen;
    }

    if (_isPopular(destination)) {
      return BitmapDescriptor.hueOrange;
    }

    return BitmapDescriptor.hueAzure;
  }

  // ============================================================
  // MARKERS
  // ============================================================

  Set<Marker> _buildMarkers() {
    return _nearbyDestinations.map(
          (
          CheckpointDestination destination,
          ) {
        return Marker(
          markerId:
          MarkerId(
            destination.destinationId,
          ),

          position:
          LatLng(
            destination.latitude,
            destination.longitude,
          ),

          icon:
          BitmapDescriptor
              .defaultMarkerWithHue(
            _markerHue(
              destination,
            ),
          ),

          infoWindow:
          InfoWindow(
            title:
            destination.name,

            snippet:
            _distanceText(
              destination,
            ),
          ),

          onTap:
              () {
            _selectDestination(
              destination,
            );
          },
        );
      },
    ).toSet();
  }

  // ============================================================
  // 5 KM CIRCLE
  // ============================================================

  Set<Circle> _buildCircles() {
    final Position? current =
        _currentPosition;

    if (current == null) {
      return {};
    }

    return {
      Circle(
        circleId:
        const CircleId(
          'checkpoint_5km_radius',
        ),

        center:
        LatLng(
          current.latitude,
          current.longitude,
        ),

        radius:
        _maximumDistanceMeters,

        fillColor:
        _primaryBlue
            .withOpacity(
          0.05,
        ),

        strokeColor:
        _primaryBlue
            .withOpacity(
          0.35,
        ),

        strokeWidth:
        2,
      ),
    };
  }

  // ============================================================
  // OPEN MISSION
  // ============================================================

  Future<void> _openMission(
      CheckpointDestination destination,
      ) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            CheckpointMissionScreen(
              destination:
              destination,
            ),
      ),
    );

    if (!mounted) {
      return;
    }

    // Reload status after coming back.
    await _loadCheckpointData(
      keepSelectedDestinationId:
      destination.destinationId,
    );
  }

  // ============================================================
  // OPEN PUZZLE
  //
  // IMPORTANT:
  // THIS IS THE ONLY PUZZLE CONNECTION INSIDE YOUR MODULE.
  // ============================================================

  Future<void> _openPuzzle(
      CheckpointDestination destination,
      ) async {
    // ----------------------------------------------------------
    // DEBUG SO YOU CAN CONFIRM CORRECT LOCATION IS PASSED
    // ----------------------------------------------------------

    debugPrint(
      '======================================',
    );

    debugPrint(
      'PUZZLE LOCATION SELECTED',
    );

    debugPrint(
      'Destination ID: '
          '${destination.destinationId}',
    );

    debugPrint(
      'Name: '
          '${destination.name}',
    );

    debugPrint(
      'Latitude: '
          '${destination.latitude}',
    );

    debugPrint(
      'Longitude: '
          '${destination.longitude}',
    );

    debugPrint(
      'Address: '
          '${destination.address}',
    );

    debugPrint(
      '======================================',
    );

    // ----------------------------------------------------------
    // IF PUZZLE TEAMMATE CONNECTS CALLBACK
    // ----------------------------------------------------------

    if (widget.onOpenPuzzle != null) {
      widget.onOpenPuzzle!(
        destination,
      );

      return;
    }

    try {
      await _supabaseDataSource.savePuzzleLocation(
        destinationId: destination.destinationId,
        locationSource: 'CHECKPOINT',
      );
    } catch (error) {
      debugPrint('SAVE CHECKPOINT PUZZLE LOCATION ERROR: $error');
      if (mounted) {
        _showMessage('Unable to save this puzzle location. Please try again.');
      }
      return;
    }

    if (!mounted) return;

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PuzzleScreen(
          initialLocationSource: PuzzleLocationSource.checkpoint,
          mission: MissionCheckpoint(
            id: destination.destinationId,
            title: destination.name,
            imageUrl: destination.imageUrl,
            locationName: destination.address,
            category: destination.category ?? 'Checkpoint',
          ),
        ),
      ),
    );
  }

  // ============================================================
  // TEMP PUZZLE LOCATION PREVIEW
  // ============================================================

  void _showPuzzleLocationReady(
      CheckpointDestination destination,
      ) {
    showModalBottomSheet<void>(
      context:
      context,

      backgroundColor:
      Colors.transparent,

      isScrollControlled:
      true,

      builder:
          (
          BuildContext context,
          ) {
        return SafeArea(
          child:
          Container(
            margin:
            const EdgeInsets.all(
              14,
            ),

            padding:
            const EdgeInsets.all(
              22,
            ),

            decoration:
            BoxDecoration(
              color:
              Colors.white,

              borderRadius:
              BorderRadius.circular(
                26,
              ),
            ),

            child:
            Column(
              mainAxisSize:
              MainAxisSize.min,

              crossAxisAlignment:
              CrossAxisAlignment.start,

              children: [
                Center(
                  child:
                  Container(
                    width:
                    42,

                    height:
                    5,

                    decoration:
                    BoxDecoration(
                      color:
                      const Color(
                        0xFFCBD5E1,
                      ),

                      borderRadius:
                      BorderRadius.circular(
                        99,
                      ),
                    ),
                  ),
                ),

                const SizedBox(
                  height:
                  20,
                ),

                Row(
                  children: [
                    Container(
                      width:
                      48,

                      height:
                      48,

                      decoration:
                      BoxDecoration(
                        color:
                        const Color(
                          0xFFF5F3FF,
                        ),

                        borderRadius:
                        BorderRadius.circular(
                          14,
                        ),
                      ),

                      child:
                      const Icon(
                        Icons
                            .extension_rounded,

                        color:
                        _purple,
                      ),
                    ),

                    const SizedBox(
                      width:
                      12,
                    ),

                    const Expanded(
                      child:
                      Column(
                        crossAxisAlignment:
                        CrossAxisAlignment.start,

                        children: [
                          Text(
                            'Puzzle Location Ready',
                            style:
                            TextStyle(
                              color:
                              _darkText,
                              fontSize:
                              17,
                              fontWeight:
                              FontWeight.w800,
                            ),
                          ),

                          SizedBox(
                            height:
                            3,
                          ),

                          Text(
                            'Selected checkpoint data is ready for Puzzle module.',
                            style:
                            TextStyle(
                              color:
                              _greyText,
                              fontSize:
                              11,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(
                  height:
                  20,
                ),

                _PuzzleLocationRow(
                  label:
                  'Destination',

                  value:
                  destination.name,
                ),

                const SizedBox(
                  height:
                  10,
                ),

                _PuzzleLocationRow(
                  label:
                  'Destination ID',

                  value:
                  destination.destinationId,
                ),

                const SizedBox(
                  height:
                  10,
                ),

                _PuzzleLocationRow(
                  label:
                  'Latitude',

                  value:
                  destination.latitude
                      .toStringAsFixed(
                    6,
                  ),
                ),

                const SizedBox(
                  height:
                  10,
                ),

                _PuzzleLocationRow(
                  label:
                  'Longitude',

                  value:
                  destination.longitude
                      .toStringAsFixed(
                    6,
                  ),
                ),

                if (destination.address !=
                    null &&
                    destination.address!
                        .trim()
                        .isNotEmpty) ...[
                  const SizedBox(
                    height:
                    10,
                  ),

                  _PuzzleLocationRow(
                    label:
                    'Address',

                    value:
                    destination.address!,
                  ),
                ],

                const SizedBox(
                  height:
                  20,
                ),

                Container(
                  width:
                  double.infinity,

                  padding:
                  const EdgeInsets.all(
                    14,
                  ),

                  decoration:
                  BoxDecoration(
                    color:
                    const Color(
                      0xFFF5F3FF,
                    ),

                    borderRadius:
                    BorderRadius.circular(
                      14,
                    ),
                  ),

                  child:
                  const Text(
                    'Your teammate only needs this CheckpointDestination object. '
                        'The Puzzle module can use destinationId to retrieve puzzles '
                        'for this selected location.',
                    style:
                    TextStyle(
                      color:
                      Color(
                        0xFF5B21B6,
                      ),

                      fontSize:
                      12,

                      height:
                      1.45,
                    ),
                  ),
                ),

                const SizedBox(
                  height:
                  18,
                ),

                SizedBox(
                  width:
                  double.infinity,

                  child:
                  ElevatedButton(
                    onPressed:
                        () {
                      Navigator.pop(
                        context,
                      );
                    },

                    style:
                    ElevatedButton
                        .styleFrom(
                      backgroundColor:
                      _purple,

                      foregroundColor:
                      Colors.white,

                      padding:
                      const EdgeInsets.symmetric(
                        vertical:
                        14,
                      ),

                      shape:
                      RoundedRectangleBorder(
                        borderRadius:
                        BorderRadius.circular(
                          20,
                        ),
                      ),
                    ),

                    child:
                    const Text(
                      'OK',
                      style:
                      TextStyle(
                        fontWeight:
                        FontWeight.w800,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ============================================================
  // FOCUS CURRENT LOCATION
  // ============================================================

  Future<void> _focusCurrentLocation() async {
    final Position? current =
        _currentPosition;

    if (current == null) {
      return;
    }

    await _mapController
        ?.animateCamera(
      CameraUpdate.newLatLngZoom(
        LatLng(
          current.latitude,
          current.longitude,
        ),
        14,
      ),
    );
  }

  // ============================================================
  // MESSAGE
  // ============================================================

  void _showMessage(
      String message,
      ) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior:
          SnackBarBehavior.floating,

          margin:
          const EdgeInsets.fromLTRB(
            18,
            0,
            18,
            85,
          ),

          content:
          Text(
            message,
          ),
        ),
      );
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(
      BuildContext context,
      ) {
    return Scaffold(
      backgroundColor:
      _pageBackground,

      extendBody:
      true,

      // ========================================================
      // PAGE
      // ========================================================

      body:
      SafeArea(
        bottom:
        false,

        child:
        Column(
          children: [
            _buildHeader(),

            Expanded(
              child:
              _buildMainContent(),
            ),
          ],
        ),
      ),

      // ========================================================
      // HOME BUTTON
      // ========================================================

      floatingActionButtonLocation:
      FloatingActionButtonLocation
          .centerDocked,

      floatingActionButton:
      _buildHomeButton(),

      // ========================================================
      // BOTTOM NAV
      // ========================================================

      bottomNavigationBar:
      _buildBottomNavigation(),
    );
  }

  // ============================================================
  // HEADER
  // ============================================================

  Widget _buildHeader() {
    return Container(
      color:
      Colors.white,

      padding:
      const EdgeInsets.fromLTRB(
        12,
        10,
        12,
        8,
      ),

      child:
      Column(
        children: [
          Row(
            children: [
              // ------------------------------------------------
              // BACK
              // ------------------------------------------------

              InkWell(
                customBorder:
                const CircleBorder(),

                onTap:
                    () {
                  Navigator.maybePop(
                    context,
                  );
                },

                child:
                Container(
                  width:
                  40,

                  height:
                  40,

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
                        0xFFE2E8F0,
                      ),
                    ),
                  ),

                  child:
                  const Icon(
                    Icons
                        .arrow_back_ios_new_rounded,

                    size:
                    17,

                    color:
                    _darkText,
                  ),
                ),
              ),

              const SizedBox(
                width:
                10,
              ),

              // ------------------------------------------------
              // CHECKPOINT / PUZZLE OPTIONS
              // ------------------------------------------------

              Expanded(
                child:
                Container(
                  height:
                  40,

                  padding:
                  const EdgeInsets.all(
                    3,
                  ),

                  decoration:
                  BoxDecoration(
                    color:
                    const Color(
                      0xFFF0F9FF,
                    ),

                    borderRadius:
                    BorderRadius.circular(
                      22,
                    ),

                    border:
                    Border.all(
                      color:
                      const Color(
                        0xFFBAE6FD,
                      ),
                    ),
                  ),

                  child:
                  Row(
                    children: [
                      // CHECKPOINT
                      Expanded(
                        child:
                        Container(
                          alignment:
                          Alignment.center,

                          decoration:
                          BoxDecoration(
                            color:
                            _primaryBlue,

                            borderRadius:
                            BorderRadius.circular(
                              18,
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
                              10,

                              fontWeight:
                              FontWeight.w800,
                            ),
                          ),
                        ),
                      ),

                      // PUZZLE
                      Expanded(
                        child:
                        InkWell(
                          borderRadius:
                          BorderRadius.circular(
                            18,
                          ),

                          onTap:
                              () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => const PuzzleScreen(),
                              ),
                            );
                          },

                          child:
                          const Center(
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
                                9,

                                fontWeight:
                                FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(
                width:
                10,
              ),

              // ------------------------------------------------
              // REFRESH
              // ------------------------------------------------

              IconButton(
                onPressed:
                    () {
                  _loadCheckpointData();
                },

                icon:
                const Icon(
                  Icons.refresh_rounded,

                  color:
                  _primaryBlue,
                ),
              ),
            ],
          ),

          const SizedBox(
            height:
            8,
          ),

          Row(
            children: [
              const Icon(
                Icons
                    .explore_outlined,

                size:
                15,

                color:
                _primaryBlue,
              ),

              const SizedBox(
                width:
                6,
              ),

              Expanded(
                child:
                Text(
                  '${_nearbyDestinations.length} checkpoints available within 5 km of your location',

                  style:
                  const TextStyle(
                    color:
                    _greyText,

                    fontSize:
                    11,

                    fontWeight:
                    FontWeight.w500,
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
  // MAIN
  // ============================================================

  Widget _buildMainContent() {
    if (_isLoading) {
      return const Center(
        child:
        Column(
          mainAxisSize:
          MainAxisSize.min,

          children: [
            CircularProgressIndicator(
              color:
              _primaryBlue,
            ),

            SizedBox(
              height:
              14,
            ),

            Text(
              'Finding checkpoints near you...',
              style:
              TextStyle(
                color:
                _greyText,
              ),
            ),
          ],
        ),
      );
    }

    if (_errorMessage != null) {
      return _buildErrorState();
    }

    return _buildMap();
  }

  // ============================================================
  // MAP
  // ============================================================

  Widget _buildMap() {
    final Position? current =
        _currentPosition;

    final LatLng initialPosition =
    current != null
        ? LatLng(
      current.latitude,
      current.longitude,
    )
        : const LatLng(
      3.1390,
      101.6869,
    );

    return Padding(
      padding:
      const EdgeInsets.fromLTRB(
        8,
        0,
        8,
        76,
      ),

      child:
      ClipRRect(
        borderRadius:
        BorderRadius.circular(
          24,
        ),

        child:
        Stack(
          children: [
            // ==================================================
            // GOOGLE MAP
            // ==================================================

            Positioned.fill(
              child:
              GoogleMap(
                initialCameraPosition:
                CameraPosition(
                  target:
                  initialPosition,

                  zoom:
                  13.5,
                ),

                markers:
                _buildMarkers(),

                circles:
                _buildCircles(),

                myLocationEnabled:
                current != null,

                myLocationButtonEnabled:
                false,

                zoomControlsEnabled:
                false,

                mapToolbarEnabled:
                false,

                compassEnabled:
                true,

                onMapCreated:
                    (
                    GoogleMapController controller,
                    ) {
                  _mapController =
                      controller;
                },
              ),
            ),

            // ==================================================
            // LEGEND
            // ==================================================

            Positioned(
              top:
              8,

              left:
              12,

              right:
              12,

              child:
              _buildLegend(),
            ),

            // ==================================================
            // CURRENT LOCATION
            // ==================================================

            Positioned(
              top:
              72,

              right:
              14,

              child:
              Material(
                color:
                Colors.transparent,

                child:
                InkWell(
                  customBorder:
                  const CircleBorder(),

                  onTap:
                  _focusCurrentLocation,

                  child:
                  Container(
                    width:
                    48,

                    height:
                    48,

                    decoration:
                    const BoxDecoration(
                      color:
                      Colors.white,

                      shape:
                      BoxShape.circle,

                      boxShadow: [
                        BoxShadow(
                          color:
                          Color(
                            0x26000000,
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
                    const Icon(
                      Icons
                          .my_location_rounded,

                      color:
                      _primaryBlue,
                    ),
                  ),
                ),
              ),
            ),

            // ==================================================
            // SELECTED CHECKPOINT CARD
            // ==================================================

            if (_selectedDestination !=
                null)
              Positioned(
                left:
                12,

                right:
                12,

                bottom:
                14,

                child:
                _buildSelectedCheckpointCard(
                  _selectedDestination!,
                ),
              ),
          ],
        ),
      ),
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
        11,

        vertical:
        8,
      ),

      decoration:
      BoxDecoration(
        color:
        Colors.white
            .withOpacity(
          0.95,
        ),

        borderRadius:
        BorderRadius.circular(
          18,
        ),

        boxShadow:
        const [
          BoxShadow(
            color:
            Color(
              0x14000000,
            ),

            blurRadius:
            6,
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
            Color(
              0xFF10B981,
            ),

            text:
            'Completed',
          ),

          _LegendItem(
            color:
            Color(
              0xFFF59E0B,
            ),

            text:
            'Popular',
          ),

          _LegendItem(
            color:
            Color(
              0xFF0284C7,
            ),

            text:
            'Hidden Gem',
          ),

          _LegendItem(
            color:
            Color(
              0xFF38BDF8,
            ),

            text:
            'You (5km)',
          ),
        ],
      ),
    );
  }

  // ============================================================
  // SELECTED CHECKPOINT CARD
  // ============================================================

  Widget _buildSelectedCheckpointCard(
      CheckpointDestination destination,
      ) {
    final bool completed =
    _isCompleted(
      destination,
    );

    final int reward =
        _selectedMission
            ?.rewardPoints ??
            0;

    final String description =
    destination.description
        ?.trim()
        .isNotEmpty ==
        true
        ? destination.description!
        : 'Explore this checkpoint and complete the available activity.';

    return Container(
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
          20,
        ),

        boxShadow:
        const [
          BoxShadow(
            color:
            Color(
              0x260F172A,
            ),

            blurRadius:
            18,

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
          // ====================================================
          // NAME + REWARD
          // ====================================================

          Row(
            crossAxisAlignment:
            CrossAxisAlignment.start,

            children: [
              Container(
                width:
                34,

                height:
                34,

                decoration:
                BoxDecoration(
                  color:
                  completed
                      ? const Color(
                    0xFFECFDF5,
                  )
                      : const Color(
                    0xFFE0F2FE,
                  ),

                  borderRadius:
                  BorderRadius.circular(
                    10,
                  ),
                ),

                child:
                Icon(
                  completed
                      ? Icons
                      .check_circle_rounded
                      : Icons
                      .location_on_rounded,

                  color:
                  completed
                      ? const Color(
                    0xFF10B981,
                  )
                      : _primaryBlue,

                  size:
                  21,
                ),
              ),

              const SizedBox(
                width:
                10,
              ),

              Expanded(
                child:
                Column(
                  crossAxisAlignment:
                  CrossAxisAlignment.start,

                  children: [
                    Text(
                      destination.name,

                      maxLines:
                      1,

                      overflow:
                      TextOverflow.ellipsis,

                      style:
                      const TextStyle(
                        color:
                        _darkText,

                        fontSize:
                        15,

                        fontWeight:
                        FontWeight.w900,
                      ),
                    ),

                    const SizedBox(
                      height:
                      3,
                    ),

                    Text(
                      '${_distanceText(destination)} • ${_classificationText(destination)}',

                      style:
                      const TextStyle(
                        color:
                        _greyText,

                        fontSize:
                        9,

                        fontWeight:
                        FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),

              if (_isLoadingMission)
                const SizedBox(
                  width:
                  20,

                  height:
                  20,

                  child:
                  CircularProgressIndicator(
                    strokeWidth:
                    2,
                  ),
                )
              else
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
                      20,
                    ),
                  ),

                  child:
                  Text(
                    '+$reward',

                    style:
                    const TextStyle(
                      color:
                      _primaryBlue,

                      fontSize:
                      10,

                      fontWeight:
                      FontWeight.w900,
                    ),
                  ),
                ),
            ],
          ),

          const SizedBox(
            height:
            10,
          ),

          // ====================================================
          // STATUS
          // ====================================================

          if (completed)
            const Row(
              children: [
                Icon(
                  Icons
                      .verified_rounded,

                  color:
                  Color(
                    0xFF059669,
                  ),

                  size:
                  15,
                ),

                SizedBox(
                  width:
                  6,
                ),

                Text(
                  'Checkpoint completed',

                  style:
                  TextStyle(
                    color:
                    Color(
                      0xFF047857,
                    ),

                    fontSize:
                    10,

                    fontWeight:
                    FontWeight.w800,
                  ),
                ),
              ],
            )
          else
            const Row(
              children: [
                Icon(
                  Icons
                      .flag_outlined,

                  color:
                  _primaryBlue,

                  size:
                  15,
                ),

                SizedBox(
                  width:
                  6,
                ),

                Text(
                  'Checkpoint available',

                  style:
                  TextStyle(
                    color:
                    _primaryBlue,

                    fontSize:
                    10,

                    fontWeight:
                    FontWeight.w800,
                  ),
                ),
              ],
            ),

          const SizedBox(
            height:
            10,
          ),

          // ====================================================
          // DESCRIPTION
          // ====================================================

          Text(
            description,

            maxLines:
            2,

            overflow:
            TextOverflow.ellipsis,

            style:
            const TextStyle(
              color:
              _greyText,

              fontSize:
              10,

              height:
              1.45,
            ),
          ),

          const SizedBox(
            height:
            14,
          ),

          // ====================================================
          // TWO OPTIONS
          // ====================================================

          Row(
            children: [
              // ------------------------------------------------
              // VIEW MISSION
              // ------------------------------------------------

              Expanded(
                child:
                SizedBox(
                  height:
                  44,

                  child:
                  ElevatedButton.icon(
                    onPressed:
                    _selectedMission ==
                        null &&
                        !_isLoadingMission
                        ? null
                        : () {
                      _openMission(
                        destination,
                      );
                    },

                    icon:
                    const Icon(
                      Icons
                          .visibility_rounded,

                      size:
                      15,
                    ),

                    label:
                    const Text(
                      'VIEW MISSION',
                    ),

                    style:
                    ElevatedButton
                        .styleFrom(
                      backgroundColor:
                      _primaryBlue,

                      foregroundColor:
                      Colors.white,

                      disabledBackgroundColor:
                      const Color(
                        0xFFCBD5E1,
                      ),

                      elevation:
                      0,

                      textStyle:
                      const TextStyle(
                        fontSize:
                        9,

                        fontWeight:
                        FontWeight.w900,
                      ),

                      shape:
                      RoundedRectangleBorder(
                        borderRadius:
                        BorderRadius.circular(
                          25,
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              const SizedBox(
                width:
                8,
              ),

              // ------------------------------------------------
              // VIEW PUZZLE
              // ------------------------------------------------

              Expanded(
                child:
                SizedBox(
                  height:
                  44,

                  child:
                  OutlinedButton.icon(
                    onPressed:
                        () {
                      _openPuzzle(
                        destination,
                      );
                    },

                    icon:
                    const Icon(
                      Icons
                          .extension_rounded,

                      size:
                      15,
                    ),

                    label:
                    const Text(
                      'VIEW PUZZLE',
                    ),

                    style:
                    OutlinedButton
                        .styleFrom(
                      foregroundColor:
                      _purple,

                      side:
                      const BorderSide(
                        color:
                        _purple,

                        width:
                        1.3,
                      ),

                      textStyle:
                      const TextStyle(
                        fontSize:
                        9,

                        fontWeight:
                        FontWeight.w900,
                      ),

                      shape:
                      RoundedRectangleBorder(
                        borderRadius:
                        BorderRadius.circular(
                          25,
                        ),
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
  // ERROR
  // ============================================================

  Widget _buildErrorState() {
    return Center(
      child:
      Padding(
        padding:
        const EdgeInsets.all(
          30,
        ),

        child:
        Column(
          mainAxisSize:
          MainAxisSize.min,

          children: [
            const Icon(
              Icons
                  .location_off_outlined,

              size:
              60,

              color:
              Color(
                0xFF94A3B8,
              ),
            ),

            const SizedBox(
              height:
              15,
            ),

            const Text(
              'Unable to Load Checkpoints',

              textAlign:
              TextAlign.center,

              style:
              TextStyle(
                color:
                _darkText,

                fontSize:
                18,

                fontWeight:
                FontWeight.w800,
              ),
            ),

            const SizedBox(
              height:
              8,
            ),

            Text(
              _errorMessage ??
                  'Unknown error.',

              textAlign:
              TextAlign.center,

              style:
              const TextStyle(
                color:
                _greyText,

                fontSize:
                12,
              ),
            ),

            const SizedBox(
              height:
              18,
            ),

            ElevatedButton.icon(
              onPressed:
                  () {
                _loadCheckpointData();
              },

              icon:
              const Icon(
                Icons.refresh_rounded,
              ),

              label:
              const Text(
                'TRY AGAIN',
              ),

              style:
              ElevatedButton
                  .styleFrom(
                backgroundColor:
                _primaryBlue,

                foregroundColor:
                Colors.white,
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
        top:
        10,
      ),

      child:
      InkWell(
        customBorder:
        const CircleBorder(),

        onTap:
            () {
          Navigator.of(context)
              .pushAndRemoveUntil(
            MaterialPageRoute(
              builder: (_) =>
              const HomeScreen(),
            ),
                (
                route,
                ) =>
            false,
          );
        },

        child:
        Container(
          width:
          64,

          height:
          64,

          decoration:
          BoxDecoration(
            shape:
            BoxShape.circle,

            gradient:
            const LinearGradient(
              colors: [
                _primaryBlue,
                _teal,
              ],
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
                14,

                offset:
                Offset(
                  0,
                  6,
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
                Icons
                    .home_rounded,

                color:
                Color(
                  0xFFFFE66D,
                ),

                size:
                25,
              ),

              Text(
                'HOME',

                style:
                TextStyle(
                  color:
                  Colors.white,

                  fontSize:
                  7,

                  fontWeight:
                  FontWeight.w900,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================
  // BOTTOM NAV
  // ============================================================

  Widget _buildBottomNavigation() {
    return BottomAppBar(
      height:
      72,

      color:
      Colors.white,

      elevation:
      15,

      shape:
      const CircularNotchedRectangle(),

      notchMargin:
      8,

      padding:
      EdgeInsets.zero,

      child:
      Row(
        children: [
          Expanded(
            child:
            _CheckpointBottomItem(
              icon:
              Icons
                  .inventory_2_outlined,

              label:
              'BLIND\nBOX',

              onTap:
                  () {
                Navigator.of(context)
                    .pushReplacement(
                  MaterialPageRoute(
                    builder: (_) =>
                    const BlindBoxPage(),
                  ),
                );
              },
            ),
          ),

          Expanded(
            child:
            _CheckpointBottomItem(
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

          const SizedBox(
            width:
            70,
          ),

          Expanded(
            child:
            _CheckpointBottomItem(
              icon:
              Icons
                  .map_outlined,

              label:
              'PLAN',

              onTap:
                  () {
                _showMessage(
                  'Plan page will be connected later.',
                );
              },
            ),
          ),

          Expanded(
            child:
            _CheckpointBottomItem(
              icon:
              Icons
                  .groups_2_outlined,

              label:
              'TEAMS',

              onTap:
                  () {
                _showMessage(
                  'Teams page will be connected later.',
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // DISPOSE
  // ============================================================

  @override
  void dispose() {
    _mapController?.dispose();

    super.dispose();
  }
}

// ============================================================================
// LEGEND
// ============================================================================

class _LegendItem extends StatelessWidget {
  final Color color;
  final String text;

  const _LegendItem({
    required this.color,
    required this.text,
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
          7,

          height:
          7,

          decoration:
          BoxDecoration(
            color:
            color,

            shape:
            BoxShape.circle,
          ),
        ),

        const SizedBox(
          width:
          4,
        ),

        Text(
          text,

          style:
          const TextStyle(
            color:
            Color(
              0xFF475569,
            ),

            fontSize:
            8,

            fontWeight:
            FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

// ============================================================================
// PUZZLE LOCATION ROW
// ============================================================================

class _PuzzleLocationRow
    extends StatelessWidget {
  final String label;
  final String value;

  const _PuzzleLocationRow({
    required this.label,
    required this.value,
  });

  @override
  Widget build(
      BuildContext context,
      ) {
    return Row(
      crossAxisAlignment:
      CrossAxisAlignment.start,

      children: [
        SizedBox(
          width:
          100,

          child:
          Text(
            label,

            style:
            const TextStyle(
              color:
              Color(
                0xFF94A3B8,
              ),

              fontSize:
              10,

              fontWeight:
              FontWeight.w700,
            ),
          ),
        ),

        Expanded(
          child:
          Text(
            value,

            style:
            const TextStyle(
              color:
              Color(
                0xFF334155,
              ),

              fontSize:
              11,

              fontWeight:
              FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

// ============================================================================
// BOTTOM NAV ITEM
// ============================================================================

class _CheckpointBottomItem
    extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _CheckpointBottomItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.active = false,
  });

  @override
  Widget build(
      BuildContext context,
      ) {
    final Color color =
    active
        ? const Color(
      0xFF0284C7,
    )
        : const Color(
      0xFF64748B,
    );

    return InkWell(
      onTap:
      onTap,

      child:
      Column(
        mainAxisAlignment:
        MainAxisAlignment.center,

        children: [
          Container(
            padding:
            const EdgeInsets.all(
              6,
            ),

            decoration:
            BoxDecoration(
              color:
              active
                  ? const Color(
                0xFFE0F2FE,
              )
                  : Colors.transparent,

              borderRadius:
              BorderRadius.circular(
                9,
              ),
            ),

            child:
            Icon(
              icon,

              color:
              color,

              size:
              20,
            ),
          ),

          const SizedBox(
            height:
            2,
          ),

          Text(
            label,

            textAlign:
            TextAlign.center,

            style:
            TextStyle(
              color:
              color,

              fontSize:
              7,

              height:
              1,

              fontWeight:
              active
                  ? FontWeight.w900
                  : FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
