import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:math';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../application/controller/trip_planner_controller.dart';
import '../../../application/controller/BlindBox_Controller.dart';
import '../../../data/models/place_candidate.dart';
import '../../../data/models/trip_plan.dart';
import '../Blindbox/BlindBox_Screen.dart';
import '../checkpoint/checkpoint_screen.dart';
import '../profile/profile_screen.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../../application/services/group_service.dart';
import '../group/team_detail_screen.dart';
import '../group/group_screen.dart';
import '../../../data/models/travel_group_model.dart';

class PlanScreen extends StatefulWidget {
  const PlanScreen({super.key});

  @override
  State<PlanScreen> createState() => _PlanScreenState();
}

class _PlanScreenState extends State<PlanScreen> {
  static const blue = Color(0xFF0284C7),
      teal = Color(0xFF069A9B),
      ink = Color(0xFF0F172A),
      border = Color(0xFFDCE6EE);
  static const int destinationsPerDay = 5;
  static const int maxTripDays = 14;
  int dashboardPage = 0;
  static const int itemsPerPage = 5; //

  final name = TextEditingController(),
      placeSearch = TextEditingController(),
      planSearch = TextEditingController(),
      teamName = TextEditingController();

  final GroupService _groupService = GroupService();
  final FocusNode _placeSearchFocus = FocusNode();

  int teamMaxCapacity = 5;

  TripPlannerController? api;
  String? error;
  String? _lastViewedPlanId;
  List<TripPlan> plans = [];
  List<TripPlan> _allPlans = [];
  List<TripPlan> _displayedPlans = [];
  TripPlan? _currentPlan;
  DateTime? _selectedFilterDate;
  List<PlaceCandidate> places = [];
  List<PlaceCandidate> nearbyPlaces = [];
  BlindBoxController? blindBoxController;
  List<PlaceCandidate> blindBoxPlaces = [];
  List<ItineraryStop> stops = [];
  RoutePreview? route;
  PlaceCandidate? _selectedPlace;
  GoogleMapController? _mapController;
  LatLng? _userLocation;

  int page = 0, routeDay = 0;
  bool history = false,
      loading = false,
      mapOpen = true,
      accepted = false,
      openPublic = true,
      isCreating = false;
  String filter = 'All Pins', mode = 'solo';
  DateTime start = DateTime.now(),
      end = DateTime.now().add(const Duration(days: 3));
  // Maps to store routes and accepted status for each day (or 0 for All Days)
  final Map<int, RoutePreview?> _dayRoutes = {};
  final Map<int, bool> _dayAccepted = {};

  @override
  void initState() {
    super.initState();
    try {
      _initController();
      load();
      nearby();
      blindBoxController = BlindBoxController.production();
      _loadBlindBoxPlaces(); // Fetch the history
    } catch (e) {
      error = '$e';
    }
  }

  @override
  void dispose() {
    api?.dispose();
    name.dispose();
    placeSearch.dispose();
    planSearch.dispose();
    teamName.dispose();
    super.dispose();
  }

  // =========================================================================
  // UNIFIED FEATURE: DUPLICATE PLAN (CHOOSE SOLO OR TEAM)
  // =========================================================================
  Future<void> _duplicatePlanDialog() async {
    if (_currentPlan == null) return;

    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      note('Please sign in first.');
      return;
    }

    final newPlanNameCtrl = TextEditingController(text: '${_currentPlan!.name} (Copy)');
    final squadNameCtrl = TextEditingController(text: '${_currentPlan!.name} Squad');
    String selectedMode = 'solo'; // 'solo' or 'team'
    bool isPublic = false;
    int maxCap = 5;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Row(
            children: [
              Icon(Icons.content_copy_rounded, color: blue),
              SizedBox(width: 8),
              Text('Duplicate Trip Plan', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Create a new copy of this itinerary with all destinations and dates.',
                  style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                ),
                const SizedBox(height: 16),

                // 1. New Plan Name
                label('NEW PLAN NAME *'),
                const SizedBox(height: 6),
                TextField(
                  controller: newPlanNameCtrl,
                  decoration: InputDecoration(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
                const SizedBox(height: 18),

                // 2. Select Expedition Mode
                label('CHOOSE EXPEDITION MODE *'),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: ChoiceChip(
                        avatar: const Icon(Icons.person, size: 16),
                        label: const Center(child: Text('Solo')),
                        selected: selectedMode == 'solo',
                        selectedColor: blue,
                        labelStyle: TextStyle(
                          color: selectedMode == 'solo' ? Colors.white : ink,
                          fontWeight: FontWeight.bold,
                        ),
                        onSelected: (_) => setDialogState(() => selectedMode = 'solo'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ChoiceChip(
                        avatar: const Icon(Icons.groups, size: 16),
                        label: const Center(child: Text('Team')),
                        selected: selectedMode == 'team',
                        selectedColor: blue,
                        labelStyle: TextStyle(
                          color: selectedMode == 'team' ? Colors.white : ink,
                          fontWeight: FontWeight.bold,
                        ),
                        onSelected: (_) => setDialogState(() => selectedMode = 'team'),
                      ),
                    ),
                  ],
                ),

                // 3. Team Configurations (Only shown if Team mode chosen)
                if (selectedMode == 'team') ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0F9FF),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFBAE6FD)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        label('SQUAD NAME'),
                        const SizedBox(height: 4),
                        TextField(
                          controller: squadNameCtrl,
                          decoration: InputDecoration(
                            fillColor: Colors.white,
                            filled: true,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Access', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                            Row(
                              children: [
                                ChoiceChip(
                                  label: const Text('Public', style: TextStyle(fontSize: 10)),
                                  selected: isPublic,
                                  onSelected: (_) => setDialogState(() => isPublic = true),
                                ),
                                const SizedBox(width: 4),
                                ChoiceChip(
                                  label: const Text('Private', style: TextStyle(fontSize: 10)),
                                  selected: !isPublic,
                                  onSelected: (_) => setDialogState(() => isPublic = false),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Capacity', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                            Row(
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.remove_circle_outline, size: 18, color: blue),
                                  onPressed: maxCap > 2 ? () => setDialogState(() => maxCap--) : null,
                                ),
                                Text('$maxCap', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                                IconButton(
                                  icon: const Icon(Icons.add_circle_outline, size: 18, color: blue),
                                  onPressed: maxCap < 10 ? () => setDialogState(() => maxCap++) : null,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: FilledButton.styleFrom(backgroundColor: blue),
              child: const Text('Create Copy'),
            ),
          ],
        ),
      ),
    );

