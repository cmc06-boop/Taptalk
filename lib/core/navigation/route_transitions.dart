import 'package:flutter/material.dart';

/// Instant full-screen routes — no slide or swipe-back gesture.
Route<T> taptalkPageRoute<T>({
  required WidgetBuilder builder,
  RouteSettings? settings,
}) {
  return PageRouteBuilder<T>(
    settings: settings,
    opaque: true,
    fullscreenDialog: false,
    transitionDuration: Duration.zero,
    reverseTransitionDuration: Duration.zero,
    pageBuilder: (context, animation, secondaryAnimation) => builder(context),
  );
}

/// Disables Material's default platform page-slide animations.
class TapTalkNoPageTransitionsBuilder extends PageTransitionsBuilder {
  const TapTalkNoPageTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    return child;
  }
}

const tapTalkPageTransitionsTheme = PageTransitionsTheme(
  builders: {
    TargetPlatform.android: TapTalkNoPageTransitionsBuilder(),
    TargetPlatform.iOS: TapTalkNoPageTransitionsBuilder(),
    TargetPlatform.macOS: TapTalkNoPageTransitionsBuilder(),
    TargetPlatform.windows: TapTalkNoPageTransitionsBuilder(),
    TargetPlatform.linux: TapTalkNoPageTransitionsBuilder(),
    TargetPlatform.fuchsia: TapTalkNoPageTransitionsBuilder(),
  },
);
