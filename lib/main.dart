library;

import 'src/groq_matcher.dart';
import 'src/moderation.dart';
import 'src/backend/repositories.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image/image.dart' as raster;
import 'src/local_media_stub.dart'
    if (dart.library.io) 'src/local_media_io.dart'
    as local_media;

import 'dart:math' as math;
import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'src/share_stub.dart'
    if (dart.library.html) 'src/share_web.dart'
    as web_share;

part 'src/theme.dart';
part 'src/data.dart';
part 'src/components.dart';
part 'src/home.dart';
part 'src/deeds.dart';
part 'src/planner.dart';
part 'src/community.dart';
part 'src/seasonal.dart';
part 'src/group_goals.dart';
part 'src/progress.dart';
part 'src/settings.dart';
part 'src/matching.dart';
part 'src/deed_catalog.g.dart';
part 'src/motion.dart';
part 'src/sharing.dart';
part 'src/app_tour.dart';
part 'src/local_storage.dart';
part 'src/local_photos.dart';
part 'src/card_captions.dart';
part 'src/startup.dart';
part 'src/backend_session.dart';
part 'src/cloud_community.dart';

final store = DeedStore();
final backend = BackendSession();
final rootNavigatorKey = GlobalKey<NavigatorState>();
final appShellKey = GlobalKey<_AppShellState>();
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const DeedWiseApp(initialize: true));
}

class DeedWiseApp extends StatelessWidget {
  final bool initialize;
  const DeedWiseApp({super.key, this.initialize = false});
  @override
  Widget build(BuildContext context) => MaterialApp(
    navigatorKey: rootNavigatorKey,
    title: 'DeedWise',
    debugShowCheckedModeBanner: false,
    theme: appTheme,
    scrollBehavior: const AppScrollBehavior(),
    builder: (context, child) => AnimatedBuilder(
      animation: backend,
      builder: (context, _) => ColoredBox(
        color: const Color(0xFFE4EAE5),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: LayoutBuilder(
                  builder: (context, constraints) => MediaQuery(
                    data: MediaQuery.of(context).copyWith(
                      size: Size(constraints.maxWidth, constraints.maxHeight),
                    ),
                    // Keep the Navigator/startup state mounted while blocking
                    // old-account content. Recreating it here would reload the
                    // guest snapshot during a restored signed-in session.
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        ExcludeSemantics(
                          excluding:
                              backend.changingAccount ||
                              backend.identityError != null,
                          child: IgnorePointer(
                            ignoring:
                                backend.changingAccount ||
                                backend.identityError != null,
                            child: child!,
                          ),
                        ),
                        if (backend.changingAccount ||
                            backend.identityError != null)
                          AppSplash(
                            onRetry: backend.identityError == null
                                ? null
                                : () => backend.retryIdentity(),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            ValueListenableBuilder<int?>(
              valueListenable: appTour.stepIndex,
              builder: (context, step, _) =>
                  step == null ||
                      backend.changingAccount ||
                      backend.identityError != null
                  ? const SizedBox.shrink()
                  : AppTourOverlay(step: step),
            ),
          ],
        ),
      ),
    ),
    home: initialize ? const AppStartup() : AppShell(key: appShellKey),
  );
}

class AppShell extends StatefulWidget {
  const AppShell({super.key});
  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> with WidgetsBindingObserver {
  int index = 0;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !store.tourSeen) showAppTour(context);
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused) {
      unawaited(localData.flush().catchError((Object _) => false));
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  final pages = const [
    HomePage(),
    PlannerPage(),
    CommunityPage(),
    ProgressPage(),
  ];
  void select(int destination) {
    if (destination == 2) {
      openPage(context, const DeedEditor());
      return;
    }
    final next = destination > 2 ? destination - 1 : destination;
    if (next == index) return;
    HapticFeedback.selectionClick();
    setState(() => index = next);
  }

  void setTabForTour(int destination) {
    if (index == destination) return;
    setState(() => index = destination);
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: store,
    builder: (context, _) => Scaffold(
      extendBody: true,
      body: SafeArea(
        bottom: false,
        child: AppTabView(index: index, children: pages),
      ),
      bottomNavigationBar: FloatingNavigationBar(
        index: index,
        onSelected: select,
      ),
    ),
  );
}

const navLabels = ['Home', 'Planner', 'Add deed', 'Community', 'Progress'];
const navIcons = [
  Icons.home_outlined,
  Icons.calendar_month_outlined,
  Icons.add,
  Icons.people_outline_rounded,
  Icons.bar_chart_rounded,
];
