import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../application/controller/BlindBox_Controller.dart';
import '../../../data/models/blind_box_history.dart';
import '../home/home_screen.dart';
import '../checkpoint/checkpoint_screen.dart';
import 'package:flutter/services.dart';
import '../plan/plan_screen.dart';
import '../profile/leaderboard_screen.dart';
import '../group/chat_list_screen.dart';
import '../profile/profile_screen.dart';
import '../group/group_screen.dart';

import 'package:mysterylane/application/services/blind_box_mission_generation_service.dart';

import '../checkpoint/checkpoint_mission_screen.dart';

enum MysteryLaneTab {
  blindBox,
  missions,
  home,
  plan,
  teams,
}

class BlindBoxDestinationUi {
  final String id;
  final String title;
  final String tag;
  final String distance;
  final String lore;
  final String difficulty;
  final String imageUrl;
  final String locationName;
  final double? rating;
  final int? userRatingCount;

  const BlindBoxDestinationUi({
    required this.id,
    required this.title,
    required this.tag,
    required this.distance,
    required this.lore,
    required this.difficulty,
    required this.imageUrl,
    required this.locationName,
    required this.rating,
    required this.userRatingCount
  });
}

class BlindBoxHistoryUi extends BlindBoxDestinationUi {
  final String drawnAtDate;
  final String drawnAtTime;

  // Needed when starting a checkpoint mission from history.
  final String destinationId;
  final String rawCategory;
  final double latitude;
  final double longitude;

  const BlindBoxHistoryUi({
    required super.id,
    required super.title,
    required super.tag,
    required super.distance,
    required super.lore,
    required super.difficulty,
    required super.imageUrl,
    required super.locationName,
    required super.rating,
    required super.userRatingCount,
    required this.drawnAtDate,
    required this.drawnAtTime,

    // Defaults keep older code compiling.
    this.destinationId = '',
    this.rawCategory = 'unknown',
    this.latitude = 0,
    this.longitude = 0,
  });
}

class BlindBoxPage extends StatefulWidget {
  // Legacy values kept only so older HomeScreen calls still compile.
  // The real values are loaded from the authenticated user's Supabase profile.
  final int? userEp;
  final int? blindBoxChances;

  /// Presentation depends only on the Application/Logic layer.
  /// If no controller is injected, production() is used.
  final BlindBoxController? controller;

  /// New user: null until a real Google Places result is returned.
  final BlindBoxDestinationUi? currentDestination;

  /// Later this list should be loaded from Supabase through Logic/Data layers.
  /// New users start with an empty history.
  final List<BlindBoxHistoryUi> history;

  /// Presentation-only callbacks.
  final VoidCallback? onBack;
  final VoidCallback? onBuyChanceRequested;
  final ValueChanged<BlindBoxDestinationUi>? onStartMission;
  final ValueChanged<MysteryLaneTab>? onBottomNavTap;

  const BlindBoxPage({
    super.key,
    this.userEp,
    this.blindBoxChances,
    this.controller,
    this.currentDestination,
    this.history = const [],
    this.onBack,
    this.onBuyChanceRequested,
    this.onStartMission,
    this.onBottomNavTap,
  });

  @override
  State<BlindBoxPage> createState() => _BlindBoxPageState();
}

class _BlindBoxPageState extends State<BlindBoxPage> {
  static const Color _primary = Color(0xFF0284C7);
  static const Color _pageBg = Color(0xFFF8FAFC);
  static const Color _slate900 = Color(0xFF0F172A);
  static const Color _slate700 = Color(0xFF334155);
  static const Color _slate500 = Color(0xFF64748B);
  static const Color _sky50 = Color(0xFFF0F9FF);
  static const Color _sky100 = Color(0xFFE0F2FE);
  static const Color _sky200 = Color(0xFFBAE6FD);

  late final BlindBoxController _controller;
  late final bool _ownsController;

  /// UI-only state.
  bool _showResult = false;
  bool _historyTab = false;
  bool _isDrawing = false;
  bool _isLoadingHistory = false;
  bool _isLoadingBalance = true;
  bool _isBuyingChance = false;

  double _radiusKm = 12;
  int _userEp = 0;
  int _blindBoxChances = 0;

  BlindBoxDestinationUi? _currentDestination;

  /// Keeps the real Google Places result for the currently revealed
  /// destination. The UI model only stores display fields, while Gemini
  /// mission generation needs the original place id / coordinates / type.
  BlindBoxResult? _currentBlindBoxResult;

  List<BlindBoxHistoryUi> _history = [];

  // Draw History date filter. Null means show all dates.
  DateTime? _selectedHistoryDate;

  // Header profile image so the Blind Box top bar matches Checkpoint.
  String? _headerProfilePictureUrl;

  TextStyle get _heading => const TextStyle(
    color: _slate900,
    fontWeight: FontWeight.w900,
  );

  TextStyle get _bodyStyle => const TextStyle();

