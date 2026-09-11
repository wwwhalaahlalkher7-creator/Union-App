import 'package:flutter/material.dart';

import '../../core/theme/design_tokens.dart';
import 'pressable.dart';

class FeatureCard extends StatefulWidget {
  const FeatureCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.badge,
    super.key,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  /// Optional small trailing badge, e.g. an unread count.
  final String? badge;

  @override
  State<FeatureCard> createState() => _FeatureCardState();
}

class _FeatureCardState extends State<FeatureCard> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isRtl = Directionality.of(context) == TextDirection.rtl;

    return Pressable(
      onTap: widget.onTap,
      scaleDown: 0.97,
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovering = true),
        onExit: (_) => setState(() => _hovering = false),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          decoration: BoxDecoration(
            color: cs.surface,
            borderRadius: BorderRadius.circular(DesignTokens.radius20),
            border: Border.all(
              color: _hovering ? cs.primary.withValues(alpha: .35) : cs.outline.withValues(alpha: .08),
            ),
            boxShadow: [
              BoxShadow(
                color: cs.primary.withValues(alpha: _hovering ? .12 : .05),
                blurRadius: _hovering ? 18 : 10,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(DesignTokens.space16),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        cs.primary.withValues(alpha: .20),
                        cs.primary.withValues(alpha: .08),
                      ],
                    ),
                  ),
                  child: Icon(widget.icon, color: cs.primary, size: 22),
                ),
                const SizedBox(width: DesignTokens.space12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              widget.title,
                              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (widget.badge != null) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                              decoration: BoxDecoration(
                                color: cs.primary,
                                borderRadius: BorderRadius.circular(DesignTokens.radius20),
                              ),
                              child: Text(
                                widget.badge!,
                                style: TextStyle(color: cs.onPrimary, fontSize: 10, fontWeight: FontWeight.w700),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: DesignTokens.space6),
                      Text(
                        widget.subtitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12.5, height: 1.3),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                AnimatedSlide(
                  duration: const Duration(milliseconds: 180),
                  offset: _hovering ? Offset(isRtl ? -0.15 : 0.15, 0) : Offset.zero,
                  child: Icon(
                    isRtl ? Icons.chevron_left_rounded : Icons.chevron_right_rounded,
                    color: cs.onSurfaceVariant.withValues(alpha: .7),
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
