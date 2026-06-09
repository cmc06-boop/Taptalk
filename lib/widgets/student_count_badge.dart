import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Compact student count shown beside the class title in the app bar.
class StudentCountBadge extends StatelessWidget {
  const StudentCountBadge({
    super.key,
    required this.count,
    required this.accent,
  });

  final int count;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: accent.withValues(alpha: 0.12),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.groups_rounded, size: 17, color: accent),
          const SizedBox(width: 5),
          Text(
            '$count',
            softWrap: false,
            maxLines: 1,
            overflow: TextOverflow.visible,
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: accent,
              height: 1.1,
            ),
          ),
        ],
      ),
    );
  }
}
