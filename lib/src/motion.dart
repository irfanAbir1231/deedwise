part of '../main.dart';

bool reducedMotion(BuildContext context) =>
    MediaQuery.disableAnimationsOf(context);

/// Detail navigation follows a consistent horizontal push/pop direction.
class AppPageTransitionsBuilder extends PageTransitionsBuilder {
  const AppPageTransitionsBuilder();
  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    if (reducedMotion(context) || route.isFirst) return child;
    return SlideTransition(
      position: Tween<Offset>(begin: const Offset(1, 0), end: Offset.zero)
          .animate(
            CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutCubic,
              reverseCurve: Curves.easeInCubic,
            ),
          ),
      child: child,
    );
  }
}

class _TabFadeScope extends InheritedNotifier<Animation<double>> {
  const _TabFadeScope({
    required Animation<double> animation,
    required super.child,
  }) : super(notifier: animation);
}

/// Only page content fades. Headers and bottom navigation stay stationary.
class TabBodyFade extends StatelessWidget {
  final Widget child;
  const TabBodyFade({super.key, required this.child});
  @override
  Widget build(BuildContext context) {
    final animation = context
        .dependOnInheritedWidgetOfExactType<_TabFadeScope>()
        ?.notifier;
    return animation == null || reducedMotion(context)
        ? child
        : FadeTransition(opacity: animation, child: child);
  }
}

/// Fade through between retained tab subtrees; rapid taps select the latest tab.
class AppTabView extends StatefulWidget {
  final int index;
  final List<Widget> children;
  const AppTabView({super.key, required this.index, required this.children});
  @override
  State<AppTabView> createState() => _AppTabViewState();
}

class _AppTabViewState extends State<AppTabView>
    with SingleTickerProviderStateMixin {
  late final AnimationController controller = AnimationController(
    vsync: this,
    value: 1,
  );
  late int displayed = widget.index;
  int generation = 0;
  @override
  void didUpdateWidget(covariant AppTabView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.index != widget.index) switchTab();
  }

  Future<void> switchTab() async {
    final token = ++generation;
    if (reducedMotion(context)) {
      controller.stop();
      displayed = widget.index;
      controller.value = 1;
      return;
    }
    try {
      await controller
          .animateTo(
            0,
            duration: const Duration(milliseconds: 70),
            curve: Curves.easeOut,
          )
          .orCancel;
      if (!mounted || token != generation) return;
      setState(() => displayed = widget.index);
      await controller
          .animateTo(
            1,
            duration: const Duration(milliseconds: 130),
            curve: Curves.easeOut,
          )
          .orCancel;
    } on TickerCanceled {
      /* A newer selection or disposal supersedes this one. */
    }
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => _TabFadeScope(
    animation: controller,
    child: IndexedStack(index: displayed, children: widget.children),
  );
}

class FloatingNavigationBar extends StatelessWidget {
  final int index;
  final ValueChanged<int> onSelected;
  const FloatingNavigationBar({
    super.key,
    required this.index,
    required this.onSelected,
  });
  @override
  Widget build(BuildContext context) {
    final selected = index > 1 ? index + 1 : index;
    return SafeArea(
      top: false,
      minimum: const EdgeInsets.fromLTRB(12, 0, 12, 10),
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: green.withValues(alpha: .12),
              blurRadius: 18,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: FrostedPanel(
          navigation: true,
          radius: 24,
          child: SizedBox(
            height: 68,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final slot = constraints.maxWidth / 5;
                return Stack(
                  children: [
                    AnimatedPositioned(
                      duration: reducedMotion(context)
                          ? Duration.zero
                          : const Duration(milliseconds: 180),
                      curve: Curves.easeOutCubic,
                      left: selected * slot + 5,
                      top: 6,
                      width: slot - 10,
                      height: 54,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: .72),
                          borderRadius: BorderRadius.circular(18),
                        ),
                      ),
                    ),
                    Row(
                      children: List.generate(5, (i) {
                        final active = i == selected;
                        return Expanded(
                          child: Semantics(
                            selected: active,
                            button: true,
                            label: navLabels[i],
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                key: i == 2 ? tourNavAddDeedKey : null,
                                borderRadius: BorderRadius.circular(20),
                                onTap: () => onSelected(i),
                                child: SizedBox(
                                  height: 66,
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      if (i == 2)
                                        Container(
                                          width: 40,
                                          height: 32,
                                          decoration: BoxDecoration(
                                            color: green,
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                          ),
                                          child: const Icon(
                                            Icons.add_rounded,
                                            color: Colors.white,
                                            size: 24,
                                          ),
                                        )
                                      else
                                        SizedBox(
                                          height: 30,
                                          child: Icon(
                                            navIcons[i],
                                            color: active ? green : muted,
                                            size: 22,
                                          ),
                                        ),
                                      const SizedBox(height: 2),
                                      Text(
                                        navLabels[i],
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 10,
                                          height: 1.2,
                                          color: active ? green : muted,
                                          fontWeight: active
                                              ? FontWeight.w700
                                              : FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        );
                      }),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class SaveConfirmationMark extends StatelessWidget {
  const SaveConfirmationMark({super.key});
  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Saved privately',
    child: TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: reducedMotion(context)
          ? Duration.zero
          : const Duration(milliseconds: 360),
      curve: Curves.easeOut,
      builder: (context, progress, _) => SizedBox(
        width: 48,
        height: 48,
        child: CustomPaint(painter: _CheckPainter(progress)),
      ),
    ),
  );
}

class _CheckPainter extends CustomPainter {
  final double progress;
  _CheckPainter(this.progress);
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawCircle(
      size.center(Offset.zero),
      size.width / 2,
      Paint()..color = sage,
    );
    final path = Path()
      ..moveTo(size.width * .28, size.height * .51)
      ..lineTo(size.width * .43, size.height * .65)
      ..lineTo(size.width * .73, size.height * .34);
    final metric = path.computeMetrics().first;
    canvas.drawPath(
      metric.extractPath(0, metric.length * progress),
      Paint()
        ..color = green
        ..strokeWidth = 2.8
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..style = PaintingStyle.stroke,
    );
  }

  @override
  bool shouldRepaint(covariant _CheckPainter oldDelegate) =>
      oldDelegate.progress != progress;
}
