import 'package:flutter/material.dart';
import '../core/app_interactions.dart';

String formatDocumentDate(String? raw, {bool includeTime = true}) {
  final date = DateTime.tryParse(raw ?? '')?.toLocal();
  if (date == null) return 'Not recorded';
  const months = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December'
  ];
  final hour = date.hour % 12 == 0 ? 12 : date.hour % 12;
  final dateLabel = '${months[date.month - 1]} ${date.day}, ${date.year}';
  if (!includeTime) return dateLabel;
  return '$dateLabel · $hour:${date.minute.toString().padLeft(2, '0')} ${date.hour < 12 ? 'AM' : 'PM'}';
}

/// Consistent, full-width disclosure headings with readable previews and text scaling.
class DocumentDetailSection extends StatelessWidget {
  const DocumentDetailSection(
      {super.key,
      required this.title,
      required this.summary,
      required this.children});
  final String title;
  final String summary;
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => DefaultTextStyle.merge(
        style: const TextStyle(
            fontSize: 16, height: 1.45, color: Color(0xFF253449)),
        child: ExpansionTile(
          expansionAnimationStyle: appMotionStyle(context),
          expandedCrossAxisAlignment: CrossAxisAlignment.stretch,
          expandedAlignment: Alignment.centerLeft,
          tilePadding: const EdgeInsets.symmetric(vertical: 8),
          childrenPadding: const EdgeInsets.only(bottom: 12, top: 4),
          shape: const Border(bottom: BorderSide(color: Color(0xFFE7EEF5))),
          collapsedShape:
              const Border(bottom: BorderSide(color: Color(0xFFE7EEF5))),
          title: Text(title,
              style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF253449))),
          subtitle: Text(summary,
              style: const TextStyle(
                  fontSize: 15, height: 1.4, color: Color(0xFF526274))),
          children: children,
        ),
      );
}

Widget _field(String label, String text) => Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 4),
        Text(text),
      ]),
    );

class DocumentLastUpdated extends StatelessWidget {
  const DocumentLastUpdated({super.key, required this.request});
  final Map<String, dynamic> request;

  @override
  Widget build(BuildContext context) {
    final submitted =
        DateTime.tryParse(request['created_at']?.toString() ?? '');
    final updated = DateTime.tryParse(request['updated_at']?.toString() ?? '');
    if (submitted == null || updated == null || !updated.isAfter(submitted)) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Text(
        'Last updated ${formatDocumentDate(request['updated_at']?.toString())}',
        style: const TextStyle(
            fontSize: 15, height: 1.4, color: Color(0xFF526274)),
      ),
    );
  }
}

/// Displays existing owner-readable fields; never exposes office audit records.
class DocumentOfficeSummary extends StatelessWidget {
  const DocumentOfficeSummary({super.key, required this.request});
  final Map<String, dynamic> request;
  String value(String key) => request[key]?.toString().trim() ?? '';
  bool get closed => ['rejected', 'completed'].contains(value('status'));
  List<String> get checks => [
        'identity',
        'residency',
        if (value('requester_capacity') == 'representative') 'authorization'
      ];
  bool get originalsNeeded =>
      !closed &&
      request['workflow_version'] == 2 &&
      checks.any((kind) =>
          value('${kind}_evidence_method') == 'in_person' &&
          request['${kind}_checked'] != true);
  String get nextStep => switch (value('status')) {
        'rejected' =>
          'Your request was rejected. Contact the barangay office if you need help understanding the reason.',
        'completed' =>
          'Your request is marked completed. You can view the recorded collection details below.',
        'ready_for_release' =>
          'Your document is ready. Contact the barangay office for collection instructions.',
        'processing' =>
          'Barangay staff are processing your request. Check Activity for updates.',
        _ => 'Your request is waiting for barangay review.',
      };
  Widget _check(String kind, String label) {
    final checked = request['${kind}_checked'] == true;
    return Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(checked ? Icons.check_circle_outline : Icons.schedule,
              size: 22,
              color:
                  checked ? const Color(0xFF237547) : const Color(0xFF526274)),
          const SizedBox(width: 12),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(label,
                    style: const TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Text(checked
                    ? 'Checked by staff'
                    : closed
                        ? 'Not completed'
                        : 'Waiting for staff review'),
              ])),
        ]));
  }

  @override
  Widget build(BuildContext context) {
    final count =
        checks.where((kind) => request['${kind}_checked'] == true).length;
    final checksSummary = count == checks.length
        ? 'All required checks completed'
        : count > 0 || closed
            ? '$count of ${checks.length} checks completed'
            : checks.length == 3
                ? 'ID, address and permission review pending'
                : 'ID and address review pending';
    final payment = value('office_payment_status');
    final collected = request['pickup_confirmed'] == true;
    return DefaultTextStyle.merge(
        style: const TextStyle(
            fontSize: 16, height: 1.45, color: Color(0xFF253449)),
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                  color: value('status') == 'rejected'
                      ? const Color(0xFFFFF1F2)
                      : const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(14)),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Semantics(
                        header: true,
                        child: const Text('What you need to know',
                            style: TextStyle(
                                fontWeight: FontWeight.w700, fontSize: 17))),
                    const SizedBox(height: 8),
                    Text(nextStep),
                    if (originalsNeeded) ...[
                      const SizedBox(height: 12),
                      const Text(
                          'Bring original documents for checking. Contact the barangay office to confirm when to visit.')
                    ],
                    if (value('status') == 'rejected') ...[
                      const SizedBox(height: 12),
                      _field(
                          'Reason for rejection',
                          value('rejection_reason').isEmpty
                              ? 'No reason recorded.'
                              : value('rejection_reason'))
                    ],
                  ])),
          if (request['workflow_version'] == 2) ...[
            const SizedBox(height: 12),
            DocumentDetailSection(
                title: 'Document checks',
                summary: checksSummary,
                children: [
                  _check('identity', 'ID check'),
                  _check('residency', 'Address check'),
                  if (checks.length == 3)
                    _check('authorization',
                        'Permission to apply for someone else'),
                ]),
            DocumentDetailSection(
                title: 'Collection details',
                summary: collected
                    ? 'Collection confirmed'
                    : closed
                        ? 'Request closed'
                        : value('status') == 'ready_for_release'
                            ? 'Ready for office collection'
                            : 'Collection not yet confirmed',
                children: [
                  _field(
                      'Payment decision',
                      payment == 'paid'
                          ? 'Paid at the barangay office'
                          : payment == 'no_fee'
                              ? 'No fee required'
                              : 'Fee information is not yet recorded.'),
                  if (payment == 'paid') ...[
                    _field(
                        'Amount recorded',
                        request['fee_amount'] is num
                            ? 'PHP ${(request['fee_amount'] as num).toStringAsFixed(2)}'
                            : 'Not recorded'),
                    _field(
                        'Receipt reference',
                        value('office_receipt_reference').isEmpty
                            ? 'Not recorded'
                            : value('office_receipt_reference')),
                  ],
                  if (payment == 'no_fee' &&
                      value('office_no_fee_reason').isNotEmpty)
                    _field('No-fee reason', value('office_no_fee_reason')),
                  _field('Physical collection',
                      collected ? 'Collection confirmed' : 'Not confirmed'),
                  if (collected)
                    _field(
                        'Collected by',
                        value('collected_by').isEmpty
                            ? 'Not recorded'
                            : value('collected_by')),
                ]),
          ],
        ]));
  }
}