    if (confirmed == true) {
      final finalPlanName = newPlanNameCtrl.text.trim().isNotEmpty
          ? newPlanNameCtrl.text.trim()
          : '${_currentPlan!.name} (Copy)';

      if (plans.any((p) => p.name.toLowerCase() == finalPlanName.toLowerCase())) {
        note('A plan named "$finalPlanName" already exists. Choose a different name.');
        return;
      }

      setState(() => loading = true);

      try {
        String? newCode;

        // If Team mode was chosen, create the squad in travel_groups
        if (selectedMode == 'team') {
          final finalTeamName = squadNameCtrl.text.trim().isNotEmpty
              ? squadNameCtrl.text.trim()
              : '$finalPlanName Squad';

          final newTeam = await _groupService.createTeam(
            ownerId: user.id,
            teamName: finalTeamName,
            teamType: isPublic ? 'PUBLIC' : 'PRIVATE',
            maxCapacity: maxCap,
          );

          newCode = newTeam.invitationCode;
        }

        // Save the new cloned plan
        final clonedPlan = await api!.savePlan(TripPlan(
          id: '',
          name: finalPlanName,
          startDate: _currentPlan!.startDate,
          endDate: _currentPlan!.endDate,
          mode: selectedMode,
          visibility: isPublic ? 'public' : 'private',
          inviteCode: newCode,
          routeAccepted: _currentPlan!.routeAccepted,
          stops: List.from(_currentPlan!.stops),
        ));

        if (mounted) {
          setState(() {
            _currentPlan = clonedPlan;
            name.text = clonedPlan.name;
            mode = selectedMode;
            plans = [clonedPlan, ...plans];
            _allPlans = [clonedPlan, ..._allPlans];
            _displayedPlans = [clonedPlan, ..._displayedPlans];
          });

          if (selectedMode == 'team') {
            await _loadSquadForPlan();
            if (newCode != null) {
              _showTeamCodeSuccessDialog(newCode);
            }
          } else {
            note('Solo copy "$finalPlanName" created successfully.');
          }
        }
      } catch (e) {
        note('Unable to duplicate plan: $e');
      } finally {
        if (mounted) setState(() => loading = false);
      }
    }
  }

  // --- SQUAD MANAGEMENT STATE ---
  TravelGroup? _currentTeam;
  List<Map<String, dynamic>> _teamMembers = [];
  bool _loadingTeam = false;

  /// Loads real squad and members for the current team plan
  Future<void> _loadSquadForPlan() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null || mode != 'team') return;

    setState(() => _loadingTeam = true);

    try {
      String? targetGroupId;

      // 1. If we have an invite code, find group by code
      if (_currentPlan?.inviteCode != null && _currentPlan!.inviteCode!.isNotEmpty) {
        // Direct query to travel_groups by invitation_code
        final res = await Supabase.instance.client
            .from('travel_groups')
            .select()
            .eq('invitation_code', _currentPlan!.inviteCode!)
            .maybeSingle();
        if (res != null) {
          targetGroupId = res['group_id'] as String;
        }
      }

      // 2. Fallback: Check user's active teams
      if (targetGroupId == null) {
        final myTeams = await _groupService.getUserTeams(user.id);
        if (myTeams.isNotEmpty) {
          final firstTeam = myTeams.first;
          targetGroupId = (firstTeam['group_id'] ?? firstTeam['travel_groups']?['group_id']) as String?;
        }
      }

      // 3. Fetch full squad details and member profiles
      if (targetGroupId != null) {
        final data = await _groupService.getTeamDetails(targetGroupId);
        if (mounted) {
          setState(() {
            _currentTeam = data['team'] as TravelGroup?;
            final rawMembers = data['members'] as List<dynamic>? ?? [];
            _teamMembers = rawMembers
                .map((m) => Map<String, dynamic>.from(m as Map<dynamic, dynamic>))
                .toList();
          });
        }
      }
    } catch (e) {
      print('Error loading squad in planner: $e');
    } finally {
      if (mounted) setState(() => _loadingTeam = false);
    }
  }

  /// Interactive Manage Squad Bottom Sheet
  void _openManageSquadBottomSheet() {
    final user = Supabase.instance.client.auth.currentUser;
    final isOwner = _currentTeam?.ownerId == user?.id;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setSheetState) => Container(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 30),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Sheet Handlebar
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFCBD5E1),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // Header: Squad Name & Type
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _currentTeam?.teamName ?? '${name.text} Squad',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: ink,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${_teamMembers.length} / ${_currentTeam?.maxCapacity ?? 5} Members',
                          style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: (_currentTeam?.teamType == 'PUBLIC')
                          ? const Color(0xFFDCFCE7)
                          : const Color(0xFFE0F2FE),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      _currentTeam?.teamType ?? 'PRIVATE',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: (_currentTeam?.teamType == 'PUBLIC')
                            ? const Color(0xFF16A34A)
                            : blue,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Private Invitation Code Box (if private)
              if (_currentTeam?.invitationCode != null || _currentPlan?.inviteCode != null) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.vpn_key_outlined, size: 18, color: blue),
                      const SizedBox(width: 10),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'INVITATION CODE',
                            style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Color(0xFF94A3B8)),
                          ),
                          SelectableText(
                            _currentTeam?.invitationCode ?? _currentPlan?.inviteCode ?? '',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 2,
                              color: ink,
                            ),
                          ),
                        ],
                      ),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.copy_rounded, size: 18, color: blue),
                        tooltip: 'Copy Code',
                        onPressed: () {
                          final code = _currentTeam?.invitationCode ?? _currentPlan?.inviteCode ?? '';
                          Clipboard.setData(ClipboardData(text: code));
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Copied code "$code" to clipboard!'),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Members List Section
              const Text(
                'SQUAD MEMBERS',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1, color: Color(0xFF64748B)),
              ),
              const SizedBox(height: 8),

              if (_teamMembers.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Text(
                    'No members joined yet. Share the code to invite friends!',
                    style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                  ),
                )
              else
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 220),
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: _teamMembers.length,
                    separatorBuilder: (_, __) => const Divider(height: 12),
                    itemBuilder: (ctx, i) {
                      final m = _teamMembers[i];
                      final profile = m['profiles'] as Map<String, dynamic>?;
                      final memberRole = m['member_role']?.toString() ?? 'MEMBER';
                      final fullName = profile?['full_name'] ?? 'Traveler';
                      final initials = fullName.length >= 2
                          ? fullName.substring(0, 2).toUpperCase()
                          : 'TR';

                      return Row(
                        children: [
                          CircleAvatar(
                            radius: 16,
                            backgroundColor: memberRole == 'OWNER' ? blue : const Color(0xFF94A3B8),
                            child: Text(
                              initials,
                              style: const TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.bold),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      fullName,
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: ink),
                                    ),
                                    if (m['user_id'] == user?.id)
                                      const Text(' (You)', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                                  ],
                                ),
                                Text(
                                  'Level ${profile?['progress_level'] ?? 1} • ${profile?['exploration_points'] ?? 0} pts',
                                  style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: memberRole == 'OWNER' ? const Color(0xFFFEF3C7) : const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                if (memberRole == 'OWNER') ...[
                                  const Icon(Icons.star, size: 12, color: Colors.amber),
                                  const SizedBox(width: 4),
                                ],
                                Text(
                                  memberRole == 'OWNER' ? 'HOST' : 'MEMBER',
                                  style: TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold,
                                    color: memberRole == 'OWNER' ? const Color(0xFFD97706) : const Color(0xFF64748B),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),

              const SizedBox(height: 20),

              // Action: Go to Full Team Hub Screen
              if (_currentTeam != null)
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(ctx);
                      openPage(TeamDetailScreen(groupId: _currentTeam!.groupId));
                    },
                    icon: const Icon(Icons.settings_outlined, size: 18),
                    label: const Text('Open Full Team Hub', style: TextStyle(fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: blue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  int get days => end.difference(start).inDays + 1;
  String date(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
  void note(String s) {
    if (mounted) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(
            content: Text(s), behavior: SnackBarBehavior.floating));
    }
  }

  Future<void> load() async {
    if (api == null) return;
    setState(() => loading = true);
    try {
      final r = await api!.loadMyPlans();
      if (mounted) setState(() {
        plans = r;
        _allPlans = r;
        _displayedPlans = r; // Initialize to show everything
      });
    } catch (e) {
      note('Unable to load plans: $e');
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _initController() async {
    try {
      api = await TripPlannerController.createProduction();
      await load();
    } catch (e) {
      setState(() => error = '$e');
    }
  }

  void fresh() => setState(() {
        isCreating = true;
        page = 1;
        history = false;
        name.clear();
        teamName.clear();
        teamMaxCapacity = 5;
        mode = 'solo';
        places = [];
        stops = [];
        route = null;
        accepted = false;
        nearby();
      });

  void viewPlan(TripPlan p) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    setState(() {
      isCreating = false;
      _currentPlan = p;
      name.text = p.name;
      start = p.startDate;
      end = p.endDate;
      mode = p.mode;
      stops = List.from(p.stops);
      accepted = p.routeAccepted;
      history = end.isBefore(today);
      route = null; // reset first

      // Load squad if team plan
      if (p.mode == 'team') {
        _loadSquadForPlan();
      }

      // CHANGE HERE: Only clear maps if this is a DIFFERENT plan
      if (_lastViewedPlanId != p.id) {
        _dayRoutes.clear();
        _dayAccepted.clear();
        _lastViewedPlanId = p.id;
      }

      routeDay = days > 1 ? 1 : 0;
      page = 3;
    });
    // If accepted and has at least 2 stops, fetch the route asynchronously
    if (accepted && stops.length >= 2) {
      _fetchRoute();
    }
  }

// Helper method to fetch route asynchronously
  Future<void> _fetchRoute() async {
    try {
      final newRoute = await api!.planEfficientRoute(stops);
      if (mounted) {
        setState(() {
          route = newRoute;
        });
      }
    } catch (_) {}
  }

  Future<void> pick(bool first) async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    // CHANGE HERE: Allow starting a trip up to 2 years in advance!
    final lastAllowedDate = today.add(const Duration(days: 730));

    final safeInitial = first ? start : end;
    final initialDate = safeInitial.isBefore(today) ? today : safeInitial;

    final d = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: today,
      lastDate: lastAllowedDate,
    );

    if (d != null) {
      setState(() {
        if (first) {
          start = d;
          // FIX: Use maxTripDays - 1 so the total count is 14 days (not 15)
          final maxEndDate = start.add(Duration(days: maxTripDays - 1));
          if (end.isAfter(maxEndDate)) {
            end = maxEndDate;
            note('Trip end date adjusted to the maximum of $maxTripDays days.');
          } else if (end.isBefore(d)) {
            end = d;
          }
        } else {
          // FIX: Use maxTripDays - 1 so the total count is 14 days (not 15)
          final maxEndDate = start.add(Duration(days: maxTripDays - 1));
          if (d.isAfter(maxEndDate)) {
            note('Your trip cannot exceed $maxTripDays days.');
            end = maxEndDate; // Force it to the maximum allowed
          } else {
            end = d.isBefore(start) ? start : d;
          }
        }
        final newTotalDays = end.difference(start).inDays + 1;

        // NEW LOGIC: Remove stops that are now out of range
        if (stops.any((stop) => stop.dayNumber > newTotalDays)) {
          stops.removeWhere((stop) => stop.dayNumber > newTotalDays);
          note('One or more destinations were removed because they fell outside the new trip dates.');
        }

        normalizeStops();

      });
    }
  }

  Future<void> _loadBlindBoxPlaces() async {
    if (blindBoxController == null) return;
    try {
      final history = await blindBoxController!.loadBlindBoxHistory();
      if (mounted) {
        setState(() {
          // Map the BlindBoxHistoryResult to PlaceCandidate for the map
          blindBoxPlaces = history.map((h) => PlaceCandidate(
            placeId: h.placeId,
            name: h.name,
            formattedAddress: h.address,
            latitude: h.latitude,
            longitude: h.longitude,
            primaryType: h.category,
            rating: h.rating,
            userRatingCount: h.userRatingCount,
          )).toList();
        });
      }
    } catch (e) {
      note('Unable to load Blind Box history: $e');
    }
  }

  Future<void> search() async {
    if (placeSearch.text.trim().isEmpty || api == null) return;
    setState(() => loading = true);
    try {
      final r = await api!.search(placeSearch.text);
      if (mounted) setState(() => places = r);
      if (r.isEmpty) note('No destinations found for this search.');
    } catch (e) {
      note('Destination search failed: $e');
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> nearby() async {
    if (api == null) return;
    setState(() => loading = true);
    try {
      // 1. Capture the user's current location
      _userLocation = await api!.getCurrentLocation();

      final r = await api!.exploreNearby();
      if (mounted) setState(() {
        nearbyPlaces = r;
        print('📍 Nearby places: ${nearbyPlaces.length}');
      });
    } catch (e) {
      note('Nearby search failed: $e');
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }



  void add(PlaceCandidate p) {
    if (history) {
      note('You cannot edit a past trip.');
      return;
    }

    if (stops.any((x) => x.placeId == p.placeId)) {
      note('This destination is already in your itinerary.');
      return;
    }
    final day = List.generate(days, (i) => i + 1).cast<int?>().firstWhere(
            (d) => stops.where((x) => x.dayNumber == d).length < destinationsPerDay,
        orElse: () => null);
    if (day == null) {
      note(
          'All $days days already have $destinationsPerDay destinations. Remove a destination or extend the trip.');
      return;
    }
    final position = stops.where((x) => x.dayNumber == day).length + 1;
    setState(() {
      stops.add(ItineraryStop(
          placeId: p.placeId,
          name: p.name,
          address: p.formattedAddress,
          latitude: p.latitude,
          longitude: p.longitude,
          dayNumber: day,
          sortOrder: position,
          source: 'GOOGLE'));

      // ✨ NEW CODE: Remove it from the search/nearby lists so the red pin disappears
      places.removeWhere((element) => element.placeId == p.placeId);
      nearbyPlaces.removeWhere((element) => element.placeId == p.placeId);
      blindBoxPlaces.removeWhere((element) => element.placeId == p.placeId);

      route = null;
      accepted = false;
    });

    _placeSearchFocus.unfocus();
    placeSearch.clear();

    note('${p.name} added to Day $day, position $position.');

    note('${p.name} added to Day $day, position $position.');

    FocusManager.instance.primaryFocus?.unfocus(); // Force close keyboard
    placeSearch.clear(); // Clear the search box so it loses focus
  }

  void next() {
    if (name.text.trim().isEmpty) {
      note('Please enter a trip plan name.');
      return;
    }
    if (stops.isEmpty) {
      note('Add at least one destination first.');
      return;
    }
    setState(() {
      normalizeStops();
      // Starts on Day 1 if it's a multi-day trip (instead of "All Days")
      routeDay = days > 1 ? 1 : 0;
      page = 2;
    });
  }

  void generate() async {
    if (stops.length < 2) {
      note('Add at least two destinations to plan a route.');
      return;
    }
    setState(() => loading = true);

    // 1. Get the user's current location
    // (Ensure your TripPlannerController has a getCurrentLocation method or use LocationDataSource directly)
    final position = await api!.getCurrentLocation();

    // 2. Get the stops for the selected day
    final s = routeDay == 0
        ? stops
        : stops.where((x) => x.dayNumber == routeDay).toList();

    // 3. Create a "Start" stop representing the current location
    final startStop = ItineraryStop(
      placeId: 'current_location',
      name: 'My Location',
      address: 'Your current location', // <--- ADD THIS
      latitude: position.latitude,
      longitude: position.longitude,
      dayNumber: routeDay == 0 ? 1 : routeDay,
      sortOrder: 0,
      source: 'GPS', // <--- ADD THIS
    );

    // 4. Combine the start point with the actual destinations
    final fullRouteStops = [startStop, ...s];

    try {
      // 5. Plan the route including the start location
      final newRoute = await api!.planEfficientRoute(fullRouteStops);
      if (mounted) {
        setState(() {
          route = newRoute;
          accepted = false;
          loading = false;
          // SAVE to map so it persists when switching days
          _dayRoutes[routeDay] = newRoute;
          _dayAccepted[routeDay] = false;
        });
        _focusOnStart();
      }
    } catch (e) {
      note('$e');
      if (mounted) setState(() => loading = false);
    }
  }

  void accept() {
    if (route == null) return;
    setState(() {
      accepted = true;
      _dayAccepted[routeDay] = true;

      // Update the local plan object so we remember it
      if (_currentPlan != null) {
        _currentPlan = TripPlan(
          id: _currentPlan!.id,
          name: _currentPlan!.name,
          startDate: _currentPlan!.startDate,
          endDate: _currentPlan!.endDate,
          mode: _currentPlan!.mode,
          visibility: _currentPlan!.visibility,
          inviteCode: _currentPlan!.inviteCode,
          routeAccepted: true, // Only this changes
          stops: _currentPlan!.stops,
        );

        // Find the plan in the main list and update it too
        final index = plans.indexWhere((x) => x.id == _currentPlan?.id);
        if (index != -1) {
          plans[index] = _currentPlan!;
        }
      }
    });
    reorderStopsFromRoute();

    _focusOnStart();
    note('Route accepted.');
  }

  void reorderStopsFromRoute() {
    if (route == null || route!.points.isEmpty) return;

    // Get only the stops for the currently selected day (0 means all days)
    final currentStops = stops.where((s) => routeDay == 0 || s.dayNumber == routeDay).toList();
    if (currentStops.length < 2) return;

    List<ItineraryStop> reorderedStops = [];

    // Walk through the polyline points and find which stop is closest (within 50 meters)
    // This gives us the actual driving order from the map
    for (final point in route!.points) {
      for (final stop in currentStops) {
        final dist = _calculateDistance(point, LatLng(stop.latitude, stop.longitude));
        if (dist < 0.05) { // 50 meters threshold
          if (!reorderedStops.contains(stop)) {
            reorderedStops.add(stop);
          }
        }
      }
    }

    // Safety: Add any stops that were somehow missed by the map matching
    for (final stop in currentStops) {
      if (!reorderedStops.contains(stop)) {
        reorderedStops.add(stop);
      }
    }

    setState(() {
      // Remove the current day's stops from the main list
      stops.removeWhere((s) => routeDay == 0 || s.dayNumber == routeDay);

      // Add the stops back in the optimized map order with new sort numbers
      for (var i = 0; i < reorderedStops.length; i++) {
        stops.add(reorderedStops[i].copyWith(sortOrder: i + 1));
      }

      // Sort the whole list so Day 1, Day 2, etc. are still grouped correctly
      stops.sort((a, b) {
        if (a.dayNumber == b.dayNumber) {
          return a.sortOrder.compareTo(b.sortOrder);
        }
        return a.dayNumber.compareTo(b.dayNumber);
      });
    });
  }

  void _focusOnStart() {
    if (_mapController == null) return;

    // The first point of the route is always the "current location" start point
    if (route != null && route!.points.isNotEmpty) {
      final startPoint = route!.points.first;
      _mapController!.animateCamera(CameraUpdate.newCameraPosition(
        CameraPosition(
          target: LatLng(startPoint.latitude, startPoint.longitude),
          zoom: 15, // Good zoom level to see the dot and first destination
        ),
      ));
    } else if (stops.isNotEmpty) {
      // Fallback if route isn't loaded yet
      final firstStop = stops.first;
      _mapController!.animateCamera(CameraUpdate.newCameraPosition(
        CameraPosition(
          target: LatLng(firstStop.latitude, firstStop.longitude),
          zoom: 14,
        ),
      ));
    }
  }

  Future<void> remove(int i) async {
    final yes = await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
                title: const Text('Remove destination?'),
                content:
                    const Text('Are you sure you want to remove this destination?'),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(c, false),
                      child: const Text('Cancel')),
                  FilledButton(
                      style: FilledButton.styleFrom(backgroundColor: Colors.red),
                      onPressed: () => Navigator.pop(c, true),
                      child: const Text('Remove'))
                ]));
    if (yes == true) {
      setState(() {
        stops.removeAt(i);
        normalizeStops();
        route = null;
        accepted = false;
      });
    }
  }

  Future<void> save() async {
    if (stops.isEmpty) {
      note('Add at least one destination first.');
      return;
    }

    final newName = name.text.trim().toLowerCase();
    if (plans.any((p) => p.name.toLowerCase() == newName)) {
      note('A plan with this name already exists. Please choose a different name.');
      return;
    }

    setState(() => loading = true);

    try {
      normalizeStops();

      String? generatedCode;

      // --- CREATE SQUAD IN SUPABASE IF TEAM EXPEDITION ---
      if (mode == 'team') {
        final user = Supabase.instance.client.auth.currentUser;
        if (user == null) {
          note('Please sign in to create a team expedition.');
          setState(() => loading = false);
          return;
        }

        final finalTeamName = teamName.text.trim().isNotEmpty
            ? teamName.text.trim()
            : '${name.text.trim()} Squad';

        final teamType = openPublic ? 'PUBLIC' : 'PRIVATE';

        // 1. Create team via GroupService
        final newGroup = await _groupService.createTeam(
          ownerId: user.id,
          teamName: finalTeamName,
          teamType: teamType,
          maxCapacity: teamMaxCapacity,
        );

        generatedCode = newGroup.invitationCode;

        // 2. Update user profile team status
        await Supabase.instance.client
            .from('profiles')
            .update({'team_status': openPublic ? 'PUBLIC_TEAM' : 'PRIVATE_TEAM'})
            .eq('id', user.id);
      }

      // --- SAVE TRIP PLAN ---
      final p = await api!.savePlan(TripPlan(
        id: '',
        name: name.text.trim(),
        startDate: start,
        endDate: end,
        mode: mode,
        visibility: openPublic ? 'public' : 'private',
        inviteCode: generatedCode,
        routeAccepted: accepted,
        stops: stops,
      ));

      if (mounted) {
        setState(() {
          _currentPlan = p;
          plans = [p, ...plans];
          _allPlans = [p, ..._allPlans];
          _displayedPlans = [p, ..._displayedPlans];
          page = 3; // Navigate to Itinerary view
          history = false;
          isCreating = false;
          dashboardPage = 0;
        });

        if (mode == 'team') {
          _loadSquadForPlan(); // <-- Trigger squad fetch
        }

        // Show dialog with code if private team
        if (mode == 'team' && generatedCode != null) {
          _showTeamCodeSuccessDialog(generatedCode);
        } else {
          note('Trip plan created successfully.');
        }
      }
    } on PostgrestException catch (e) {
      if (e.code == '23505') {
        note('A plan with this name already exists. Please choose a different name.');
      } else {
        note('Unable to save plan: ${e.message}');
      }
    } catch (e) {
      note('Unable to save plan: $e');
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  // Dialog showing the generated 6-character private invite code
  void _showTeamCodeSuccessDialog(String code) {
    if (code == null || code.isEmpty) return;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.celebration, color: blue),
            SizedBox(width: 8),
            Text('Squad Ready!'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Your team expedition has been created! Share this invitation code with your squad members to join via the Teams screen:',
              style: TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFF0F9FF),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFBAE6FD), width: 1.5),
              ),
              child: SelectableText(
                code,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 4,
                  color: blue,
                ),
              ),
            ),
          ],
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(ctx),
            style: FilledButton.styleFrom(backgroundColor: blue),
            child: const Text('Got it!'),
          ),
        ],
      ),
    );
  }

  void openPage(Widget page) =>
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));
  void goHome() {
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    } else {
      note('You are already on the main screen.');
    }
  }

  void _openFilterMenu() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Padding(
          // Better padding from all sides, especially the bottom
          padding: const EdgeInsets.fromLTRB(20.0, 24.0, 20.0, 32.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            // This is the key change: it makes the children span the full width
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                "Filter by Date",
                textAlign: TextAlign.center,
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
              const SizedBox(height: 24),
              FilledButton(
                // Adding padding and rounded corners to the button
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                onPressed: () async {
                  DateTime? pickedDate = await showDatePicker(
                    context: context,
                    initialDate: DateTime.now(),
                    firstDate: DateTime(2020),
                    lastDate: DateTime(2030),
                  );
                  if (pickedDate != null) {
                    _applyFilter(pickedDate);
                    Navigator.pop(context);
                  }
                },
                child: const Text("Pick a Specific Day"),
              ),
              const SizedBox(height: 12),
              TextButton(
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: () {
                  _clearFilter();
                  Navigator.pop(context);
                },
                child: const Text("Show All Days", style: TextStyle(color: Colors.grey)),
              ),
            ],
          ),
        );
      },
    );
  }

  void _applyFilter(DateTime selectedDate) {
    setState(() {
      _selectedFilterDate = selectedDate;
      _displayedPlans = _allPlans.where((plan) {
        // Normalize to just the day (remove time)
        DateTime pStart = DateTime(plan.startDate.year, plan.startDate.month, plan.startDate.day);
        DateTime pEnd = DateTime(plan.endDate.year, plan.endDate.month, plan.endDate.day);
        DateTime nSelected = DateTime(selectedDate.year, selectedDate.month, selectedDate.day);

        // Check if the selected day falls inside the trip dates
        return !nSelected.isBefore(pStart) && !nSelected.isAfter(pEnd);
      }).toList();
    });
  }

  void _clearFilter() {
    setState(() {
      _selectedFilterDate = null;
      _displayedPlans = _allPlans;
    });
  }

  @override
  Widget build(BuildContext c) {
    final body = error != null
        ? Center(child: Text(error!))
        : page == 0
            ? dashboard()
            : page == 1
                ? create()
                : page == 2
                  ? dayByDayStep()
                  : itinerary();
    return Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        body: SafeArea(
            child: Stack(children: [
          Column(children: [header(), Expanded(child: body)]),
          Align(alignment: Alignment.bottomCenter, child: bottom()),
          if (page == 0)
            Positioned(right: 10, bottom: 200, child: createButton())
        ])));
  }

  Widget header() => Container(
      height: 68,
      padding: const EdgeInsets.fromLTRB(16, 0, 12, 0),
      decoration: const BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
                color: Color(0x240F172A), blurRadius: 5, offset: Offset(0, 2))
          ],
          border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0)))),
      child: Row(children: [
        InkWell(
            onTap: goHome,
            customBorder: const CircleBorder(),
            child: Container(
                width: 38,
                height: 38,
                decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                        colors: [blue, teal],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight),
                    boxShadow: [
                      BoxShadow(
                          color: Color(0x300284C7),
                          blurRadius: 10,
                          offset: Offset(0, 4))
                    ]),
                child: const Icon(Icons.explore_rounded,
                    color: Colors.white, size: 23))),
        const SizedBox(width: 10),
        Expanded(
          child: InkWell(
              onTap: goHome,
              child: const FittedBox(
                  alignment: Alignment.centerLeft,
                  fit: BoxFit.scaleDown,
                  child: Text('MYSTERYLANE',
                      style: TextStyle(
                          color: ink,
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -.5)))),
        ),
        action(Icons.emoji_events_rounded, const Color(0xFFFFFBEB),
            const Color(0xFFD97706), () => note('Leaderboard is not available yet.')),
        const SizedBox(width: 6),
        action(Icons.chat_bubble_outline_rounded, const Color(0xFFF0F9FF), blue,
            () => note('Chat is not available yet.')),
        const SizedBox(width: 6),
        InkWell(
            onTap: () => openPage(const ProfileScreen()),
            customBorder: const CircleBorder(),
            child: Container(
                width: 38,
                height: 38,
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    border: Border.all(color: const Color(0xFFBAE6FD), width: 1.4)),
                child: const CircleAvatar(
                    backgroundColor: Color(0xFFE0F2FE),
                    child: Icon(Icons.person_rounded, size: 20, color: blue))))
      ]));

  Widget dayByDayStep() => ListView(
    padding: const EdgeInsets.fromLTRB(18, 20, 18, 102),
    children: [
      banner(),
      const SizedBox(height: 18),
      tabs(active: false, enabled: true),
      const SizedBox(height: 18),
      Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: const Color(0xFFF1F5F9)),
        ),
        child: Column(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: step('STEP 2 OF 2 • ITINERARY & ROUTE', 'Day by Day Places')),
                const SizedBox(width: 8),
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: OutlinedButton(
                    onPressed: () => setState(() => page = 1),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      minimumSize: const Size(0, 32),
                      side: const BorderSide(color: border),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))
                    ),
                    child: const Text('Back', style: TextStyle(color: ink, fontSize: 11, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),
            ...stops.asMap().entries.map((e) => stopTile(e.key, e.value)),
            const SizedBox(height: 20),
            label('SELECT EXPEDITION MODE'),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: modeButton('Solo Expedition', 'solo')),
              const SizedBox(width: 10),
              Expanded(child: modeButton('Team Expedition', 'team')),
            ]),

            // --- TEAM EXPEDITION CONFIGURATION ---
            if (mode == 'team') ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0F9FF),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFBAE6FD)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      const Icon(Icons.groups_rounded, color: blue, size: 20),
                      const SizedBox(width: 8),
                      const Text(
                        'CREATE SQUAD SETTINGS',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                          letterSpacing: 1,
                          color: blue,
                        ),
                      ),
                    ]),
                    const SizedBox(height: 14),

                    // Team Name input field
                    label('SQUAD NAME *'),
                    const SizedBox(height: 6),
                    field(
                      teamName,
                      name.text.isNotEmpty ? '${name.text.trim()} Squad' : 'Enter Squad Name',
                          (_) {},
                    ),
                    const SizedBox(height: 14),

                    // Access Type (Public vs Private Code)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Access Type',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: ink),
                            ),
                            Text(
                              openPublic ? 'Public: Listed in Teams tab' : 'Private: Requires 6-char code',
                              style: const TextStyle(fontSize: 10, color: Color(0xFF64748B)),
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.all(3),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: border),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              small('PUBLIC', openPublic, () => setState(() => openPublic = true)),
                              small('PRIVATE', !openPublic, () => setState(() => openPublic = false)),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // Member Capacity stepper
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Max Capacity',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: ink),
                        ),
                        Row(
                          children: [
                            IconButton(
                              icon: const Icon(Icons.remove_circle_outline, color: blue, size: 22),
                              onPressed: teamMaxCapacity > 2
                                  ? () => setState(() => teamMaxCapacity--)
                                  : null,
                            ),
                            Text(
                              '$teamMaxCapacity Members',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                            IconButton(
                              icon: const Icon(Icons.add_circle_outline, color: blue, size: 22),
                              onPressed: teamMaxCapacity < 10
                                  ? () => setState(() => teamMaxCapacity++)
                                  : null,
                            ),
                          ],
                        ),
                      ],
                    ),
                    const Divider(height: 20),

                    // Info explanation card
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            openPublic ? Icons.public : Icons.lock_outline,
                            size: 16,
                            color: openPublic ? const Color(0xFF00A774) : blue,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              openPublic
                                  ? 'Other travelers can browse and request to join this squad in the Teams UI.'
                                  : 'A unique 6-character invitation code will be generated upon creation.',
                              style: const TextStyle(fontSize: 11, color: ink),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 20),
            label('PLAN ROUTE PREVIEW'),
            const SizedBox(height: 12),
            routePreview(stops),
            const SizedBox(height: 15),

            // ADD THIS BLOCK
            if (days > 1) ...[
              label('PLAN ROUTE BY DAY'),
              const SizedBox(height: 8),
              SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(children: [
                    for (int i = 1; i <= days; i++) routePill('Day $i', i),
                  ])),
              const SizedBox(height: 16),
            ],
            // End of added block

            if (route == null)
              primary('PLAN ROUTE', generate)
            else if (!accepted)
              Row(children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: accept,
                    icon: const Icon(Icons.thumb_up_alt_outlined, size: 18),
                    label: const Text("Accept Route", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    style: OutlinedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: const Color(0xFF00A774), // Green
                        side: const BorderSide(color: Color(0xFF00A774), width: 1.5),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => setState(() { route = null; accepted = false; }),
                    icon: const Icon(Icons.thumb_down_alt_outlined, size: 18),
                    label: const Text("Reject Route", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    style: OutlinedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: const Color(0xFFEF4444), // Red
                        side: const BorderSide(color: Color(0xFFEF4444), width: 1.5),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))
                    ),
                  ),
                ),
              ])
            else
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0FDF4),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFBBF7D0)),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.verified_rounded, color: Color(0xFF16A34A), size: 18),
                    SizedBox(width: 8),
                    Text('Route Plan Accepted', style: TextStyle(color: Color(0xFF16A34A), fontWeight: FontWeight.bold, fontSize: 13)),
                  ],
                ),
              ),

            const SizedBox(height: 30),
            primary('START YOUR ADVENTURE', loading ? null : save)
          ],
        ),
      ),
    ],
  );

  Widget action(IconData i, Color bg, Color fg, VoidCallback tap) => InkWell(
      onTap: tap,
      customBorder: const CircleBorder(),
      child: Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
              color: bg,
              shape: BoxShape.circle,
              border: Border.all(color: fg.withValues(alpha: .20))),
          child: Icon(i, color: fg, size: 20)));
  Widget banner() => Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 17),
      decoration: BoxDecoration(
          gradient: const LinearGradient(
              colors: [blue, teal, blue], stops: [0, .5, 1]),
          borderRadius: BorderRadius.circular(17),
          boxShadow: const [
            BoxShadow(
                color: Color(0x440284C7), blurRadius: 9, offset: Offset(0, 4))
          ]),
      child: Row(children: [
        const Icon(Icons.auto_awesome, color: Color(0xFFBAE6FD)),
        const SizedBox(width: 10),
        const Expanded(
            child: Text('MYSTERYLANE PLANNER\nSYSTEM',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.7))),
        Container(
            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
            decoration: BoxDecoration(
                color: const Color(0x4438BDF8),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: const Color(0x99BAE6FD))),
            child: const Text('DYNAMIC\nROUTING',
                style: TextStyle(
                    fontSize: 8,
                    color: Colors.white,
                    fontWeight: FontWeight.bold)))
      ]));

  Widget tabs({bool active = true, bool enabled = true}) => Container(
    padding: const EdgeInsets.all(7),
    decoration: BoxDecoration(
      color: const Color(0xFFF0F9FF),
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: const Color(0xFFD7EAF7)),
    ),
    child: Row(children: [
      Expanded(
        child: tab('My Plan', Icons.explore_outlined, active && !history, () {
          if (enabled) {
            // Only show popup if actively creating a new plan (Page 1 or 2)
            if (page == 1 || page == 2) {
              showDialog(
                context: context,
                builder: (c) => AlertDialog(
                  title: const Text('Leave this page?'),
                  content: const Text('Your current unsaved progress will be lost.'),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(c), child: const Text('Cancel')),
                    FilledButton(
                      onPressed: () {
                        Navigator.pop(c);
                        setState(() {
                          isCreating = false; // Reset it!
                          history = false;
                          page = 0;
                          dashboardPage = 0;
                        });
                      },
                      child: const Text('Leave'),
                    ),
                  ],
                ),
              );
            } else {
              // Dashboard or Viewing a saved plan -> Just switch instantly
              setState(() { history = false; page = 0; });
            }
          }
        }),
      ),
      Expanded(
        child: tab('History', Icons.history, active && history, () {
          if (enabled) {
            if (page == 1 || page == 2) {
              showDialog(
                context: context,
                builder: (c) => AlertDialog(
                  title: const Text('Leave this page?'),
                  content: const Text('Your current unsaved progress will be lost.'),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(c), child: const Text('Cancel')),
                    FilledButton(
                      onPressed: () {
                        Navigator.pop(c);
                        setState(() {
                          isCreating = false; // Reset it!
                          history = true;
                          page = 0;
                          dashboardPage = 0;
                        });
                      },
                      child: const Text('Leave'),
                    ),
                  ],
                ),
              );
            } else {
              // Dashboard or Viewing a saved plan -> Just switch instantly
              setState(() { history = true; page = 0; });
            }
          }
        }),
      )
    ]),
  );

  Widget tab(String s, IconData i, bool on, VoidCallback f) => InkWell(
      onTap: f,
      borderRadius: BorderRadius.circular(14),
      child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
              color: on ? blue : Colors.transparent,
              borderRadius: BorderRadius.circular(14)),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(i, size: 18, color: on ? Colors.white : const Color(0xFF475569)),
            const SizedBox(width: 6),
            Text(s,
                style: TextStyle(
                    fontFamily: 'serif',
                    color: on ? Colors.white : const Color(0xFF334155),
                    fontWeight: FontWeight.bold))
          ])));

  Widget dashboard() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final q = planSearch.text.toLowerCase();

    final filteredByDate = _displayedPlans.where((p) {
      final isHistory = p.endDate.isBefore(today);
      return history ? isHistory : !isHistory;
    }).toList();

    final list = filteredByDate
        .where((p) => q.isEmpty || p.name.toLowerCase().contains(q))
        .toList();

    // Calculate Pagination
    int totalPages = (list.length / itemsPerPage).ceil();
    if (totalPages == 0) totalPages = 1; // Prevent division by zero
    if (dashboardPage >= totalPages) dashboardPage = totalPages - 1;

    // Slice the list for the current page
    final paginatedList = list.skip(dashboardPage * itemsPerPage).take(itemsPerPage).toList();

    return ListView(padding: const EdgeInsets.fromLTRB(16, 18, 16, 155), children: [
      banner(),
      const SizedBox(height: 20),
      tabs(),
      const SizedBox(height: 18),
      Row(children: [
        Expanded(
            child: field(
                planSearch,
                history
                    ? 'Search history plans or destination'
                    : 'Search active plans or destination',
                    (_) => setState(() { dashboardPage = 0; }),
                suffix: Icons.search)), // <--- ADD THIS
        const SizedBox(width: 8),
        InkWell(
          onTap: _openFilterMenu,
          child: boxIcon(Icons.tune),
        ),
      ]),
      const SizedBox(height: 22),
      Row(children: [
        Text(history ? 'Expedition History' : 'Active Expeditions',
            style: const TextStyle(
                fontFamily: 'serif', fontSize: 23, fontWeight: FontWeight.w900)),
        const Spacer(),
        Text('${list.length} PLANS',
            style: const TextStyle(
                fontSize: 10,
                color: blue,
                fontWeight: FontWeight.bold,
                letterSpacing: 1))
      ]),
      const SizedBox(height: 12),
      if (loading)
        const Center(
            child: Padding(
                padding: EdgeInsets.all(24), child: CircularProgressIndicator()))
      else if (list.isEmpty)
        empty()
      else ...[
          ...paginatedList.map(cardPlan),

          // THE NEW PAGINATION BAR
          if (totalPages > 1) ...[
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(15),
                border: Border.all(color: border),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  TextButton(
                    onPressed: dashboardPage == 0 ? null : () => setState(() => dashboardPage--),
                    child: const Text('< Prev', style: TextStyle(color: blue, fontWeight: FontWeight.bold)),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text('Page ${dashboardPage + 1} of $totalPages',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  ),
                  TextButton(
                    onPressed: dashboardPage >= totalPages - 1 ? null : () => setState(() => dashboardPage++),
                    child: const Text('Next >', style: TextStyle(color: blue, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),
          ],
        ]
    ]);
  }

  Widget create() => ListView(padding: const EdgeInsets.fromLTRB(18, 20, 18, 102), children: [
        banner(),
        const SizedBox(height: 18),
        tabs(active: false, enabled: true),
        const SizedBox(height: 22),
        surface(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          step('STEP 1 OF 2 • TRIP SETUP', 'Create New Expedition\nPlan'),
          const Divider(height: 28),
          label('TRIP PLAN NAME *'),
          const SizedBox(height: 8),
          field(name, 'Enter Trip Plan Name', (val) {
            // If the name they typed matches an existing plan, show a warning
            if (plans.any((p) => p.name.toLowerCase() == val.toLowerCase())) {
              note('Name already exists!');
            }
          }),
          const SizedBox(height: 16),
          Row(children: [
            Expanded(child: dateBox('START DATE', start, () => pick(true))),
            const SizedBox(width: 12),
            Expanded(child: dateBox('END DATE', end, () => pick(false)))
          ]),
          const SizedBox(height: 14),
          Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                  color: const Color(0xFFF0F9FF),
                  borderRadius: BorderRadius.circular(14)),
              child: Row(children: [
                const Expanded(
                    child: Text('Calculated Total Days:',
                        style:
                            TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                badge('$days DAYS')
              ])),
          const SizedBox(height: 20),
          mapSection(),
          const SizedBox(height: 20),
          primary('NEXT • DAY-BY-DAY SETUP  →', next)
        ]))
      ]);
  Widget mapSection() =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        primary(
            mapOpen ? 'CLOSE INTERACTIVE MAP' : 'OPEN INTERACTIVE MAP',
            () => setState(() => mapOpen = !mapOpen)),
        if (mapOpen) ...[
          const SizedBox(height: 18),
          field(placeSearch, 'Search map location, mission or landmark',
              (_) => search(),
              suffix: Icons.search,
              focusNode: _placeSearchFocus),

          const SizedBox(height: 12),
          SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(children: [
                pill('All Pins'),
                pill('Nearby (<5.0km)', pin: true),
                pill('Planner Pins', tick: true),
                pill('Blind Box', blind: true)
              ])),
          const SizedBox(height: 14),
          _buildMapWidget(),
          ...places.map((p) => ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const CircleAvatar(
                  backgroundColor: Color(0xFFE0F2FE),
                  child: Icon(Icons.location_pin, color: blue)),
              title: Text(p.name, maxLines: 1, overflow: TextOverflow.ellipsis),
              subtitle: Text(p.formattedAddress,
                  maxLines: 1, overflow: TextOverflow.ellipsis),
              trailing: FilledButton(onPressed: () => add(p), child: const Text('ADD'))))
        ]
      ]);

  Widget itinerary() => ListView(padding: const EdgeInsets.fromLTRB(18, 20, 18, 102), children: [
    banner(),
    const SizedBox(height: 18),
    tabs(),
    const SizedBox(height: 18),
    if(page == 3)
      outline('Print Trip Plan', const Color(0xFF00A774), _generateTripPdf),
    const SizedBox(height: 18),
    surface(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(child: step('EXPEDITION DETAILS & ROUTE', name.text)),
        badge(history ? 'COMPLETED' : 'ACTIVE')
      ]),
      const SizedBox(height: 20),
      Row(children: [
        Expanded(
            child: detailBox(
                'DATES', '${date(start)} →\n${date(end)}', '$days Days Trip')),
        const SizedBox(width: 12),
        Expanded(
          child: detailBox(
            mode == 'team' ? 'TEAM CODE' : 'EXPEDITION',
            mode == 'team' ? (_currentPlan?.inviteCode ?? 'PUBLIC') : 'SOLO',
            mode == 'team' ? 'TEAM MODE' : 'SOLO MODE',
          ),
        ),
      ]),
      const SizedBox(height: 14),
      const SizedBox(height: 14),

      // --- SINGLE "DUPLICATE PLAN" ACTION ---
      InkWell(
        onTap: _duplicatePlanDialog,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: const Row(
            children: [
              Icon(Icons.content_copy_rounded, size: 20, color: blue),
              SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Duplicate Trip Plan',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: ink),
                    ),
                    Text(
                      'Create a new copy of this plan as Solo or Team Expedition.',
                      style: TextStyle(fontSize: 10, color: Color(0xFF64748B)),
                    ),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_ios, size: 12, color: blue),
            ],
          ),
        ),
      ),
      const SizedBox(height: 24),
      // --- DYNAMIC SQUAD MEMBERS SECTION (TEAM EXPEDITION ONLY) ---
      if (mode == 'team') ...[
        const SizedBox(height: 24),
        Row(
          children: [
            Expanded(
              child: label('SQUAD MEMBERS (${_teamMembers.isNotEmpty ? _teamMembers.length : 1})'),
            ),
            TextButton.icon(
              onPressed: _openManageSquadBottomSheet,
              icon: const Icon(Icons.settings_outlined, size: 14, color: blue),
              label: const Text(
                'Manage Squad Members',
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: blue),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),

        if (_loadingTeam)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: LinearProgressIndicator(color: blue),
          )
        else if (_teamMembers.isEmpty)
        // Fallback if members haven't loaded yet or just created
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                member(
                  'ME',
                  'You (Host)',
                  blue,
                  true,
                ),
                const SizedBox(width: 8),
                InkWell(
                  onTap: _openManageSquadBottomSheet,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0F9FF),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFFBAE6FD)),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.person_add_alt_1_outlined, size: 14, color: blue),
                        SizedBox(width: 6),
                        Text(
                          'Invite Squad',
                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: blue),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          )
        else
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _teamMembers.map((m) {
                final profile = m['profiles'] as Map<String, dynamic>?;
                final role = m['member_role']?.toString() ?? 'MEMBER';
                final isHost = role == 'OWNER';
                final fullName = profile?['full_name'] ?? 'Traveler';
                final initials = fullName.length >= 2
                    ? fullName.substring(0, 2).toUpperCase()
                    : 'TR';

                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: member(
                    initials,
                    isHost ? '$fullName (Host)' : fullName,
                    isHost ? blue : const Color(0xFF64748B),
                    isHost,
                  ),
                );
              }).toList(),
            ),
          ),
      ],
      const Divider(height: 40),
      Row(children: [
        Expanded(child: label('DAY-BY-DAY ITINERARY')),
        const Text('Tap pencil to edit place\nlocation',
            textAlign: TextAlign.right,
            style: TextStyle(fontSize: 8, color: Colors.grey))
      ]),
      const SizedBox(height: 16),
      ...stops.asMap().entries.map((e) => stopTile(e.key, e.value)),
      const SizedBox(height: 28),
      label('CONNECTED PLAN ROUTE MAP'),
      const Text('Connected waypoints route map preview',
          style: TextStyle(fontSize: 9, color: Colors.grey)),
      const SizedBox(height: 16),
      Stack(children: [
        routePreview(routeDay == 0 ? stops : stops.where((x) => x.dayNumber == routeDay).toList()),
        Positioned(
            right: 10,
            top: 10,
            child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                    color: Colors.white.withOpacity(.85),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFBAE6FD))),
                child: const Row(children: [
                  Icon(Icons.hub_outlined, size: 14, color: blue),
                  SizedBox(width: 4),
                  Text('Fit Route View',
                      style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          color: blue))
                ])))
      ]),
      const SizedBox(height: 16),

      // ADD THE DAY SELECTOR HERE (This is the new part)
      if (days > 1) ...[
        label('PLAN ROUTE BY DAY'),
        const SizedBox(height: 8),
        SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(children: [
              for (int i = 1; i <= days; i++) routePill('Day $i', i),
            ])),
        const SizedBox(height: 16),
      ],

      if (route == null)
        primary('PLAN ROUTE', generate)
      else if (!accepted)
        Row(children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: accept,
              style: OutlinedButton.styleFrom(
                  backgroundColor: Colors.white, // White background
                  foregroundColor: const Color(0xFF00A774), // Green text
                  side: const BorderSide(color: Color(0xFF00A774), width: 1.5), // Green border
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))
              ),
              icon: const Icon(Icons.check_circle_outline, size: 18),
              label: const Text("Accept Route", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () => setState(() {
                route = null;
                accepted = false;
                _dayRoutes.remove(routeDay);
                _dayAccepted[routeDay] = false;
              }),
              style: OutlinedButton.styleFrom(
                  backgroundColor: Colors.white, // White background
                  foregroundColor: const Color(0xFFEF4444), // Red text
                  side: const BorderSide(color: Color(0xFFEF4444), width: 1.5), // Red border
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))
              ),
              icon: const Icon(Icons.cancel_outlined, size: 18),
              label: const Text("Reject Route", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
            ),
          ),
        ])
      else
        Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFF0FDF4),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFBBF7D0)),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.verified_rounded, color: Color(0xFF16A34A), size: 18),
                  SizedBox(width: 8),
                  Text('Route Accepted & Optimized', style: TextStyle(color: Color(0xFF16A34A), fontWeight: FontWeight.bold, fontSize: 13)),
                ],
              ),
            ),
            const SizedBox(height: 12),
            primary('RE-PLAN ROUTE', generate)
          ],
        ),
      // Removed the duplicate SizedBox here
      const SizedBox(height: 22),

      if (isCreating) primary('◉  START YOUR ADVENTURE', loading ? null : save),
      const SizedBox(height: 12),
      Center(
        child: TextButton.icon(
          onPressed: () => setState(() => page = 0),
          icon: const Icon(Icons.arrow_back, size: 16),
          label: const Text('Back to Plan Listing'),
          style: TextButton.styleFrom(foregroundColor: Colors.grey),
        ),
      ),
    ]))
  ]);

  void normalizeStops() {
    for (var day = 1; day <= days; day++) {
      final indexes = <int>[];
      for (var i = 0; i < stops.length; i++) {
        if (stops[i].dayNumber == day) {
          indexes.add(i);
        }
      }
      indexes.sort((a, b) => stops[a].sortOrder.compareTo(stops[b].sortOrder));
      for (var position = 0; position < indexes.length; position++) {
        stops[indexes[position]] =
            stops[indexes[position]].copyWith(sortOrder: position + 1); // Fix: 1-based
      }
    }
    stops.sort((a, b) => a.dayNumber == b.dayNumber
        ? a.sortOrder.compareTo(b.sortOrder)
        : a.dayNumber.compareTo(b.dayNumber));
  }

  Future<void> editSequence(int index) async {
    final originalDay = stops[index].dayNumber;
    final originalPosition = stops[index].sortOrder;
    var selectedDay = originalDay;
    var selectedPosition = originalPosition;
    int countFor(int day) => stops.where((x) => x.dayNumber == day).length;
    int maxPosition(int day) {
      if (day == originalDay) {
        return countFor(day);
      } else {

        return (countFor(day) + 1).clamp(1, destinationsPerDay);
      }
    }
    await showModalBottomSheet<void>(
        context: context,
        showDragHandle: true,
        builder: (context) => StatefulBuilder(
            builder: (context, setSheet) => Padding(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
                child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Adjust itinerary position',
                          style: TextStyle(
                              fontFamily: 'serif',
                              fontSize: 21,
                              fontWeight: FontWeight.bold)),
                      const SizedBox(height: 16),
                      const Text(
                          'Moving to a full day swaps the destination at the selected position.'),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<int>(
                          initialValue: selectedDay,
                          decoration: const InputDecoration(labelText: 'Day'),
                          items: List.generate(
                              days,
                              (d) => DropdownMenuItem(
                                  value: d + 1, child: Text('Day ${d + 1}'))),
                          onChanged: (v) => setSheet(() {
                                selectedDay = v!;
                                selectedPosition = 1;
                              })),
                      const SizedBox(height: 14),
                      DropdownButtonFormField<int>(
                          initialValue: selectedPosition,
                          decoration:
                              const InputDecoration(labelText: 'Position in the day'),
                          items: List.generate(
                              maxPosition(selectedDay),
                              (p) => DropdownMenuItem(
                                  value: p + 1, child: Text('Number ${p + 1}'))),
                          onChanged: (v) => setSheet(() => selectedPosition = v!)),
                      const SizedBox(height: 20),
                      primary('SAVE POSITION', () {
                        var swapped = false;
                        setState(() {
                          final moved = stops[index];
                          final targetIndex = stops.indexWhere((x) =>
                          x.dayNumber == selectedDay &&
                              x.sortOrder == selectedPosition);
                          final targetFull = selectedDay != originalDay &&
                              countFor(selectedDay) >= destinationsPerDay;

                          if (targetFull && targetIndex >= 0) {
                            // Swap logic (for moving to a full different day)
                            final displaced = stops[targetIndex];
                            stops[index] = displaced.copyWith(
                                dayNumber: originalDay,
                                sortOrder: originalPosition);
                            stops[targetIndex] = moved.copyWith(
                                dayNumber: selectedDay,
                                sortOrder: selectedPosition);
                            swapped = true;
                          } else {
                            // Robust Reorder Logic (Fixes your issue)
                            stops.removeAt(index);

                            // Extract all items for the target day and remove them temporarily
                            final dayItems = stops.where((x) => x.dayNumber == selectedDay).toList();
                            stops.removeWhere((x) => x.dayNumber == selectedDay);

                            // Calculate 0-based index for insertion
                            var pos = selectedPosition - 1;
                            if (pos < 0) pos = 0;
                            if (pos > dayItems.length) pos = dayItems.length;

                            // Insert the moved item with its proper temporary sortOrder
                            dayItems.insert(pos, moved.copyWith(dayNumber: selectedDay, sortOrder: pos + 1));

                            // Sort the day items to ensure correct relative order
                            dayItems.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));

                            // Add them back to the main list
                            stops.addAll(dayItems);
                          }

                          normalizeStops();
                          route = null;
                          accepted = false;
                        });
                        Navigator.pop(context);
                        note(swapped
                            ? 'Destinations swapped successfully.'
                            : 'Destination position updated.');
                      })
                    ]))));
  }
  Widget stopTile(int i, ItineraryStop s) => Container(
    margin: const EdgeInsets.only(bottom: 12),
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: border)),
    child: Row(children: [
      badge("D${s.dayNumber}"),
      const SizedBox(width: 12),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(s.name,
                style: const TextStyle(
                    fontFamily: 'serif',
                    fontSize: 15,
                    fontWeight: FontWeight.bold)),
            Text(i % 2 == 0 ? 'Secret Mission' : 'Historical Code',
                style: const TextStyle(fontSize: 10, color: Color(0xFF64748B)))
          ],
        ),
      ),
      // NEW: Only show edit/delete icons if it is NOT a history plan
      if (!history)
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            InkWell(
              onTap: () => editSequence(i),
              child: Icon(Icons.edit_outlined, size: 20, color: Colors.blueGrey.withValues(alpha: 0.6)),
            ),
            const SizedBox(width: 12),
            InkWell(
              onTap: () => remove(i),
              child: const Icon(Icons.delete_outline, color: Color(0xFFEF4444), size: 20),
            ),
          ],
        ),
    ]),
  );

  Widget bottom() => SizedBox(
      height: 78,
      child: Stack(clipBehavior: Clip.none, children: [
        Container(
            height: 78,
            decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(top: BorderSide(color: border))),
            child: Row(children: [
              Expanded(
                  child: nav(Icons.inventory_2_outlined, 'BLIND BOX', false,
                      () => openPage(const BlindBoxPage()))),
              Expanded(
                  child: nav(Icons.assignment_outlined, 'MISSIONS', false,
                      () => openPage(const CheckpointScreen()))),
              const SizedBox(width: 72),
              Expanded(child: nav(Icons.map_outlined, 'PLAN', true, () {})),
              Expanded(
                  child: nav(Icons.groups_2_outlined, 'TEAMS', false,
                      () => note('Teams is not available yet.')))
            ])),
        Positioned(
            top: -26,
            left: 0,
            right: 0,
            child: Center(
                child: InkWell(
                    onTap: goHome,
                    customBorder: const CircleBorder(),
                    child: Container(
                        width: 62,
                        height: 62,
                        decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: const LinearGradient(
                                colors: [blue, teal],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight),
                            border: Border.all(color: Colors.white, width: 4),
                            boxShadow: const [
                              BoxShadow(
                                  color: Color(0x3D0284C7),
                                  blurRadius: 16,
                                  offset: Offset(0, 7))
                            ]),
                        child: const Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.home_rounded,
                                  color: Color(0xFFFDE68A), size: 27),
                              Text('HOME',
                                  style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 8,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: .8))
                            ])))))
      ]));
  Widget nav(IconData i, String s, bool on, VoidCallback tap) => InkWell(
      onTap: tap,
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Container(
            width: on ? 48 : 39,
            height: on ? 43 : 32,
            decoration: BoxDecoration(
                color: on ? blue : Colors.transparent,
                borderRadius: BorderRadius.circular(16),
                boxShadow: on
                    ? const [
                        BoxShadow(
                            color: Color(0x550284C7),
                            blurRadius: 12,
                            offset: Offset(0, 5))
                      ]
                    : null),
            child: Icon(i, color: on ? Colors.white : const Color(0xFF64748B))),
        const SizedBox(height: 3),
        Text(s,
            textAlign: TextAlign.center,
            style: TextStyle(
                fontSize: 8,
                color: on ? blue : const Color(0xFF64748B),
                fontWeight: FontWeight.bold))
      ]));
  Widget createButton() => Material(
      color: Colors.transparent,
      child: InkWell(
          onTap: fresh,
          borderRadius: BorderRadius.circular(32),
          child: Container(
              width: 210,
              height: 60,
              decoration: BoxDecoration(
                  color: blue,
                  borderRadius: BorderRadius.circular(32),
                  boxShadow: const [
                    BoxShadow(
                        color: Color(0x550284C7),
                        blurRadius: 14,
                        offset: Offset(0, 6))
                  ]),
              child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircleAvatar(
                        radius: 15,
                        backgroundColor: Color(0x4438BDF8),
                        child: Icon(Icons.add, color: Colors.white)),
                    SizedBox(width: 9),
                    Text('Create New Plan',
                        style: TextStyle(
                            fontFamily: 'serif',
                            color: Colors.white,
                            fontWeight: FontWeight.w800))
                  ]))));

  Widget mapPreview() => Container(
      height: 245,
      decoration: BoxDecoration(
          color: const Color(0xFFD9EFF5),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFBAE6FD))),
      child: Stack(children: [
        const Center(child: Icon(Icons.map_outlined, size: 100, color: Color(0x550284C7))),
        Positioned(left: 12, top: 12, child: overlay('⌁ Google Maps + Places API', Colors.amber)),
        Positioned(left: 12, top: 48, child: overlay('⌾ Current Location Circle: 5km Radius', const Color(0xFF7DD3FC))),
        const Positioned(right: 12, top: 12, child: Icon(Icons.zoom_in_map, size: 34)),
        const Positioned(bottom: 8, right: 10, child: Text('Google Maps SDK pending', style: TextStyle(fontSize: 9, color: Color(0xFF475569))))
      ]));


  Widget _buildMapWidget() {
    final searchPinColor = BitmapDescriptor.hueRed;

    final markers = <Marker>{};
    // NEW: Only show blue Planner pins for the selected day
    final currentDayStops = routeDay == 0
        ? stops
        : stops.where((x) => x.dayNumber == routeDay).toList();

    // 1. Planner pins (blue) – from stops (already added to itinerary)
    if (filter == 'All Pins' || filter == 'Planner Pins') {
      for (final stop in currentDayStops) {
        markers.add(Marker(
          markerId: MarkerId('stop_${stop.placeId}'),
          position: LatLng(stop.latitude, stop.longitude),
          infoWindow: InfoWindow(title: stop.name),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue), // BLUE
        ));
      }
    }

    // 1.5 Search pins (RED - Uses the variable at the top)
    if (filter == 'All Pins') {
      for (final p in places) {
        markers.add(Marker(
          markerId: MarkerId('search_${p.placeId}'),
          position: LatLng(p.latitude, p.longitude),
          infoWindow: InfoWindow(title: p.name, snippet: p.formattedAddress),
          icon: BitmapDescriptor.defaultMarkerWithHue(searchPinColor),

          onTap: () {
            FocusManager.instance.primaryFocus?.unfocus();
            _showAddPlaceDialog(p);
          },
        ));
      }
    }

    // 2. Nearby pins (RED - Same color as Search)
    if (filter == 'All Pins' || filter == 'Nearby') {
      for (final p in nearbyPlaces) {
        markers.add(Marker(
          markerId: MarkerId('nearby_${p.placeId}'),
          position: LatLng(p.latitude, p.longitude),
          infoWindow: InfoWindow(title: p.name, snippet: p.formattedAddress),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
          // ADD THIS: Opens the dialog with the "Add to Trip" button
          onTap: () => _showAddPlaceDialog(p),
        ));
      }
    }

    // 3. Blind Box pins (PURPLE)
    if (filter == 'All Pins' || filter == 'Blind Box') {
      for (final p in blindBoxPlaces) {
        markers.add(Marker(
          markerId: MarkerId('blind_${p.placeId}'),
          position: LatLng(p.latitude, p.longitude),
          infoWindow: InfoWindow(title: p.name, snippet: p.formattedAddress),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueViolet),
          // ADD THIS: Opens the dialog with the "Add to Trip" button
          onTap: () => _showAddPlaceDialog(p),
        ));
      }
    }

    // Logic for initial camera view based on the selected filter
    final initialPosition = CameraPosition(
      target: _getInitialMapTarget(markers),
      zoom: 15, // Zoomed in a bit more to see the immediate area
    );



    return Container(
      height: 245,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFBAE6FD)),
      ),
      // Stack allows us to put the legend ON TOP of the map
      child: Stack(
        children: [
          // 1. Wrap map in GestureDetector to stop ListView from stealing vertical swipes
          GestureDetector(
            onVerticalDragUpdate: (details) {},
            child: GoogleMap(
              initialCameraPosition: initialPosition,
              markers: markers, // If empty, it just shows an empty map!
              myLocationEnabled: true,
              myLocationButtonEnabled: true,
              onMapCreated: (controller) {
                _mapController = controller;
              },
              onTap: (latLng) async {
                // Find the closest pin within 50 meters (0.05 km)
                PlaceCandidate? found;
                double closestDistance = 0.05; // 50 meters threshold

                // Check Nearby
                for (final p in nearbyPlaces) {
                  double distance = _calculateDistance(latLng, LatLng(p.latitude, p.longitude));
                  if (distance < closestDistance) { found = p; closestDistance = distance; }
                }

                // Check Search
                if (found == null) {
                  for (final p in places) {
                    double distance = _calculateDistance(latLng, LatLng(p.latitude, p.longitude));
                    if (distance < closestDistance) { found = p; closestDistance = distance; }
                  }
                }

                // Check Blind Box
                if (found == null) {
                  for (final p in blindBoxPlaces) {
                    double distance = _calculateDistance(latLng, LatLng(p.latitude, p.longitude));
                    if (distance < closestDistance) { found = p; closestDistance = distance; }
                  }
                }

                if (found != null) {
                  _showAddPlaceDialog(found);
                } else {
                  // Optional: Show a message if they tap empty space
                  // note('Tap directly on a pin to add it.');
                }
              },
            ),
          ),

          // 2. Legend moved to BOTTOM LEFT to not cover the pin's popup
          Positioned(
            bottom: 10,
            left: 10,
            child: IgnorePointer(
              child: _mapLegend(),
            ),
          ),
        ],
      ),
    );
  }



  LatLng _getInitialMapTarget(Set<Marker> markers) {
    // 1. If "All Pins", primarily redirect to the User Location
    if (filter == 'All Pins') {
      if (_userLocation != null) return _userLocation!;
      if (markers.isNotEmpty) return markers.first.position; // Fallback to pin
    } else {
      // 2. If a specific filter (Planner, Blind Box, Nearby), primarily redirect to the Pin
      if (markers.isNotEmpty) return markers.first.position;
      if (_userLocation != null) return _userLocation!; // Fallback to user location
    }

    // 3. Fallback if neither exists
    return const LatLng(3.1390, 101.6869); // Default to KL
  }

  double _calculateDistance(LatLng a, LatLng b) {
    const earthRadius = 6371.0;
    double radians(double value) => value * pi / 180;
    final dLat = radians(b.latitude - a.latitude);
    final dLng = radians(b.longitude - a.longitude);
    final h = sin(dLat / 2) * sin(dLat / 2) +
        cos(radians(a.latitude)) * cos(radians(b.latitude)) *
            sin(dLng / 2) * sin(dLng / 2);
    return earthRadius * 2 * atan2(sqrt(h), sqrt(1 - h));
  }



  // Helper to show a bottom sheet with Add button
  void _showAddPlaceDialog(PlaceCandidate place) {

    FocusScope.of(context).unfocus();
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(place.name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(place.formattedAddress, style: const TextStyle(color: Colors.grey)),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () {
                    add(place);

                    FocusManager.instance.primaryFocus?.unfocus();

                    Navigator.pop(context);
                  },
                  child: const Text('Add to Trip'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // Universal handler for tapping any marker
  void _handleMarkerTap(Marker marker) {
    String id = marker.markerId.value;
    PlaceCandidate? found;

    // Look in Nearby pins
    if (id.startsWith('nearby_')) {
      String placeId = id.substring(8); // removes "nearby_"
      for (var p in nearbyPlaces) {
        if (p.placeId == placeId) {
          found = p;
          break;
        }
      }
    }
    // Look in Search pins
    else if (id.startsWith('search_')) {
      String placeId = id.substring(8); // removes "search_"
      for (var p in places) {
        if (p.placeId == placeId) {
          found = p;
          break;
        }
      }
    }
    // Look in Blind Box pins
    else if (id.startsWith('blind_')) {
      String placeId = id.substring(7); // removes "blind_"
      for (var p in blindBoxPlaces) {
        if (p.placeId == placeId) {
          found = p;
          break;
        }
      }
    }

    if (found != null) {
      _showAddPlaceDialog(found);
    }
  }

  Widget routePreview(List<ItineraryStop> s) {
    if (s.length < 2) {
      return Container(
        height: 245,
        decoration: BoxDecoration(
          color: const Color(0xFFEAF6FD),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFBAE6FD)),
        ),
        child: const Center(
          child: Text('Choose at least two destinations for this route day.'),
        ),
      );
    }

    // 1. Identify the Start Point (Current Location)
    final bool hasStart = s.isNotEmpty && s.first.placeId == 'current_location';
    // If there is a start point, get the actual destinations (everything after it)
    final List<ItineraryStop> destinations = hasStart ? s.sublist(1) : s;

    // 2. Use the start point as the initial camera target
    final first = s.first;
    final initialPosition = CameraPosition(
      target: LatLng(first.latitude, first.longitude),
      zoom: 12,
    );

    // 3. Build Markers (Azure Blue for Start, Blue for Destinations)
    final markers = <Marker>{};

    // Add the Start Point marker (GPS Blue)
    if (hasStart) {
      markers.add(Marker(
        markerId: const MarkerId('current_location'),
        position: LatLng(s.first.latitude, s.first.longitude),
        infoWindow: const InfoWindow(title: "Start Point"),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
      ));
    }

    // Add the Blue Destination markers
    for (final stop in destinations) {
      markers.add(Marker(
        markerId: MarkerId(stop.placeId),
        position: LatLng(stop.latitude, stop.longitude),
        infoWindow: InfoWindow(title: stop.name),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
      ));
    }

    // 4. Polylines
    Set<Polyline> polylines = {};
    if (route != null && route!.points.isNotEmpty) {
      polylines.add(
        Polyline(
          polylineId: const PolylineId('route'),
          color: Colors.blue,
          width: 4,
          points: route!.points,
        ),
      );
    }

    return Container(
      height: 245,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFBAE6FD)),
      ),
      child: GoogleMap(
        initialCameraPosition: initialPosition,
        markers: markers,
        polylines: polylines,
        myLocationEnabled: true, // <--- THIS adds the real GPS Blue Dot on top
        myLocationButtonEnabled: true, // <--- This adds the crosshair button to center on yourself
        onMapCreated: (controller) {
          _mapController = controller;
        },
      ),
    );
  }

  Widget pill(String s, {bool pin = false, bool tick = false, bool blind = false}) {
    final on = filter == s || (s.startsWith('Nearby') && filter == 'Nearby');
    return Padding(
        padding: const EdgeInsets.only(right: 8),
        child: InkWell(
            onTap: () async {
              setState(() => filter = s.startsWith('Nearby') ? 'Nearby' : s);

              if (s.startsWith('Nearby')) {
                await nearby();
                // Move to first nearby pin if it loaded, otherwise fallback to user location
                if (_mapController != null) {
                  if (nearbyPlaces.isNotEmpty) {
                    _mapController!.animateCamera(CameraUpdate.newLatLng(
                        LatLng(nearbyPlaces.first.latitude, nearbyPlaces.first.longitude)
                    ));
                  } else if (_userLocation != null) {
                    _mapController!.animateCamera(CameraUpdate.newLatLng(_userLocation!));
                  }
                }
              } else if (s == 'All Pins') {
                // All Pins: Move to user location
                if (_mapController != null && _userLocation != null) {
                  _mapController!.animateCamera(CameraUpdate.newLatLng(_userLocation!));
                }
              } else if (s == 'Blind Box') {
                await _loadBlindBoxPlaces();
                // Move to first blind box pin if it loaded, otherwise fallback to user location
                if (_mapController != null) {
                  if (blindBoxPlaces.isNotEmpty) {
                    _mapController!.animateCamera(CameraUpdate.newLatLng(
                        LatLng(blindBoxPlaces.first.latitude, blindBoxPlaces.first.longitude)
                    ));
                  } else if (_userLocation != null) {
                    _mapController!.animateCamera(CameraUpdate.newLatLng(_userLocation!));
                  }
                }
              }
              // If Planner Pins selected
              else if (s == 'Planner Pins') {
                if (_mapController != null) {
                  if (stops.isNotEmpty) {
                    _mapController!.animateCamera(CameraUpdate.newLatLng(
                        LatLng(stops.first.latitude, stops.first.longitude)
                    ));
                  } else if (_userLocation != null) {
                    _mapController!.animateCamera(CameraUpdate.newLatLng(_userLocation!));
                  }
                }
              }
            },

            borderRadius: BorderRadius.circular(22),
            child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                    color: on
                        ? (s == 'All Pins'
                            ? ink
                            : (blind
                                ? const Color(0xFFFAF5FF)
                                : const Color(0xFFF0F9FF)))
                        : Colors.white,
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(
                        color: on && s != 'All Pins'
                            ? (blind ? const Color(0xFFD8B4FE) : ink)
                            : border,
                        width: on && s != 'All Pins' ? 2 : 1)),
                child: Text('${tick ? '✓ ' : pin ? '📍 ' : blind ? '♢ ' : ''}$s',
                    style: TextStyle(
                        fontSize: 12,
                        color: on && s == 'All Pins'
                            ? Colors.white
                            : (on && blind ? const Color(0xFF7E22CE) : ink),
                        fontWeight: FontWeight.w700)))));
  }

  Widget routePill(String s, int d) => Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
          label: Text(s),
          selected: routeDay == d,
          selectedColor: ink,
          labelStyle: TextStyle(
              color: routeDay == d ? Colors.white : ink,
              fontWeight: FontWeight.bold,
              fontSize: 12),
          onSelected: (_) => setState(() {
            routeDay = d;
            // Load the saved state for this day, or default to null/false
            route = _dayRoutes[d];
            accepted = _dayAccepted[d] ?? false;
          })));
  Widget modeButton(String s, String v) => InkWell(
      onTap: () => setState(() => mode = v),
      borderRadius: BorderRadius.circular(13),
      child: Container(
          padding: const EdgeInsets.symmetric(vertical: 13),
          decoration: BoxDecoration(
              color: mode == v ? blue : Colors.white,
              borderRadius: BorderRadius.circular(13),
              border: Border.all(color: mode == v ? blue : border)),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(v == 'solo' ? Icons.person : Icons.groups,
                color: const Color(0xFF5B2B90), size: 19),
            const SizedBox(width: 9),
            Text(s,
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: mode == v ? Colors.white : const Color(0xFF334155),
                    fontFamily: 'serif',
                    fontWeight: FontWeight.bold))
          ])));
  Widget yesNo() => Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: border)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        small('YES', openPublic, () => setState(() => openPublic = true)),
        small('NO', !openPublic, () => setState(() => openPublic = false))
      ]));
  Widget small(String s, bool on, VoidCallback f) => InkWell(
      onTap: f,
      borderRadius: BorderRadius.circular(10),
      child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
          decoration: BoxDecoration(
              color: on ? const Color(0xFF00A774) : Colors.transparent,
              borderRadius: BorderRadius.circular(10)),
          child: Text(s,
              style: TextStyle(
                  fontSize: 11,
                  color: on ? Colors.white : const Color(0xFF64748B),
                  fontWeight: FontWeight.bold))));

  Widget cardPlan(TripPlan p) => Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(19),
          border: Border.all(color: border)),
      child: Material(
          color: Colors.transparent,
          child: InkWell(
              onTap: () => viewPlan(p),
              borderRadius: BorderRadius.circular(19),
              child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Title & Badge Row
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                                child: Text(p.name,
                                    style: const TextStyle(
                                        fontFamily: 'serif',
                                        fontSize: 18,
                                        fontWeight: FontWeight.w900))),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: p.mode == 'team' ? const Color(0xFFE0F2FE) : const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: p.mode == 'team' ? const Color(0xFFBAE6FD) : const Color(0xFFE2E8F0),
                                ),
                              ),
                              // Displays actual mode (TEAM or SOLO)
                              child: Text(
                                p.mode.toUpperCase(),
                                style: TextStyle(
                                  fontSize: 9,
                                  color: p.mode == 'team' ? blue : const Color(0xFF64748B),
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Icon(Icons.arrow_forward, color: blue)
                          ],
                        ),
                        const SizedBox(height: 7),
                        // Dates Row
                        Row(children: [
                          const Icon(Icons.calendar_month_outlined, size: 14, color: blue),
                          const SizedBox(width: 6),
                          Text(
                              '${date(p.startDate)} → ${date(p.endDate)}  (${p.totalDays} Days)',
                              style: const TextStyle(fontSize: 11, color: blue)),
                        ]),
                        const SizedBox(height: 12),
                        // Inner Grey Highlights Box
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: border),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('ITINERARY HIGHLIGHTS:',
                                  style: TextStyle(
                                      fontSize: 9,
                                      color: Color(0xFF527090),
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 1.3)),
                              const SizedBox(height: 8),
                              // White boxes for each day
                              ...p.stops.take(4).map((s) => Container(
                                  margin: const EdgeInsets.only(bottom: 6),
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: border),
                                  ),
                                  child: Text(
                                      'Day ${s.dayNumber}: ${s.name}',
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                          fontSize: 10,
                                          color: ink,
                                          fontWeight: FontWeight.w700)
                                  )
                              )),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),

                        // ✅ DYNAMIC FOOTER: Differentiates Solo vs Team
                        Row(children: [
                          if (p.mode == 'solo') ...[
                            const Icon(Icons.person_outline, size: 15, color: Color(0xFF64748B)),
                            const SizedBox(width: 6),
                            const Text('Solo Expedition',
                                style: TextStyle(fontSize: 10, color: Color(0xFF64748B), fontWeight: FontWeight.w600)),
                            const Spacer(),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Text('PERSONAL',
                                  style: TextStyle(fontSize: 10, color: Color(0xFF64748B), fontWeight: FontWeight.bold)),
                            ),
                          ] else ...[
                            const Icon(Icons.people_alt_outlined, size: 15, color: blue),
                            const SizedBox(width: 6),
                            const Text('Team Expedition',
                                style: TextStyle(fontSize: 10, color: blue, fontWeight: FontWeight.w600)),
                            const Spacer(),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF0F9FF),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: const Color(0xFFBAE6FD)),
                              ),
                              child: Text(
                                (p.inviteCode != null && p.inviteCode!.isNotEmpty)
                                    ? 'Code: #${p.inviteCode}'
                                    : 'PUBLIC SQUAD',
                                style: const TextStyle(fontSize: 10, color: blue, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ]
                        ]),
                      ])
              )
          )
      )
  );

  Widget empty() => Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: border)),
      child: const Column(children: [
        Icon(Icons.map_outlined, size: 44, color: Color(0xFF94A3B8)),
        SizedBox(height: 8),
        Text('No plans found', style: TextStyle(fontWeight: FontWeight.bold)),
        Text('Create your next expedition to see it here.')
      ]));
  Widget field(TextEditingController c, String h, ValueChanged<String> f,
      {IconData? suffix, FocusNode? focusNode}) =>
      TextField(
          controller: c,
          focusNode: focusNode,
          onChanged: f,
          onSubmitted: f,
          decoration: InputDecoration(
              hintText: h,
              hintStyle: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
              suffixIcon: suffix == null
                  ? null
                  : IconButton(
                  icon: Icon(suffix, color: const Color(0xFF64748B)),
                  onPressed: search),
              filled: true,
              fillColor: const Color(0xFFFBFDFF),
              contentPadding:
              const EdgeInsets.symmetric(horizontal: 15, vertical: 14),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(color: border)),
              enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(color: border))));
  Widget dateBox(String l, DateTime d, VoidCallback f) => InkWell(
      onTap: f,
      child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
              color: const Color(0xFFFBFDFF),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: border)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            label(l),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(
                  child: Text(date(d),
                      style: const TextStyle(
                          fontSize: 12, fontWeight: FontWeight.bold))),
              const Icon(Icons.calendar_month_outlined, size: 16)
            ])
          ])));
  Widget detailBox(String l, String v, String s) => Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
          color: const Color(0xFFFBFDFF),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: border)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        label(l),
        const SizedBox(height: 8),
        Text(v, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text(s,
            style: const TextStyle(
                fontSize: 10, color: blue, fontWeight: FontWeight.bold))
      ]));
  Widget member(String i, String n, Color c, bool h) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: border)),
      child: Row(children: [
        CircleAvatar(
            radius: 12,
            backgroundColor: c,
            child: Text(i,
                style: const TextStyle(fontSize: 8, color: Colors.white))),
        const SizedBox(width: 8),
        Text(n, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
        if (h) ...[
          const SizedBox(width: 4),
          const Icon(Icons.workspace_premium, color: Colors.amber, size: 14)
        ]
      ]));
  Widget step(String s, String t) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        label(s),
        const SizedBox(height: 7),
        Text(t,
            style: const TextStyle(
                fontFamily: 'serif',
                fontSize: 27,
                height: 1.08,
                fontWeight: FontWeight.w900))
      ]);
  Widget label(String s) => Text(s,
      style: const TextStyle(
          fontSize: 9,
          color: Color(0xFF527090),
          fontWeight: FontWeight.bold,
          letterSpacing: 1.3));
  Widget surface(Widget c) => Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: border)),
      child: c);
  Widget primary(String s, VoidCallback? f) => SizedBox(
      width: double.infinity,
      child: FilledButton(
          onPressed: f,
          style: FilledButton.styleFrom(
              backgroundColor: blue,
              disabledBackgroundColor: const Color(0xFF94A3B8),
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16))),
          child: Text(s,
              style: const TextStyle(
                  fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.1))));

  Future<void> _generateTripPdf() async {
    // Safety check
    if (_currentPlan == null) {
      note('Please save the trip first before printing.');
      return;
    }

    final plan = _currentPlan!;
    final doc = pw.Document();

    // Reusable style for the little grid boxes
    pw.Widget gridBox(String label, String value) => pw.Container(
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey300, width: 1),
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(label, style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600, letterSpacing: 1)),
          pw.SizedBox(height: 6),
          pw.Text(value, style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900)),
        ],
      ),
    );

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(20),
        build: (pw.Context context) => [
          // 1. The Hero "Dossier" Header
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            decoration: pw.BoxDecoration(
              gradient: pw.LinearGradient(
                begin: pw.Alignment.centerLeft,
                end: pw.Alignment.centerRight,
                colors: [
                  PdfColor.fromHex('#0284C7'),
                  PdfColor.fromHex('#069A9B')
                ],
              ),
              borderRadius: pw.BorderRadius.circular(16),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('✦ MYSTERYLANE DOSSIER', style: pw.TextStyle(color: PdfColors.white, fontSize: 12, letterSpacing: 1.5)),
                    pw.Container(
                      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: pw.BoxDecoration(
                        border: pw.Border.all(color: PdfColors.white, width: 1),
                        borderRadius: pw.BorderRadius.circular(10),
                      ),
                      child: pw.Text('VERIFIED', style: pw.TextStyle(color: PdfColors.white, fontSize: 10, fontWeight: pw.FontWeight.bold)),
                    ),
                  ],
                ),
                pw.SizedBox(height: 20),
                pw.Text(plan.name, style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold, color: PdfColors.white)),
                pw.SizedBox(height: 6),
                pw.Text('Curated Dynamic Expedition Plan', style: pw.TextStyle(color: PdfColors.white, fontSize: 12, fontStyle: pw.FontStyle.italic)),
              ],
            ),
          ),
          pw.SizedBox(height: 20),

          // 2. The 4 Grid Boxes (Dates, Duration, Mode, Code)
          pw.Row(
            children: [
              pw.Expanded(child: gridBox('TRAVEL DATES', '${date(plan.startDate)} - ${date(plan.endDate)}')),
              pw.SizedBox(width: 10),
              pw.Expanded(child: gridBox('DURATION', '${plan.totalDays} Days\nExpedition')),
            ],
          ),
          pw.SizedBox(height: 10),
          pw.Row(
            children: [
              pw.Expanded(child: gridBox('SQUAD MODE', plan.mode.toUpperCase())),
              pw.SizedBox(width: 10),
              pw.Expanded(
                child: gridBox(
                  'TEAM CODE',
                  plan.mode == 'team'
                      ? (plan.inviteCode != null && plan.inviteCode!.isNotEmpty ? '#${plan.inviteCode}' : 'PUBLIC')
                      : 'N/A (SOLO)',
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 20),

          // 3. Registered Squad Members
          pw.Container(
            padding: const pw.EdgeInsets.all(16),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.grey300, width: 1),
              borderRadius: pw.BorderRadius.circular(12),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text('REGISTERED SQUAD MEMBERS (3)', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey600, letterSpacing: 1)),
                pw.SizedBox(height: 12),
                pw.Row(
                  children: [
                    _avatarPdf('AV', PdfColor.fromHex('#0F172A'), 'Alex Vance (Host)', true),
                    pw.SizedBox(width: 8),
                    _avatarPdf('SL', PdfColor.fromHex('#FACC15'), 'Sophia L.', false),
                    pw.SizedBox(width: 8),
                    _avatarPdf('KT', PdfColor.fromHex('#0F172A'), 'Kenji T.', false),
                  ],
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 20),

          // 4. Day-by-Day Route Schedule
          pw.Container(
            padding: const pw.EdgeInsets.all(16),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.grey300, width: 1),
              borderRadius: pw.BorderRadius.circular(12),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text('DAY-BY-DAY ROUTE SCHEDULE', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey600, letterSpacing: 1)),
                pw.SizedBox(height: 12),
                for (final stop in plan.stops)
                  pw.Padding(
                    padding: const pw.EdgeInsets.only(bottom: 8),
                    child: pw.Row(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Container(
                          padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: pw.BoxDecoration(
                            color: PdfColors.blue700,
                            borderRadius: pw.BorderRadius.circular(8),
                          ),
                          child: pw.Text(
                            'Day\n${stop.dayNumber}',
                            textAlign: pw.TextAlign.center,
                            style: pw.TextStyle(fontSize: 8, color: PdfColors.white, letterSpacing: 1),
                          ),
                        ),
                        pw.SizedBox(width: 12),
                        pw.Expanded(
                          child: pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.start,
                            children: [
                              pw.Text(stop.name, style: pw.TextStyle(fontSize: 8, color: PdfColors.grey600, letterSpacing: 1)),
                              pw.SizedBox(height: 2),
                              pw.Text(
                                stop.dayNumber % 2 == 0 ? 'Historical Code' : 'Secret Mission',
                                style: const pw.TextStyle(fontSize: 9, color: PdfColors.black),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          pw.SizedBox(height: 20),
          pw.Text('Report generated by MysteryLane', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey400)),
        ],
      ),
    );

    try {
      await Printing.layoutPdf(
        onLayout: (format) async => doc.save(),
        name: '${plan.name.replaceAll(' ', '_')}_Trip_Plan.pdf',
      );
      if (mounted) note('PDF Preview Closed.');
    } catch (e) {
      if (mounted) note('Failed to generate PDF: $e');
    }
  }

  pw.Widget _avatarPdf(String initials, PdfColor color, String name, bool isHost) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey300, width: 1),
        borderRadius: pw.BorderRadius.circular(20),
      ),
      child: pw.Row(
        children: [
          pw.Container(
            width: 16,
            height: 16,
            decoration: pw.BoxDecoration(color: color, shape: pw.BoxShape.circle),
            child: pw.Center(
              // REMOVED "const" from style:
              child: pw.Text(initials, style: pw.TextStyle(color: PdfColors.white, fontSize: 8, fontWeight: pw.FontWeight.bold)),
            ),
          ),
          pw.SizedBox(width: 6),
          // REMOVED "const" from style:
          pw.Text(name, style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
          if (isHost) ...[
            pw.SizedBox(width: 4),
            // REMOVED "const" from style:
            pw.Text('👑', style: pw.TextStyle(fontSize: 10)),
          ],
        ],
      ),
    );
  }

  Widget outline(String s, Color c, VoidCallback f) => Container(
    width: double.infinity,
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: border),
    ),
    padding: const EdgeInsets.all(6),
    child: Align(
      alignment: Alignment.centerRight,
      child: FilledButton.icon(
          onPressed: f,
          icon: const Icon(Icons.print_outlined, size: 18),
          label: Text(s, style: const TextStyle(fontWeight: FontWeight.bold)),
          style: FilledButton.styleFrom(
              backgroundColor: c,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))
          )
      ),
    ),
  );

  Widget badge(String s) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration:
          BoxDecoration(color: blue, borderRadius: BorderRadius.circular(10)),
      child: Text(s,
          style: const TextStyle(
              color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)));
  Widget boxIcon(IconData i) => Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: border)),
      child: Icon(i, color: const Color(0xFF475569)));
  Widget overlay(String s, Color c) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration:
          BoxDecoration(color: ink, borderRadius: BorderRadius.circular(12)),
      child: Text(s,
          style: TextStyle(fontSize: 9, color: c, fontWeight: FontWeight.bold)));

  // Main Legend Container
  Widget _mapLegend() {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.92),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFBAE6FD)),
        boxShadow: const [
          BoxShadow(color: Color(0x22000000), blurRadius: 4, offset: Offset(0, 2))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          _legendItem(const Color(0xFF2196F3), 'Planner Pins'),
          _legendItem(const Color(0xFFF44336), 'Nearby / Search'),
          _legendItem(const Color(0xFF9C27B0), 'Blind Box'),
        ],
      ),
    );
  }

  // Individual Legend Row
  Widget _legendItem(Color color, String label) {
    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 1),
            ),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: Color(0xFF0F172A)
            ),
          ),
        ],
      ),
    );
  }
}

