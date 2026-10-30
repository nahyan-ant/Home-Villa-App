import 'package:flutter/material.dart';

import '../models.dart';
import '../theme.dart';
import '../widgets/common.dart';

/// Full-screen photos: swipe between them, pinch or double-tap to zoom.
class PhotoViewer extends StatefulWidget {
  const PhotoViewer({super.key, required this.photos, required this.initialIndex});

  final List<Photo> photos;
  final int initialIndex;

  @override
  State<PhotoViewer> createState() => _PhotoViewerState();
}

class _PhotoViewerState extends State<PhotoViewer> {
  late final PageController _pages = PageController(initialPage: widget.initialIndex);
  late int _index = widget.initialIndex;

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final photo = widget.photos[_index];
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          fit: StackFit.expand,
          children: [
            PageView.builder(
              controller: _pages,
              itemCount: widget.photos.length,
              onPageChanged: (i) => setState(() => _index = i),
              itemBuilder: (context, i) => _ZoomablePhoto(photo: widget.photos[i]),
            ),
            Positioned(
              left: 8,
              right: 8,
              top: 8,
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: Palette.white),
                    tooltip: 'Close',
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      photo.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Palette.white, fontSize: 15, fontWeight: FontWeight.w500),
                    ),
                  ),
                  if (widget.photos.length > 1)
                    Padding(
                      padding: const EdgeInsets.only(right: 12),
                      child: Text(
                        '${_index + 1} of ${widget.photos.length}',
                        style: const TextStyle(color: Palette.nightText, fontSize: 14),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ZoomablePhoto extends StatefulWidget {
  const _ZoomablePhoto({required this.photo});

  final Photo photo;

  @override
  State<_ZoomablePhoto> createState() => _ZoomablePhotoState();
}

class _ZoomablePhotoState extends State<_ZoomablePhoto> {
  final _zoom = TransformationController();

  @override
  void dispose() {
    _zoom.dispose();
    super.dispose();
  }

  void _toggleZoom(TapDownDetails details) {
    if (_zoom.value.getMaxScaleOnAxis() > 1.01) {
      _zoom.value = Matrix4.identity();
    } else {
      final p = details.localPosition;
      _zoom.value = Matrix4.identity()
        ..translateByDouble(-p.dx * 1.5, -p.dy * 1.5, 0, 1)
        ..scaleByDouble(2.5, 2.5, 1, 1);
    }
  }

  @override
  Widget build(BuildContext context) {
    final Widget image = ProofImage(
      photo: widget.photo,
      fit: BoxFit.contain,
      placeholder: Container(
            width: 280,
            height: 280,
            decoration: BoxDecoration(color: Palette.nightCard, borderRadius: BorderRadius.circular(24)),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.image_outlined, size: 64, color: Palette.faint),
                const SizedBox(height: 10),
                Text(widget.photo.label, style: const TextStyle(color: Palette.nightText, fontSize: 16)),
                const SizedBox(height: 4),
                const Text('Loading photo…', style: TextStyle(color: Palette.faint, fontSize: 13)),
              ],
            ),
          ),
    );
    return GestureDetector(
      onDoubleTapDown: _toggleZoom,
      onDoubleTap: () {},
      child: InteractiveViewer(
        transformationController: _zoom,
        maxScale: 5,
        child: Center(child: image),
      ),
    );
  }
}
