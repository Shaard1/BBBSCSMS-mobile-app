import 'dart:convert';
import 'dart:ui' as ui;

import 'package:capstone_app/screens/residents/resident_dashboard_screen.dart';
import 'package:capstone_app/screens/residents/announcement_detail_screen.dart';
import 'package:capstone_app/widgets/app_tap_surface.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app_interactions_test.dart' show testApp, captureUi, loadAppTestFonts;

// All content and credentials in this file are local test fixtures.
const _posterUrl = 'https://example.test/community-poster.png';
const _secondPosterUrl = 'https://example.test/community-poster-2.png';
const _announcementTitle = 'Free theoretical driving course';

class _TestAuthStorage extends GotrueAsyncStorage {
  final _values = <String, String>{};
  @override
  Future<String?> getItem({required String key}) async => _values[key];
  @override
  Future<void> setItem({required String key, required String value}) async {
    _values[key] = value;
  }

  @override
  Future<void> removeItem({required String key}) async {
    _values.remove(key);
  }
}

Future<void> _cacheTestPoster() async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  canvas.drawRect(const Rect.fromLTWH(0, 0, 720, 340),
      Paint()..color = const Color(0xFF124D76));
  canvas.drawCircle(
      const Offset(655, 45), 180, Paint()..color = const Color(0xFF128C98));
  canvas.drawCircle(
      const Offset(705, 310), 130, Paint()..color = const Color(0xFFF1A400));
  final text = TextPainter(
      textDirection: TextDirection.ltr,
      text: const TextSpan(
        text:
            'COMMUNITY PROGRAM\n\nFREE DRIVING COURSE\nLearn together. Drive safely.',
        style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 28,
            height: 1.3,
            color: Colors.white),
      ))
    ..layout(maxWidth: 610);
  text.paint(canvas, const Offset(36, 42));
  final picture = recorder.endRecording();
  final image = await picture.toImage(720, 340);
  picture.dispose();
  PaintingBinding.instance.imageCache.putIfAbsent(
      const NetworkImage(_posterUrl),
      () =>
          OneFrameImageStreamCompleter(Future.value(ImageInfo(image: image))));
  PaintingBinding.instance.imageCache.putIfAbsent(
      const NetworkImage(_secondPosterUrl),
      () => OneFrameImageStreamCompleter(
          Future.value(ImageInfo(image: image.clone()))));
}

