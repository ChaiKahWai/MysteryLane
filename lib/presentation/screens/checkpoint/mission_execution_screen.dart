import 'dart:io';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';

import 'package:mysterylane/data/models/checkpoint_destination.dart';
import 'package:mysterylane/data/models/checkpoint_mission.dart';
import 'package:mysterylane/data/models/mission_verification_result.dart';
import 'package:mysterylane/data/repositories/checkpoint_repository.dart';

import 'package:mysterylane/application/services/mission_photo_verification_service.dart';

import 'complete_mission_screen.dart';

class MissionExecutionScreen extends StatefulWidget {
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
  State<MissionExecutionScreen> createState() =>
      _MissionExecutionScreenState();
}

class _MissionExecutionScreenState
    extends State<MissionExecutionScreen> {
  // ============================================================
  // SERVICES
  // ============================================================

  final CheckpointRepository _repository =
  CheckpointRepository();

  final MissionPhotoVerificationService
  _verificationService =
  MissionPhotoVerificationService();

  final ImagePicker _imagePicker =
  ImagePicker();

  // ============================================================
  // LOCATION STATE
  // ============================================================

  bool _checkingLocation = false;
  bool _locationVerified = false;

  double? _distanceMetres;
  String? _locationMessage;

  // ============================================================
  // PHOTO STATE
  // ============================================================

  XFile? _missionPhoto;

  // ============================================================
  // GEMINI STATE
  // ============================================================

  bool _submitting = false;

  MissionVerificationResult? _verificationResult;

  // ============================================================
  // VERIFY LOCATION
  // ============================================================

  Future<void> _verifyLocation() async {
    if (_checkingLocation) {
      return;
    }

    setState(() {
      _checkingLocation = true;
      _locationMessage = null;
    });

    try {
      // --------------------------------------------------------
      // CHECK GPS SERVICE
      // --------------------------------------------------------

      final bool serviceEnabled =
      await Geolocator.isLocationServiceEnabled();

      if (!serviceEnabled) {
        throw Exception(
          'Location service is disabled. Please enable GPS.',
        );
      }

      // --------------------------------------------------------
      // CHECK LOCATION PERMISSION
      // --------------------------------------------------------

      LocationPermission permission =
      await Geolocator.checkPermission();

      if (permission ==
          LocationPermission.denied) {
        permission =
        await Geolocator.requestPermission();
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
              'Please enable it from your phone settings.',
        );
      }

      // --------------------------------------------------------
      // GET CURRENT LOCATION
      // --------------------------------------------------------

      final Position position =
      await Geolocator.getCurrentPosition(
        locationSettings:
        const LocationSettings(
          accuracy:
          LocationAccuracy.high,
        ),
      );

      // --------------------------------------------------------
      // CALCULATE DISTANCE
      // --------------------------------------------------------

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

        if (verified) {
          _locationMessage =
          'Location verified successfully. '
              'You are within the checkpoint radius.';
        } else {
          _locationMessage =
          'You are ${distance.toStringAsFixed(0)} metres away. '
              'Move within '
              '${widget.mission.verificationRadiusM} metres '
              'of the checkpoint.';
        }
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
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
    } finally {
      if (mounted) {
        setState(() {
          _checkingLocation =
          false;
        });
      }
    }
  }

  // ============================================================
  // TAKE PHOTO WITH CAMERA
  // ============================================================

  Future<void> _capturePhoto() async {
    if (!_locationVerified) {
      _showMessage(
        'Please verify your location before taking the mission photo.',
      );

      return;
    }

    try {
      final XFile? photo =
      await _imagePicker.pickImage(
        source:
        ImageSource.camera,

        imageQuality:
        70,

        maxWidth:
        1600,

        maxHeight:
        1600,

        preferredCameraDevice:
        CameraDevice.rear,
      );

      if (photo == null) {
        return;
      }

      if (!mounted) {
        return;
      }

      setState(() {
        _missionPhoto =
            photo;

        // Clear previous Gemini result
        // because this is a new image.
        _verificationResult =
        null;
      });
    } catch (error) {
      _showMessage(
        'Unable to capture mission photo: $error',
      );
    }
  }

  // ============================================================
  // UPLOAD PHOTO FROM GALLERY
  // ============================================================

  Future<void> _uploadPhoto() async {
    if (!_locationVerified) {
      _showMessage(
        'Please verify your location before uploading the mission photo.',
      );

      return;
    }

    try {
      final XFile? photo =
      await _imagePicker.pickImage(
        source:
        ImageSource.gallery,

        imageQuality:
        70,

        maxWidth:
        1600,

        maxHeight:
        1600,
      );

      if (photo == null) {
        return;
      }

      if (!mounted) {
        return;
      }

      setState(() {
        _missionPhoto =
            photo;

        // New image = previous verification no longer valid.
        _verificationResult =
        null;
      });
    } catch (error) {
      _showMessage(
        'Unable to upload mission photo: $error',
      );
    }
  }

  // ============================================================
  // SUBMIT MISSION
  // ============================================================

  Future<void> _submitMission() async {
    if (_submitting) {
      return;
    }

    // ----------------------------------------------------------
    // CHECK LOCATION
    // ----------------------------------------------------------

    if (!_locationVerified) {
      _showMessage(
        'Please verify your location first.',
      );

      return;
    }

    // ----------------------------------------------------------
    // CHECK PHOTO
    // ----------------------------------------------------------

    final XFile? photo =
        _missionPhoto;

    if (photo == null) {
      _showMessage(
        'Please take or upload a mission photo first.',
      );

      return;
    }

    setState(() {
      _submitting =
      true;

      _verificationResult =
      null;
    });

    try {
      // ========================================================
      // 1. SEND PHOTO TO EDGE FUNCTION + GEMINI
      // ========================================================

      final MissionVerificationResult verification =
      await _verificationService
          .verifyMissionPhoto(
        userMissionId:
        widget.userMissionId,

        photo:
        photo,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _verificationResult =
            verification;
      });

      // ========================================================
      // 2. GEMINI FAIL / UNCERTAIN
      // ========================================================

      if (!verification.passed) {
        await _showVerificationFailedDialog(
          verification,
        );

        return;
      }

      // ========================================================
      // 3. GEMINI PASS
      //
      // Edge Function already sets:
      // verification_result = VERIFIED
      //
      // Now complete mission and award EP.
      // ========================================================

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

      // ========================================================
      // 4. COMPLETION SCREEN
      // ========================================================

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) =>
              CompleteMissionScreen(
                title:
                widget.mission.missionName,

                reward:
                widget.mission.rewardPoints,

                totalPoints:
                totalPoints,

                // Actual submitted image
                photoPath:
                photo.path,

                // Gemini result
                verificationReason:
                verification.reason,

                verificationConfidence:
                verification.confidence,
              ),
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      _showMessage(
        error
            .toString()
            .replaceFirst(
          'Exception: ',
          '',
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _submitting =
          false;
        });
      }
    }
  }

  // ============================================================
  // GEMINI FAILED / UNCERTAIN DIALOG
  // ============================================================

  Future<void> _showVerificationFailedDialog(
      MissionVerificationResult verification,
      ) async {
    final bool uncertain =
        verification.uncertain;

    await showDialog<void>(
      context:
      context,

      barrierDismissible:
      false,

      builder:
          (
          BuildContext dialogContext,
          ) {
        return AlertDialog(
          backgroundColor:
          Colors.white,

          shape:
          RoundedRectangleBorder(
            borderRadius:
            BorderRadius.circular(
              22,
            ),
          ),

          icon:
          Container(
            width:
            58,

            height:
            58,

            decoration:
            BoxDecoration(
              color:
              uncertain
                  ? const Color(
                0xFFFFF7ED,
              )
                  : const Color(
                0xFFFEF2F2,
              ),

              shape:
              BoxShape.circle,
            ),

            child:
            Icon(
              uncertain
                  ? Icons
                  .help_outline_rounded
                  : Icons
                  .close_rounded,

              size:
              34,

              color:
              uncertain
                  ? const Color(
                0xFFF59E0B,
              )
                  : const Color(
                0xFFEF4444,
              ),
            ),
          ),

          title:
          Text(
            uncertain
                ? 'Photo Could Not Be Verified'
                : 'Mission Photo Rejected',

            textAlign:
            TextAlign.center,

            style:
            const TextStyle(
              color:
              Color(
                0xFF0F172A,
              ),

              fontWeight:
              FontWeight.w800,
            ),
          ),

          content:
          Column(
            mainAxisSize:
            MainAxisSize.min,

            crossAxisAlignment:
            CrossAxisAlignment.start,

            children: [
              const Text(
                'Gemini Verification Result',

                style:
                TextStyle(
                  color:
                  Color(
                    0xFF64748B,
                  ),

                  fontSize:
                  11,

                  fontWeight:
                  FontWeight.w700,
                ),
              ),

              const SizedBox(
                height:
                7,
              ),

              Text(
                verification.reason,

                style:
                const TextStyle(
                  color:
                  Color(
                    0xFF334155,
                  ),

                  fontSize:
                  14,

                  height:
                  1.5,
                ),
              ),

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
                  const Color(
                    0xFFF8FAFC,
                  ),

                  borderRadius:
                  BorderRadius.circular(
                    12,
                  ),
                ),

                child:
                Row(
                  children: [
                    const Icon(
                      Icons
                          .psychology_alt_outlined,

                      size:
                      18,

                      color:
                      Color(
                        0xFF64748B,
                      ),
                    ),

                    const SizedBox(
                      width:
                      7,
                    ),

                    Text(
                      'Confidence: '
                          '${(verification.confidence * 100).toStringAsFixed(0)}%',

                      style:
                      const TextStyle(
                        color:
                        Color(
                          0xFF64748B,
                        ),

                        fontSize:
                        12,

                        fontWeight:
                        FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(
                height:
                14,
              ),

              const Text(
                'Please retake or upload another photo that clearly follows the mission requirement.',

                style:
                TextStyle(
                  color:
                  Color(
                    0xFF475569,
                  ),

                  fontSize:
                  12,

                  height:
                  1.4,
                ),
              ),
            ],
          ),

          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(
                  dialogContext,
                );
              },

              child:
              const Text(
                'CANCEL',
              ),
            ),

            ElevatedButton.icon(
              onPressed: () {
                Navigator.pop(
                  dialogContext,
                );

                _showPhotoSourceDialog();
              },

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

              icon:
              const Icon(
                Icons
                    .add_a_photo_rounded,
              ),

              label:
              const Text(
                'CHOOSE PHOTO',
              ),
            ),
          ],
        );
      },
    );
  }

  // ============================================================
  // PHOTO SOURCE DIALOG
  // ============================================================

  Future<void> _showPhotoSourceDialog() async {
    if (!_locationVerified) {
      _showMessage(
        'Please verify your location first.',
      );

      return;
    }

    await showModalBottomSheet<void>(
      context:
      context,

      backgroundColor:
      Colors.transparent,

      builder:
          (
          BuildContext sheetContext,
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
              20,
            ),

            decoration:
            BoxDecoration(
              color:
              Colors.white,

              borderRadius:
              BorderRadius.circular(
                24,
              ),
            ),

            child:
            Column(
              mainAxisSize:
              MainAxisSize.min,

              children: [
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

                const SizedBox(
                  height:
                  20,
                ),

                const Text(
                  'Choose Mission Photo',

                  style:
                  TextStyle(
                    color:
                    Color(
                      0xFF0F172A,
                    ),

                    fontSize:
                    18,

                    fontWeight:
                    FontWeight.w800,
                  ),
                ),

                const SizedBox(
                  height:
                  18,
                ),

                ListTile(
                  leading:
                  const CircleAvatar(
                    backgroundColor:
                    Color(
                      0xFFE0F2FE,
                    ),

                    child:
                    Icon(
                      Icons
                          .camera_alt_rounded,

                      color:
                      Color(
                        0xFF0284C7,
                      ),
                    ),
                  ),

                  title:
                  const Text(
                    'Take Photo',

                    style:
                    TextStyle(
                      fontWeight:
                      FontWeight.w700,
                    ),
                  ),

                  subtitle:
                  const Text(
                    'Use your phone camera',
                  ),

                  onTap: () {
                    Navigator.pop(
                      sheetContext,
                    );

                    _capturePhoto();
                  },
                ),

                const Divider(),

                ListTile(
                  leading:
                  const CircleAvatar(
                    backgroundColor:
                    Color(
                      0xFFECFDF5,
                    ),

                    child:
                    Icon(
                      Icons
                          .photo_library_rounded,

                      color:
                      Color(
                        0xFF059669,
                      ),
                    ),
                  ),

                  title:
                  const Text(
                    'Upload Photo',

                    style:
                    TextStyle(
                      fontWeight:
                      FontWeight.w700,
                    ),
                  ),

                  subtitle:
                  const Text(
                    'Choose a photo from gallery',
                  ),

                  onTap: () {
                    Navigator.pop(
                      sheetContext,
                    );

                    _uploadPhoto();
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ============================================================
  // SNACKBAR
  // ============================================================

  void _showMessage(
      String message,
      ) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(
      context,
    )
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior:
          SnackBarBehavior.floating,

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
      const Color(
        0xFFF8FAFC,
      ),

      appBar:
      AppBar(
        backgroundColor:
        Colors.white,

        surfaceTintColor:
        Colors.white,

        elevation:
        0,

        leading:
        IconButton(
          onPressed:
          _submitting
              ? null
              : () {
            Navigator.pop(
              context,
            );
          },

          icon:
          const Icon(
            Icons
                .arrow_back_ios_new_rounded,

            color:
            Color(
              0xFF0F172A,
            ),
          ),
        ),

        title:
        const Text(
          'Complete Mission',

          style:
          TextStyle(
            color:
            Color(
              0xFF0F172A,
            ),

            fontSize:
            19,

            fontWeight:
            FontWeight.w800,
          ),
        ),

        centerTitle:
        true,
      ),

      body:
      SafeArea(
        child:
        SingleChildScrollView(
          padding:
          const EdgeInsets.fromLTRB(
            18,
            18,
            18,
            30,
          ),

          child:
          Column(
            crossAxisAlignment:
            CrossAxisAlignment.stretch,

            children: [
              // =================================================
              // MISSION HEADER
              // =================================================

              _buildMissionHeader(),

              const SizedBox(
                height:
                16,
              ),

              // =================================================
              // LOCATION
              // =================================================

              _buildLocationCard(),

              const SizedBox(
                height:
                16,
              ),

              // =================================================
              // PHOTO
              // =================================================

              _buildPhotoCard(),

              // =================================================
              // GEMINI RESULT
              // =================================================

              if (_verificationResult !=
                  null) ...[
                const SizedBox(
                  height:
                  16,
                ),

                _buildGeminiResultCard(),
              ],

              const SizedBox(
                height:
                22,
              ),

              // =================================================
              // SUBMIT BUTTON
              // =================================================

              SizedBox(
                width:
                double.infinity,

                child:
                ElevatedButton(
                  onPressed:
                  _submitting
                      ? null
                      : _submitMission,

                  style:
                  ElevatedButton
                      .styleFrom(
                    backgroundColor:
                    const Color(
                      0xFF0284C7,
                    ),

                    foregroundColor:
                    Colors.white,

                    disabledBackgroundColor:
                    const Color(
                      0xFF94A3B8,
                    ),

                    padding:
                    const EdgeInsets
                        .symmetric(
                      vertical:
                      16,
                    ),

                    elevation:
                    0,

                    shape:
                    RoundedRectangleBorder(
                      borderRadius:
                      BorderRadius.circular(
                        16,
                      ),
                    ),
                  ),

                  child:
                  _submitting
                      ? const Row(
                    mainAxisAlignment:
                    MainAxisAlignment.center,

                    children: [
                      SizedBox(
                        width:
                        20,

                        height:
                        20,

                        child:
                        CircularProgressIndicator(
                          strokeWidth:
                          2,

                          color:
                          Colors.white,
                        ),
                      ),

                      SizedBox(
                        width:
                        10,
                      ),

                      Text(
                        'GEMINI IS VERIFYING...',

                        style:
                        TextStyle(
                          fontWeight:
                          FontWeight.w800,
                        ),
                      ),
                    ],
                  )
                      : const Row(
                    mainAxisAlignment:
                    MainAxisAlignment.center,

                    children: [
                      Icon(
                        Icons.verified_rounded,
                      ),

                      SizedBox(
                        width:
                        8,
                      ),

                      Text(
                        'SUBMIT MISSION',

                        style:
                        TextStyle(
                          fontWeight:
                          FontWeight.w800,
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
    );
  }

  // ============================================================
  // MISSION HEADER
  // ============================================================

  Widget _buildMissionHeader() {
    return Container(
      padding:
      const EdgeInsets.all(
        20,
      ),

      decoration:
      BoxDecoration(
        gradient:
        const LinearGradient(
          colors: [
            Color(
              0xFF0284C7,
            ),
            Color(
              0xFF0369A1,
            ),
          ],

          begin:
          Alignment.topLeft,

          end:
          Alignment.bottomRight,
        ),

        borderRadius:
        BorderRadius.circular(
          24,
        ),

        boxShadow:
        const [
          BoxShadow(
            color:
            Color(
              0x280284C7,
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
      Column(
        crossAxisAlignment:
        CrossAxisAlignment.start,

        children: [
          Row(
            children: [
              Container(
                padding:
                const EdgeInsets.symmetric(
                  horizontal:
                  10,

                  vertical:
                  5,
                ),

                decoration:
                BoxDecoration(
                  color:
                  const Color(
                    0x33FFFFFF,
                  ),

                  borderRadius:
                  BorderRadius.circular(
                    20,
                  ),
                ),

                child:
                const Text(
                  'ACTIVE MISSION',

                  style:
                  TextStyle(
                    color:
                    Colors.white,

                    fontSize:
                    10,

                    fontWeight:
                    FontWeight.w800,

                    letterSpacing:
                    0.8,
                  ),
                ),
              ),

              const Spacer(),

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
                    0xFFFDE68A,
                  ),

                  borderRadius:
                  BorderRadius.circular(
                    20,
                  ),
                ),

                child:
                Text(
                  '+${widget.mission.rewardPoints} EP',

                  style:
                  const TextStyle(
                    color:
                    Color(
                      0xFF92400E,
                    ),

                    fontSize:
                    11,

                    fontWeight:
                    FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(
            height:
            16,
          ),

          Text(
            widget.mission
                .missionName,

            style:
            const TextStyle(
              color:
              Colors.white,

              fontSize:
              22,

              fontWeight:
              FontWeight.w900,
            ),
          ),

          const SizedBox(
            height:
            7,
          ),

          Row(
            children: [
              const Icon(
                Icons
                    .location_on_outlined,

                color:
                Color(
                  0xFFE0F2FE,
                ),

                size:
                17,
              ),

              const SizedBox(
                width:
                5,
              ),

              Expanded(
                child:
                Text(
                  widget.destination.name,

                  style:
                  const TextStyle(
                    color:
                    Color(
                      0xFFE0F2FE,
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
                  _locationVerified
                      ? const Color(
                    0xFFECFDF5,
                  )
                      : const Color(
                    0xFFE0F2FE,
                  ),

                  borderRadius:
                  BorderRadius.circular(
                    12,
                  ),
                ),

                child:
                Icon(
                  _locationVerified
                      ? Icons
                      .check_circle_rounded
                      : Icons
                      .my_location_rounded,

                  color:
                  _locationVerified
                      ? const Color(
                    0xFF059669,
                  )
                      : const Color(
                    0xFF0284C7,
                  ),
                ),
              ),

              const SizedBox(
                width:
                11,
              ),

              const Expanded(
                child:
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
                    FontWeight.w800,
                  ),
                ),
              ),

              Text(
                '${widget.mission.verificationRadiusM} m',

                style:
                const TextStyle(
                  color:
                  Color(
                    0xFF64748B,
                  ),

                  fontSize:
                  12,

                  fontWeight:
                  FontWeight.w600,
                ),
              ),
            ],
          ),

          if (_distanceMetres !=
              null) ...[
            const SizedBox(
              height:
              14,
            ),

            Text(
              'Current distance: '
                  '${_distanceMetres!.toStringAsFixed(0)} metres',

              style:
              const TextStyle(
                color:
                Color(
                  0xFF334155,
                ),

                fontSize:
                13,

                fontWeight:
                FontWeight.w600,
              ),
            ),
          ],

          if (_locationMessage !=
              null) ...[
            const SizedBox(
              height:
              8,
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
                  0xFFECFDF5,
                )
                    : const Color(
                  0xFFFFFBEB,
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
                    0xFF047857,
                  )
                      : const Color(
                    0xFF92400E,
                  ),

                  fontSize:
                  12,

                  height:
                  1.4,

                  fontWeight:
                  FontWeight.w600,
                ),
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
              _checkingLocation ||
                  _submitting
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
                    .my_location_rounded,
              ),

              label:
              Text(
                _locationVerified
                    ? 'VERIFY LOCATION AGAIN'
                    : 'VERIFY MY LOCATION',
              ),

              style:
              OutlinedButton
                  .styleFrom(
                foregroundColor:
                const Color(
                  0xFF0284C7,
                ),

                side:
                const BorderSide(
                  color:
                  Color(
                    0xFF0284C7,
                  ),
                ),

                padding:
                const EdgeInsets
                    .symmetric(
                  vertical:
                  13,
                ),

                shape:
                RoundedRectangleBorder(
                  borderRadius:
                  BorderRadius.circular(
                    13,
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
  // PHOTO CARD
  // ============================================================

  Widget _buildPhotoCard() {
    return Container(
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
                  0xFF0284C7,
                ),
              ),

              SizedBox(
                width:
                9,
              ),

              Text(
                'Mission Evidence',

                style:
                TextStyle(
                  color:
                  Color(
                    0xFF0F172A,
                  ),

                  fontSize:
                  15,

                  fontWeight:
                  FontWeight.w800,
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
                'Capture or upload a clear photo that satisfies the mission requirement.',

            style:
            const TextStyle(
              color:
              Color(
                0xFF64748B,
              ),

              fontSize:
              12,

              height:
              1.5,
            ),
          ),

          const SizedBox(
            height:
            15,
          ),

          // ----------------------------------------------------
          // PHOTO PREVIEW
          // ----------------------------------------------------

          if (_missionPhoto != null) ...[
            ClipRRect(
              borderRadius:
              BorderRadius.circular(
                16,
              ),

              child:
              Image.file(
                File(
                  _missionPhoto!.path,
                ),

                width:
                double.infinity,

                height:
                220,

                fit:
                BoxFit.cover,
              ),
            ),

            const SizedBox(
              height:
              13,
            ),
          ] else
            Container(
              width:
              double.infinity,

              height:
              145,

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
                MainAxisAlignment.center,

                children: [
                  Icon(
                    Icons
                        .add_a_photo_outlined,

                    size:
                    40,

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
                    'No mission photo selected',

                    style:
                    TextStyle(
                      color:
                      Color(
                        0xFF64748B,
                      ),

                      fontSize:
                      12,
                    ),
                  ),
                ],
              ),
            ),

          const SizedBox(
            height:
            14,
          ),

          // ----------------------------------------------------
          // CAMERA + UPLOAD BUTTONS
          // ----------------------------------------------------

          Row(
            children: [
              Expanded(
                child:
                ElevatedButton.icon(
                  onPressed:
                  _locationVerified &&
                      !_submitting
                      ? _capturePhoto
                      : null,

                  icon:
                  const Icon(
                    Icons
                        .camera_alt_outlined,

                    size:
                    17,
                  ),

                  label:
                  Text(
                    _missionPhoto ==
                        null
                        ? 'TAKE PHOTO'
                        : 'RETAKE',
                  ),

                  style:
                  ElevatedButton
                      .styleFrom(
                    backgroundColor:
                    const Color(
                      0xFFE0F2FE,
                    ),

                    foregroundColor:
                    const Color(
                      0xFF0284C7,
                    ),

                    elevation:
                    0,

                    padding:
                    const EdgeInsets
                        .symmetric(
                      vertical:
                      13,
                    ),

                    textStyle:
                    const TextStyle(
                      fontSize:
                      11,

                      fontWeight:
                      FontWeight.w700,
                    ),

                    shape:
                    RoundedRectangleBorder(
                      borderRadius:
                      BorderRadius.circular(
                        13,
                      ),
                    ),
                  ),
                ),
              ),

              const SizedBox(
                width:
                9,
              ),

              Expanded(
                child:
                ElevatedButton.icon(
                  onPressed:
                  _locationVerified &&
                      !_submitting
                      ? _uploadPhoto
                      : null,

                  icon:
                  const Icon(
                    Icons
                        .photo_library_outlined,

                    size:
                    17,
                  ),

                  label:
                  const Text(
                    'UPLOAD PHOTO',
                  ),

                  style:
                  ElevatedButton
                      .styleFrom(
                    backgroundColor:
                    const Color(
                      0xFFECFDF5,
                    ),

                    foregroundColor:
                    const Color(
                      0xFF059669,
                    ),

                    elevation:
                    0,

                    padding:
                    const EdgeInsets
                        .symmetric(
                      vertical:
                      13,
                    ),

                    textStyle:
                    const TextStyle(
                      fontSize:
                      10.5,

                      fontWeight:
                      FontWeight.w700,
                    ),

                    shape:
                    RoundedRectangleBorder(
                      borderRadius:
                      BorderRadius.circular(
                        13,
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
  // GEMINI RESULT CARD
  // ============================================================

  Widget _buildGeminiResultCard() {
    final MissionVerificationResult verification =
    _verificationResult!;

    final bool passed =
        verification.passed;

    final bool uncertain =
        verification.uncertain;

    Color background;
    Color border;
    Color iconColor;

    if (passed) {
      background =
      const Color(
        0xFFECFDF5,
      );

      border =
      const Color(
        0xFFA7F3D0,
      );

      iconColor =
      const Color(
        0xFF059669,
      );
    } else if (uncertain) {
      background =
      const Color(
        0xFFFFFBEB,
      );

      border =
      const Color(
        0xFFFDE68A,
      );

      iconColor =
      const Color(
        0xFFD97706,
      );
    } else {
      background =
      const Color(
        0xFFFEF2F2,
      );

      border =
      const Color(
        0xFFFECACA,
      );

      iconColor =
      const Color(
        0xFFDC2626,
      );
    }

    return Container(
      padding:
      const EdgeInsets.all(
        16,
      ),

      decoration:
      BoxDecoration(
        color:
        background,

        borderRadius:
        BorderRadius.circular(
          18,
        ),

        border:
        Border.all(
          color:
          border,
        ),
      ),

      child:
      Row(
        crossAxisAlignment:
        CrossAxisAlignment.start,

        children: [
          Icon(
            passed
                ? Icons
                .verified_rounded
                : uncertain
                ? Icons
                .help_outline_rounded
                : Icons
                .cancel_rounded,

            color:
            iconColor,
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
                  passed
                      ? 'Gemini Verified'
                      : uncertain
                      ? 'Verification Uncertain'
                      : 'Photo Rejected',

                  style:
                  TextStyle(
                    color:
                    iconColor,

                    fontWeight:
                    FontWeight.w800,
                  ),
                ),

                const SizedBox(
                  height:
                  5,
                ),

                Text(
                  verification.reason,

                  style:
                  const TextStyle(
                    color:
                    Color(
                      0xFF475569,
                    ),

                    fontSize:
                    12,

                    height:
                    1.4,
                  ),
                ),

                const SizedBox(
                  height:
                  6,
                ),

                Text(
                  'Confidence: '
                      '${(verification.confidence * 100).toStringAsFixed(0)}%',

                  style:
                  const TextStyle(
                    color:
                    Color(
                      0xFF64748B,
                    ),

                    fontSize:
                    10,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // CARD STYLE
  // ============================================================

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

      boxShadow:
      const [
        BoxShadow(
          color:
          Color(
            0x0D000000,
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
    );
  }
}