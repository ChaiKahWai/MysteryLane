import 'package:flutter/material.dart';
import 'dart:math';
import '../../../application/controller/trip_planner_controller.dart';
import '../../../data/models/place_candidate.dart';
import '../../../data/models/trip_plan.dart';
import '../Blindbox/BlindBox_Screen.dart';
import '../checkpoint/checkpoint_screen.dart';
import '../profile/profile_screen.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

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

  final name = TextEditingController(),
      placeSearch = TextEditingController(),
      planSearch = TextEditingController();

  TripPlannerController? api;
  String? error;
  List<TripPlan> plans = [];
  List<PlaceCandidate> places = [];
  List<PlaceCandidate> nearbyPlaces = [];
  List<ItineraryStop> stops = [];
  RoutePreview? route;
  PlaceCandidate? _selectedPlace;
  GoogleMapController? _mapController;

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

  @override
  void initState() {
    super.initState();
    try {
      _initController();
      load();
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
    super.dispose();
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
      if (mounted) setState(() => plans = r);
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
        places = [];
        stops = [];
        route = null;
        accepted = false;
      });

  void viewPlan(TripPlan p) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    setState(() {
      isCreating = false;
      name.text = p.name;
      start = p.startDate;
      end = p.endDate;
      mode = p.mode;
      stops = List.from(p.stops);
      accepted = p.routeAccepted;
      history = end.isBefore(today);
      route = null; // reset first
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
    final d = await showDatePicker(
        context: context,
        initialDate: first ? start : end,
        firstDate: DateTime.now().subtract(const Duration(days: 1)),
        lastDate: DateTime.now().add(const Duration(days: 730)));
    if (d != null) {
      setState(() {
        if (first) {
          start = d;
          if (end.isBefore(d)) end = d;
        } else {
          end = d.isBefore(start) ? start : d;
        }
      });
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
      final r = await api!.search(placeSearch.text);
      if (mounted) setState(() => places = r);
  }

  Future<void> nearby() async {
    if (api == null) return;
    setState(() => loading = true);
    try {
      final r = await api!.exploreNearby();
      if (mounted) setState(() {
        nearbyPlaces = r; // ← ensure this is set
        print('📍 Nearby places: ${nearbyPlaces.length}');
      });

    } catch (e) {
      note('Nearby search failed: $e');
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  void add(PlaceCandidate p) {
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
    final position = stops.where((x) => x.dayNumber == day).length + 1; // Fix: 1-based for DB
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
      route = null;
      accepted = false;
    });
    note('${p.name} added to Day $day, position $position.');
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
      page = 2;
    });
  }

  void generate() async {
    if (stops.length < 2) {
      note('Add at least two destinations to plan a route.');
      return;
    }
    setState(() => loading = true);
    final s = routeDay == 0
        ? stops
        : stops.where((x) => x.dayNumber == routeDay).toList();
    try {
      final newRoute = await api!.planEfficientRoute(s);
      if (mounted) {
        setState(() {
          route = newRoute;
          accepted = false;
          loading = false;
        });
      }
    } catch (e) {
      note('$e');
      if (mounted) setState(() => loading = false);
    }
  }

  void accept() {
    if (route == null) return;
    setState(() => accepted = true);
    note('Route accepted.');
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
    setState(() => loading = true);
    try {
      normalizeStops();
      final p = await api!.savePlan(TripPlan(
          id: '',
          name: name.text.trim(),
          startDate: start,
          endDate: end,
          mode: mode,
          visibility: openPublic ? 'public' : 'private',
          inviteCode: openPublic ? null : '123456',
          routeAccepted: accepted,
          stops: stops));
      if (mounted) {
        setState(() {
          plans = [p, ...plans];
          page = 3;
          history = false;
          isCreating = false;   // <-- ADD THIS
        });
      }
      note('Trip plan created successfully.');
    } catch (e) {
      note('Unable to save plan: $e');
    } finally {
      if (mounted) setState(() => loading = false);
    }
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
            Positioned(right: 10, bottom: 132, child: createButton())
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
      tabs(active: false),
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
              Expanded(child: modeButton('Solo', 'solo')),
              const SizedBox(width: 10),
              Expanded(child: modeButton('Team', 'team')),
            ]),
            if (mode == 'team') ...[
              const SizedBox(height: 15),
              Row(children: [
                const Expanded(child: Text('Open to Public?', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                yesNo(),
              ]),
              const SizedBox(height: 10),
              detailBox('Private Code:', '123456', 'TEAM MODE'),
            ],
            const SizedBox(height: 20),
            label('PLAN ROUTE PREVIEW'),
            const SizedBox(height: 12),
            routePreview(stops),
            const SizedBox(height: 15),
            if (route == null)
              primary('PLAN ROUTE', generate)
            else if (!accepted)
              Row(children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: accept,
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF22C55E),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))
                    ),
                    icon: const Icon(Icons.check_circle_outline, size: 18),
                    label: const Text("Accept Route", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () => setState(() {
                      route = null;
                      accepted = false;
                    }),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFFEF4444),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))
                    ),
                    icon: const Icon(Icons.cancel_outlined, size: 18),
                    label: const Text("Reject Route", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
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
                    Text('Route Accepted & Optimized', style: TextStyle(color: Color(0xFF16A34A), fontWeight: FontWeight.bold, fontSize: 13)),
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
  Widget tabs({bool active = true}) => Container(
    padding: const EdgeInsets.all(7),
    decoration: BoxDecoration(
      color: const Color(0xFFF0F9FF),
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: const Color(0xFFD7EAF7)),
    ),
    child: Row(children: [
      Expanded(
        child: tab('My Plan', Icons.explore_outlined, active && !history, () {
          if (active) {
            setState(() { history = false; page = 0; });
          }
        }),
      ),
      Expanded(
        child: tab('History', Icons.history, active && history, () {
          if (active) {
            setState(() { history = true; page = 0; });
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

    final filteredByDate = plans.where((p) {
      final isHistory = p.endDate.isBefore(today);
      return history ? isHistory : !isHistory;
    }).toList();

    final list = filteredByDate
        .where((p) => q.isEmpty || p.name.toLowerCase().contains(q))
        .toList();

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
                (_) => setState(() {}))),
        const SizedBox(width: 8),
        boxIcon(Icons.tune)
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
      else
        ...list.map(cardPlan)
    ]);
  }

  Widget create() => ListView(padding: const EdgeInsets.fromLTRB(18, 20, 18, 102), children: [
        banner(),
        const SizedBox(height: 18),
        tabs(active: false),
        const SizedBox(height: 22),
        surface(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          step('STEP 1 OF 2 • TRIP SETUP', 'Create New Expedition\nPlan'),
          const Divider(height: 28),
          label('TRIP PLAN NAME *'),
          const SizedBox(height: 8),
          field(name, 'e.g. Kyoto Ancient Secrets Quest', (_) => {}),
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
            mapOpen ? '♧  CLOSE INTERACTIVE MAP' : '♧  OPEN INTERACTIVE MAP',
            () => setState(() => mapOpen = !mapOpen)),
        if (mapOpen) ...[
          const SizedBox(height: 18),
          field(placeSearch, 'Search map location, mission or landmark',
              (_) => search(),
              suffix: Icons.search),
          const SizedBox(height: 12),
          SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(children: [
                pill('All Pins'),
                pill('Nearby (<2.5km)', pin: true),
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
        Row(children: [
          const Spacer(),
          if(page == 3)
            outline('Print Report', const Color(0xFF00A774), () => note('Report generation pending.'))
        ]),
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
            Expanded(child: detailBox('TEAM CODE', '#123456', 'TEAM MODE')),
          ]),
          const SizedBox(height: 24),
          Row(children: [
            Expanded(child: label('SQUAD MEMBERS (3)')),
            TextButton(
                onPressed: () {},
                child: const Text('Manage Squad Members',
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)))
          ]),
          const SizedBox(height: 8),
          SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(children: [
                member('AV', 'Alex Vance (Host)', ink, true),
                const SizedBox(width: 8),
                member('SL', 'Sophia L.', const Color(0xFFFACC15), false),
                const SizedBox(width: 8),
                member('KT', 'Kenji T.', ink, false),
              ])),
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
            routePreview(stops),
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
          const SizedBox(height: 22),
          if (isCreating) primary('◉  START YOUR ADVENTURE', loading ? null : save),
          const SizedBox(height: 12),
          Center(
            child: TextButton.icon(
              onPressed: () => setState(() => page = 0),
              icon: const Icon(Icons.arrow_back, size: 16),
              label: const Text('Back to Dashboard'),
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
    int maxPosition(int day) => day == originalDay
        ? countFor(day)
        : countFor(day).clamp(1, destinationsPerDay);
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
                            final displaced = stops[targetIndex];
                            stops[index] = displaced.copyWith(
                                dayNumber: originalDay,
                                sortOrder: originalPosition);
                            stops[targetIndex] = moved.copyWith(
                                dayNumber: selectedDay,
                                sortOrder: selectedPosition);
                            swapped = true;
                          } else {
                            stops.removeAt(index);
                            for (var i = 0; i < stops.length; i++) {
                              final stop = stops[i];
                              if (stop.dayNumber == originalDay &&
                                  stop.sortOrder > originalPosition) {
                                stops[i] =
                                    stop.copyWith(sortOrder: stop.sortOrder - 1);
                              }
                              if (stop.dayNumber == selectedDay &&
                                  stop.sortOrder >= selectedPosition) {
                                stops[i] =
                                    stop.copyWith(sortOrder: stop.sortOrder + 1);
                              }
                            }
                            stops.add(moved.copyWith(
                                dayNumber: selectedDay,
                                sortOrder: selectedPosition));
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
    final markers = <Marker>{};

    // 1. Planner pins (blue) – from stops (already added to itinerary)
    if (filter == 'All Pins' || filter == 'Planner Pins') {
      for (final stop in stops) {
        markers.add(Marker(
          markerId: MarkerId('stop_${stop.placeId}'),
          position: LatLng(stop.latitude, stop.longitude),
          infoWindow: InfoWindow(title: stop.name),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
        ));
      }
      // Also show search results as blue (optional)
      if (filter == 'All Pins') {
        for (final p in places) {
          markers.add(Marker(
            markerId: MarkerId('search_${p.placeId}'),
            position: LatLng(p.latitude, p.longitude),
            infoWindow: InfoWindow(title: p.name, snippet: p.formattedAddress),
            icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
          ));
        }
      }
    }

    // 2. Nearby pins (red)
    if (filter == 'All Pins' || filter == 'Nearby') {
      for (final p in nearbyPlaces) {
        markers.add(Marker(
          markerId: MarkerId('nearby_${p.placeId}'),
          position: LatLng(p.latitude, p.longitude),
          infoWindow: InfoWindow(title: p.name, snippet: p.formattedAddress),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
        ));
      }
    }

    // 3. Blind Box pins (purple) – add if you have a list, e.g., blindBoxPlaces

    if (markers.isEmpty) {
      return Container(
        height: 245,
        decoration: BoxDecoration(
          color: const Color(0xFFD9EFF5),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFBAE6FD)),
        ),
        child: const Center(child: Text('No pins to display.')),
      );
    }

    // Use the first marker as camera target
    final first = markers.first;
    final initialPosition = CameraPosition(
      target: first.position,
      zoom: 13,
    );

    return Container(
      height: 245,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFBAE6FD)),
      ),
      child: GoogleMap(
        initialCameraPosition: initialPosition,
        markers: markers,
        onMapCreated: (controller) {
          _mapController = controller;
        },
        onTap: (latLng) async {
          if (_mapController == null) return;

          // Get the current zoom level
          final zoom = await _mapController!.getZoomLevel();

          // Calculate a dynamic threshold (in km) based on zoom
          double thresholdKm;
          if (zoom > 16) {
            thresholdKm = 0.05; // 50 meters (very close)
          } else if (zoom > 14) {
            thresholdKm = 0.1;  // 100 meters
          } else if (zoom > 12) {
            thresholdKm = 0.2;  // 200 meters
          } else {
            thresholdKm = 0.5;  // 500 meters (zoomed out)
          }

          PlaceCandidate? found;

          // Check search results
          for (final p in places) {
            final distance = _calculateDistance(latLng, LatLng(p.latitude, p.longitude));
            if (distance < thresholdKm) {
              found = p;
              break;
            }
          }

          // Check nearby results
          if (found == null) {
            for (final p in nearbyPlaces) {
              final distance = _calculateDistance(latLng, LatLng(p.latitude, p.longitude));
              if (distance < thresholdKm) {
                found = p;
                break;
              }
            }
          }

          if (found != null) {
            print('✅ Found: ${found.name} (zoom: $zoom)');
            _showAddPlaceDialog(found);
          } else {
            print('❌ No place found (zoom: $zoom)');
          }
        },
      ),
    );
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

    final first = s.first;
    final initialPosition = CameraPosition(
      target: LatLng(first.latitude, first.longitude),
      zoom: 12,
    );

    // Markers
    final markers = s.map((stop) {
      return Marker(
        markerId: MarkerId(stop.placeId),
        position: LatLng(stop.latitude, stop.longitude),
        infoWindow: InfoWindow(title: stop.name),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
      );
    }).toSet();

    // Polylines
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
              if (s.startsWith('Nearby')) await nearby();
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
                route = null;
                accepted = false;
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
                        Row(children: [
                          Expanded(
                              child: Text(p.name,
                                  style: const TextStyle(
                                      fontFamily: 'serif',
                                      fontSize: 18,
                                      fontWeight: FontWeight.w900))),
                          const Icon(Icons.arrow_forward, color: blue)
                        ]),
                        const SizedBox(height: 7),
                        Text(
                            '▣ ${date(p.startDate)} → ${date(p.endDate)} (${p.totalDays} Days)',
                            style: const TextStyle(fontSize: 11, color: blue)),
                        const SizedBox(height: 12),
                        ...p.stops.take(4).map((s) => Text(
                            'Day ${s.dayNumber}: ${s.name}',
                            style: const TextStyle(
                                fontSize: 10, fontWeight: FontWeight.w700)))
                      ])))));

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
          {IconData? suffix}) =>
      TextField(
          controller: c,
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

  Widget outline(String s, Color c, VoidCallback f) => OutlinedButton.icon(
    onPressed: f,
    icon: const Icon(Icons.print_outlined, size: 18),
    label: Text(s, style: const TextStyle(fontWeight: FontWeight.bold)),
    style: OutlinedButton.styleFrom(
        foregroundColor: c,
        side: BorderSide(color: c, width: 1.5),   // <-- thicker border
        backgroundColor: Colors.white,            // <-- white background
        padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
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
