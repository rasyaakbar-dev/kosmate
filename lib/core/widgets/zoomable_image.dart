import 'package:flutter/material.dart';

class ZoomableImage extends StatelessWidget {
  final ImageProvider<Object>? imageProvider;
  final Widget child;

  const ZoomableImage({
    super.key,
    required this.imageProvider,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final provider = imageProvider;
    if (provider == null) return child;

    return GestureDetector(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute<void>(
          fullscreenDialog: true,
          builder: (_) => _ZoomedImagePage(imageProvider: provider),
        ),
      ),
      child: child,
    );
  }
}

class _ZoomedImagePage extends StatelessWidget {
  final ImageProvider<Object> imageProvider;

  const _ZoomedImagePage({required this.imageProvider});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            Positioned.fill(
              child: InteractiveViewer(
                minScale: 1,
                maxScale: 5,
                child: Image(
                  image: imageProvider,
                  width: double.infinity,
                  height: double.infinity,
                  fit: BoxFit.contain,
                  errorBuilder: (_, _, _) => const Center(
                    child: Icon(
                      Icons.broken_image_outlined,
                      color: Colors.white70,
                      size: 48,
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              top: 8,
              right: 8,
              child: IconButton.filled(
                tooltip: 'Close image',
                onPressed: () => Navigator.pop(context),
                style: IconButton.styleFrom(
                  backgroundColor: Colors.black54,
                  foregroundColor: Colors.white,
                ),
                icon: const Icon(Icons.close),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
