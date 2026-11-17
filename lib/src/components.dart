part of '../main.dart';

Future<T?> openPage<T>(BuildContext context, Widget page) =>
    Navigator.of(context).push<T>(MaterialPageRoute(builder: (_) => page));
void toast(BuildContext context, String message) =>
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
Future<bool> confirm(
  BuildContext context,
  String title,
  String message, {
  String action = 'Confirm',
}) async =>
    await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(action),
          ),
        ],
      ),
    ) ??
    false;

class Brand extends StatelessWidget {
  const Brand({super.key});
  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      const BrandMark(size: 30),
      const SizedBox(width: 9),
      Text('DeedWise', style: editorial(24)),
    ],
  );
}

class FrostedPanel extends StatelessWidget {
  final Widget child;
  final bool navigation;
  final bool solid;
  final bool bottomRounded;
  final double radius;
  const FrostedPanel({
    super.key,
    required this.child,
    this.navigation = false,
    this.solid = false,
    this.bottomRounded = false,
    this.radius = 0,
  });
  BorderRadiusGeometry get panelBorderRadius => bottomRounded
      ? BorderRadius.vertical(bottom: Radius.circular(radius))
      : BorderRadius.circular(radius);

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: panelBorderRadius,
    child: solid
        ? Container(
            decoration: BoxDecoration(
              color: paper,
              borderRadius: panelBorderRadius,
              border: Border.all(color: line),
              boxShadow: [
                BoxShadow(
                  color: green.withValues(alpha: .06),
                  blurRadius: 14,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: child,
          )
        : BackdropFilter(
            filter: ui.ImageFilter.blur(sigmaX: 18, sigmaY: 18),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: panelBorderRadius,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: navigation
                      ? [
                          const Color(0xFFCADDD1).withValues(alpha: .87),
                          const Color(0xFFBFD4C8).withValues(alpha: .82),
                        ]
                      : [
                          const Color(0xFFE3EDE5).withValues(alpha: .84),
                          const Color(0xFFD3E2D8).withValues(alpha: .76),
                        ],
                ),
                border: Border.all(color: Colors.white.withValues(alpha: .65)),
                boxShadow: [
                  BoxShadow(
                    color: green.withValues(alpha: .05),
                    blurRadius: 18,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: child,
            ),
          ),
  );
}

class RootPage extends StatelessWidget {
  final String title, subtitle;
  final Widget child;
  final Widget? action, headerAction;
  final bool botanicalTitle;
  const RootPage({
    super.key,
    required this.title,
    required this.subtitle,
    required this.child,
    this.action,
    this.headerAction,
    this.botanicalTitle = false,
  });
  @override
  Widget build(BuildContext context) => Stack(
    children: [
      Positioned.fill(
        child: TabBodyFade(
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: ClipRect(
                  child: Stack(
                    children: [
                      if (botanicalTitle)
                        Positioned(
                          top: 44,
                          right: -18,
                          width: 164,
                          height: 190,
                          child: IgnorePointer(
                            child: ExcludeSemantics(
                              child: Opacity(
                                opacity: .085,
                                child: CustomPaint(
                                  painter: BotanicalPainter(color: green),
                                ),
                              ),
                            ),
                          ),
                        ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 72, 16, 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(title, style: editorial(32)),
                                ),
                                ?action,
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              subtitle,
                              style: const TextStyle(
                                color: muted,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SliverPadding(
                padding: EdgeInsets.fromLTRB(
                  16,
                  0,
                  16,
                  20 + MediaQuery.paddingOf(context).bottom,
                ),
                sliver: SliverToBoxAdapter(child: child),
              ),
            ],
          ),
        ),
      ),
      Positioned(
        top: 0,
        left: 0,
        right: 0,
        child: FrostedPanel(
          solid: true,
          bottomRounded: true,
          radius: 18,
          child: SizedBox(
            height: 56,
            child: Padding(
              padding: const EdgeInsets.only(left: 16, right: 8),
              child: Row(
                children: [
                  const Brand(),
                  const Spacer(),
                  ?headerAction,
                  IconButton(
                    tooltip: 'Profile and settings',
                    onPressed: () => openPage(context, const SettingsPage()),
                    icon: const ProfileAvatar(radius: 16),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ],
  );
}

class DetailPage extends StatelessWidget {
  final String title;
  final Widget child;
  final List<Widget>? actions;
  const DetailPage({
    super.key,
    required this.title,
    required this.child,
    this.actions,
  });
  @override
  Widget build(BuildContext context) => Scaffold(
    extendBodyBehindAppBar: true,
    appBar: AppBar(
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      scrolledUnderElevation: 0,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(18)),
      ),
      flexibleSpace: const FrostedPanel(
        solid: true,
        radius: 18,
        child: SizedBox.expand(),
      ),
      title: Text(
        title,
        style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
      ),
      actions: actions,
    ),
    body: Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            16,
            MediaQuery.paddingOf(context).top + kToolbarHeight + 16,
            16,
            24,
          ),
          child: child,
        ),
      ),
    ),
  );
}

class Surface extends StatelessWidget {
  final Widget child;
  final Color color;
  final Gradient? gradient;
  final EdgeInsets padding;
  final VoidCallback? onTap;
  const Surface({
    super.key,
    required this.child,
    this.color = Colors.white,
    this.gradient,
    this.padding = const EdgeInsets.all(16),
    this.onTap,
  });
  @override
  Widget build(BuildContext context) {
    final surface = Material(
      color: color,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: color == Colors.white ? line : Colors.transparent,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Ink(
        decoration: BoxDecoration(gradient: gradient),
        child: InkWell(
          onTap: onTap,
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
    return surface;
  }
}

class Section extends StatelessWidget {
  final String title;
  final String? link;
  final VoidCallback? onTap;
  const Section(this.title, {super.key, this.link, this.onTap});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 20, bottom: 10),
    child: Row(
      children: [
        Expanded(child: Text(title, style: editorial(23))),
        if (link != null)
          TextButton(
            onPressed: onTap,
            child: Text(link!, style: const TextStyle(fontSize: 12)),
          ),
      ],
    ),
  );
}

class Eyebrow extends StatelessWidget {
  final String text;
  final Color color;
  const Eyebrow(this.text, {super.key, this.color = muted});
  @override
  Widget build(BuildContext context) => Text(
    text.toUpperCase(),
    style: TextStyle(
      fontSize: 10,
      letterSpacing: 1.7,
      color: color,
      fontWeight: FontWeight.w600,
    ),
  );
}

class Tag extends StatelessWidget {
  final String text;
  final Color color, background;
  final IconData? icon;
  const Tag(
    this.text, {
    super.key,
    this.color = green,
    this.background = sage,
    this.icon,
  });
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(
      color: background,
      borderRadius: BorderRadius.circular(8),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null) ...[
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 5),
        ],
        Flexible(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 10,
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    ),
  );
}

class TemplateIcon extends StatelessWidget {
  final DeedTemplate template;
  final double size;
  const TemplateIcon(this.template, {super.key, this.size = 40});
  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      color: template.tint,
      borderRadius: BorderRadius.circular(15),
    ),
    child: Icon(template.icon, color: green, size: size * .48),
  );
}

class ActivityRow extends StatelessWidget {
  final DeedTemplate template;
  final String? title, subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  const ActivityRow(
    this.template, {
    super.key,
    this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
  });
  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(14),
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          TemplateIcon(template),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title ?? template.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle ?? template.category,
                  style: const TextStyle(fontSize: 12, color: muted),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          trailing ??
              const Icon(Icons.chevron_right_rounded, color: muted, size: 19),
        ],
      ),
    ),
  );
}

