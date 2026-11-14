import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import '../../theme/palette.dart';
import 'v_icon.dart';

/// A parchment-cream card with a fine gold edge.
class ParchmentCard extends StatelessWidget {
  const ParchmentCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(14),
    this.tint,
    this.edge,
    this.onTap,
    this.radius = 18,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? tint;
  final Color? edge;
  final VoidCallback? onTap;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final base = tint ?? Palette.parchment;
    final shape = BorderRadius.circular(radius);
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: shape,
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Palette.forestNight.withValues(alpha: 0.28),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: shape,
        clipBehavior: Clip.antiAlias,
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: shape,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: <Color>[
                Color.lerp(base, Colors.white, 0.35)!,
                base,
                Color.lerp(base, Palette.parchmentShade, 0.55)!,
              ],
            ),
            border: Border.all(color: edge ?? Palette.parchmentEdge),
          ),
          child: InkWell(
            onTap: onTap,
            borderRadius: shape,
            splashColor: Palette.gold.withValues(alpha: 0.18),
            highlightColor: Palette.gold.withValues(alpha: 0.08),
            child: Padding(padding: padding, child: child),
          ),
        ),
      ),
    );
  }
}

/// An XP or progress bar that glides to its new value.
class XpBar extends StatelessWidget {
  const XpBar({
    super.key,
    required this.fraction,
    this.color = Palette.gold,
    this.track,
    this.height = 8,
  });

  final double fraction;
  final Color color;
  final Color? track;
  final double height;

