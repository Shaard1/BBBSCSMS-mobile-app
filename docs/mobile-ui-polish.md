# Flutter UI review and polish

The review covered all 16 Flutter screen files, the application shell, shared
feedback, fonts, and Android/iOS launch resources. The existing colors, screen
structure, service flows, and navigation destinations remain the basis of the UI.

## Changes

| Area | Finding and improvement |
| --- | --- |
| Startup | The intro route was bypassed and displayed only loading dots. Startup now renders both existing logos while initialization runs, keeps the Flutter presentation visible for at least two seconds, and fades into login or the existing session's home screen. Initialization failures have a retry action. |
| Native launch | Android launch resources and the iOS storyboard now include the BancaoConnect mark and barangay seal on the same pale background. Android 12 uses the system icon and branding positions. |
| Dropdowns | Registration and ID verification expanded choices inside the form, moving later fields. Shared bounded bottom sheets now show selected choices, large touch targets, scrolling, and an explicit close action. Report categories use the same picker. The short admin dropdown retains a compact menu. |
| Scrolling and navigation | Flutter retains its platform scroll physics. Forms dismiss the keyboard on drag; tabs and service forms have separate stored scroll positions. Report drafts survive tab switches, and system back returns through the dashboard's service views. Activity cards build lazily. |
| Forms | Login scrolls as a whole when the keyboard or larger text leaves less space. Registration section headings and its continuation button wrap. Service headings become compact when the keyboard is visible or space is limited. Password buttons have accessible labels. |
| Feedback and motion | Decorative tap targets use visible ink and keyboard/semantic actions. Tab changes and sheets use short transitions. Added motion respects the device's reduced-motion preference. Toasts announce messages, allow dismissal, and provide more reading time. |
| Loading and errors | Dashboard activity and announcements distinguish failed loads from empty data. Refresh failures retain previously loaded dashboard activity. Report and resident lists offer refresh/retry, including when empty. |
| Supporting screens | Profile photo controls, camera capture feedback and safe-area spacing, crop progress/retry, map search targets, and mobile admin action wrapping were improved. |
| Typography | Existing Public Sans, Plus Jakarta Sans, and Inter variants are bundled with their licenses, so these styles can load offline. |

## Visual refinement pass

- Home now uses a contained blue welcome panel, stronger section headings,
  outlined quick-action cards, and a visible selected-tab indicator. Announcement
  artwork is shown in full with its title and excerpt on a separate white surface.
- Services and Activity use smaller headings and shorter introductory copy.
  Service cards have consistent icon sizes, padding, and clear action rows.
- Activity separates the request type, title, description, and status. The entire
  document card, including “View details,” opens document details. Pending labels
  have darker text, and report details reuse the same status colors.
- Profile has a compact avatar inside a defined identity panel, one verification
  badge, and consistent bordered information and account groups.
- Certificate options, service form headers, announcement list cards, and report
  details follow the same visual treatment. Reports without a photo show a compact
  explanatory panel. Detail metadata wraps on narrow screens.
- Login uses BancaoConnect naming and softer input corners. Registration and ID
  verification have more restrained headings. Shared inputs, buttons, cards,
  dialogs, and account pages use consistent spacing and shapes.
- At enlarged text sizes, Home section actions move below the heading and the
  decorative banner logo yields space to the copy. Both launch logos remain.

`build/ui-review/mobile-overview.png` combines actual Flutter renders of the four
main tabs. The visual test data, poster artwork, and account are synthetic and
never sent to the production backend.

## Announcement details and new-report refinement

- Announcement details use a persistent back bar, an uncropped poster with an
  explicit zoom action, a photo counter and selectable thumbnails when there are
  multiple photos, and a separate reading panel. Author and date stack and wrap;
  rich-text formatting remains available. The page owns and disposes its gallery
  controller. Image loading and unavailable-image states stay within the frame.
- New reports group the issue, photos, and location into three numbered cards.
  The heading scrolls with the form, leaving a compact back bar while typing.
  Required fields show inline errors, and submission scrolls to the first
  incomplete section. Existing report requirements and submission payloads remain.
- Photo selection offers camera and gallery choices in a dismissible Flutter
  bottom sheet. Selected photos have larger removal controls and a count. The
  existing ten-photo limit is reflected in the instructions; the former
  unenforced file-size claim is removed.
- Unselected locations show an honest empty state instead of a default map pin.
  Selecting a location shows the preview and coordinates. Changing the pin
  rebuilds the map around the new coordinates. Location actions remain outside
  the map so text can wrap without hiding map content.
- `build/ui-review/announcement-report-redesign.png` shows the updated details
  and report form using local sample content. Widget checks exercise gallery
  swiping/zoom/back, cancelling photo choices, preserving report text, required
  fields, and selecting/changing a map pin at normal and 160% text sizes.

## Validation

- Dart analysis: no issues.
- Flutter tests: 18 passing, covering startup timing/retry, selection and
  cancellation, small-screen dropdown scrolling, reduced motion, keyboard
  dismissal, toast dismissal, large-text forms, tab scroll restoration,
  report-draft retention, system back navigation, populated resident flows at
  100% and 160% text sizes, and document-detail routing, plus existing model tests.
- Phone-size Flutter renders inspected under `build/ui-review/`.
- Android debug APK built with `flutter build apk --debug --no-pub`.
- Widget tests use either no session or a local fixture session with a mocked
  HTTP client; they do not submit real data. Map requests are
  blocked by Flutter's test HTTP client; their logged HTTP 400 responses do not
  indicate a live-server failure. Map caching uses an isolated test directory.

No Android device or emulator was connected during validation. Camera capture,
GPS permissions, live authenticated submissions, OS launch transitions, and the
iOS build still require device testing. UI improvements do not establish that
those integrations have been tested end to end.

## References

Launch resources follow Flutter's guidance for
[Android splash screens](https://docs.flutter.dev/platform-integration/android/splash-screen)
and [iOS launch screens](https://docs.flutter.dev/platform-integration/ios/launch-screen).
Picker behavior uses Flutter's
[modal bottom sheet API](https://api.flutter.dev/flutter/material/showModalBottomSheet.html).
