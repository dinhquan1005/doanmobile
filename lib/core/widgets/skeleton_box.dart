import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

bool get isRunningInFlutterTest =>
    (kDebugMode && Platform.environment.containsKey('FLUTTER_TEST')) ||
    WidgetsBinding.instance.runtimeType.toString().contains('Test');

class SkeletonBox extends StatefulWidget {
  const SkeletonBox({
    super.key,
    this.width,
    this.height = 16,
    this.borderRadius = 10,
  });

  final double? width;
  final double height;
  final double borderRadius;

  @override
  State<SkeletonBox> createState() => _SkeletonBoxState();
}

class _SkeletonBoxState extends State<SkeletonBox>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    );
    if (!isRunningInFlutterTest) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final baseColor =
        isDark ? const Color(0xFF1E2D47) : const Color(0xFFE2E8F0);
    final highlightColor =
        isDark ? const Color(0xFF2B4162) : const Color(0xFFF1F5F9);

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            color: Color.lerp(baseColor, highlightColor, _controller.value),
            borderRadius: BorderRadius.circular(widget.borderRadius),
          ),
        );
      },
    );
  }
}

class ProductGridSkeleton extends StatelessWidget {
  const ProductGridSkeleton({
    super.key,
    this.itemCount = 6,
  });

  final int itemCount;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      itemCount: itemCount,
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 220,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 0.64,
      ),
      itemBuilder: (context, index) {
        return const Card(
          child: Padding(
            padding: EdgeInsets.all(10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: SkeletonBox(
                    width: double.infinity,
                    borderRadius: 10,
                  ),
                ),
                SizedBox(height: 10),
                SkeletonBox(width: 70, height: 12),
                SizedBox(height: 6),
                SkeletonBox(width: double.infinity, height: 14),
                SizedBox(height: 4),
                SkeletonBox(width: 120, height: 14),
                SizedBox(height: 10),
                SkeletonBox(width: 100, height: 18),
              ],
            ),
          ),
        );
      },
    );
  }
}
