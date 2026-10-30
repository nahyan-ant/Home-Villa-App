import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../app_state.dart';
import '../format.dart';
import '../models.dart';
import '../screens/photo_viewer.dart';
import '../theme.dart';

/// Small capitals heading above a section, such as DAYS.
const sectionLabel = TextStyle(
  color: Palette.muted,
  fontSize: 12,
  fontWeight: FontWeight.w700,
  letterSpacing: 1,
);

const bodyMuted = TextStyle(color: Palette.muted, fontSize: 13);
const bodyMutedTall = TextStyle(color: Palette.muted, fontSize: 13, height: 1.35);

bool reduceMotion(BuildContext context) => MediaQuery.maybeDisableAnimationsOf(context) ?? false;

/// Slides each item of a list in, one shortly after another.
class Stagger extends StatefulWidget {
  const Stagger({super.key, required this.index, required this.child});

  final int index;
  final Widget child;

  @override
  State<Stagger> createState() => _StaggerState();
}

class _StaggerState extends State<Stagger> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    final delay = math.min(widget.index, 10) * 45;
    final total = delay + 380;
    _controller = AnimationController(vsync: this, duration: Duration(milliseconds: total));
    _animation = CurvedAnimation(
      parent: _controller,
      curve: Interval(delay / total, 1, curve: Curves.easeOutCubic),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_controller.status == AnimationStatus.dismissed) {
      if (reduceMotion(context)) {
        _controller.value = 1;
      } else {
        _controller.forward();
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FadeTransition(
    opacity: _animation,
    child: SlideTransition(
      position: Tween(begin: const Offset(0, 0.12), end: Offset.zero).animate(_animation),
      child: widget.child,
    ),
  );
}

/// Cross-fades when [swapKey] changes, such as a new tab or day.
class Swap extends StatelessWidget {
  const Swap({super.key, required this.swapKey, required this.child});

  final String swapKey;
  final Widget child;

  @override
  Widget build(BuildContext context) => AnimatedSwitcher(
    duration: reduceMotion(context) ? Duration.zero : const Duration(milliseconds: 320),
    switchInCurve: Curves.easeOutCubic,
    switchOutCurve: const Cubic(0.55, 0.055, 0.675, 0.19),
    transitionBuilder: (child, animation) => FadeTransition(
      opacity: animation,
      child: ScaleTransition(scale: Tween(begin: 0.985, end: 1.0).animate(animation), child: child),
    ),
    child: KeyedSubtree(key: ValueKey(swapKey), child: child),
  );
}

/// The day's progress as a ring around a percentage.
class ProgressRing extends StatelessWidget {
  const ProgressRing({super.key, required this.value, required this.size, required this.child});

  final double value;
  final double size;
  final Widget child;

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
    tween: Tween(end: value.clamp(0, 1)),
    duration: reduceMotion(context) ? Duration.zero : const Duration(milliseconds: 900),
    curve: Curves.easeOutCubic,
    child: child,
    builder: (context, v, child) => SizedBox.square(
      dimension: size,
      child: CustomPaint(
        painter: _RingPainter(v, 8, Palette.ink),
        child: Center(child: child),
      ),
    ),
  );
}

class _RingPainter extends CustomPainter {
  _RingPainter(this.value, this.stroke, this.color);

  final double value;
  final double stroke;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = (Offset.zero & size).deflate(stroke / 2);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..color = Palette.butter;
    canvas.drawArc(rect, 0, math.pi * 2, false, paint);
    if (value <= 0) return;
    paint
      ..color = color
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(rect, -math.pi / 2, math.pi * 2 * value, false, paint);
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.value != value || old.color != color || old.stroke != stroke;
}

/// A rounded progress bar that fills in.
class ProgressBar extends StatelessWidget {
  const ProgressBar({super.key, required this.value, required this.color});

  final double value;
  final Color color;

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
    tween: Tween(end: value.clamp(0, 1)),
    duration: reduceMotion(context) ? Duration.zero : const Duration(milliseconds: 800),
    curve: Curves.easeOutCubic,
    builder: (context, v, _) => ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: LinearProgressIndicator(value: v, color: color),
    ),
  );
}

/// A message box: butter for news, red for something to act on.
class InfoBanner extends StatelessWidget {
  const InfoBanner({super.key, required this.icon, required this.text, this.alert = false});

  final IconData icon;
  final String text;
  final bool alert;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: alert ? Palette.alertLight : Palette.butter,
      border: Border.all(color: alert ? Palette.alert : Palette.butter),
      borderRadius: BorderRadius.circular(14),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: alert ? Palette.alert : Palette.ink, size: 20),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              color: alert ? Palette.alert : Palette.text,
              fontSize: 14,
              fontWeight: FontWeight.w500,
              height: 1.35,
            ),
          ),
        ),
      ],
    ),
  );
}

/// Shown under anything saved offline.
class PendingNote extends StatelessWidget {
  const PendingNote({super.key});

  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.only(top: 3),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.cloud_upload_outlined, size: 15, color: Palette.amber),
        SizedBox(width: 5),
        Flexible(
          child: Text(
            'Saved on this phone, not sent yet',
            style: TextStyle(color: Palette.amber, fontSize: 12.5, fontWeight: FontWeight.w700),
          ),
        ),
      ],
    ),
  );
}

