import 'package:flutter/material.dart';

/// Motion in one place, so the whole app moves the same way: short, eased,
/// and never in the way of a tap.
abstract final class Motion {
  /// A press, a tick, a chip appearing.
  static const Duration quick = Duration(milliseconds: 160);

  /// A card or sheet arriving, a tab changing.
  static const Duration standard = Duration(milliseconds: 280);

  /// A screen arriving, a story page turning.
  static const Duration gentle = Duration(milliseconds: 460);

  static const Curve enter = Curves.easeOutCubic;
  static const Curve leave = Curves.easeInCubic;
}

/// [duration], or none at all when the device asks for reduced motion.
Duration motion(BuildContext context, Duration duration) =>
    (MediaQuery.maybeDisableAnimationsOf(context) ?? false)
        ? Duration.zero
        : duration;

/// A full-screen route that fades in while rising a few pixels, and fades
/// out the way it came. Used for the screens that open over the board.
class RiseRoute<T> extends PageRouteBuilder<T> {
  RiseRoute({required WidgetBuilder builder, super.settings})
      : super(
          transitionDuration: Motion.standard,
          reverseTransitionDuration: const Duration(milliseconds: 220),
          pageBuilder: (context, animation, secondary) => builder(context),
          transitionsBuilder: (context, animation, secondary, child) {
            if (MediaQuery.maybeDisableAnimationsOf(context) ?? false) {
              return child;
            }
            final curved = CurvedAnimation(
              parent: animation,
              curve: Motion.enter,
              reverseCurve: Motion.leave,
            );
            return FadeTransition(
              opacity: curved,
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0, 0.035),
                  end: Offset.zero,
                ).animate(curved),
                child: child,
              ),
            );
          },
        );
}
