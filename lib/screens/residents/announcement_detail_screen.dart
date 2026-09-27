import 'package:flutter/material.dart';

import '../../core/app_interactions.dart';
import '../../models/announcement_model.dart';
import '../../widgets/app_tap_surface.dart';

/// A reading view with its own gallery state and an always available back action.
class AnnouncementDetailScreen extends StatefulWidget {
  const AnnouncementDetailScreen({
    super.key,
    required this.announcement,
    required this.author,
    required this.date,
    required this.category,
    required this.content,
    required this.onOpenImage,
  });

  final Announcement announcement;
  final String author;
  final String date;
  final String category;
  final Widget content;
  final void Function(List<String> images, int index) onOpenImage;

  @override
  State<AnnouncementDetailScreen> createState() => _AnnouncementDetailScreenState();
}

class _AnnouncementDetailScreenState extends State<AnnouncementDetailScreen> {
  static const _blue = Color(0xFF0B4F94);
  final _pages = PageController();
  int _selectedImage = 0;

  late final _images = <String>{
    if (widget.announcement.thumbnailUrl.trim().isNotEmpty)
      widget.announcement.thumbnailUrl.trim(),
    ...widget.announcement.imageUrls.map((url) => url.trim()).where((url) => url.isNotEmpty),
  }.toList();

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  Widget _image(String url, {BoxFit fit = BoxFit.contain}) => Image.network(
    url, fit: fit,
    loadingBuilder: (context, image, progress) => progress == null ? image : const Center(
      child: SizedBox.square(dimension: 24, child: CircularProgressIndicator(strokeWidth: 2))),
    errorBuilder: (_, __, ___) => const Center(child: Padding(
      padding: EdgeInsets.all(16), child: Icon(Icons.broken_image_outlined, color: Color(0xFF64748B), size: 32))),
  );

  Widget _metadata(IconData icon, String text) => Row(
    mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Padding(padding: const EdgeInsets.only(top: 2), child: Icon(icon, size: 16, color: const Color(0xFF64748B))),
      const SizedBox(width: 7),
      Flexible(child: Text(text, style: const TextStyle(color: Color(0xFF64748B), fontSize: 12, height: 1.5))),
    ],
  );

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFFF8FAFC),
    appBar: AppBar(
      title: const Text('Announcement'),
      leading: BackButton(onPressed: () => Navigator.pop(context)),
      centerTitle: false,
    ),
    body: SafeArea(top: false, child: SingleChildScrollView(
      key: const PageStorageKey('announcement-details'),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
      child: Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 680),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          if (_images.isNotEmpty) ...[
            Material(color: Colors.white, clipBehavior: Clip.antiAlias,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20),
                side: const BorderSide(color: Color(0xFFE1E9F2))),
              child: Column(children: [
                AspectRatio(aspectRatio: 16 / 10, child: PageView.builder(
                  controller: _pages, itemCount: _images.length,
                  onPageChanged: (index) => setState(() => _selectedImage = index),
                  itemBuilder: (_, index) => AppTapSurface(
                    label: 'Open announcement image ${index + 1} full screen',
                    onTap: () => widget.onOpenImage(_images, index),
                    child: SizedBox.expand(child: _image(_images[index])),
                  ),
                )),
                const Divider(height: 1),
                Padding(padding: const EdgeInsets.only(left: 14, right: 6), child: Row(children: [
                  Expanded(child: Text(_images.length == 1 ? 'Announcement photo' : 'Photo ${_selectedImage + 1} of ${_images.length}',
                    style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)))),
                  TextButton.icon(onPressed: () => widget.onOpenImage(_images, _selectedImage),
                    icon: const Icon(Icons.open_in_full_rounded, size: 16),
                    label: const Text('Zoom', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600))),
                ])),
              ])),
            if (_images.length > 1) ...[
              const SizedBox(height: 10),
              SizedBox(height: 62, child: ListView.separated(
                scrollDirection: Axis.horizontal, itemCount: _images.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (_, index) => AppTapSurface(
                  label: 'Show photo ${index + 1}', selected: _selectedImage == index,
                  onTap: () {
                    if (MediaQuery.disableAnimationsOf(context)) {
                      _pages.jumpToPage(index);
                    } else {
                      _pages.animateToPage(index, duration: appMotionDuration(context), curve: Curves.easeOut);
                    }
                  },
                  child: Container(width: 76, padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: _selectedImage == index ? _blue : const Color(0xFFE1E9F2), width: 2)),
                    child: ClipRRect(borderRadius: BorderRadius.circular(8), child: _image(_images[index], fit: BoxFit.cover))),
                ),
              )),
            ],
            const SizedBox(height: 16),
          ],
          Container(padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(22),
              border: Border.all(color: const Color(0xFFE1E9F2))),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(color: const Color(0xFFEAF3FF), borderRadius: BorderRadius.circular(8)),
                child: Text(widget.category, style: const TextStyle(color: _blue, fontSize: 11, fontWeight: FontWeight.w600))),
              const SizedBox(height: 14),
              Semantics(header: true, child: Text(
                widget.announcement.title.trim().isEmpty ? 'Barangay update' : widget.announcement.title.trim(),
                style: const TextStyle(color: Color(0xFF172B46), fontSize: 23,
                  fontWeight: FontWeight.w700, height: 1.3, letterSpacing: -0.4))),
              const SizedBox(height: 16),
              _metadata(Icons.person_outline_rounded, widget.author),
              const SizedBox(height: 7),
              _metadata(Icons.calendar_today_outlined, widget.date),
              const Padding(padding: EdgeInsets.symmetric(vertical: 20), child: Divider(height: 1)),
              widget.content,
            ])),
        ]),
      )),
    )),
  );
}