class NoteBox extends StatelessWidget {
  final String text;
  final IconData icon;
  const NoteBox(this.text, {super.key, this.icon = Icons.lock_outline_rounded});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: sage,
      borderRadius: BorderRadius.circular(14),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 17, color: green),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(fontSize: 12, color: green, height: 1.6),
          ),
        ),
      ],
    ),
  );
}

class EmptyState extends StatelessWidget {
  final String title, message;
  final IconData icon;
  final Widget? action;
  const EmptyState(
    this.title,
    this.message, {
    super.key,
    this.icon = Icons.spa_outlined,
    this.action,
  });
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 35),
    child: Center(
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(22),
            decoration: const BoxDecoration(
              color: sage,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 32, color: green),
          ),
          const SizedBox(height: 20),
          Text(title, style: editorial(25), textAlign: TextAlign.center),
          const SizedBox(height: 10),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: muted),
          ),
          if (action != null) ...[const SizedBox(height: 20), action!],
        ],
      ),
    ),
  );
}

class FieldLabel extends StatelessWidget {
  final String text;
  const FieldLabel(this.text, {super.key});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 22, bottom: 9),
    child: Text(
      text,
      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
    ),
  );
}

class Metric extends StatelessWidget {
  final String value, label;
  final IconData icon;
  final VoidCallback? onTap;
  const Metric(this.value, this.label, this.icon, {super.key, this.onTap});
  @override
  Widget build(BuildContext context) => Expanded(
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 7),
        child: Column(
          children: [
            Icon(icon, color: gold, size: 20),
            const SizedBox(height: 10),
            Text(value, style: editorial(28)),
            const SizedBox(height: 4),
            Text(label, style: const TextStyle(fontSize: 10, color: muted)),
          ],
        ),
      ),
    ),
  );
}

class BotanicalPainter extends CustomPainter {
  final Color color;
  BotanicalPainter({this.color = const Color(0xFFBCCBB5)});
  @override
  void paint(Canvas canvas, Size size) {
    final stem = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6;
    final fill = Paint()..color = color.withValues(alpha: .28);
    for (var b = 0; b < 3; b++) {
      final x = size.width * (.3 + b * .24);
      final path = Path()
        ..moveTo(size.width * .55, size.height)
        ..quadraticBezierTo(x - 30, size.height * .5, x + 18, size.height * .1);
      canvas.drawPath(path, stem);
      for (var i = 0; i < 5; i++) {
        final y = size.height * (.24 + i * .14);
        final lx = x + 8 - math.sin(i * .5) * 20;
        for (final side in [-1, 1]) {
          final leaf = Path()
            ..moveTo(lx, y + 22)
            ..quadraticBezierTo(lx + side * 43, y + 16, lx + side * 34, y - 13)
            ..quadraticBezierTo(lx + side * 6, y - 13, lx, y + 22);
          canvas.drawPath(leaf, fill);
          canvas.drawPath(leaf, stem);
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant BotanicalPainter oldDelegate) =>
      color != oldDelegate.color;
}
