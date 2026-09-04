import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../../data/models/checkpoint_destination.dart';
import '../../../data/models/checkpoint_mission.dart';
import '../../../data/repositories/checkpoint_repository.dart';

import '../../navigation/mysterylane_bottom_navigation.dart';

import '../Blindbox/BlindBox_Screen.dart';
import '../home/home_screen.dart';
import '../puzzle/puzzle_screen.dart';

import 'checkpoint_mission_screen.dart';

class CheckpointScreen extends StatefulWidget {
  const CheckpointScreen({
    super.key,
  });

  @override
  State<CheckpointScreen> createState() =>
      _CheckpointScreenState();
}

class _CheckpointScreenState
    extends State<CheckpointScreen> {
  // ============================================================
  // REPOSITORY
  // ============================================================

  final CheckpointRepository _repository =
  CheckpointRepository();

  // ============================================================
  // GOOGLE MAP
  // ============================================================

  GoogleMapController? _mapController;

  Position? _currentPosition;

  // ============================================================
  // DATA
  // ============================================================

  List<CheckpointDestination> _destinations =
  <CheckpointDestination>[];

  Set<String> _completedDestinationIds =
  <String>{};

  CheckpointDestination? _selectedDestination;

  CheckpointMission? _selectedMission;

  // ============================================================
  // UI STATE
  // ============================================================

  bool _isLoading = true;

  bool _isLoadingMission = false;

  String? _errorMessage;

  // ============================================================
  // CONFIGURATION
  // ============================================================

  static const double _searchRadiusMetres =
  5000;

  static const CameraPosition _initialCamera =
  CameraPosition(
    target: LatLng(
      3.141600,
      101.697680,
    ),
    zoom: 14,
  );

  // ============================================================
  // INIT
  // ============================================================

  @override
  void initState() {
    super.initState();

    _initializeMap();
  }

  // ============================================================
  // INITIALIZE MAP
  // ============================================================

  Future<void> _initializeMap() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }

    try {
      // --------------------------------------------------------
      // 1. Get traveller current location
      // --------------------------------------------------------

      final Position position =
      await _getCurrentLocation();

      // --------------------------------------------------------
      // 2. Load curated destinations
      // --------------------------------------------------------

      final List<CheckpointDestination>
      allDestinations =
      await _repository
          .getHiddenGemDestinations();

      // --------------------------------------------------------
      // 3. Load completed checkpoints
      // --------------------------------------------------------

      final Set<String> completedIds =
      await _repository
          .getCompletedDestinationIds();

      // --------------------------------------------------------
      // 4. Filter within 5 km
      // --------------------------------------------------------

      final List<CheckpointDestination>
      nearbyDestinations =
      allDestinations.where(
            (
            CheckpointDestination destination,
            ) {
          final double distance =
          Geolocator.distanceBetween(
            position.latitude,
            position.longitude,
            destination.latitude,
            destination.longitude,
          );

          return distance <=
              _searchRadiusMetres;
        },
      ).toList();

      // --------------------------------------------------------
      // 5. Sort nearest first
      // --------------------------------------------------------

      nearbyDestinations.sort(
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

      setState(() {
        _currentPosition =
            position;

        _destinations =
            nearbyDestinations;

        _completedDestinationIds =
            completedIds;

        _selectedDestination =
        nearbyDestinations.isNotEmpty
            ? nearbyDestinations.first
            : null;

        _isLoading =
        false;
      });

      // --------------------------------------------------------
      // Load mission for nearest checkpoint
      // --------------------------------------------------------

      if (_selectedDestination != null) {
        await _loadSelectedMission(
          _selectedDestination!,
          moveCamera: false,
        );
      }

      await _moveToCurrentLocation();
    } catch (error) {
      debugPrint(
        'CHECKPOINT MAP ERROR: $error',
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _isLoading =
        false;

        _errorMessage =
            error
                .toString()
                .replaceFirst(
              'Exception: ',
              '',
            );
      });
    }
  }

  // ============================================================
  // GET GPS
  // ============================================================

  Future<Position> _getCurrentLocation() async {
    final bool serviceEnabled =
    await Geolocator
        .isLocationServiceEnabled();

    if (!serviceEnabled) {
      throw Exception(
        'Location service is disabled. '
            'Please enable GPS on your device.',
      );
    }

    LocationPermission permission =
    await Geolocator
        .checkPermission();

    if (permission ==
        LocationPermission.denied) {
      permission =
      await Geolocator
          .requestPermission();
    }

    if (permission ==
        LocationPermission.denied) {
      throw Exception(
        'Location permission was denied.',
      );
    }

    if (permission ==
        LocationPermission.deniedForever) {
      throw Exception(
        'Location permission is permanently denied. '
            'Please enable it from Android settings.',
      );
    }

    return Geolocator.getCurrentPosition(
      locationSettings:
      const LocationSettings(
        accuracy:
        LocationAccuracy.high,
      ),
    );
  }

  // ============================================================
  // GOOGLE MAP CREATED
  // ============================================================

  void _onMapCreated(
      GoogleMapController controller,
      ) {
    _mapController =
        controller;

    _moveToCurrentLocation();
  }

  // ============================================================
  // MOVE MAP TO CURRENT LOCATION
  // ============================================================

  Future<void>
  _moveToCurrentLocation() async {
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
          zoom: 14.2,
        ),
      ),
    );
  }

  // ============================================================
  // SELECT DESTINATION
  // ============================================================

  Future<void> _selectDestination(
      CheckpointDestination destination,
      ) async {
    await _loadSelectedMission(
      destination,
      moveCamera: true,
    );
  }

  // ============================================================
  // LOAD SELECTED MISSION
  // ============================================================

  Future<void> _loadSelectedMission(
      CheckpointDestination destination, {
        required bool moveCamera,
      }) async {
    if (!mounted) {
      return;
    }

    setState(() {
      _selectedDestination =
          destination;

      _selectedMission =
      null;

      _isLoadingMission =
      true;
    });

    if (moveCamera) {
      await _mapController?.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(
            target: LatLng(
              destination.latitude,
              destination.longitude,
            ),
            zoom: 15.5,
          ),
        ),
      );
    }

    try {
      final CheckpointMission? mission =
      await _repository
          .getMissionByDestinationId(
        destination.destinationId,
      );

      if (!mounted) {
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
        'SELECTED MISSION ERROR: $error',
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
  // GET DISTANCE
  // ============================================================

  double _distanceKm(
      CheckpointDestination destination,
      ) {
    final Position? position =
        _currentPosition;

    if (position == null) {
      return 0;
    }

    final double metres =
    Geolocator.distanceBetween(
      position.latitude,
      position.longitude,
      destination.latitude,
      destination.longitude,
    );

    return metres / 1000;
  }

  // ============================================================
  // BUILD MARKERS
  // ============================================================

  Set<Marker> _buildMarkers() {
    return _destinations.map(
          (
          CheckpointDestination destination,
          ) {
        final bool completed =
        _completedDestinationIds
            .contains(
          destination.destinationId,
        );

        final String popularity =
            destination
                .popularityClassification
                ?.toUpperCase() ??
                '';

        // Hidden Gem = Blue
        double hue =
            BitmapDescriptor.hueAzure;

        // Completed = Green
        if (completed) {
          hue =
              BitmapDescriptor.hueGreen;
        }

        // Popular = Orange
        else if (popularity ==
            'POPULAR') {
          hue =
              BitmapDescriptor.hueOrange;
        }

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
            hue,
          ),

          infoWindow:
          InfoWindow(
            title:
            destination.name,

            snippet:
            completed
                ? 'Completed'
                : 'Checkpoint Mission',
          ),

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
  // BUILD 5KM RADIUS
  // ============================================================

  Set<Circle> _buildCircles() {
    final Position? position =
        _currentPosition;

    if (position == null) {
      return <Circle>{};
    }

    return <Circle>{
      Circle(
        circleId:
        const CircleId(
          'user_5km_radius',
        ),

        center:
        LatLng(
          position.latitude,
          position.longitude,
        ),

        radius:
        _searchRadiusMetres,

        strokeWidth:
        2,

        strokeColor:
        const Color(
          0xFF0284C7,
        ),

        fillColor:
        const Color(
          0x180284C7,
        ),
      ),
    };
  }

  // ============================================================
  // OPEN MISSION
  // ============================================================

  Future<void> _openMission() async {
    final CheckpointDestination? destination =
        _selectedDestination;

    if (destination == null) {
      return;
    }

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

    await _refreshCompletedCheckpoints();
  }

  // ============================================================
  // REFRESH COMPLETED CHECKPOINTS
  // ============================================================

  Future<void>
  _refreshCompletedCheckpoints() async {
    try {
      final Set<String> completed =
      await _repository
          .getCompletedDestinationIds();

      if (!mounted) {
        return;
      }

      setState(() {
        _completedDestinationIds =
            completed;
      });
    } catch (error) {
      debugPrint(
        'REFRESH COMPLETED ERROR: $error',
      );
    }
  }

  // ============================================================
  // BOTTOM NAVIGATION
  // ============================================================

  void _goToBlindBox() {
    Navigator.of(context)
        .pushReplacement(
      MaterialPageRoute(
        builder: (_) =>
        const BlindBoxPage(),
      ),
    );
  }

  void _goToMissions() {
    // Already on Missions.
    _moveToCurrentLocation();
  }

  void _goHome() {
    if (Navigator.of(context)
        .canPop()) {
      Navigator.of(context)
          .pop();

      return;
    }

    Navigator.of(context)
        .pushReplacement(
      MaterialPageRoute(
        builder: (_) =>
        const HomeScreen(),
      ),
    );
  }

  void _goToPlan() {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          behavior:
          SnackBarBehavior.floating,

          content:
          Text(
            'Plan page will be connected later.',
          ),
        ),
      );
  }

  void _goToTeams() {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          behavior:
          SnackBarBehavior.floating,

          content:
          Text(
            'Teams page will be connected later.',
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
      const Color(
        0xFFF8FAFC,
      ),

      extendBody:
      false,

      // ========================================================
      // CENTER HOME BUTTON
      // ========================================================

      floatingActionButtonLocation:
      FloatingActionButtonLocation
          .centerDocked,

      floatingActionButton:
      MysteryLaneHomeFloatingButton(
        onTap:
        _goHome,
      ),

      // ========================================================
      // BOTTOM NAVIGATION
      // ========================================================

      bottomNavigationBar:
      MysteryLaneBottomBar(
        selectedItem:
        MysteryLaneBottomItem
            .missions,

        onBlindBoxTap:
        _goToBlindBox,

        onMissionsTap:
        _goToMissions,

        onPlanTap:
        _goToPlan,

        onTeamsTap:
        _goToTeams,
      ),

      body:
      SafeArea(
        child:
        _buildBody(),
      ),
    );
  }

  // ============================================================
  // BODY
  // ============================================================

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child:
        Column(
          mainAxisSize:
          MainAxisSize.min,

          children: [
            CircularProgressIndicator(),

            SizedBox(
              height: 16,
            ),

            Text(
              'Finding checkpoints near you...',

              style:
              TextStyle(
                color:
                Color(
                  0xFF64748B,
                ),

                fontSize:
                14,
              ),
            ),
          ],
        ),
      );
    }

    if (_errorMessage != null) {
      return _buildErrorState();
    }

    return Column(
      children: [
        _buildHeader(),

        _buildAvailableCheckpointText(),

        Expanded(
          child:
          Padding(
            padding:
            const EdgeInsets.fromLTRB(
              12,
              0,
              12,
              14,
            ),

            child:
            _buildMapArea(),
          ),
        ),
      ],
    );
  }

  // ============================================================
  // HEADER
  // ============================================================

  Widget _buildHeader() {
    return Padding(
      padding:
      const EdgeInsets.fromLTRB(
        14,
        10,
        14,
        10,
      ),

      child:
      Row(
        children: [
          Container(
            width:
            42,

            height:
            42,

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
            IconButton(
              padding:
              EdgeInsets.zero,

              onPressed: () {
                Navigator.of(
                  context,
                ).pop();
              },

              icon:
              const Icon(
                Icons
                    .arrow_back_ios_new_rounded,

                size:
                18,

                color:
                Color(
                  0xFF0F172A,
                ),
              ),
            ),
          ),

          const SizedBox(
            width: 10,
          ),

          Expanded(
            child:
            Container(
              height:
              44,

              padding:
              const EdgeInsets.all(
                4,
              ),

              decoration:
              BoxDecoration(
                color:
                const Color(
                  0xFFF0F9FF,
                ),

                borderRadius:
                BorderRadius.circular(
                  30,
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
                  Expanded(
                    child:
                    Container(
                      alignment:
                      Alignment.center,

                      decoration:
                      BoxDecoration(
                        color:
                        const Color(
                          0xFF0284C7,
                        ),

                        borderRadius:
                        BorderRadius
                            .circular(
                          25,
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
                          11,

                          fontWeight:
                          FontWeight
                              .w700,
                        ),
                      ),
                    ),
                  ),

                  Expanded(
                    child:
                    InkWell(
                      borderRadius:
                      BorderRadius
                          .circular(
                        25,
                      ),

                      onTap: () {
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
                            10,

                            fontWeight:
                            FontWeight
                                .w700,
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
            width: 8,
          ),

          IconButton(
            onPressed:
            _initializeMap,

            icon:
            const Icon(
              Icons.refresh_rounded,

              color:
              Color(
                0xFF0284C7,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // CHECKPOINT COUNT
  // ============================================================

  Widget _buildAvailableCheckpointText() {
    return Padding(
      padding:
      const EdgeInsets.fromLTRB(
        18,
        0,
        18,
        10,
      ),

      child:
      Row(
        children: [
          const Icon(
            Icons.explore_outlined,

            size: 17,

            color:
            Color(
              0xFF0284C7,
            ),
          ),

          const SizedBox(
            width: 7,
          ),

          Expanded(
            child:
            Text(
              '${_destinations.length} '
                  '${_destinations.length == 1 ? 'checkpoint' : 'checkpoints'} '
                  'available within 5 km of your location',

              style:
              const TextStyle(
                color:
                Color(
                  0xFF64748B,
                ),

                fontSize:
                12,

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
  // MAP
  // ============================================================

  Widget _buildMapArea() {
    return ClipRRect(
      borderRadius:
      BorderRadius.circular(
        24,
      ),

      child:
      Stack(
        children: [
          Positioned.fill(
            child:
            GoogleMap(
              initialCameraPosition:
              _initialCamera,

              onMapCreated:
              _onMapCreated,

              markers:
              _buildMarkers(),

              circles:
              _buildCircles(),

              myLocationEnabled:
              true,

              myLocationButtonEnabled:
              false,

              zoomControlsEnabled:
              false,

              compassEnabled:
              false,

              mapToolbarEnabled:
              false,

              buildingsEnabled:
              true,

              onTap: (
                  LatLng position,
                  ) {
                setState(() {
                  _selectedDestination =
                  null;

                  _selectedMission =
                  null;

                  _isLoadingMission =
                  false;
                });
              },
            ),
          ),

          // ====================================================
          // LEGEND
          // ====================================================

          Positioned(
            top: 12,
            left: 12,
            right: 12,

            child:
            _buildLegend(),
          ),

          // ====================================================
          // CURRENT LOCATION BUTTON
          // ====================================================

          Positioned(
            top: 70,
            right: 14,

            child:
            Material(
              elevation: 4,

              color:
              Colors.white,

              shape:
              const CircleBorder(),

              child:
              IconButton(
                onPressed:
                _moveToCurrentLocation,

                icon:
                const Icon(
                  Icons
                      .my_location_rounded,

                  color:
                  Color(
                    0xFF0284C7,
                  ),
                ),
              ),
            ),
          ),

          // ====================================================
          // NO CHECKPOINTS
          // ====================================================

          if (_destinations.isEmpty)
            Center(
              child:
              Container(
                margin:
                const EdgeInsets.all(
                  28,
                ),

                padding:
                const EdgeInsets.all(
                  20,
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
                        0x22000000,
                      ),

                      blurRadius:
                      16,
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

                      size:
                      44,

                      color:
                      Color(
                        0xFF94A3B8,
                      ),
                    ),

                    SizedBox(
                      height: 10,
                    ),

                    Text(
                      'No checkpoints found within 5 km.',

                      textAlign:
                      TextAlign.center,

                      style:
                      TextStyle(
                        color:
                        Color(
                          0xFF0F172A,
                        ),

                        fontWeight:
                        FontWeight
                            .w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // ====================================================
          // SELECTED CHECKPOINT CARD
          // ====================================================

          if (_selectedDestination != null)
            Positioned(
              left: 12,
              right: 12,
              bottom: 12,

              child:
              _buildSelectedCheckpointCard(),
            ),
        ],
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
        horizontal: 12,
        vertical: 10,
      ),

      decoration:
      BoxDecoration(
        color:
        const Color(
          0xF5FFFFFF,
        ),

        borderRadius:
        BorderRadius.circular(
          20,
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
              0x18000000,
            ),

            blurRadius:
            10,

            offset:
            Offset(
              0,
              3,
            ),
          ),
        ],
      ),

      child:
      const Row(
        mainAxisAlignment:
        MainAxisAlignment
            .spaceAround,

        children: [
          _LegendItem(
            color:
            Color(
              0xFF10B981,
            ),

            label:
            'Completed',
          ),

          _LegendItem(
            color:
            Color(
              0xFFF59E0B,
            ),

            label:
            'Popular',
          ),

          _LegendItem(
            color:
            Color(
              0xFF0284C7,
            ),

            label:
            'Hidden Gem',
          ),

          _LegendItem(
            color:
            Color(
              0xFF38BDF8,
            ),

            label:
            'You (5km)',
          ),
        ],
      ),
    );
  }

  // ============================================================
  // SELECTED CHECKPOINT CARD
  // ============================================================

  Widget _buildSelectedCheckpointCard() {
    final CheckpointDestination destination =
    _selectedDestination!;

    final bool completed =
    _completedDestinationIds
        .contains(
      destination.destinationId,
    );

    final double distance =
    _distanceKm(
      destination,
    );

    return Container(
      padding:
      const EdgeInsets.all(
        15,
      ),

      decoration:
      BoxDecoration(
        color:
        Colors.white,

        borderRadius:
        BorderRadius.circular(
          22,
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
              0x35000000,
            ),

            blurRadius:
            20,

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
        crossAxisAlignment:
        CrossAxisAlignment.start,

        mainAxisSize:
        MainAxisSize.min,

        children: [
          Row(
            crossAxisAlignment:
            CrossAxisAlignment.start,

            children: [
              Container(
                width: 44,
                height: 44,

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
                    13,
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
                      : const Color(
                    0xFF0284C7,
                  ),
                ),
              ),

              const SizedBox(
                width: 11,
              ),

              Expanded(
                child:
                Column(
                  crossAxisAlignment:
                  CrossAxisAlignment.start,

                  children: [
                    Text(
                      destination.name,

                      style:
                      const TextStyle(
                        color:
                        Color(
                          0xFF0F172A,
                        ),

                        fontSize:
                        16,

                        fontWeight:
                        FontWeight
                            .w800,
                      ),
                    ),

                    const SizedBox(
                      height: 4,
                    ),

                    Text(
                      '${distance.toStringAsFixed(2)} km away'
                          '${destination.category != null ? ' • ${destination.category}' : ''}',

                      style:
                      const TextStyle(
                        color:
                        Color(
                          0xFF64748B,
                        ),

                        fontSize:
                        11.5,
                      ),
                    ),
                  ],
                ),
              ),

              if (_selectedMission != null)
                Container(
                  padding:
                  const EdgeInsets
                      .symmetric(
                    horizontal:
                    9,

                    vertical:
                    5,
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
                    '+${_selectedMission!.rewardPoints}',

                    style:
                    const TextStyle(
                      color:
                      Color(
                        0xFF0284C7,
                      ),

                      fontSize:
                      11,

                      fontWeight:
                      FontWeight
                          .w800,
                    ),
                  ),
                ),
            ],
          ),

          if (completed) ...[
            const SizedBox(
              height: 8,
            ),

            const Row(
              children: [
                Icon(
                  Icons.verified_rounded,

                  color:
                  Color(
                    0xFF059669,
                  ),

                  size: 16,
                ),

                SizedBox(
                  width: 5,
                ),

                Text(
                  'Checkpoint completed',

                  style:
                  TextStyle(
                    color:
                    Color(
                      0xFF059669,
                    ),

                    fontSize:
                    12,

                    fontWeight:
                    FontWeight
                        .w700,
                  ),
                ),
              ],
            ),
          ],

          if (destination.description !=
              null) ...[
            const SizedBox(
              height: 9,
            ),

            Text(
              destination.description!,

              maxLines: 2,

              overflow:
              TextOverflow.ellipsis,

              style:
              const TextStyle(
                color:
                Color(
                  0xFF64748B,
                ),

                fontSize: 12,

                height: 1.4,
              ),
            ),
          ],

          const SizedBox(
            height: 12,
          ),

          if (_isLoadingMission)
            const Center(
              child:
              Padding(
                padding:
                EdgeInsets.symmetric(
                  vertical: 8,
                ),

                child:
                SizedBox(
                  width: 22,
                  height: 22,

                  child:
                  CircularProgressIndicator(
                    strokeWidth:
                    2,
                  ),
                ),
              ),
            )
          else if (_selectedMission == null)
            const Text(
              'No active mission is available for this checkpoint.',

              style:
              TextStyle(
                color:
                Color(
                  0xFFEF4444,
                ),

                fontSize:
                12,
              ),
            )
          else
            SizedBox(
              width:
              double.infinity,

              child:
              ElevatedButton.icon(
                onPressed:
                _openMission,

                icon:
                Icon(
                  completed
                      ? Icons
                      .visibility_rounded
                      : Icons
                      .flag_circle_rounded,
                ),

                label:
                Text(
                  completed
                      ? 'VIEW COMPLETED MISSION'
                      : 'VIEW MISSION',
                ),

                style:
                ElevatedButton
                    .styleFrom(
                  backgroundColor:
                  const Color(
                    0xFF0284C7,
                  ),

                  foregroundColor:
                  Colors.white,

                  elevation: 0,

                  padding:
                  const EdgeInsets
                      .symmetric(
                    vertical: 13,
                  ),

                  textStyle:
                  const TextStyle(
                    fontSize: 12,

                    fontWeight:
                    FontWeight
                        .w800,
                  ),

                  shape:
                  RoundedRectangleBorder(
                    borderRadius:
                    BorderRadius.circular(
                      30,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ============================================================
  // ERROR STATE
  // ============================================================

  Widget _buildErrorState() {
    return Center(
      child:
      Padding(
        padding:
        const EdgeInsets.all(
          28,
        ),

        child:
        Column(
          mainAxisSize:
          MainAxisSize.min,

          children: [
            const Icon(
              Icons.location_off_outlined,

              size: 65,

              color:
              Color(
                0xFF94A3B8,
              ),
            ),

            const SizedBox(
              height: 16,
            ),

            const Text(
              'Unable to Load Checkpoint Map',

              textAlign:
              TextAlign.center,

              style:
              TextStyle(
                color:
                Color(
                  0xFF0F172A,
                ),

                fontSize:
                19,

                fontWeight:
                FontWeight
                    .w800,
              ),
            ),

            const SizedBox(
              height: 8,
            ),

            Text(
              _errorMessage ??
                  'Unknown error',

              textAlign:
              TextAlign.center,

              style:
              const TextStyle(
                color:
                Color(
                  0xFF64748B,
                ),

                height: 1.4,
              ),
            ),

            const SizedBox(
              height: 20,
            ),

            ElevatedButton.icon(
              onPressed:
              _initializeMap,

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
                const Color(
                  0xFF0284C7,
                ),

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
  // DISPOSE
  // ============================================================

  @override
  void dispose() {
    _mapController?.dispose();

    super.dispose();
  }
}

// ============================================================
// MAP LEGEND ITEM
// ============================================================

class _LegendItem
    extends StatelessWidget {
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

        const SizedBox(
          width: 4,
        ),

        Text(
          label,

          style:
          const TextStyle(
            color:
            Color(
              0xFF475569,
            ),

            fontSize: 8.5,

            fontWeight:
            FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