  @override
  void initState() {
    super.initState();

    _ownsController = widget.controller == null;
    _controller = widget.controller ?? BlindBoxController.production();
    _currentDestination = widget.currentDestination;
    _showResult = _currentDestination != null;
    _history = List<BlindBoxHistoryUi>.from(widget.history);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _loadBlindBoxBalance();
        _loadBlindBoxHistory();
        _loadHeaderProfile();
      }
    });
  }

  @override
  void didUpdateWidget(covariant BlindBoxPage oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.currentDestination?.id != widget.currentDestination?.id) {
      _currentDestination = widget.currentDestination;
      _currentBlindBoxResult = null;
      _showResult = _currentDestination != null;
    }
  }

  @override
  void dispose() {
    if (_ownsController) {
      _controller.dispose();
    }
    super.dispose();
  }

  // ==========================================================================
  // TOP BAR PROFILE
  // ==========================================================================

  Future<void> _loadHeaderProfile() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return;

      final profile = await Supabase.instance.client
          .from('profiles')
          .select('profile_picture_url')
          .eq('id', user.id)
          .maybeSingle();

      if (!mounted) return;

      final picture = profile?['profile_picture_url']?.toString().trim();

      setState(() {
        _headerProfilePictureUrl =
        (picture != null && picture.isNotEmpty) ? picture : null;
      });
    } catch (error) {
      debugPrint('[BLIND BOX UI] Header profile error: $error');
    }
  }

  void _openHomeFromTopBar() {
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const HomeScreen()),
          (route) => false,
    );
  }

  void _openLeaderboardFromTopBar() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const LeaderboardScreen()),
    );
  }

  void _openChatFromTopBar() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ChatListScreen()),
    );
  }

  Future<void> _openProfileFromTopBar() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ProfileScreen()),
    );

    // The user may have changed the profile picture.
    await _loadHeaderProfile();
  }

  PreferredSizeWidget _buildTopAppBar() {
    return AppBar(
      automaticallyImplyLeading: false,
      toolbarHeight: 68,
      elevation: 0,
      scrolledUnderElevation: 2,
      backgroundColor: Colors.white.withValues(alpha: 0.97),
      surfaceTintColor: Colors.white,
      titleSpacing: 12,

      title: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: _openHomeFromTopBar,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            children: [
              const _BlindBoxMysteryLaneLogo(),
              const SizedBox(width: 8),
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: const Text(
                    'MYSTERYLANE',
                    maxLines: 1,
                    style: TextStyle(
                      color: _slate900,
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
        _BlindBoxTopActionButton(
          tooltip: 'Leaderboard',
          icon: Icons.emoji_events_rounded,
          background: const Color(0xFFFFFBEB),
          foreground: const Color(0xFFD97706),
          onTap: _openLeaderboardFromTopBar,
        ),
        const SizedBox(width: 4),
        _BlindBoxTopActionButton(
          tooltip: 'Chat',
          icon: Icons.chat_bubble_outline_rounded,
          background: const Color(0xFFF0F9FF),
          foreground: _primary,
          onTap: _openChatFromTopBar,
        ),
        const SizedBox(width: 4),
        _BlindBoxProfileButton(
          onTap: _openProfileFromTopBar,
          imageUrl: _headerProfilePictureUrl,
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

  // ==========================================================================
  // DRAW HISTORY DATE FILTER
  // ==========================================================================

  List<BlindBoxHistoryUi> get _filteredHistory {
    final selectedDate = _selectedHistoryDate;

    if (selectedDate == null) {
      return _history;
    }

    return _history.where((item) {
      final parts = item.drawnAtDate.split('/');
      if (parts.length != 3) return false;

      final day = int.tryParse(parts[0]);
      final month = int.tryParse(parts[1]);
      final year = int.tryParse(parts[2]);

      if (day == null || month == null || year == null) {
        return false;
      }

      return selectedDate.day == day &&
          selectedDate.month == month &&
          selectedDate.year == year;
    }).toList(growable: false);
  }

  Future<void> _pickHistoryDate() async {
    final now = DateTime.now();

    final selected = await showDatePicker(
      context: context,
      initialDate: _selectedHistoryDate ?? now,
      firstDate: DateTime(2020),
      lastDate: now,
      helpText: 'Filter Draw History',
      confirmText: 'FILTER',
      cancelText: 'CANCEL',
    );

    if (selected == null || !mounted) return;

    setState(() {
      _selectedHistoryDate = DateTime(
        selected.year,
        selected.month,
        selected.day,
      );
    });
  }

  void _clearHistoryDateFilter() {
    setState(() {
      _selectedHistoryDate = null;
    });
  }

  String _formatSelectedHistoryDate(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    return '$day/$month/${date.year}';
  }

  Future<void> _loadBlindBoxBalance({
    bool showError = false,
  }) async {
    if (mounted) {
      setState(() => _isLoadingBalance = true);
    }

    try {
      final balance = await _controller.loadBlindBoxBalance();

      if (!mounted) return;

      setState(() {
        _userEp = balance.explorationPoints;
        _blindBoxChances = balance.chances;
        _isLoadingBalance = false;
      });
    } catch (error) {
      if (!mounted) return;

      setState(() => _isLoadingBalance = false);

      if (showError) {
        _showError(error);
      }

      debugPrint(
        '[BLIND BOX UI] Balance load error: $error',
      );
    }
  }

  Future<bool> _buyBlindBoxChances({
    required int quantity,
  }) async {
    if (_isBuyingChance) {
      return false;
    }

    if (quantity < 1) {
      _showError(
        const BlindBoxException(
          'Please select at least '
              '1 Blind Box Chance.',
        ),
      );

      return false;
    }

    setState(() {
      _isBuyingChance = true;
    });

    try {
      final balance =
      await _controller
          .buyBlindBoxChances(
        quantity: quantity,
      );

      if (!mounted) {
        return false;
      }

      // ============================================================
      // UPDATE MAIN BLIND BOX BALANCE
      // ============================================================

      setState(() {
        _userEp =
            balance.explorationPoints;

        _blindBoxChances =
            balance.chances;
      });

      final String chanceWord =
      quantity == 1
          ? 'chance'
          : 'chances';

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            behavior:
            SnackBarBehavior.floating,

            content: Text(
              '$quantity Blind Box '
                  '$chanceWord added successfully.',
            ),
          ),
        );

      // IMPORTANT:
      // true = database purchase succeeded.
      return true;
    } catch (error) {
      if (!mounted) {
        return false;
      }

      _showError(error);

      return false;
    } finally {
      if (mounted) {
        setState(() {
          _isBuyingChance = false;
        });
      }
    }
  }

  Future<void> _drawBlindBox() async {
    if (_isDrawing || _isLoadingBalance) return;

    if (_blindBoxChances <= 0) {
      await _showChanceDialog();
      return;
    }

    setState(() => _isDrawing = true);

    try {
      final recentIds = _history.map((item) => item.id).toSet();

      final result = await _controller.drawBlindBox(
        radiusKm: _radiusKm,
        recentPlaceIds: recentIds,
      );

      if (!mounted) return;

      setState(() {
        _currentBlindBoxResult = result;
        _currentDestination = _mapResultToUi(result);
        _showResult = true;
      });

      await _loadBlindBoxBalance();
      await _loadBlindBoxHistory();
    } catch (error) {
      if (!mounted) return;
      _showError(error);
    } finally {
      if (mounted) {
        setState(() => _isDrawing = false);
      }
    }
  }

  Future<void> _redrawBlindBox() async {
    final current = _currentDestination;
    if (_isDrawing || _isLoadingBalance || current == null) return;

    if (_blindBoxChances <= 0) {
      await _showChanceDialog();
      return;
    }

    setState(() => _isDrawing = true);

    try {
      final recentIds = _history.map((item) => item.id).toSet();

      final result = await _controller.redrawBlindBox(
        radiusKm: _radiusKm,
        currentPlaceId: current.id,
        recentPlaceIds: recentIds,
      );

      if (!mounted) return;

      setState(() {
        _currentBlindBoxResult = result;
        _currentDestination = _mapResultToUi(result);
        _showResult = true;
      });

      await _loadBlindBoxBalance();
      await _loadBlindBoxHistory();
    } catch (error) {
      if (!mounted) return;
      _showError(error);
    } finally {
      if (mounted) {
        setState(() => _isDrawing = false);
      }
    }
  }

  Future<void> _loadBlindBoxHistory({
    bool showError = false,
  }) async {
    if (_isLoadingHistory) return;

    if (mounted) {
      setState(() => _isLoadingHistory = true);
    }

    try {
      final results = await _controller.loadBlindBoxHistory();

      debugPrint(
        '[BLIND BOX UI] History received: ${results.length}',
      );

      if (!mounted) return;

      setState(() {
        _history = results
            .map(_mapHistoryResultToUi)
            .toList(growable: false);
      });
    } catch (error) {
      debugPrint(
        '[BLIND BOX UI] History load error: $error',
      );

      if (showError && mounted) {
        _showError(error);
      }
    } finally {
      if (mounted) {
        setState(() => _isLoadingHistory = false);
      }
    }
  }

  BlindBoxHistoryUi _mapHistoryResultToUi(
      BlindBoxHistoryResult result,
      ) {
    final localTime =
    result.drawnAt.toLocal();

    return BlindBoxHistoryUi(
      // id here is the Google Place ID.
      id: result.placeId,

      destinationId:
      result.destinationId,

      title:
      result.name,

      tag:
      _formatPlaceType(
        result.category,
      ),

      rawCategory:
      result.category,

      latitude:
      result.latitude,

      longitude:
      result.longitude,

      distance:
      '${result.radiusKm.toStringAsFixed(0)} km radius',

      lore:
      result.description
          ?.trim()
          .isNotEmpty ==
          true
          ? result.description!
          : 'A mystery destination is waiting for you to explore.',

      difficulty:
      result.drawType == 'REDRAW'
          ? 'Redrawn destination'
          : 'Explore this destination',

      imageUrl:
      result.imageUrl ?? '',

      locationName:
      result.address
          .trim()
          .isNotEmpty
          ? result.address
          : '${result.latitude.toStringAsFixed(5)}, '
          '${result.longitude.toStringAsFixed(5)}',

      rating:
      result.rating,

      userRatingCount:
      result.userRatingCount,

      drawnAtDate:
      _formatHistoryDate(
        localTime,
      ),

      drawnAtTime:
      _formatHistoryTime(
        localTime,
      ),
    );
  }

  String _formatHistoryDate(DateTime dateTime) {
    final day = dateTime.day.toString().padLeft(2, '0');
    final month = dateTime.month.toString().padLeft(2, '0');
    return '$day/$month/${dateTime.year}';
  }

  String _formatHistoryTime(DateTime dateTime) {
    return MaterialLocalizations.of(context).formatTimeOfDay(
      TimeOfDay.fromDateTime(dateTime),
    );
  }

  BlindBoxDestinationUi _mapResultToUi(BlindBoxResult result) {
    return BlindBoxDestinationUi(
      id: result.placeId,
      title: result.name,
      tag: _formatPlaceType(result.primaryType),
      distance: '${result.distanceKm.toStringAsFixed(1)} km',
      lore:
      result.description?.trim().isNotEmpty == true
          ? result.description!
          : 'A mystery destination is waiting for you to explore.',
      difficulty: 'Explore this destination',
      imageUrl: result.imageUrl ?? '',
      rating: result.rating,
      userRatingCount: result.userRatingCount,
      locationName: result.formattedAddress.isEmpty
          ? '${result.latitude.toStringAsFixed(5)}, ${result.longitude.toStringAsFixed(5)}'
          : result.formattedAddress,
    );
  }

  String _formatPlaceType(String type) {
    if (type.trim().isEmpty || type == 'unknown') {
      return 'Discovery';
    }

    return type
        .split('_')
        .where((word) => word.isNotEmpty)
        .map((word) => '${word[0].toUpperCase()}${word.substring(1)}')
        .join(' ');
  }

  void _showError(Object error) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text(error.toString()),
        ),
      );
  }

  Future<void> _copyAddress(String address) async {
    if (address.trim().isEmpty) return;

    await Clipboard.setData(
      ClipboardData(text: address),
    );

    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text('Address copied to clipboard'),
        ),
      );
  }

  void _handleBack() {
    if (widget.onBack != null) {
      widget.onBack!.call();
      return;
    }

    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
  }

  void _replaceWith(Widget page) {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => page),
    );
  }

  void _handleBottomNavigation(MysteryLaneTab tab) {
    // Keep this inside the Presentation layer. No business/data logic here.
    if (widget.onBottomNavTap != null) {
      widget.onBottomNavTap!.call(tab);
      return;
    }

    switch (tab) {
      case MysteryLaneTab.blindBox:
      // Already on Blind Box. Return to the main Blind Box hub.
        setState(() {
          _showResult = false;
          _historyTab = false;
        });
        break;

      case MysteryLaneTab.missions:
        _replaceWith(const CheckpointScreen());
        break;

      case MysteryLaneTab.home:
      // If Blind Box was opened from Home, popping avoids creating
      // another duplicate HomeScreen in the navigation stack.
        if (Navigator.of(context).canPop()) {
          Navigator.of(context).pop();
        } else {
          _replaceWith(const HomeScreen());
        }
        break;

      case MysteryLaneTab.plan:
        _replaceWith(const PlanScreen());
        break;

      case MysteryLaneTab.teams:
        _replaceWith(const GroupScreen());
        break;
    }
  }

  // ==========================================================================
  // GEMINI CHECKPOINT MISSION GENERATION
  // ==========================================================================

  final BlindBoxMissionGenerationService _missionGenerationService =
  BlindBoxMissionGenerationService();

  bool _generatingCheckpointMission = false;

  Future<void> _generateAndOpenCheckpointMission() async {
    if (_generatingCheckpointMission) return;

    final uiDestination = _currentDestination;
    final place = _currentBlindBoxResult;

    if (uiDestination == null) {
      _showBlindBoxMessage('No Blind Box destination is currently selected.');
      return;
    }

    // Normal Blind Box draws always keep the original BlindBoxResult.
    // A destination injected externally through currentDestination does not.
    if (place == null) {
      if (widget.onStartMission != null) {
        widget.onStartMission!.call(uiDestination);
        return;
      }

      _showBlindBoxMessage(
        'This destination does not contain the Google Places data needed to generate a mission. Please draw a new Blind Box destination.',
      );
      return;
    }

    setState(() {
      _generatingCheckpointMission = true;
    });

    bool loadingDialogOpen = false;

    try {
      if (!mounted) return;

      loadingDialogOpen = true;
      showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) {
          return const PopScope(
            canPop: false,
            child: AlertDialog(
              content: Padding(
                padding: EdgeInsets.symmetric(vertical: 10),
                child: Row(
                  children: [
                    SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2.5),
                    ),
                    SizedBox(width: 16),
                    Expanded(
                      child: Text(
                        'Gemini is creating your checkpoint mission...',
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      );

      final generated = await _missionGenerationService.generateMissionForBlindBox(
        googlePlaceId: place.placeId,
        name: place.name,
        description: place.description,
        category: place.primaryType,
        imageUrl: place.imageUrl,
        latitude: place.latitude,
        longitude: place.longitude,
        formattedAddress: place.formattedAddress,
        rating: place.rating,
      );

      if (!mounted) return;

      if (loadingDialogOpen && Navigator.of(context, rootNavigator: true).canPop()) {
        Navigator.of(context, rootNavigator: true).pop();
        loadingDialogOpen = false;
      }

      debugPrint(
        '[BLIND BOX UI] Ready checkpoint mission: ${generated.missionId}',
      );

      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => CheckpointMissionScreen(
            destination: generated.destination,
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;

      if (loadingDialogOpen && Navigator.of(context, rootNavigator: true).canPop()) {
        Navigator.of(context, rootNavigator: true).pop();
        loadingDialogOpen = false;
      }

      _showBlindBoxMessage(
        error.toString().replaceFirst('Exception: ', ''),
      );
    } finally {
      if (mounted) {
        setState(() {
          _generatingCheckpointMission = false;
        });
      }
    }
  }

  Future<void> _generateAndOpenCheckpointMissionFromHistory(
      BlindBoxHistoryUi item,
      ) async {
    if (_generatingCheckpointMission) {
      return;
    }

    // item.id should contain the Google Place ID.
    if (item.id.trim().isEmpty) {
      if (!mounted) return;

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            behavior: SnackBarBehavior.floating,
            content: Text(
              'Google Place ID is missing for this destination.',
            ),
          ),
        );

      return;
    }

    setState(() {
      _generatingCheckpointMission = true;
    });

    bool loadingDialogOpen = false;

    try {
      // ==========================================================
      // SHOW LOADING
      // ==========================================================

      loadingDialogOpen = true;

      showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (_) {
          return const PopScope(
            canPop: false,
            child: AlertDialog(
              content: Padding(
                padding: EdgeInsets.symmetric(
                  vertical: 10,
                ),
                child: Row(
                  children: [
                    SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                      ),
                    ),
                    SizedBox(width: 16),
                    Expanded(
                      child: Text(
                        'Gemini is creating your checkpoint mission...',
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      );

      // ==========================================================
      // GENERATE / REUSE MISSION
      // ==========================================================

      debugPrint(
        '[HISTORY MISSION] Generating mission for ${item.title}',
      );

      debugPrint(
        '[HISTORY MISSION] Google Place ID: ${item.id}',
      );

      debugPrint(
        '[HISTORY MISSION] Coordinates: '
            '${item.latitude}, ${item.longitude}',
      );

      final generated =
      await _missionGenerationService
          .generateMissionForBlindBox(
        googlePlaceId: item.id,

        name: item.title,

        description: item.lore,

        category: item.rawCategory,

        imageUrl:
        item.imageUrl.trim().isEmpty
            ? null
            : item.imageUrl,

        latitude: item.latitude,

        longitude: item.longitude,

        formattedAddress: item.locationName,

        rating: item.rating,
      );

      if (!mounted) {
        return;
      }

      // ==========================================================
      // CLOSE LOADING
      // ==========================================================

      if (loadingDialogOpen) {
        Navigator.of(
          context,
          rootNavigator: true,
        ).pop();

        loadingDialogOpen = false;
      }

      debugPrint(
        '[HISTORY MISSION] Mission ready: '
            '${generated.missionId}',
      );

      debugPrint(
        '[HISTORY MISSION] Opening checkpoint map for '
            '${generated.destination.name}',
      );

      debugPrint(
        '[HISTORY MISSION] Destination ID: '
            '${generated.destination.destinationId}',
      );

      // ==========================================================
      // IMPORTANT:
      // OPEN MAP, NOT CheckpointMissionScreen
      //
      // The destination ID tells CheckpointScreen which pin
      // should be selected and focused.
      // ==========================================================

      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => CheckpointScreen(
            initialDestinationId:
            generated.destination.destinationId,
          ),
        ),
      );
    } catch (error) {
      debugPrint(
        '[HISTORY MISSION] ERROR: $error',
      );

      if (!mounted) {
        return;
      }

      if (loadingDialogOpen) {
        Navigator.of(
          context,
          rootNavigator: true,
        ).pop();

        loadingDialogOpen = false;
      }

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
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
    } finally {
      if (mounted) {
        setState(() {
          _generatingCheckpointMission = false;
        });
      }
    }
  }

  void _showBlindBoxMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text(message),
        ),
      );
  }



  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _pageBg,
      extendBody: false,
      appBar: _buildTopAppBar(),
      body: SafeArea(
        top: false,
        bottom: false,
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 28),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                child: (_showResult && _currentDestination != null)
                    ? _buildDestinationResult()
                    : _buildBlindBoxHub(),
              ),
            ),
          ),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      floatingActionButton: _HomeFloatingButton(
        onTap: () => _handleBottomNavigation(MysteryLaneTab.home),
      ),
      bottomNavigationBar: _MysteryLaneBottomBar(
        onTap: _handleBottomNavigation,
      ),
    );
  }


  // --------------------------------------------------------------------------
  // SCREEN 1 - BLIND BOX HUB
  // --------------------------------------------------------------------------

  Widget _buildBlindBoxHub() {
    return Column(
      key: const ValueKey('blind_box_hub'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildHubHeader(),
        const SizedBox(height: 10),
        _buildChanceBar(),
        const SizedBox(height: 22),
        _buildSubTabs(),
        const SizedBox(height: 22),
        if (_historyTab) _buildHistoryView() else _buildDrawView(),
      ],
    );
  }

  Widget _buildHubHeader() {
    return Row(
      children: [
        _RoundIconButton(
          icon: Icons.arrow_back_ios_new_rounded,
          onTap: _handleBack,
        ),
        Expanded(
          child: Text(
            'Blind Box Hub',
            textAlign: TextAlign.center,
            style: _heading.copyWith(fontSize: 25),
          ),
        ),
        _EpChip(ep: _userEp),
      ],
    );
  }

  Widget _buildChanceBar() {
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: _showChanceDialog,
      child: Container(
        constraints: const BoxConstraints(
          minHeight: 62,
        ),
        padding: const EdgeInsets.symmetric(
          horizontal: 10,
          vertical: 8,
        ),
        decoration: BoxDecoration(
          color: const Color(0xFFFFFBEB),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: const Color(0xFFFCD34D),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            // Gift icon
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: const Color(0xFFFFF1C2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.card_giftcard_rounded,
                size: 19,
                color: Color(0xFFD97706),
              ),
            ),

            const SizedBox(width: 8),

            // Middle text
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Blind Box Chances',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: _bodyStyle.copyWith(
                      fontSize: 12,
                      color: const Color(0xFF0F172A),
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _isLoadingBalance
                        ? 'Loading chances...'
                        : '$_blindBoxChances of 10 remaining',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: _bodyStyle.copyWith(
                      fontSize: 9.5,
                      color: const Color(0xFF92400E),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(width: 6),

            // GET button
            Flexible(
              flex: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFEA7900),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x22EA7900),
                      blurRadius: 5,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '+ BUY',
                      maxLines: 1,
                      style: _bodyStyle.copyWith(
                        fontSize: 9.5,
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.4,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      '200 EP EA',
                      maxLines: 1,
                      style: _bodyStyle.copyWith(
                        fontSize: 8.5,
                        color: const Color(0xFFFFF1C2),
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSubTabs() {
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: const Color(0xFFF0F9FF),
        borderRadius: BorderRadius.circular(19),
        border: Border.all(color: _sky200),
      ),
      child: Row(
        children: [
          Expanded(
            child: _SubTabButton(
              selected: !_historyTab,
              icon: Icons.casino_outlined,
              label: 'Draw Blind Box',
              badge: null,
              onTap: () => setState(() => _historyTab = false),
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: _SubTabButton(
              selected: _historyTab,
              icon: Icons.history_rounded,
              label: 'Draw History',
              badge: _history.length,
              onTap: () {
                setState(() => _historyTab = true);
                _loadBlindBoxHistory(showError: true);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDrawView() {
    return Container(
      padding: const EdgeInsets.fromLTRB(26, 30, 26, 26),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: const Color(0xFFDDE3EA)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x160F172A),
            blurRadius: 5,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  color: _sky50,
                  borderRadius: BorderRadius.circular(17),
                  border: Border.all(color: _sky200),
                ),
                child: const Icon(
                  Icons.explore_outlined,
                  color: _primary,
                  size: 31,
                ),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Exploration\nPerimeter',
                      style: _heading.copyWith(
                        fontSize: 23,
                        height: .93,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      'MYSTERY DESTINATION RADAR',
                      style: _bodyStyle.copyWith(
                        color: _primary,
                        fontSize: 9.5,
                        letterSpacing: 1.2,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding:
                const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
                decoration: BoxDecoration(
                  color: _sky100,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: _sky200),
                ),
                child: Text(
                  '${_radiusKm.round()} KM\nRADAR',
                  textAlign: TextAlign.center,
                  style: _bodyStyle.copyWith(
                    fontSize: 11.5,
                    height: 1.25,
                    fontWeight: FontWeight.w900,
                    color: _primary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 25),
          const Divider(height: 1, color: Color(0xFFE8EEF4)),
          const SizedBox(height: 24),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: const Color(0xFFA5DFF7),
              inactiveTrackColor: const Color(0xFFA5DFF7),
              trackHeight: 6,
              thumbColor: _primary,
              overlayColor: _primary.withOpacity(.10),
              thumbShape: const RoundSliderThumbShape(
                enabledThumbRadius: 12,
                elevation: 2,
              ),
              overlayShape:
              const RoundSliderOverlayShape(overlayRadius: 20),
            ),
            child: Slider(
              min: 5,
              max: 20,
              value: _radiusKm,
              onChanged: (value) => setState(() => _radiusKm = value),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 1),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '5 KM (Nearby Spots)',
                  style: _bodyStyle.copyWith(
                    color: const Color(0xFF8190B1),
                    fontSize: 9.5,
                  ),
                ),
                Text(
                  '20 KM (Extended Territory)',
                  style: _bodyStyle.copyWith(
                    color: const Color(0xFF8190B1),
                    fontSize: 9.5,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 27),
          _GradientActionButton(
            icon: _isDrawing
                ? Icons.travel_explore_rounded
                : Icons.casino_outlined,
            label: _isDrawing
                ? 'SEARCHING DESTINATION...'
                : 'DRAW MYSTERY BLIND BOX',
            onTap: _isDrawing ? () {} : _drawBlindBox,
          ),
        ],
      ),
    );
  }

  // --------------------------------------------------------------------------
  // SCREEN 2 - HISTORY
  // --------------------------------------------------------------------------

  Widget _buildHistoryView() {
    final filteredHistory = _filteredHistory;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Text(
                  'Blind Box Draw\nHistory',
                  style: _heading.copyWith(
                    fontSize: 24,
                    height: 1.15,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  '${filteredHistory.length} RECORDED\nDRAWS',
                  textAlign: TextAlign.right,
                  style: _bodyStyle.copyWith(
                    color: _slate500,
                    fontSize: 9.5,
                    letterSpacing: 1.2,
                    fontWeight: FontWeight.w700,
                    height: 1.55,
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 14),

        // Date filter
        Row(
          children: [
            Expanded(
              child: InkWell(
                onTap: _pickHistoryDate,
                borderRadius: BorderRadius.circular(15),
                child: Container(
                  height: 46,
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(15),
                    border: Border.all(
                      color: _selectedHistoryDate == null
                          ? const Color(0xFFE2E8F0)
                          : _primary,
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.calendar_month_rounded,
                        size: 19,
                        color: _primary,
                      ),
                      const SizedBox(width: 9),
                      Expanded(
                        child: Text(
                          _selectedHistoryDate == null
                              ? 'Filter by date'
                              : _formatSelectedHistoryDate(
                            _selectedHistoryDate!,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: _bodyStyle.copyWith(
                            color: _selectedHistoryDate == null
                                ? _slate500
                                : _slate900,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const Icon(
                        Icons.keyboard_arrow_down_rounded,
                        color: _slate500,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            if (_selectedHistoryDate != null) ...[
              const SizedBox(width: 8),
              InkWell(
                onTap: _clearHistoryDateFilter,
                borderRadius: BorderRadius.circular(15),
                child: Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(15),
                    border: Border.all(
                      color: const Color(0xFFE2E8F0),
                    ),
                  ),
                  child: const Icon(
                    Icons.close_rounded,
                    size: 20,
                    color: _slate700,
                  ),
                ),
              ),
            ],
          ],
        ),

        const SizedBox(height: 20),

        if (_isLoadingHistory && _history.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 40),
            child: Center(
              child: CircularProgressIndicator(
                color: _primary,
                strokeWidth: 2.5,
              ),
            ),
          )
        else if (_history.isEmpty)
          _buildEmptyHistory()
        else if (filteredHistory.isEmpty)
            _buildNoFilteredHistory()
          else ...[
              if (_isLoadingHistory)
                const Padding(
                  padding: EdgeInsets.only(bottom: 14),
                  child: LinearProgressIndicator(
                    color: _primary,
                    minHeight: 2,
                  ),
                ),
              ...filteredHistory.map(
                    (item) => Padding(
                  padding: const EdgeInsets.only(bottom: 13),
                  child: _HistoryCard(
                    item: item,
                    onTap: () => _showHistoryDialog(item),
                  ),
                ),
              ),
            ],
      ],
    );
  }

  Widget _buildEmptyHistory() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 38),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(27),
        border: Border.all(color: const Color(0xFFCBD5E1)),
      ),
      child: Column(
        children: [
          const Icon(Icons.history_rounded, color: _slate500, size: 38),
          const SizedBox(height: 10),
          Text(
            'No blind boxes drawn yet.',
            textAlign: TextAlign.center,
            style: _heading.copyWith(fontSize: 17),
          ),
          const SizedBox(height: 8),
          Text(
            'Draw a mystery blind box to start filling your history log.',
            textAlign: TextAlign.center,
            style: _bodyStyle.copyWith(
              fontSize: 11,
              color: _slate500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoFilteredHistory() {
    final selectedDate = _selectedHistoryDate;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 30,
        vertical: 38,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(27),
        border: Border.all(
          color: const Color(0xFFCBD5E1),
        ),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.calendar_month_outlined,
            color: _slate500,
            size: 38,
          ),
          const SizedBox(height: 10),
          Text(
            'No draws found',
            textAlign: TextAlign.center,
            style: _heading.copyWith(fontSize: 17),
          ),
          const SizedBox(height: 8),
          Text(
            selectedDate == null
                ? 'No Blind Box destinations match this filter.'
                : 'No Blind Box destinations were drawn on ${_formatSelectedHistoryDate(selectedDate)}.',
            textAlign: TextAlign.center,
            style: _bodyStyle.copyWith(
              fontSize: 11,
              color: _slate500,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 15),
          TextButton.icon(
            onPressed: _clearHistoryDateFilter,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Show All History'),
          ),
        ],
      ),
    );
  }

  // --------------------------------------------------------------------------
  // SCREEN 3 - DESTINATION REVEALED
  // --------------------------------------------------------------------------

  Widget _buildDestinationResult() {
    final destination = _currentDestination!;

    return Column(
      key: const ValueKey('destination_result'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            _RoundIconButton(
              icon: Icons.arrow_back_ios_new_rounded,
              onTap: () => setState(() => _showResult = false),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(right: 44),
                child: Text(
                  'Destination Revealed',
                  textAlign: TextAlign.center,
                  style: _heading.copyWith(fontSize: 20),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 23),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(25),
            border: Border.all(color: const Color(0xFFD9E1EA)),
            boxShadow: const [
              BoxShadow(
                color: Color(0x1A0F172A),
                blurRadius: 8,
                offset: Offset(0, 3),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              _DestinationHero(destination: destination),
              Padding(
                padding: const EdgeInsets.fromLTRB(22, 24, 22, 21),
                child: Column(
                  children: [
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F9FD),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: const Color(0xFFD9ECF6)),
                      ),
                      child: Text(
                        '"${destination.lore}"',
                        style: const TextStyle(
                          fontSize: 13.5,
                          fontStyle: FontStyle.italic,
                          height: 1.55,
                          color: _slate700,
                        ),
                      ),
                    ),
                    const SizedBox(height: 19),
                    const Divider(height: 1, color: Color(0xFFE8EEF4)),
                    const SizedBox(height: 14),

                    // Explore this destination
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.explore_outlined,
                          color: _primary,
                          size: 17,
                        ),
                        const SizedBox(width: 7),
                        Expanded(
                          child: Text(
                            destination.difficulty,
                            style: _bodyStyle.copyWith(
                              color: _slate900,
                              fontSize: 11.8,
                              height: 1.25,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 12),

                    // Address + working copy button
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: const Color(0xFFE2E8F0),
                        ),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.location_on,
                            color: Color(0xFFEC4899),
                            size: 18,
                          ),
                          const SizedBox(width: 9),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Address',
                                  style: _bodyStyle.copyWith(
                                    color: _slate500,
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  destination.locationName,
                                  style: _bodyStyle.copyWith(
                                    color: _primary,
                                    fontSize: 11.5,
                                    height: 1.35,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Material(
                            color: const Color(0xFFE0F2FE),
                            borderRadius: BorderRadius.circular(12),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(12),
                              onTap: () => _copyAddress(
                                destination.locationName,
                              ),
                              child: const Padding(
                                padding: EdgeInsets.all(9),
                                child: Icon(
                                  Icons.copy_rounded,
                                  color: _primary,
                                  size: 17,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 27),
                    _SolidPrimaryButton(
                      icon: _generatingCheckpointMission
                          ? Icons.auto_awesome_rounded
                          : Icons.navigation_rounded,
                      label: _generatingCheckpointMission
                          ? 'GENERATING MISSION...'
                          : 'GO CHECKPOINT MISSION',
                      onTap: _generatingCheckpointMission
                          ? () {}
                          : _generateAndOpenCheckpointMission,
                    ),
                    const SizedBox(height: 12),
                    _OutlineActionButton(
                      icon: Icons.refresh_rounded,
                      label: 'REDRAW',
                      trailingLabel: _blindBoxChances > 0
                          ? '1 CHANCE'
                          : 'GET CHANCE',
                      isLoading: _isDrawing,
                      loadingLabel: 'SEARCHING NEW LOCATION...',
                      onTap: _redrawBlindBox,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // --------------------------------------------------------------------------
  // DIALOGS
  // --------------------------------------------------------------------------
  Future<void> _showHistoryDialog(
      BlindBoxHistoryUi item,
      ) {
    return showDialog<void>(
      context: context,
      barrierColor: const Color(0xA6424D61),
      builder: (dialogContext) {
        final width =
            MediaQuery.sizeOf(dialogContext).width;

        return Dialog(
          insetPadding: EdgeInsets.symmetric(
            horizontal: width < 390 ? 13 : 20,
            vertical: 30,
          ),
          backgroundColor: Colors.transparent,
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: 365,
            ),
            child: Container(
              padding: const EdgeInsets.fromLTRB(
                27,
                26,
                27,
                27,
              ),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius:
                BorderRadius.circular(27),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x380F172A),
                    blurRadius: 24,
                    offset: Offset(0, 12),
                  ),
                ],
              ),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment:
                  CrossAxisAlignment.stretch,
                  children: [
                    // ============================================================
                    // HEADER
                    // ============================================================

                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'DRAW HISTORY DETAILS',
                            style:
                            _bodyStyle.copyWith(
                              color: _primary,
                              fontSize: 9.5,
                              fontWeight:
                              FontWeight.w900,
                              letterSpacing: 1.15,
                            ),
                          ),
                        ),

                        InkWell(
                          borderRadius:
                          BorderRadius.circular(
                            20,
                          ),
                          onTap: () {
                            Navigator.of(
                              dialogContext,
                            ).pop();
                          },
                          child: Container(
                            width: 31,
                            height: 31,
                            decoration:
                            const BoxDecoration(
                              color:
                              Color(0xFFF1F5F9),
                              shape:
                              BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.close_rounded,
                              size: 18,
                              color: _slate700,
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(
                      height: 10,
                    ),

                    const Divider(
                      height: 1,
                      color: Color(
                        0xFFE8EEF4,
                      ),
                    ),

                    const SizedBox(
                      height: 20,
                    ),

                    // ============================================================
                    // DESTINATION IMAGE
                    // ============================================================

                    ClipRRect(
                      borderRadius:
                      BorderRadius.circular(
                        15,
                      ),
                      child: SizedBox(
                        height: 160,
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            _NetworkImage(
                              url: item.imageUrl,
                              fit: BoxFit.cover,
                            ),

                            // ====================================================
                            // ADDRESS ON IMAGE
                            // ====================================================

                            Align(
                              alignment:
                              Alignment
                                  .bottomLeft,
                              child: Container(
                                margin:
                                const EdgeInsets
                                    .all(
                                  9,
                                ),
                                padding:
                                const EdgeInsets
                                    .symmetric(
                                  horizontal: 10,
                                  vertical: 7,
                                ),
                                decoration:
                                BoxDecoration(
                                  color:
                                  const Color(
                                    0xCC1E293B,
                                  ),
                                  borderRadius:
                                  BorderRadius
                                      .circular(
                                    8,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize:
                                  MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      Icons
                                          .location_on,
                                      size: 13,
                                      color: Color(
                                        0xFFEC4899,
                                      ),
                                    ),

                                    const SizedBox(
                                      width: 5,
                                    ),

                                    Flexible(
                                      child: Text(
                                        item
                                            .locationName,
                                        maxLines: 2,
                                        overflow:
                                        TextOverflow
                                            .ellipsis,
                                        style:
                                        _bodyStyle
                                            .copyWith(
                                          color:
                                          Colors
                                              .white,
                                          fontSize:
                                          10,
                                          fontWeight:
                                          FontWeight
                                              .w700,
                                        ),
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

                    const SizedBox(
                      height: 18,
                    ),

                    // ============================================================
                    // DESTINATION NAME
                    // ============================================================

                    Text(
                      item.title,
                      style: _heading.copyWith(
                        fontSize: 24,
                        height: 1.1,
                      ),
                    ),

                    const SizedBox(
                      height: 7,
                    ),

                    // ============================================================
                    // DRAW DATE + TIME
                    // ============================================================

                    Text(
                      'Drawn on '
                          '${item.drawnAtDate} '
                          'at '
                          '${item.drawnAtTime}',
                      style:
                      _bodyStyle.copyWith(
                        color: _slate500,
                        fontSize: 11,
                      ),
                    ),

                    const SizedBox(
                      height: 20,
                    ),

                    // ============================================================
                    // DESCRIPTION
                    // ============================================================

                    Container(
                      padding:
                      const EdgeInsets
                          .fromLTRB(
                        16,
                        13,
                        16,
                        13,
                      ),
                      decoration:
                      BoxDecoration(
                        color: const Color(
                          0xFFF0F9FF,
                        ),
                        borderRadius:
                        BorderRadius
                            .circular(
                          19,
                        ),
                        border: Border.all(
                          color: const Color(
                            0xFFD9ECF6,
                          ),
                        ),
                      ),
                      child: Text(
                        '"${item.lore}"',
                        style:
                        const TextStyle(
                          fontStyle:
                          FontStyle.italic,
                          color:
                          _slate700,
                          fontSize: 13,
                          height: 1.55,
                        ),
                      ),
                    ),

                    const SizedBox(
                      height: 14,
                    ),

                    // ============================================================
                    // ADDRESS + COPY BUTTON
                    // ============================================================

                    Container(
                      width:
                      double.infinity,
                      padding:
                      const EdgeInsets
                          .symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      decoration:
                      BoxDecoration(
                        color: const Color(
                          0xFFF8FAFC,
                        ),
                        borderRadius:
                        BorderRadius
                            .circular(
                          16,
                        ),
                        border: Border.all(
                          color: const Color(
                            0xFFE2E8F0,
                          ),
                        ),
                      ),
                      child: Row(
                        crossAxisAlignment:
                        CrossAxisAlignment
                            .center,
                        children: [
                          const Icon(
                            Icons.location_on,
                            color: Color(
                              0xFFEC4899,
                            ),
                            size: 18,
                          ),

                          const SizedBox(
                            width: 9,
                          ),

                          Expanded(
                            child: Column(
                              crossAxisAlignment:
                              CrossAxisAlignment
                                  .start,
                              children: [
                                Text(
                                  'Address',
                                  style:
                                  _bodyStyle
                                      .copyWith(
                                    color:
                                    _slate500,
                                    fontSize:
                                    10.5,
                                    fontWeight:
                                    FontWeight
                                        .w700,
                                  ),
                                ),

                                const SizedBox(
                                  height: 3,
                                ),

                                Text(
                                  item
                                      .locationName,
                                  style:
                                  _bodyStyle
                                      .copyWith(
                                    color:
                                    _primary,
                                    fontSize:
                                    11.5,
                                    height:
                                    1.35,
                                    fontWeight:
                                    FontWeight
                                        .w800,
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(
                            width: 8,
                          ),

                          // ======================================================
                          // COPY BUTTON
                          // ======================================================

                          Material(
                            color:
                            const Color(
                              0xFFE0F2FE,
                            ),
                            borderRadius:
                            BorderRadius
                                .circular(
                              12,
                            ),
                            child: InkWell(
                              borderRadius:
                              BorderRadius
                                  .circular(
                                12,
                              ),
                              onTap: () {
                                _copyAddress(
                                  item
                                      .locationName,
                                );
                              },
                              child:
                              const Padding(
                                padding:
                                EdgeInsets
                                    .all(
                                  9,
                                ),
                                child: Icon(
                                  Icons
                                      .copy_rounded,
                                  color:
                                  _primary,
                                  size: 17,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(
                      height: 26,
                    ),

                    // ============================================================
                    // START CHECKPOINT MISSION
                    // ============================================================

                    _SolidPrimaryButton(
                      icon:
                      Icons.navigation_rounded,
                      label:
                      _generatingCheckpointMission
                          ? 'GENERATING MISSION...'
                          : 'START CHECKPOINT MISSION',
                      onTap: () async {
                        Navigator.of(
                          dialogContext,
                        ).pop();

                        await Future<void>
                            .delayed(
                          const Duration(
                            milliseconds:
                            100,
                          ),
                        );

                        if (!mounted) {
                          return;
                        }
                        await _generateAndOpenCheckpointMissionFromHistory(
                          item,
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _showChanceDialog() async {
    if (_isBuyingChance) return;

    Map<String, int> status;

    try {
      status = await _controller.loadBlindBoxPurchaseStatus();
    } catch (error) {
      if (!mounted) return;
      _showError(error);
      return;
    }

    if (!mounted) return;

    final int currentEp = status['exploration_points'] ?? _userEp;
    final int currentChances =
        status['blind_box_chances'] ?? _blindBoxChances;
    final int purchasedToday = status['purchased_today'] ?? 0;
    final int dailyRemaining = status['daily_remaining'] ?? 0;
    final int holdingRemaining = status['holding_remaining'] ??
        (BlindBoxController.maxBlindBoxChances - currentChances);
    final int dailyLimit = status['daily_limit'] ??
        BlindBoxController.maxDailyBlindBoxPurchases;
    final int maxChances = status['max_chances'] ??
        BlindBoxController.maxBlindBoxChances;
    final int costPerChance = status['chance_cost_ep'] ??
        BlindBoxController.blindBoxChanceCostEp;

    setState(() {
      _userEp = currentEp;
      _blindBoxChances = currentChances;
    });

    final int affordableQuantity = costPerChance <= 0
        ? 0
        : currentEp ~/ costPerChance;

    int maxSelectable = holdingRemaining;
    if (dailyRemaining < maxSelectable) {
      maxSelectable = dailyRemaining;
    }
    if (affordableQuantity < maxSelectable) {
      maxSelectable = affordableQuantity;
    }
    if (maxSelectable < 0) {
      maxSelectable = 0;
    }

    int selectedQuantity = maxSelectable > 0 ? 1 : 0;
    bool dialogBuying = false;

    String? unavailableReason() {
      if (holdingRemaining <= 0) {
        return 'You already hold the maximum of $maxChances Blind Box Chances.';
      }

      if (dailyRemaining <= 0) {
        return 'You have reached today\'s purchase limit of $dailyLimit Blind Box Chances.';
      }

      if (affordableQuantity <= 0) {
        return 'You need at least $costPerChance EP to buy 1 Blind Box Chance.';
      }

      return null;
    }

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      barrierColor: const Color(0xA6424D61),
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final int totalCost = selectedQuantity * costPerChance;
            final int afterPurchase = currentChances + selectedQuantity;
            final String? blockedMessage = unavailableReason();
            final bool canBuy =
                maxSelectable > 0 && selectedQuantity > 0 && !dialogBuying;

            void decreaseQuantity() {
              if (dialogBuying || selectedQuantity <= 1) return;

              setDialogState(() {
                selectedQuantity--;
              });
            }

            void increaseQuantity() {
              if (dialogBuying || selectedQuantity >= maxSelectable) return;

              setDialogState(() {
                selectedQuantity++;
              });
            }

            return Dialog(
              insetPadding: const EdgeInsets.symmetric(
                horizontal: 18,
                vertical: 24,
              ),
              backgroundColor: Colors.transparent,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 380),
                child: Container(
                  padding: const EdgeInsets.fromLTRB(22, 22, 22, 20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(27),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x380F172A),
                        blurRadius: 24,
                        offset: Offset(0, 12),
                      ),
                    ],
                  ),
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFF7D6),
                                borderRadius: BorderRadius.circular(13),
                              ),
                              child: const Icon(
                                Icons.card_giftcard_rounded,
                                color: Color(0xFFD97706),
                                size: 21,
                              ),
                            ),
                            const SizedBox(width: 11),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Buy Blind Box Chances',
                                    style: _heading.copyWith(fontSize: 19),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '$costPerChance EP per chance',
                                    style: _bodyStyle.copyWith(
                                      color: _slate500,
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              onPressed: dialogBuying
                                  ? null
                                  : () => Navigator.of(dialogContext).pop(),
                              icon: const Icon(Icons.close_rounded),
                            ),
                          ],
                        ),

                        const SizedBox(height: 10),
                        const Divider(color: Color(0xFFE8EEF4)),
                        const SizedBox(height: 12),

                        Container(
                          padding: const EdgeInsets.all(15),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFFBEB),
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(
                              color: const Color(0xFFFDE68A),
                            ),
                          ),
                          child: Column(
                            children: [
                              _DialogInfoRow(
                                label: 'Current Chances:',
                                value: '$currentChances / $maxChances',
                                valueColor: const Color(0xFF92400E),
                              ),
                              const SizedBox(height: 9),
                              _DialogInfoRow(
                                label: 'Purchased Today:',
                                value: '$purchasedToday / $dailyLimit',
                                valueColor: const Color(0xFF92400E),
                              ),
                              const SizedBox(height: 9),
                              _DialogInfoRow(
                                label: 'Daily Remaining:',
                                value: '$dailyRemaining',
                                valueColor: const Color(0xFF92400E),
                              ),
                              const SizedBox(height: 9),
                              _DialogInfoRow(
                                label: 'Your Points:',
                                value: '$currentEp EP',
                                valueColor: _primary,
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 18),

                        Text(
                          'SELECT QUANTITY',
                          style: _bodyStyle.copyWith(
                            color: _slate500,
                            fontSize: 9.5,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.1,
                          ),
                        ),
                        const SizedBox(height: 9),

                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(17),
                            border: Border.all(
                              color: const Color(0xFFE2E8F0),
                            ),
                          ),
                          child: Row(
                            children: [
                              _QuantityButton(
                                icon: Icons.remove_rounded,
                                enabled: selectedQuantity > 1 && !dialogBuying,
                                onTap: decreaseQuantity,
                              ),
                              Expanded(
                                child: Column(
                                  children: [
                                    Text(
                                      '$selectedQuantity',
                                      style: _heading.copyWith(
                                        fontSize: 26,
                                      ),
                                    ),
                                    Text(
                                      selectedQuantity == 1
                                          ? 'CHANCE'
                                          : 'CHANCES',
                                      style: _bodyStyle.copyWith(
                                        color: _slate500,
                                        fontSize: 9,
                                        fontWeight: FontWeight.w900,
                                        letterSpacing: 1.0,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              _QuantityButton(
                                icon: Icons.add_rounded,
                                enabled: selectedQuantity < maxSelectable &&
                                    !dialogBuying,
                                onTap: increaseQuantity,
                              ),
                              const SizedBox(width: 8),
                              OutlinedButton(
                                onPressed: maxSelectable > 0 && !dialogBuying
                                    ? () {
                                  setDialogState(() {
                                    selectedQuantity = maxSelectable;
                                  });
                                }
                                    : null,
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: _primary,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 10,
                                  ),
                                  side: const BorderSide(
                                    color: Color(0xFFBAE6FD),
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                child: const Text(
                                  'MAX',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        if (blockedMessage != null) ...[
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFF1F2),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: const Color(0xFFFECACA),
                              ),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(
                                  Icons.info_outline_rounded,
                                  size: 18,
                                  color: Color(0xFFDC2626),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    blockedMessage,
                                    style: _bodyStyle.copyWith(
                                      color: const Color(0xFF991B1B),
                                      fontSize: 10.5,
                                      height: 1.4,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],

                        const SizedBox(height: 16),

                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF0F9FF),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: const Color(0xFFBAE6FD),
                            ),
                          ),
                          child: Column(
                            children: [
                              _DialogInfoRow(
                                label: 'Total Cost:',
                                value: '$totalCost EP',
                                valueColor: _primary,
                              ),
                              const SizedBox(height: 9),
                              _DialogInfoRow(
                                label: 'After Purchase:',
                                value: '$afterPurchase / $maxChances chances',
                                valueColor: const Color(0xFF0D9488),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 12),

                        Text(
                          'Limit: you can hold up to $maxChances chances and purchase up to $dailyLimit chances per day.',
                          style: _bodyStyle.copyWith(
                            color: _slate500,
                            fontSize: 10.5,
                            height: 1.4,
                          ),
                        ),

                        const SizedBox(height: 20),

                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: dialogBuying
                                    ? null
                                    : () => Navigator.of(dialogContext).pop(),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: _slate700,
                                  side: BorderSide.none,
                                  backgroundColor: const Color(0xFFF1F5F9),
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 14,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                ),
                                child: Text(
                                  'Cancel',
                                  style: _bodyStyle.copyWith(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 11,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              flex: 2,
                              child: ElevatedButton(
                                onPressed: canBuy
                                    ? () async {
                                  setDialogState(() {
                                    dialogBuying = true;
                                  });

                                  final int purchasedQuantity =
                                      selectedQuantity;

                                  final bool success =
                                  await _buyBlindBoxChances(
                                    quantity: purchasedQuantity,
                                  );

                                  if (!mounted) {
                                    return;
                                  }

                                  if (success) {
                                    // =====================================================
                                    // PURCHASE SUCCESSFUL -> CLOSE DIALOG
                                    // =====================================================
                                    final rootNavigator =
                                    Navigator.of(
                                      context,
                                      rootNavigator: true,
                                    );

                                    if (rootNavigator.canPop()) {
                                      rootNavigator.pop();
                                    }

                                    // Reload again to make sure Hub values
                                    // are exactly the same as database.
                                    await _loadBlindBoxBalance();
                                  } else {
                                    // Purchase failed -> keep dialog open.
                                    if (dialogContext.mounted) {
                                      setDialogState(() {
                                        dialogBuying = false;
                                      });
                                    }
                                  }
                                }
                                    : null,

                                style: ElevatedButton.styleFrom(
                                  elevation: 1,

                                  backgroundColor:
                                  const Color(0xFFD97706),

                                  disabledBackgroundColor:
                                  const Color(0xFFE2E8F0),

                                  foregroundColor:
                                  Colors.white,

                                  padding:
                                  const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 14,
                                  ),

                                  shape: RoundedRectangleBorder(
                                    borderRadius:
                                    BorderRadius.circular(14),
                                  ),
                                ),

                                child: dialogBuying
                                    ? const SizedBox(
                                  width: 19,
                                  height: 19,
                                  child:
                                  CircularProgressIndicator(
                                    strokeWidth: 2.2,
                                    color: Colors.white,
                                  ),
                                )
                                    : FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Text(
                                    selectedQuantity > 0
                                        ? 'GET $selectedQuantity · $totalCost EP'
                                        : 'UNAVAILABLE',

                                    style: _bodyStyle.copyWith(
                                      fontWeight:
                                      FontWeight.w900,
                                      fontSize: 10.5,
                                    ),
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
            );
          },
        );
      },
    );
  }

}

class _QuantityButton extends StatelessWidget {
  final IconData icon;
  final bool enabled;
  final VoidCallback onTap;

  const _QuantityButton({
    required this.icon,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: enabled
          ? const Color(0xFFE0F2FE)
          : const Color(0xFFF1F5F9),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: enabled ? onTap : null,
        child: SizedBox(
          width: 40,
          height: 40,
          child: Icon(
            icon,
            size: 20,
            color: enabled
                ? const Color(0xFF0284C7)
                : const Color(0xFFCBD5E1),
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// TOP APP BAR
// =============================================================================
class _BlindBoxMysteryLaneLogo extends StatelessWidget {
  const _BlindBoxMysteryLaneLogo();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 38,
      height: 38,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: [
            Color(0xFF0284C7),
            Color(0xFF0D9488),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: Color(0x300284C7),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: const Icon(
        Icons.explore_rounded,
        color: Colors.white,
        size: 23,
      ),
    );
  }
}

class _BlindBoxTopActionButton extends StatelessWidget {
  final String tooltip;
  final IconData icon;
  final Color background;
  final Color foreground;
  final VoidCallback onTap;

  const _BlindBoxTopActionButton({
    required this.tooltip,
    required this.icon,
    required this.background,
    required this.foreground,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,

      child: InkWell(
        borderRadius: BorderRadius.circular(99),
        onTap: onTap,

        child: Container(
          width: 38,
          height: 38,

          decoration: BoxDecoration(
            color: background,
            shape: BoxShape.circle,

            border: Border.all(
              color: foreground.withValues(
                alpha: 0.20,
              ),
            ),
          ),

          child: Icon(
            icon,
            color: foreground,
            size: 20,
          ),
        ),
      ),
    );
  }
}

class _BlindBoxProfileButton extends StatelessWidget {
  final VoidCallback onTap;
  final String? imageUrl;

  const _BlindBoxProfileButton({
    required this.onTap,
    required this.imageUrl,
  });

  @override
  Widget build(BuildContext context) {
    final cleanUrl = imageUrl?.trim();
    final ImageProvider? provider =
    cleanUrl != null && cleanUrl.isNotEmpty ? NetworkImage(cleanUrl) : null;

    return Tooltip(
      message: 'Profile',
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Container(
          width: 38,
          height: 38,
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            border: Border.all(
              color: const Color(0xFFBAE6FD),
              width: 1.4,
            ),
          ),
          child: CircleAvatar(
            backgroundColor: const Color(0xFFE0F2FE),
            backgroundImage: provider,
            child: provider == null
                ? const Icon(
              Icons.person_rounded,
              size: 20,
              color: Color(0xFF0284C7),
            )
                : null,
          ),
        ),
      ),
    );
  }
}

class _TopCircleButton extends StatelessWidget {
  final Color background;
  final Color border;
  final IconData icon;
  final Color iconColor;

  const _TopCircleButton({
    required this.background,
    required this.border,
    required this.icon,
    required this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 43,
      height: 43,
      decoration: BoxDecoration(
        color: background,
        shape: BoxShape.circle,
        border: Border.all(color: border),
      ),
      child: Icon(icon, color: iconColor, size: 22),
    );
  }
}

// =============================================================================
// BOTTOM NAVIGATION
// =============================================================================

class _MysteryLaneBottomBar extends StatelessWidget {
  final ValueChanged<MysteryLaneTab> onTap;

  const _MysteryLaneBottomBar({
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return BottomAppBar(
      height: 78,
      padding: EdgeInsets.zero,
      elevation: 18,
      color: Colors.white,
      shadowColor: const Color(0x220F172A),
      shape: const CircularNotchedRectangle(),
      notchMargin: 8,
      child: Row(
        children: [
          Expanded(
            child: _BottomItem(
              icon: Icons.inventory_2_outlined,
              label: 'BLIND\nBOX',
              selected: true,
              onTap: () => onTap(MysteryLaneTab.blindBox),
            ),
          ),
          Expanded(
            child: _BottomItem(
              icon: Icons.assignment_outlined,
              label: 'MISSIONS',
              onTap: () => onTap(MysteryLaneTab.missions),
            ),
          ),
          const SizedBox(width: 72),
          Expanded(
            child: _BottomItem(
              icon: Icons.map_outlined,
              label: 'PLAN',
              onTap: () => onTap(MysteryLaneTab.plan),
            ),
          ),
          Expanded(
            child: _BottomItem(
              icon: Icons.groups_2_outlined,
              label: 'TEAMS',
              onTap: () => onTap(MysteryLaneTab.teams),
            ),
          ),
        ],
      ),
    );
  }
}

class _BottomItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _BottomItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.selected = false,
  });

  @override
  Widget build(BuildContext context) {
    const Color blue = Color(0xFF0284C7);

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.only(top: 10, bottom: 4),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              width: 42,
              height: 29,
              decoration: BoxDecoration(
                color: selected ? blue : Colors.transparent,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                size: 21,
                color: selected ? Colors.white : const Color(0xFF64748B),
              ),
            ),
            const SizedBox(height: 3),
            Text(
              label,
              maxLines: 2,
              textAlign: TextAlign.center,
              overflow: TextOverflow.clip,
              style: TextStyle(
                color: selected ? blue : const Color(0xFF64748B),
                fontSize: 8,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.45,
                height: 1.0,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HomeFloatingButton extends StatelessWidget {
  final VoidCallback onTap;

  const _HomeFloatingButton({
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Container(
          width: 62,
          height: 62,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(
              colors: [
                Color(0xFF0284C7),
                Color(0xFF0D9488),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            border: Border.all(color: Colors.white, width: 4),
            boxShadow: const [
              BoxShadow(
                color: Color(0x3D0284C7),
                blurRadius: 16,
                offset: Offset(0, 7),
              ),
            ],
          ),
          child: const Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.home_rounded,
                color: Color(0xFFFDE68A),
                size: 27,
              ),
              Text(
                'HOME',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 8,
                  fontWeight: FontWeight.w900,
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
// REUSABLE UI COMPONENTS
// =============================================================================

class _RoundIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;

  const _RoundIconButton({
    required this.icon,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      shape: const CircleBorder(),
      elevation: .5,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Container(
          width: 45,
          height: 45,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: const Color(0xFFDDE5ED)),
          ),
          child: Icon(
            icon,
            color: const Color(0xFF334155),
            size: 19,
          ),
        ),
      ),
    );
  }
}

class _EpChip extends StatelessWidget {
  final int ep;

  const _EpChip({
    required this.ep,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
      decoration: BoxDecoration(
        color: const Color(0xFFF0F9FF),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFBAE6FD)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.auto_awesome_rounded,
            color: Color(0xFF0284C7),
            size: 17,
          ),
          const SizedBox(width: 5),
          Text(
            '$ep EP',
            style: const TextStyle(
              color: Color(0xFF0284C7),
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _SubTabButton extends StatelessWidget {
  final bool selected;
  final IconData icon;
  final String label;
  final int? badge;
  final VoidCallback onTap;

  const _SubTabButton({
    required this.selected,
    required this.icon,
    required this.label,
    required this.badge,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    const primary = Color(0xFF0284C7);

    return Material(
      color: selected ? primary : Colors.transparent,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          height: 45,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 18,
                color: selected
                    ? const Color(0xFFFDE68A)
                    : const Color(0xFF0284C7),
              ),
              const SizedBox(width: 7),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  style: TextStyle(
                    fontSize: 11.5,
                    color: selected
                        ? Colors.white
                        : const Color(0xFF475569),
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              if (badge != null) ...[
                const SizedBox(width: 7),
                Container(
                  width: 21,
                  height: 21,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: selected
                        ? Colors.white.withValues(alpha: .10)
                        : const Color(0xFFBAE6FD),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      '$badge',
                      maxLines: 1,
                      softWrap: false,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 9,
                        height: 1.0,
                        color: selected ? Colors.white : primary,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _GradientActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _GradientActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 60,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFF0284C7),
            Color(0xFF0D9488),
          ],
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [
          BoxShadow(
            color: Color(0x260284C7),
            blurRadius: 9,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: const Color(0xFFFFE66D), size: 21),
              const SizedBox(width: 12),
              Flexible(
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    letterSpacing: 2.3,
                    fontWeight: FontWeight.w900,
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

class _SolidPrimaryButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _SolidPrimaryButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 55,
      child: ElevatedButton.icon(
        onPressed: onTap,
        icon: Icon(
          icon,
          color: Colors.white,
          size: 18,
        ),
        label: Text(
          label,
          style: const TextStyle(
            fontSize: 11.5,
            letterSpacing: 2.0,
            fontWeight: FontWeight.w900,
          ),
        ),
        style: ElevatedButton.styleFrom(
          elevation: 3,
          backgroundColor: const Color(0xFF0284C7),
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
      ),
    );
  }
}

class _OutlineActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final String trailingLabel;
  final VoidCallback onTap;
  final bool isLoading;
  final String? loadingLabel;

  const _OutlineActionButton({
    required this.icon,
    required this.label,
    required this.trailingLabel,
    required this.onTap,
    this.isLoading = false,
    this.loadingLabel,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: OutlinedButton(
        onPressed: isLoading ? null : onTap,
        style: OutlinedButton.styleFrom(
          foregroundColor: const Color(0xFF0F172A),
          side: const BorderSide(color: Color(0xFFD8E1EA)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
        ),
        child: isLoading
            ? Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2.2,
                valueColor: AlwaysStoppedAnimation<Color>(
                  Color(0xFF0284C7),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Flexible(
              child: Text(
                loadingLabel ?? 'LOADING...',
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 11.5,
                ),
              ),
            ),
          ],
        )
            : Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: const Color(0xFF0284C7), size: 18),
            const SizedBox(width: 7),
            Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 11.5,
              ),
            ),
            const SizedBox(width: 9),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 7,
                vertical: 4,
              ),
              decoration: BoxDecoration(
                color: const Color(0xFFE0F2FE),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                trailingLabel,
                style: const TextStyle(
                  color: Color(0xFF0284C7),
                  fontWeight: FontWeight.w800,
                  fontSize: 8.5,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
class _DestinationHero extends StatelessWidget {
  final BlindBoxDestinationUi destination;

  const _DestinationHero({
    required this.destination,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 286,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // ================================================================
          // DESTINATION IMAGE
          // ================================================================
          _NetworkImage(
            url: destination.imageUrl,
            fit: BoxFit.cover,
          ),

          // ================================================================
          // DARK GRADIENT
          // ================================================================
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0x000F172A),
                  Color(0x200F172A),
                  Color(0xE80F172A),
                ],
                stops: [0, .48, 1],
              ),
            ),
          ),

          // ================================================================
          // TOP LEFT - GOOGLE RATING
          // ================================================================
          if (destination.rating != null)
            Positioned(
              top: 14,
              left: 14,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 11,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xEEFFF7ED),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: const Color(0xFFFCD34D),
                  ),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x33000000),
                      blurRadius: 5,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.star_rounded,
                      color: Color(0xFFF59E0B),
                      size: 16,
                    ),
                    const SizedBox(width: 4),

                    Text(
                      destination.rating!.toStringAsFixed(1),
                      style: const TextStyle(
                        color: Color(0xFF7C2D12),
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                      ),
                    ),

                  ],
                ),
              ),
            ),

          // ================================================================
          // TOP RIGHT - MYSTERY SPOT
          // ================================================================
          Positioned(
            top: 14,
            right: 14,
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 7,
              ),
              decoration: BoxDecoration(
                color: const Color(0xDD17243B),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: const Color(0x997C6A2B),
                ),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x33000000),
                    blurRadius: 5,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: const Text(
                '✦ Mystery Spot ✦',
                style: TextStyle(
                  color: Color(0xFFFCD34D),
                  fontSize: 9.5,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),

          // ================================================================
          // BOTTOM CONTENT
          // CATEGORY + TITLE + DISTANCE
          // ================================================================
          Positioned(
            left: 18,
            right: 18,
            bottom: 17,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                // ----------------------------------------------------------
                // CATEGORY + DESTINATION NAME
                // ----------------------------------------------------------
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Category
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(9),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x26000000),
                              blurRadius: 4,
                              offset: Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Text(
                          destination.tag,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Color(0xFF1E293B),
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),

                      const SizedBox(height: 6),

                      // Destination Name
                      _AutoFitDestinationTitle(
                        text: destination.title,
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: 10),

                // ----------------------------------------------------------
                // DISTANCE
                // ----------------------------------------------------------
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 11,
                    vertical: 9,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xE60284C7),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: const Color(0xFF7DD3FC),
                    ),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x33000000),
                        blurRadius: 4,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.location_on_outlined,
                        color: Color(0xFFA5F3FC),
                        size: 16,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        destination.distance,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
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
    );
  }

}

class _AutoFitDestinationTitle extends StatelessWidget {
  final String text;

  const _AutoFitDestinationTitle({
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const maxFontSize = 28.0;
        const minFontSize = 16.0;
        const maxLines = 3;

        double fontSize = maxFontSize;

        while (fontSize > minFontSize) {
          final painter = TextPainter(
            text: TextSpan(
              text: text,
              style: TextStyle(
                fontSize: fontSize,
                fontWeight: FontWeight.w900,
                height: 1.02,
              ),
            ),
            maxLines: maxLines,
            textDirection: TextDirection.ltr,
          )..layout(maxWidth: constraints.maxWidth);

          if (!painter.didExceedMaxLines) {
            break;
          }

          fontSize -= 1;
        }

        return Text(
          text,
          maxLines: maxLines,
          overflow: TextOverflow.clip,
          style: TextStyle(
            color: Colors.white,
            fontSize: fontSize,
            fontWeight: FontWeight.w900,
            height: 1.02,
            shadows: const [
              Shadow(
                color: Color(0x99000000),
                blurRadius: 4,
                offset: Offset(0, 2),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _HistoryCard extends StatelessWidget {
  final BlindBoxHistoryUi item;
  final VoidCallback onTap;

  const _HistoryCard({
    required this.item,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(27),
      child: InkWell(
        borderRadius: BorderRadius.circular(27),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(27),
            border: Border.all(color: const Color(0xFFDCE3EA)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(17),
                child: SizedBox(
                  width: 77,
                  height: 77,
                  child: _NetworkImage(
                    url: item.imageUrl,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            item.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Color(0xFF0F172A),
                              fontSize: 17.5,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF0F9FF),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFD9ECF6)),
                          ),
                          child: Text(
                            item.distance,
                            style: const TextStyle(
                              color: Color(0xFF0284C7),
                              fontSize: 9,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '"${item.lore}"',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        height: 1.23,
                        fontStyle: FontStyle.italic,
                        color: Color(0xFF59677B),
                      ),
                    ),
                    const SizedBox(height: 11),
                    Wrap(
                      spacing: 13,
                      runSpacing: 7,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        _HistoryMeta(
                          icon: Icons.calendar_today_outlined,
                          iconColor: const Color(0xFF0284C7),
                          text: item.drawnAtDate,
                        ),
                        _HistoryMeta(
                          icon: Icons.access_time_rounded,
                          iconColor: const Color(0xFF94A3B8),
                          text: item.drawnAtTime,
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(7),
                          ),
                          child: Text(
                            item.tag,
                            style: const TextStyle(
                              color: Color(0xFF334155),
                              fontSize: 9.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
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
}

class _HistoryMeta extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String text;

  const _HistoryMeta({
    required this.icon,
    required this.iconColor,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: iconColor),
        const SizedBox(width: 4),
        Text(
          text,
          style: const TextStyle(
            fontSize: 9.5,
            color: Color(0xFF475569),
          ),
        ),
      ],
    );
  }
}

class _DialogInfoRow extends StatelessWidget {
  final String label;
  final String value;
  final Color valueColor;

  const _DialogInfoRow({
    required this.label,
    required this.value,
    required this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              color: Color(0xFF334155),
              fontWeight: FontWeight.w700,
              fontSize: 11.5,
            ),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            color: valueColor,
            fontWeight: FontWeight.w900,
            fontSize: 10.5,
          ),
        ),
      ],
    );
  }
}

class _NetworkImage extends StatelessWidget {
  final String url;
  final BoxFit fit;

  const _NetworkImage({
    required this.url,
    required this.fit,
  });

  @override
  Widget build(BuildContext context) {
    if (url.trim().isEmpty) {
      return const ColoredBox(
        color: Color(0xFF0C4A6E),
        child: Center(
          child: Icon(
            Icons.landscape_rounded,
            color: Color(0x88FFFFFF),
            size: 64,
          ),
        ),
      );
    }

    return Image.network(
      url,
      fit: fit,
      loadingBuilder: (context, child, progress) {
        if (progress == null) return child;
        return const ColoredBox(
          color: Color(0xFFE2E8F0),
          child: Center(
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: Color(0xFF0284C7),
            ),
          ),
        );
      },
      errorBuilder: (context, error, stackTrace) {
        return const ColoredBox(
          color: Color(0xFFE2E8F0),
          child: Center(
            child: Icon(
              Icons.image_not_supported_outlined,
              color: Color(0xFF64748B),
              size: 34,
            ),
          ),
        );
      },
    );
  }
}

