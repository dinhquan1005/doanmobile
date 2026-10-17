import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../features/home/providers/catalog_providers.dart';
import 'skeleton_box.dart';

class StorageNetworkImage extends ConsumerWidget {
  const StorageNetworkImage({
    super.key,
    required this.imageUrlOrPath,
    this.fit = BoxFit.cover,
    this.borderRadius,
  });

  final String imageUrlOrPath;
  final BoxFit fit;
  final BorderRadius? borderRadius;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final trimmed = imageUrlOrPath.trim();
    if (trimmed.isEmpty) {
      return _buildFallback(context);
    }

    if (isRunningInFlutterTest) {
      return _wrapRadius(_buildFallback(context));
    }

    if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
      return _wrapRadius(_buildCachedImage(context, trimmed));
    }

    final resolvedAsync = ref.watch(storageDownloadUrlProvider(trimmed));
    return _wrapRadius(
      resolvedAsync.when(
        loading: () => _buildPlaceholder(context),
        error: (_, __) => _buildFallback(context),
        data: (url) {
          if (url.isEmpty) {
            return _buildFallback(context);
          }
          return _buildCachedImage(context, url);
        },
      ),
    );
  }

  Widget _wrapRadius(Widget child) {
    if (borderRadius == null) {
      return child;
    }
    return ClipRRect(
      borderRadius: borderRadius!,
      child: child,
    );
  }

  Widget _buildCachedImage(BuildContext context, String url) {
    return CachedNetworkImage(
      imageUrl: url,
      fit: fit,
      placeholder: (context, _) => _buildPlaceholder(context),
      errorWidget: (context, _, __) => _buildFallback(context),
    );
  }

  Widget _buildPlaceholder(BuildContext context) {
    return Container(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      alignment: Alignment.center,
      child: const SizedBox(
        width: 22,
        height: 22,
        child: CircularProgressIndicator(strokeWidth: 2),
      ),
    );
  }

  Widget _buildFallback(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      color: scheme.surfaceContainerHighest.withValues(alpha: 0.65),
      alignment: Alignment.center,
      child: Icon(
        Icons.memory_rounded,
        size: 36,
        color: scheme.primary.withValues(alpha: 0.65),
      ),
    );
  }
}