class _RoutePainter extends CustomPainter {
  final List<ItineraryStop> s;
  late double minLat, maxLat, minLon, maxLon;

  _RoutePainter(this.s) {
    if (s.isNotEmpty) {
      final lats = s.map((x) => x.latitude).toList();
      final lons = s.map((x) => x.longitude).toList();

      minLat = lats.reduce((a, b) => a < b ? a : b);
      maxLat = lats.reduce((a, b) => a > b ? a : b);
      minLon = lons.reduce((a, b) => a < b ? a : b);
      maxLon = lons.reduce((a, b) => a > b ? a : b);
    }
  }

  @override
  void paint(Canvas c, Size z) {
    if (s.length < 2) return;

    Offset p(ItineraryStop x) => Offset(
      30 + (x.longitude - minLon) / ((maxLon - minLon).abs() + .00001) * (z.width - 60),
      30 + (maxLat - x.latitude) / ((maxLat - minLat).abs() + .00001) * (z.height - 60),
    );

    final path = Path()..moveTo(p(s.first).dx, p(s.first).dy);
    for (var i = 1; i < s.length; i++) {
      path.lineTo(p(s[i]).dx, p(s[i]).dy);
    }

    c.drawPath(
        path,
        Paint()
          ..color = const Color(0xFF0284C7)
          ..strokeWidth = 3
          ..style = PaintingStyle.stroke);

    for (final x in s) {
      final q = p(x);
      c.drawCircle(q, 14, Paint()..color = const Color(0xFF0284C7));

      final tp = TextPainter(
        text: TextSpan(
          text: 'D${x.dayNumber}',
          style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(c, q - Offset(tp.width / 2, tp.height / 2));
    }
  }

  @override
  bool shouldRepaint(_RoutePainter old) => old.s != s;
}
