import 'package:flutter/material.dart';

import '../di/service_locator.dart';

class PrivateStorageImage extends StatefulWidget {
  final String bucketName;
  final String path;
  final double height;

  const PrivateStorageImage({
    super.key,
    required this.bucketName,
    required this.path,
    this.height = 220,
  });

  @override
  State<PrivateStorageImage> createState() => _PrivateStorageImageState();
}

class _PrivateStorageImageState extends State<PrivateStorageImage> {
  late Future<String> _signedUrl;

  @override
  void initState() {
    super.initState();
    _createSignedUrl();
  }

  @override
  void didUpdateWidget(covariant PrivateStorageImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.bucketName != oldWidget.bucketName ||
        widget.path != oldWidget.path) {
      _createSignedUrl();
    }
  }

  void _createSignedUrl() {
    _signedUrl = sl.storage.createSignedUrl(
      bucketName: widget.bucketName,
      path: widget.path,
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String>(
      future: _signedUrl,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Text('Unable to create private image link: ${snapshot.error}');
        }
        if (!snapshot.hasData) {
          return SizedBox(
            height: widget.height,
            child: const Center(child: CircularProgressIndicator()),
          );
        }
        return Image.network(
          snapshot.data!,
          height: widget.height,
          width: double.infinity,
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) =>
              Text('Unable to load private image: $error'),
        );
      },
    );
  }
}
