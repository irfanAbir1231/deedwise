part of '../main.dart';

const brandCream = Color(0xFFFFFCF4);

class BrandMark extends StatelessWidget {
  final double size;
  const BrandMark({super.key, this.size = 64});
  @override
  Widget build(BuildContext context) => Image.asset(
    'assets/brand/deedwise-mark.png',
    width: size,
    height: size,
    semanticLabel: 'DeedWise logo',
    filterQuality: FilterQuality.high,
  );
}

/// Every current-user avatar listens independently, including cached tab headers.
class ProfileAvatar extends StatelessWidget {
  final double radius;
  const ProfileAvatar({super.key, this.radius = 20});
  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: store,
    builder: (context, _) => Semantics(
      label: 'Your profile photo',
      image: true,
      child: CircleAvatar(
        radius: radius,
        backgroundColor: sage,
        child: localData.profilePhoto == null
            ? Text(
                store.name.isEmpty ? 'Y' : store.name.characters.first,
                style: TextStyle(
                  color: green,
                  fontSize: radius * .8,
                  fontWeight: FontWeight.w600,
                ),
              )
            : ClipOval(
                child: LocalPhoto(
                  localData.profilePhoto!,
                  width: radius * 2,
                  height: radius * 2,
                ),
              ),
      ),
    ),
  );
}

class AppStartup extends StatefulWidget {
  const AppStartup({super.key});
  @override
  State<AppStartup> createState() => _AppStartupState();
}

class _AppStartupState extends State<AppStartup> {
  late Future<void> loading;
  bool entered = false;
  @override
  void initState() {
    super.initState();
    loading = initialize();
  }

  Future<void> initialize() async {
    await Future.wait([localData.initialize(), DeedModeration.load()]);
    await backend.initialize();
  }

  Future<void> finishIntro() async {
    var remembered = false;
    try {
      remembered = await localData.markIntroSeen();
    } catch (_) {}
    if (!mounted) return;
    if (!remembered) {
      toast(
        context,
        'The introduction may appear again because device storage is unavailable.',
      );
    }
    setState(() => entered = true);
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<void>(
    future: loading,
    builder: (context, snapshot) {
      if (snapshot.hasError) {
        return AppSplash(onRetry: () => setState(() => loading = initialize()));
      }
      if (snapshot.connectionState != ConnectionState.done) {
        return const AppSplash();
      }
      if (!entered && !localData.introSeen) {
        return AppIntroduction(onDone: finishIntro);
      }
      return backend.configured
          ? const BackendAccountGate()
          : AppShell(key: appShellKey);
    },
  );
}

class AppSplash extends StatelessWidget {
  final VoidCallback? onRetry;
  const AppSplash({super.key, this.onRetry});
  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: brandCream,
    body: SafeArea(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const BrandMark(size: 108),
              const SizedBox(height: 24),
              Text('DeedWise', style: editorial(35)),
              const SizedBox(height: 8),
              const Text(
                'A little good, remembered.',
                style: TextStyle(color: muted),
              ),
              const SizedBox(height: 30),
              if (onRetry == null)
                const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else ...[
                const Text(
                  'Could not open local storage. Please try again.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: onRetry,
                  child: const Text('Try again'),
                ),
              ],
            ],
          ),
        ),
      ),
    ),
  );
}

class IntroSlide {
  final IconData icon;
  final String label, title, description, note;
  const IntroSlide(
    this.icon,
    this.label,
    this.title,
    this.description,
    this.note,
  );
}

const introSlides = [
  IntroSlide(
    Icons.edit_note_rounded,
    'REMEMBER',
    'Make room for the good you do.',
    'Write one completed action in your own words. DeedWise helps you recognise it and keep a personal record.',
    'Online checks send your deed text to Groq. Your photos and journal are not sent.',
  ),
  IntroSlide(
    Icons.calendar_month_outlined,
    'GROW',
    'Small actions. A lasting habit.',
    'Plan a thoughtful action, reflect on your day and follow your progress. Participation points celebrate eligible activities, not personal worth.',
    'Your own pace. Your own reasons. One day at a time.',
  ),
  IntroSlide(
    Icons.ios_share_rounded,
    'INSPIRE',
    'Keep it personal. Share by choice.',
    'Turn a deed into a card when you want to inspire someone. Add a photo or your profile picture only if you choose.',
    'Photos stay on this device. They leave the app only when you share them.',
  ),
];

