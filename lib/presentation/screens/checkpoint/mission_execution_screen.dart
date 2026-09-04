import 'dart:io';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';

import '../../../data/models/checkpoint_destination.dart';
import '../../../data/models/checkpoint_mission.dart';
import '../../../data/repositories/checkpoint_repository.dart';

import 'complete_mission_screen.dart';

class MissionExecutionScreen
    extends StatefulWidget {
  final CheckpointDestination destination;
  final CheckpointMission mission;
  final String userMissionId;

  const MissionExecutionScreen({
    super.key,
    required this.destination,
    required this.mission,
    required this.userMissionId,
  });

  @override
  State<MissionExecutionScreen>
  createState() =>
      _MissionExecutionScreenState();
}

class _MissionExecutionScreenState
    extends State<MissionExecutionScreen> {
  final CheckpointRepository _repository =
  CheckpointRepository();

  final ImagePicker _imagePicker =
  ImagePicker();

  bool _checkingLocation = false;

  bool _locationVerified = false;

  bool _submitting = false;

  double? _distanceMetres;

  String? _locationMessage;

  XFile? _missionPhoto;

  // ============================================================
  // CHECK GPS
  // ============================================================

  Future<void> _verifyLocation() async {
    setState(() {
      _checkingLocation = true;
      _locationMessage = null;
    });

    try {
      final bool serviceEnabled =
      await Geolocator
          .isLocationServiceEnabled();

      if (!serviceEnabled) {
        throw Exception(
          'Location service is disabled. Please enable GPS.',
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
          LocationPermission
              .deniedForever) {
        throw Exception(
          'Location permission is permanently denied. '
              'Please enable it from Settings.',
        );
      }

      final Position position =
      await Geolocator
          .getCurrentPosition(
        locationSettings:
        const LocationSettings(
          accuracy:
          LocationAccuracy.high,
        ),
      );

      final double distance =
      Geolocator.distanceBetween(
        position.latitude,
        position.longitude,
        widget.destination.latitude,
        widget.destination.longitude,
      );

      final bool verified =
          distance <=
              widget.mission
                  .verificationRadiusM;

      if (!mounted) {
        return;
      }

      setState(() {
        _distanceMetres =
            distance;

        _locationVerified =
            verified;

        _checkingLocation =
        false;

        if (verified) {
          _locationMessage =
          'Location verified successfully.';
        } else {
          _locationMessage =
          'You are ${distance.toStringAsFixed(1)} metres away. '
              'Move within ${widget.mission.verificationRadiusM} metres '
              'to continue.';
        }
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _checkingLocation =
        false;

        _locationVerified =
        false;

        _locationMessage =
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
  // TAKE PHOTO
  // ============================================================

  Future<void> _capturePhoto() async {
    if (!_locationVerified) {
      ScaffoldMessenger.of(context)
          .showSnackBar(
        const SnackBar(
          content: Text(
            'Verify your location first.',
          ),
        ),
      );

      return;
    }

    try {
      final XFile? image =
      await _imagePicker.pickImage(
        source:
        ImageSource.camera,

        imageQuality:
        85,
      );

      if (image == null) {
        return;
      }

      if (!mounted) {
        return;
      }

      setState(() {
        _missionPhoto =
            image;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context)
          .showSnackBar(
        SnackBar(
          content: Text(
            'Camera error: $error',
          ),
        ),
      );
    }
  }

  // ============================================================
  // SUBMIT
  // ============================================================

  Future<void> _submitMission() async {
    if (!_locationVerified) {
      ScaffoldMessenger.of(context)
          .showSnackBar(
        const SnackBar(
          content: Text(
            'You must verify your location first.',
          ),
        ),
      );

      return;
    }

    if (widget.mission.photoRequired &&
        _missionPhoto == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(
        const SnackBar(
          content: Text(
            'Please capture the required mission photo.',
          ),
        ),
      );

      return;
    }

    setState(() {
      _submitting = true;
    });

    try {
      // ======================================================
      // TEMPORARY PHOTO VERIFICATION
      //
      // CURRENT:
      // GPS + photo = VERIFIED
      //
      // LATER:
      // Photo + photo requirement -> Gemini -> PASS / FAIL
      // ======================================================

      final int totalPoints =
      await _repository
          .completeMissionForTesting(
        userMissionId:
        widget.userMissionId,

        missionId:
        widget.mission.missionId,

        destinationId:
        widget.destination.destinationId,

        rewardPoints:
        widget.mission.rewardPoints,
      );

      if (!mounted) {
        return;
      }

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) =>
              CompleteMissionScreen(
                title:
                widget
                    .mission
                    .missionName,

                reward:
                widget
                    .mission
                    .rewardPoints,

                totalPoints:
                totalPoints,
              ),
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _submitting =
        false;
      });

      ScaffoldMessenger.of(context)
          .showSnackBar(
        SnackBar(
          content: Text(
            error
                .toString()
                .replaceFirst(
              'Exception: ',
              '',
            ),
          ),
        ),
      );
    }
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor:
      const Color(
        0xFFF4F7FB,
      ),

      appBar: AppBar(
        backgroundColor:
        Colors.white,

        surfaceTintColor:
        Colors.white,

        elevation: 0,

        centerTitle: true,

        leading: IconButton(
          onPressed: () {
            Navigator.pop(
              context,
            );
          },

          icon: const Icon(
            Icons
                .arrow_back_ios_new_rounded,

            color:
            Color(
              0xFF0F172A,
            ),
          ),
        ),

        title: const Text(
          'Complete Mission',

          style: TextStyle(
            color:
            Color(
              0xFF0F172A,
            ),

            fontSize: 19,

            fontWeight:
            FontWeight.w700,
          ),
        ),
      ),

      body: SafeArea(
        child:
        SingleChildScrollView(
          padding:
          const EdgeInsets
              .fromLTRB(
            18,
            18,
            18,
            32,
          ),

          child: Column(
            children: [
              _buildMissionCard(),

              const SizedBox(
                height: 16,
              ),

              _buildLocationCard(),

              const SizedBox(
                height: 16,
              ),

              _buildPhotoCard(),

              const SizedBox(
                height: 22,
              ),

              SizedBox(
                width:
                double.infinity,

                height:
                52,

                child:
                FilledButton.icon(
                  onPressed:
                  _submitting
                      ? null
                      : _submitMission,

                  icon: _submitting
                      ? const SizedBox(
                    width: 19,
                    height: 19,

                    child:
                    CircularProgressIndicator(
                      strokeWidth:
                      2,

                      color:
                      Colors.white,
                    ),
                  )
                      : const Icon(
                    Icons
                        .check_circle_outline_rounded,
                  ),

                  label: Text(
                    _submitting
                        ? 'SUBMITTING...'
                        : 'SUBMIT MISSION',
                  ),

                  style:
                  FilledButton
                      .styleFrom(
                    backgroundColor:
                    const Color(
                      0xFF2563EB,
                    ),

                    shape:
                    RoundedRectangleBorder(
                      borderRadius:
                      BorderRadius
                          .circular(
                        16,
                      ),
                    ),

                    textStyle:
                    const TextStyle(
                      fontWeight:
                      FontWeight
                          .w800,
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

  // ============================================================
  // MISSION CARD
  // ============================================================

  Widget _buildMissionCard() {
    return Container(
      width:
      double.infinity,

      padding:
      const EdgeInsets.all(
        18,
      ),

      decoration:
      _cardDecoration(),

      child:
      Column(
        crossAxisAlignment:
        CrossAxisAlignment.start,

        children: [
          const Text(
            'ACTIVE MISSION',

            style:
            TextStyle(
              color:
              Color(
                0xFF2563EB,
              ),

              fontSize:
              11,

              fontWeight:
              FontWeight.w800,

              letterSpacing:
              1,
            ),
          ),

          const SizedBox(
            height: 8,
          ),

          Text(
            widget
                .mission
                .missionName,

            style:
            const TextStyle(
              color:
              Color(
                0xFF0F172A,
              ),

              fontSize:
              21,

              fontWeight:
              FontWeight.w800,
            ),
          ),

          const SizedBox(
            height: 8,
          ),

          Text(
            widget
                .mission
                .objective,

            style:
            const TextStyle(
              color:
              Color(
                0xFF64748B,
              ),

              fontSize:
              13,

              height:
              1.5,
            ),
          ),

          const SizedBox(
            height: 12,
          ),

          Row(
            children: [
              const Icon(
                Icons
                    .location_on_outlined,

                color:
                Color(
                  0xFF2563EB,
                ),

                size:
                18,
              ),

              const SizedBox(
                width:
                6,
              ),

              Expanded(
                child: Text(
                  widget
                      .destination
                      .name,

                  style:
                  const TextStyle(
                    color:
                    Color(
                      0xFF475569,
                    ),

                    fontSize:
                    13,

                    fontWeight:
                    FontWeight.w600,
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
  // LOCATION CARD
  // ============================================================

  Widget _buildLocationCard() {
    return Container(
      width:
      double.infinity,

      padding:
      const EdgeInsets.all(
        18,
      ),

      decoration:
      _cardDecoration(),

      child:
      Column(
        crossAxisAlignment:
        CrossAxisAlignment.start,

        children: [
          const Row(
            children: [
              Icon(
                Icons
                    .my_location_rounded,

                color:
                Color(
                  0xFF2563EB,
                ),
              ),

              SizedBox(
                width:
                9,
              ),

              Text(
                'Location Verification',

                style:
                TextStyle(
                  color:
                  Color(
                    0xFF0F172A,
                  ),

                  fontSize:
                  15,

                  fontWeight:
                  FontWeight.w700,
                ),
              ),
            ],
          ),

          const SizedBox(
            height:
            12,
          ),

          Text(
            'You must be within '
                '${widget.mission.verificationRadiusM} metres '
                'of ${widget.destination.name}.',

            style:
            const TextStyle(
              color:
              Color(
                0xFF64748B,
              ),

              fontSize:
              13,

              height:
              1.45,
            ),
          ),

          if (_locationMessage !=
              null) ...[
            const SizedBox(
              height:
              14,
            ),

            Container(
              width:
              double.infinity,

              padding:
              const EdgeInsets.all(
                12,
              ),

              decoration:
              BoxDecoration(
                color:
                _locationVerified
                    ? const Color(
                  0xFFF0FDF4,
                )
                    : const Color(
                  0xFFFFF7ED,
                ),

                borderRadius:
                BorderRadius.circular(
                  12,
                ),
              ),

              child:
              Text(
                _locationMessage!,

                style:
                TextStyle(
                  color:
                  _locationVerified
                      ? const Color(
                    0xFF15803D,
                  )
                      : const Color(
                    0xFFC2410C,
                  ),

                  fontSize:
                  12.5,

                  fontWeight:
                  FontWeight.w600,
                ),
              ),
            ),
          ],

          if (_distanceMetres !=
              null) ...[
            const SizedBox(
              height:
              8,
            ),

            Text(
              'Distance: '
                  '${_distanceMetres!.toStringAsFixed(1)} metres',

              style:
              const TextStyle(
                color:
                Color(
                  0xFF64748B,
                ),

                fontSize:
                12,
              ),
            ),
          ],

          const SizedBox(
            height:
            15,
          ),

          SizedBox(
            width:
            double.infinity,

            child:
            OutlinedButton.icon(
              onPressed:
              _checkingLocation
                  ? null
                  : _verifyLocation,

              icon:
              _checkingLocation
                  ? const SizedBox(
                width:
                17,
                height:
                17,

                child:
                CircularProgressIndicator(
                  strokeWidth:
                  2,
                ),
              )
                  : const Icon(
                Icons
                    .gps_fixed_rounded,
              ),

              label: Text(
                _checkingLocation
                    ? 'Checking Location...'
                    : _locationVerified
                    ? 'Check Location Again'
                    : 'Verify My Location',
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // PHOTO CARD
  // ============================================================

  Widget _buildPhotoCard() {
    return Container(
      width:
      double.infinity,

      padding:
      const EdgeInsets.all(
        18,
      ),

      decoration:
      _cardDecoration(),

      child:
      Column(
        crossAxisAlignment:
        CrossAxisAlignment.start,

        children: [
          const Row(
            children: [
              Icon(
                Icons
                    .camera_alt_rounded,

                color:
                Color(
                  0xFF2563EB,
                ),
              ),

              SizedBox(
                width:
                9,
              ),

              Text(
                'Mission Photo',

                style:
                TextStyle(
                  color:
                  Color(
                    0xFF0F172A,
                  ),

                  fontSize:
                  15,

                  fontWeight:
                  FontWeight.w700,
                ),
              ),
            ],
          ),

          const SizedBox(
            height:
            12,
          ),

          Text(
            widget.mission
                .photoRequirement ??
                'Capture a clear checkpoint photo.',

            style:
            const TextStyle(
              color:
              Color(
                0xFF64748B,
              ),

              fontSize:
              13,

              height:
              1.45,
            ),
          ),

          const SizedBox(
            height:
            15,
          ),

          if (_missionPhoto !=
              null)
            ClipRRect(
              borderRadius:
              BorderRadius.circular(
                16,
              ),

              child:
              Image.file(
                File(
                  _missionPhoto!
                      .path,
                ),

                height:
                220,

                width:
                double.infinity,

                fit:
                BoxFit.cover,
              ),
            )
          else
            Container(
              height:
              170,

              width:
              double.infinity,

              decoration:
              BoxDecoration(
                color:
                const Color(
                  0xFFF1F5F9,
                ),

                borderRadius:
                BorderRadius.circular(
                  16,
                ),
              ),

              child:
              const Column(
                mainAxisAlignment:
                MainAxisAlignment
                    .center,

                children: [
                  Icon(
                    Icons
                        .add_a_photo_outlined,

                    size:
                    44,

                    color:
                    Color(
                      0xFF94A3B8,
                    ),
                  ),

                  SizedBox(
                    height:
                    8,
                  ),

                  Text(
                    'No photo captured',

                    style:
                    TextStyle(
                      color:
                      Color(
                        0xFF64748B,
                      ),
                    ),
                  ),
                ],
              ),
            ),

          const SizedBox(
            height:
            15,
          ),

          SizedBox(
            width:
            double.infinity,

            child:
            FilledButton.icon(
              onPressed:
              _locationVerified
                  ? _capturePhoto
                  : null,

              style:
              FilledButton
                  .styleFrom(
                backgroundColor:
                const Color(
                  0xFF0F172A,
                ),
              ),

              icon:
              const Icon(
                Icons
                    .photo_camera_rounded,
              ),

              label: Text(
                _missionPhoto ==
                    null
                    ? 'CAPTURE PHOTO'
                    : 'RETAKE PHOTO',
              ),
            ),
          ),
        ],
      ),
    );
  }

  BoxDecoration _cardDecoration() {
    return BoxDecoration(
      color:
      Colors.white,

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
    );
  }
}