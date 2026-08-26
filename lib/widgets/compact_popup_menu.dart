import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../core/constants/app_spacing.dart';

class CompactMenuAction {
  const CompactMenuAction({
    required this.value,
    required this.label,
    required this.icon,
    required this.color,
  });

  final String value;
  final String label;
  final IconData icon;
  final Color color;
}

/// Dots menu sized tight to its labels — the app's one actions-menu look.
///
/// Built on [MenuAnchor] rather than [PopupMenuButton]: a popup menu route lays
/// a full-screen modal barrier that swallows drags, so the list behind it freezes
/// while the menu is open. This one leaves the page scrollable and closes itself
/// as soon as the surrounding list moves, so the sheet never floats away from
/// the button that opened it.
///
/// Menus are also pinned to a measured width. Material sizes a menu up to the
/// next 56px step and pads the sheet, which leaves a wide blank strip beside one
/// or two short actions; measuring the widest label keeps it snug in every
/// language.
class CompactPopupMenu extends StatefulWidget {
  const CompactPopupMenu({
    super.key,
    required this.actions,
    required this.onSelected,
    required this.iconColor,
    this.vertical = false,
    this.buttonWidth = 32,
    this.buttonHeight = 24,
    this.dotsSize = 20,
    this.buttonBackground,
    this.tooltip,
  });

  static const double _iconSize = 16;
  static const double _itemHeight = 32;

  final List<CompactMenuAction> actions;
  final ValueChanged<String> onSelected;
  final Color iconColor;

  /// Vertical dots for menus pinned to a card corner, horizontal for menus
  /// sitting inline at the end of a row.
  final bool vertical;
  final double buttonWidth;
  final double buttonHeight;
  final double dotsSize;

  /// Circle behind the dots, so they stay readable over artwork or color.
  final Color? buttonBackground;
  final String? tooltip;

  static TextStyle _labelStyle(Color color) => GoogleFonts.poppins(
    fontSize: 12.5,
    fontWeight: FontWeight.w600,
    color: color,
  );

  @override
  State<CompactPopupMenu> createState() => _CompactPopupMenuState();
}

class _CompactPopupMenuState extends State<CompactPopupMenu> {
  final MenuController _controller = MenuController();
  ScrollPosition? _watchedPosition;

  @override
  void dispose() {
    _stopWatchingScroll();
    super.dispose();
  }

  void _open() {
    _controller.open();
    _stopWatchingScroll();
    _watchedPosition = Scrollable.maybeOf(context)?.position
      ?..addListener(_closeOnScroll);
  }

  void _closeOnScroll() {
    _stopWatchingScroll();
    if (_controller.isOpen) _controller.close();
  }

  void _stopWatchingScroll() {
    _watchedPosition?.removeListener(_closeOnScroll);
    _watchedPosition = null;
  }

  double _menuWidth() {
    final textDirection = Directionality.of(context);
    final textScaler = MediaQuery.textScalerOf(context);
    var widestLabel = 0.0;
    for (final action in widget.actions) {
      final painter = TextPainter(
        text: TextSpan(
          text: action.label,
          style: CompactPopupMenu._labelStyle(action.color),
        ),
        textDirection: textDirection,
        textScaler: textScaler,
      )..layout();
      if (painter.width > widestLabel) widestLabel = painter.width;
      painter.dispose();
    }
    // Round up and add a hairline of slack — the painter's fractional width is
    // a shade narrower than what the Text widget lays out.
    return widestLabel.ceilToDouble() +
        CompactPopupMenu._iconSize +
        AppSpacing.xs +
        AppSpacing.sm * 2 +
        2;
  }

  @override
  Widget build(BuildContext context) {
    final menuWidth = _menuWidth();

    Widget dots = Icon(
      widget.vertical ? Icons.more_vert_rounded : Icons.more_horiz_rounded,
      size: widget.dotsSize,
      color: widget.iconColor,
    );
    if (widget.buttonBackground != null) {
      dots = Container(
        width: widget.buttonWidth,
        height: widget.buttonHeight,
        decoration: BoxDecoration(
          color: widget.buttonBackground,
          shape: BoxShape.circle,
        ),
        child: Center(child: dots),
      );
    }

    return MenuAnchor(
      controller: _controller,
      // Sit over the button the way the old popup did, instead of dropping a
      // menu's height below it.
      alignmentOffset: Offset(0, -(widget.buttonHeight + 6)),
      style: MenuStyle(
        backgroundColor: const WidgetStatePropertyAll(Colors.white),
        surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
        padding: const WidgetStatePropertyAll(EdgeInsets.zero),
        elevation: const WidgetStatePropertyAll(8),
        minimumSize: WidgetStatePropertyAll(Size(menuWidth, 0)),
        maximumSize: WidgetStatePropertyAll(Size(menuWidth, double.infinity)),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      ),
      builder: (context, controller, _) => SizedBox(
        width: widget.buttonWidth,
        height: widget.buttonHeight,
        child: IconButton(
          onPressed: () => controller.isOpen ? controller.close() : _open(),
          icon: dots,
          iconSize: widget.dotsSize,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
          tooltip: widget.tooltip,
          style: const ButtonStyle(
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ),
      ),
      menuChildren: [
        for (final action in widget.actions)
          MenuItemButton(
            onPressed: () => widget.onSelected(action.value),
            style: ButtonStyle(
              minimumSize: const WidgetStatePropertyAll(
                Size(0, CompactPopupMenu._itemHeight),
              ),
              padding: const WidgetStatePropertyAll(
                EdgeInsets.symmetric(horizontal: AppSpacing.sm),
              ),
              shape: const WidgetStatePropertyAll(RoundedRectangleBorder()),
              foregroundColor: WidgetStatePropertyAll(action.color),
              visualDensity: VisualDensity.compact,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  action.icon,
                  size: CompactPopupMenu._iconSize,
                  color: action.color,
                ),
                const SizedBox(width: AppSpacing.xs),
                Text(
                  action.label,
                  style: CompactPopupMenu._labelStyle(action.color),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