class PrivacyNote extends StatelessWidget {
  const PrivacyNote(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      const Icon(Icons.lock_outline, size: 16, color: Palette.muted),
      const SizedBox(width: 6),
      Expanded(child: Text(text, style: bodyMuted)),
    ],
  );
}

/// A maid's note on a task.
class NoteView extends StatelessWidget {
  const NoteView(this.note, {super.key});

  final TaskNote note;

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(color: Palette.track, borderRadius: BorderRadius.circular(14)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 1),
            child: Icon(Icons.sticky_note_2_outlined, size: 16, color: Palette.muted),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(note.text, style: const TextStyle(color: Palette.text, fontSize: 13.5, height: 1.35)),
                const SizedBox(height: 2),
                Text(
                  '${state.person(note.byId).name}, ${clockOf(note.time)}',
                  style: const TextStyle(color: Palette.muted, fontSize: 12),
                ),
                if (!note.sent) const PendingNote(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A small chip such as "Photo of common areas only".
class HintChip extends StatelessWidget {
  const HintChip({super.key, required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(color: Palette.butter, borderRadius: BorderRadius.circular(20)),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: Palette.ink, size: 15),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            text,
            style: const TextStyle(color: Palette.ink, fontSize: 12.5, fontWeight: FontWeight.w700),
          ),
        ),
      ],
    ),
  );
}

/// A round initial in the person's colour.
class Avatar extends StatelessWidget {
  const Avatar({super.key, required this.id, required this.name, required this.size, required this.style});

  final String id;
  final String name;
  final double size;
  final TextStyle style;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    alignment: Alignment.center,
    decoration: BoxDecoration(color: personColor(id), shape: BoxShape.circle),
    child: Text(name.isEmpty ? '?' : name[0], style: style),
  );
}

/// A photo thumbnail, or a placeholder for the demo's sample photos.
class PhotoThumb extends StatelessWidget {
  const PhotoThumb({super.key, required this.photo, required this.size, this.onRemove, required this.onOpen});

  final Photo photo;
  final double size;
  final VoidCallback? onRemove;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final placeholder = Container(
      color: Palette.track,
      padding: const EdgeInsets.all(4),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.image_outlined, color: Palette.faint, size: size * 0.32),
          if (size >= 56)
            Text(
              photo.label,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Palette.muted, fontSize: 9.5, height: 1.15),
            ),
        ],
      ),
    );
    final image = ProofImage(photo: photo, fit: BoxFit.cover, placeholder: placeholder);
    final thumb = Semantics(
      button: true,
      label: 'Open photo: ${photo.label}',
      child: GestureDetector(
        onTap: onOpen,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: SizedBox(width: size, height: size, child: image),
        ),
      ),
    );
    if (onRemove == null) return thumb;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        thumb,
        Positioned(
          top: -6,
          right: -6,
          child: Material(
            color: Palette.ink,
            shape: const CircleBorder(),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: onRemove,
              child: const Padding(
                padding: EdgeInsets.all(3),
                child: Icon(Icons.close, size: 14, color: Palette.white),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// A proof photo from this phone if not sent yet, else from storage.
class ProofImage extends StatelessWidget {
  const ProofImage({super.key, required this.photo, required this.fit, required this.placeholder});

  final Photo photo;
  final BoxFit fit;
  final Widget placeholder;

  @override
  Widget build(BuildContext context) {
    final bytes = photo.bytes;
    if (bytes != null) return Image.memory(bytes, fit: fit);
    return FutureBuilder<String?>(
      future: AppScope.of(context).photoUrl(photo.path),
      builder: (context, snap) {
        final url = snap.data;
        if (url == null) return placeholder;
        return Image.network(url, fit: fit, errorBuilder: (_, _, _) => placeholder);
      },
    );
  }
}

/// Opens [photos] full screen at [index].
Future<void> openPhotos(BuildContext context, List<Photo> photos, int index) =>
    Navigator.of(context).push(
      PageRouteBuilder<void>(
        opaque: false,
        barrierColor: Colors.black,
        transitionDuration: const Duration(milliseconds: 250),
        reverseTransitionDuration: const Duration(milliseconds: 250),
        pageBuilder: (context, _, _) => PhotoViewer(photos: photos, initialIndex: index),
        transitionsBuilder: (context, animation, _, child) =>
            FadeTransition(opacity: animation, child: child),
      ),
    );

/// The app's logo: two marigold ticks beside two lines.
class Logo extends StatelessWidget {
  const Logo({super.key, this.size = 56});

  final double size;

  @override
  Widget build(BuildContext context) =>
      CustomPaint(size: Size.square(size), painter: _LogoPainter());
}

class _LogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 96);
    canvas.drawRRect(
      RRect.fromRectAndRadius(const Rect.fromLTWH(0, 0, 96, 96), const Radius.circular(24)),
      Paint()..color = Palette.ink,
    );
    final pen = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 7
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    for (final y in [35.0, 61.0]) {
      final tick = Path()
        ..moveTo(22, y)
        ..relativeLineTo(7.5, 7.5)
        ..relativeLineTo(14, -14);
      canvas.drawPath(tick, pen..color = Palette.marigold);
      canvas.drawLine(Offset(53, y + 0.5), Offset(75, y + 0.5), pen..color = Palette.white);
    }
  }

  @override
  bool shouldRepaint(_LogoPainter old) => false;
}

/// "Mon / Wed / Fri", as used for extra details.
String slashDays(Set<int> days) => daysLabel(days).replaceAll(', ', ' / ');
