part of '../main.dart';

const green = Color(0xFF234E40);
const ink = Color(0xFF263C33);
const muted = Color(0xFF707A71);
const paper = Color(0xFFFAF9F5);
const sage = Color(0xFFEAF0E7);
const line = Color(0xFFE7E8E0);
const gold = Color(0xFF99713A);
const peach = Color(0xFFF5EDE1);

class AppScrollBehavior extends MaterialScrollBehavior {
  const AppScrollBehavior();

  @override
  Widget buildOverscrollIndicator(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) => child;

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) =>
      const ClampingScrollPhysics();
}

final appTheme = ThemeData(
  useMaterial3: true,
  bottomSheetTheme: const BottomSheetThemeData(
    backgroundColor: paper,
    surfaceTintColor: Colors.transparent,
    showDragHandle: true,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
  ),
  pageTransitionsTheme: const PageTransitionsTheme(
    builders: {
      TargetPlatform.android: AppPageTransitionsBuilder(),
      TargetPlatform.iOS: AppPageTransitionsBuilder(),
      TargetPlatform.macOS: AppPageTransitionsBuilder(),
      TargetPlatform.windows: AppPageTransitionsBuilder(),
      TargetPlatform.linux: AppPageTransitionsBuilder(),
      TargetPlatform.fuchsia: AppPageTransitionsBuilder(),
    },
  ),
  scaffoldBackgroundColor: paper,
  colorScheme: ColorScheme.fromSeed(
    seedColor: green,
    primary: green,
    surface: paper,
    onSurface: ink,
  ),
  fontFamily: 'DMSans',
  textTheme: const TextTheme(
    bodyMedium: TextStyle(fontSize: 14, height: 1.55, color: ink),
    bodyLarge: TextStyle(fontSize: 16, height: 1.55, color: ink),
    titleMedium: TextStyle(
      fontSize: 16,
      fontWeight: FontWeight.w600,
      color: ink,
    ),
  ),
  appBarTheme: const AppBarTheme(
    backgroundColor: paper,
    foregroundColor: ink,
    surfaceTintColor: Colors.transparent,
    centerTitle: false,
    elevation: 0,
  ),
  filledButtonTheme: FilledButtonThemeData(
    style: FilledButton.styleFrom(
      minimumSize: const Size(48, 52),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      textStyle: const TextStyle(
        fontFamily: 'DMSans',
        fontWeight: FontWeight.w600,
        fontSize: 14,
      ),
    ),
  ),
  outlinedButtonTheme: OutlinedButtonThemeData(
    style: OutlinedButton.styleFrom(
      minimumSize: const Size(48, 50),
      side: const BorderSide(color: line),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
    ),
  ),
  inputDecorationTheme: InputDecorationTheme(
    filled: true,
    fillColor: Colors.white,
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 17),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: line),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: line),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: green, width: 1.5),
    ),
  ),
  dividerTheme: const DividerThemeData(color: line, thickness: 1),
);
TextStyle editorial(double size, {Color color = ink}) => TextStyle(
  fontFamily: 'DMSans',
  fontSize: size >= 44
      ? 32
      : size >= 30
      ? 24
      : size >= 24
      ? 21
      : size >= 20
      ? 18
      : size,
  fontWeight: FontWeight.w700,
  height: 1.25,
  letterSpacing: -.35,
  color: color,
);
String dateLabel(DateTime date) =>
    '${monthNames[date.month - 1]} ${date.day}, ${date.year}';
String shortDate(DateTime date) => '${monthNames[date.month - 1]} ${date.day}';
const monthNames = [
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December',
];
const weekNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
DateTime dayOnly(DateTime date) => DateTime(date.year, date.month, date.day);
bool sameDay(DateTime a, DateTime b) => dayOnly(a) == dayOnly(b);
DateTime get today =>
    dayOnly(DateTime.now().toUtc().add(const Duration(hours: 6)));