  @override
  Widget build(BuildContext context) {
    final target = fraction.clamp(0.0, 1.0);
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(end: target),
      duration: const Duration(milliseconds: 700),
      curve: Curves.easeOutCubic,
      builder: (context, value, _) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(height),
          child: SizedBox(
            height: height,
            child: Stack(
              fit: StackFit.expand,
              children: <Widget>[
                ColoredBox(
                  color: track ?? Palette.forestNight.withValues(alpha: 0.35),
                ),
                FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: value,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(height),
                      gradient: LinearGradient(
                        colors: <Color>[
                          Color.lerp(color, Colors.black, 0.12)!,
                          color,
                          Color.lerp(color, Colors.white, 0.35)!,
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Section title on the dark background.
class SectionHeader extends StatelessWidget {
  const SectionHeader(
    this.title, {
    super.key,
    this.icon,
    this.color = Palette.onDark,
    this.trailing,
    this.count,
  });

  final String title;
  final String? icon;
  final Color color;
  final Widget? trailing;
  final int? count;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 18, 4, 10),
      child: Row(
        children: <Widget>[
          if (icon != null) ...<Widget>[
            VIcon(icon!, size: 18, color: color),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppText.title.copyWith(color: color),
            ),
          ),
          if (count != null) ...<Widget>[
            const SizedBox(width: 8),
            Text(
              '$count',
              style: AppText.small.copyWith(
                color: color.withValues(alpha: 0.7),
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
          const Spacer(),
          ?trailing,
        ],
      ),
    );
  }
}

/// A round attribute or quest emblem.
class Roundel extends StatelessWidget {
  const Roundel({
    super.key,
    required this.icon,
    required this.color,
    this.size = 44,
  });

  final String icon;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          center: const Alignment(-0.3, -0.4),
          radius: 0.95,
          colors: <Color>[
            Color.lerp(color, Colors.white, 0.3)!,
            color,
            Color.lerp(color, Colors.black, 0.22)!,
          ],
        ),
        border: Border.all(
          color: Color.lerp(color, Colors.black, 0.3)!,
          width: 1,
        ),
      ),
      alignment: Alignment.center,
      child: VIcon(icon, size: size * 0.54, color: Palette.parchment),
    );
  }
}

/// A selectable pill used for attribute, difficulty, track and schedule.
class ChoicePill extends StatelessWidget {
  const ChoicePill({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.color = Palette.forest,
    this.icon,
    this.caption,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Color color;
  final String? icon;
  final String? caption;

  @override
  Widget build(BuildContext context) {
    final foreground = selected ? Palette.parchment : Palette.slate;
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: Material(
        color: selected ? color : Colors.white.withValues(alpha: 0.5),
        shape: StadiumBorder(
          side: BorderSide(
            color: selected ? color : Palette.parchmentEdge,
            width: 1.2,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 44),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  if (icon != null) ...<Widget>[
                    VIcon(icon!, size: 18, color: foreground),
                    const SizedBox(width: 7),
                  ],
                  ExcludeSemantics(
                    child: Text(
                      label,
                      style: AppText.small.copyWith(
                        color: foreground,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  if (caption != null) ...<Widget>[
                    const SizedBox(width: 6),
                    ExcludeSemantics(
                      child: Text(
                        caption!,
                        style: AppText.small.copyWith(
                          color: foreground.withValues(alpha: 0.75),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The main call to action: forest green with a gold edge.
class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.color = Palette.forest,
  });

  final String label;
  final VoidCallback? onPressed;
  final String? icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    return Opacity(
      opacity: enabled ? 1 : 0.45,
      child: Material(
        color: color,
        shape: const StadiumBorder(
          side: BorderSide(color: Palette.gold, width: 1.4),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onPressed,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 52),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  if (icon != null) ...<Widget>[
                    VIcon(icon!, size: 20, color: Palette.goldBright),
                    const SizedBox(width: 10),
                  ],
                  Flexible(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.cardTitle.copyWith(color: Palette.onDark),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A quieter secondary action.
class QuietButton extends StatelessWidget {
  const QuietButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.color = Palette.slate,
  });

  final String label;
  final VoidCallback? onPressed;
  final String? icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      shape: StadiumBorder(
        side: BorderSide(color: color.withValues(alpha: 0.35), width: 1.2),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onPressed,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                if (icon != null) ...<Widget>[
                  VIcon(icon!, size: 18, color: color),
                  const SizedBox(width: 8),
                ],
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.small.copyWith(
                      color: color,
                      fontWeight: FontWeight.w600,
                      fontSize: 14.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A small icon + number, e.g. materials and gold.
class StatChip extends StatelessWidget {
  const StatChip({
    super.key,
    required this.icon,
    required this.value,
    required this.label,
    this.color = Palette.onDark,
    this.iconColor,
  });

  final String icon;
  final String value;
  final String label;
  final Color color;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '$label: $value',
      child: ExcludeSemantics(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            VIcon(icon, size: 16, color: iconColor ?? color),
            const SizedBox(width: 5),
            Text(
              value,
              style: AppText.small.copyWith(
                color: color,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A round icon button with a comfortable touch target.
class RoundIconButton extends StatelessWidget {
  const RoundIconButton({
    super.key,
    required this.icon,
    required this.onPressed,
    required this.semanticLabel,
    this.size = 44,
    this.background = Palette.forest,
    this.foreground = Palette.goldBright,
    this.edge = Palette.gold,
  });

  final String icon;
  final VoidCallback? onPressed;
  final String semanticLabel;
  final double size;
  final Color background;
  final Color foreground;
  final Color edge;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: semanticLabel,
      child: Material(
        color: background,
        shape: CircleBorder(side: BorderSide(color: edge, width: 1.4)),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onPressed,
          child: SizedBox(
            width: size,
            height: size,
            child: Center(
              child: VIcon(icon, size: size * 0.48, color: foreground),
            ),
          ),
        ),
      ),
    );
  }
}

/// A labelled tick box, with an optional line of explanation beneath.
class ToggleRow extends StatelessWidget {
  const ToggleRow({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.caption,
  });

  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;
  final String? caption;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      checked: value,
      label: label,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => onChanged(!value),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 2),
          child: Row(
            children: <Widget>[
              Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  color: value
                      ? Palette.forest
                      : Colors.white.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: value ? Palette.gold : Palette.parchmentEdge,
                    width: 1.4,
                  ),
                ),
                alignment: Alignment.center,
                child: value
                    ? const VIcon('check', size: 16, color: Palette.goldBright)
                    : null,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ExcludeSemantics(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        label,
                        style: AppText.body.copyWith(color: Palette.slate),
                      ),
                      if (caption != null)
                        Text(
                          caption!,
                          style: AppText.small.copyWith(
                            color: Palette.slateSoft,
                            fontSize: 12.5,
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
    );
  }
}

String formatClock(int seconds) {
  final s = seconds < 0 ? 0 : seconds;
  final m = s ~/ 60;
  final r = s % 60;
  return '${m.toString().padLeft(2, '0')}:${r.toString().padLeft(2, '0')}';
}

String formatTimeOfDay(DateTime t) =>
    '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