class AppIntroduction extends StatefulWidget {
  final Future<void> Function() onDone;
  const AppIntroduction({super.key, required this.onDone});
  @override
  State<AppIntroduction> createState() => _AppIntroductionState();
}

class _AppIntroductionState extends State<AppIntroduction> {
  final controller = PageController();
  int page = 0;
  bool finishing = false;
  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  Future<void> finish() async {
    if (finishing) return;
    setState(() => finishing = true);
    await widget.onDone();
    if (mounted) setState(() => finishing = false);
  }

  void move(int target) {
    controller.animateToPage(
      target,
      duration: MediaQuery.disableAnimationsOf(context)
          ? Duration.zero
          : const Duration(milliseconds: 240),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: brandCream,
    body: SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 18, 16, 8),
            child: Row(
              children: [
                const Brand(),
                const Spacer(),
                TextButton(
                  onPressed: finishing ? null : finish,
                  child: const Text('Skip'),
                ),
              ],
            ),
          ),
          Expanded(
            child: PageView.builder(
              controller: controller,
              itemCount: introSlides.length,
              onPageChanged: (index) => setState(() => page = index),
              itemBuilder: (context, index) {
                final slide = introSlides[index];
                return SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(28, 20, 28, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        height: 190,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(30),
                          gradient: const LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [Color(0xFFE7EDDF), Color(0xFFF5EFE0)],
                          ),
                        ),
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            Container(
                              width: 148,
                              height: 148,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: green.withValues(alpha: .08),
                                  width: 20,
                                ),
                              ),
                            ),
                            const BrandMark(size: 94),
                            Positioned(
                              right: 22,
                              bottom: 22,
                              child: Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: brandCream,
                                  borderRadius: BorderRadius.circular(18),
                                ),
                                child: Icon(slide.icon, color: green, size: 28),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 28),
                      Eyebrow(slide.label),
                      const SizedBox(height: 12),
                      Text(slide.title, style: editorial(33)),
                      const SizedBox(height: 16),
                      Text(
                        slide.description,
                        style: const TextStyle(
                          color: muted,
                          fontSize: 15,
                          height: 1.6,
                        ),
                      ),
                      const SizedBox(height: 22),
                      Text(
                        slide.note,
                        style: const TextStyle(
                          color: muted,
                          fontSize: 12,
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(28, 10, 28, 24),
            child: Column(
              children: [
                Row(
                  children: [
                    for (var i = 0; i < introSlides.length; i++)
                      Container(
                        width: i == page ? 22 : 7,
                        height: 7,
                        margin: const EdgeInsets.only(right: 6),
                        decoration: BoxDecoration(
                          color: i == page ? green : line,
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                    const Spacer(),
                    Text(
                      '${page + 1} of ${introSlides.length}',
                      style: const TextStyle(color: muted, fontSize: 12),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    if (page > 0) ...[
                      IconButton(
                        tooltip: 'Previous introduction',
                        onPressed: finishing ? null : () => move(page - 1),
                        icon: const Icon(Icons.arrow_back_rounded),
                      ),
                      const SizedBox(width: 10),
                    ],
                    Expanded(
                      child: FilledButton(
                        onPressed: finishing
                            ? null
                            : () {
                                if (page == introSlides.length - 1) {
                                  finish();
                                } else {
                                  move(page + 1);
                                }
                              },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Text(
                            finishing
                                ? 'Opening…'
                                : page == introSlides.length - 1
                                ? 'Start my journey'
                                : 'Continue',
                          ),
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
  );
}