void main() {
  setUpAll(() async {
    GoogleFonts.config.allowRuntimeFetching = false;
    await loadAppTestFonts();
    await Supabase.initialize(
      url: 'https://example.test',
      publishableKey: 'local-widget-test',
      authOptions: FlutterAuthClientOptions(
        persistSession: false,
        autoRefreshToken: false,
        localStorage: const EmptyLocalStorage(),
        pkceAsyncStorage: _TestAuthStorage(),
      ),
      httpClient: MockClient((request) async {
        Object data = <Object>[];
        switch (request.url.path.split('/').last) {
          case 'residents':
            data = [
              {
                'id': 'resident-fixture',
                'full_name': 'Alex Santos',
                'address':
                    'Purok 4, Barangay Bancao-Bancao, Puerto Princesa City, Palawan',
                'contact_number': '+639171234567',
                'profile_image': ''
              }
            ];
          case 'announcements':
            data = [
              for (var i = 0; i < 2; i++)
                {
                  'id': 'announcement-$i',
                  'title': _announcementTitle,
                  'content': 'Registration is now open at the barangay hall.\n\n'
                      'Please bring a valid ID and visit the barangay office for the updated schedule. '
                      'Our team will assist you with the requirements.\n\n'
                      'Thank you for your patience and continued support for our community programs.',
                  'thumbnail_url': _posterUrl,
                  'image_urls': [_posterUrl, _secondPosterUrl],
                  'created_by_name':
                      'Barangay Bancao-Bancao Information Office',
                  'created_at': '2026-09-20T08:00:00Z',
                }
            ];
          case 'reports':
            data = [
              {
                'id': 'report-1',
                'category': 'Noise Complaint',
                'status': 'resolved',
                'description': 'A community concern near the covered court.',
                'created_at': '2026-09-23T08:00:00Z'
              },
              {
                'id': 'report-2',
                'category': 'Road Damage',
                'status': 'pending',
                'description': 'Road surface needs attention near the corner.',
                'created_at': '2026-09-21T08:00:00Z'
              },
            ];
          case 'document_requests':
            data = [
              {
                'id': 'document-1',
                'workflow_version': 2,
                'requester_capacity': 'self',
                'office_payment_status': 'pending',
                'form_data': {
                  'purpose': 'Employment',
                  'civil_status': 'Single',
                  'date_of_birth': '2000-01-01'
                },
                'certificate_title': 'Barangay Clearance',
                'status': 'pending',
                'created_at': '2026-09-20T08:00:00Z',
                'full_name': 'Alex Santos',
                'purpose': 'Employment'
              }
            ];
        }
        return http.Response(jsonEncode(data), 200,
            request: request, headers: {'content-type': 'application/json'});
      }),
    );
    final payload = base64Url
        .encode(utf8.encode(jsonEncode({
          'exp': DateTime.now()
                  .add(const Duration(hours: 1))
                  .millisecondsSinceEpoch ~/
              1000,
          'sub': 'resident-fixture',
        })))
        .replaceAll('=', '');
    await Supabase.instance.client.auth.recoverSession(jsonEncode({
      'access_token': 'eyJhbGciOiJIUzI1NiJ9.$payload.test',
      'token_type': 'bearer',
      'user': {
        'id': 'resident-fixture',
        'aud': 'authenticated',
        'email': 'alex@example.test',
        'created_at': '2026-01-01T00:00:00Z',
        'app_metadata': <String, Object>{},
        'user_metadata': <String, Object>{}
      },
    }));
    expect(await Supabase.instance.client.from('announcements').select(),
        hasLength(2));
  });

  tearDownAll(() => Supabase.instance.dispose());

  for (final scale in [1.0, 1.6]) {
    testWidgets('populated resident flows remain readable at text scale $scale',
        (tester) async {
      tester.view.physicalSize = Size(scale == 1 ? 390 : 320, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.runAsync(_cacheTestPoster);
      await tester.pumpWidget(testApp(
          const ResidentDashboardScreen(name: 'Alex Santos'),
          textScale: scale));
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 50));
      });
      await tester.pumpAndSettle();
      expect(find.text(_announcementTitle).first, findsOneWidget);
      expect(tester.takeException(), isNull);
      await captureUi(tester, 'home-populated-$scale');

      final announcementCard = find.ancestor(
          of: find.text(_announcementTitle).first,
          matching: find.byType(AppTapSurface));
      await tester.ensureVisible(announcementCard);
      await tester.tap(find.descendant(
          of: announcementCard, matching: find.byType(InkWell)));
      await tester.pumpAndSettle();
      expect(find.byType(AnnouncementDetailScreen), findsOneWidget);
      expect(find.text('Photo 1 of 2'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await captureUi(tester, 'announcement-detail-$scale');
      await tester.drag(find.byType(PageView), const Offset(-300, 0));
      await tester.pumpAndSettle();
      expect(find.text('Photo 2 of 2'), findsOneWidget);
      await tester.tap(find.text('Zoom'));
      await tester.pumpAndSettle();
      expect(find.byType(InteractiveViewer), findsWidgets);
      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();
      await tester.drag(
          find.byKey(const PageStorageKey('announcement-details')),
          const Offset(0, -440));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await captureUi(tester, 'announcement-reading-$scale');
      await tester.pageBack();
      await tester.pumpAndSettle();

      await tester.tap(find.text('Services').last);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await captureUi(tester, 'services-populated-$scale');
      await tester.ensureVisible(find.text('Request Certificate'));
      await tester.tap(find.text('Request Certificate'));
      await tester.pumpAndSettle();
      await captureUi(tester, 'certificates-$scale');
      await tester.tap(find.text('Certificate of Indigency').first);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await captureUi(tester, 'certificate-form-$scale');

      await tester.tap(find.text('Activity').last);
      await tester.pumpAndSettle();
      expect(find.text('Noise Complaint'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await captureUi(tester, 'activity-populated-$scale');
      await tester.tap(find.text('Noise Complaint'));
      await tester.pumpAndSettle();
      expect(find.text('Report Details'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await captureUi(tester, 'report-details-$scale');
      await tester.tap(find.byIcon(Icons.arrow_back).first);
      await tester.pumpAndSettle();

      // The whole document card must route to document details, including its CTA.
      await tester.scrollUntilVisible(find.text('Barangay Clearance'), 250,
          scrollable: find
              .descendant(
                  of: find.byKey(const PageStorageKey('activity')),
                  matching: find.byType(Scrollable))
              .first);
      final card = find
          .ancestor(
              of: find.text('Barangay Clearance'),
              matching: find.byType(InkWell))
          .first;
      final details =
          find.descendant(of: card, matching: find.text('View details'));
      await tester.ensureVisible(details);
      await tester.pumpAndSettle();
      await tester.tap(details);
      await tester.pumpAndSettle();
      expect(find.text('Report Details'), findsNothing);
      expect(find.text('Document Request Details'), findsOneWidget);
      expect(find.text('Employment'), findsNothing);
      await captureUi(tester, 'document-owner-details-$scale');
      await tester.scrollUntilVisible(find.text('Application details'), 200,
          scrollable: find.byType(Scrollable).last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Application details'));
      await tester.pumpAndSettle();
      expect(find.text('Employment'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(find.byIcon(Icons.arrow_back).first);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Profile').last);
      await tester.pumpAndSettle();
      expect(find.text('alex@example.test'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await captureUi(tester, 'profile-populated-$scale');
      await tester.scrollUntilVisible(find.text('Edit Profile'), 200);
      await tester.tap(find.text('Edit Profile'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await captureUi(tester, 'edit-profile-$scale');
      await tester.pumpWidget(const SizedBox());
    });
  }
}
