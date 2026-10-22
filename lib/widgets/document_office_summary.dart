import 'package:flutter/material.dart';
import '../core/app_interactions.dart';

/// Uses only the request owner's existing fields; office audit history stays private.
class DocumentOfficeSummary extends StatelessWidget {
  const DocumentOfficeSummary({super.key, required this.request});
  final Map<String, dynamic> request;
  String get status => request['status']?.toString() ?? 'pending';
  String get nextStep => switch (status) {
        'rejected' =>
          'This request was rejected. Review the reason below and contact the barangay office if you need clarification.',
        'completed' =>
          'This request is completed. The recorded collection details are shown below.',
        'ready_for_release' =>
          'Your document is ready for release. Check with the barangay office for collection instructions and bring any required originals.',
        'processing' =>
          'Staff are processing your request. Check Activity for updates or further requirements.',
        _ =>
          'Your request is awaiting staff review. Check Activity for updates.',
      };
  String value(String key) => request[key]?.toString().trim() ?? '';
  Widget row(String label, String text) => Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 4),
        Text(text)
      ]));
  @override
  Widget build(BuildContext context) {
    final payment = value('office_payment_status');
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
              color: status == 'rejected'
                  ? const Color(0xFFFFF1F2)
                  : const Color(0xFFEFF6FF),
              borderRadius: BorderRadius.circular(14)),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('What happens next',
                style: TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Text(nextStep),
            if (status == 'rejected') ...[
              const SizedBox(height: 12),
              row(
                  'Reason for rejection',
                  value('rejection_reason').isEmpty
                      ? 'No reason recorded.'
                      : value('rejection_reason'))
            ],
          ])),
      if (request['workflow_version'] == 2) ...[
        const SizedBox(height: 16),
        ExpansionTile(
            expansionAnimationStyle: appMotionStyle(context),
            tilePadding: EdgeInsets.zero,
            childrenPadding: const EdgeInsets.symmetric(vertical: 8),
            title: const Text('Requirements and checks'),
            children: [
              row(
                  'Identity',
                  request['identity_checked'] == true
                      ? 'Checked'
                      : 'Awaiting staff check'),
              row(
                  'Residency',
                  request['residency_checked'] == true
                      ? 'Checked'
                      : 'Awaiting staff check'),
              if (value('requester_capacity') == 'representative')
                row(
                    'Representative permission',
                    request['authorization_checked'] == true
                        ? 'Checked'
                        : 'Awaiting staff check'),
              if (!['rejected', 'completed'].contains(status))
                const Text(
                    'An upload does not automatically verify identity. Staff may ask to inspect originals.'),
            ]),
        ExpansionTile(
            expansionAnimationStyle: appMotionStyle(context),
            tilePadding: EdgeInsets.zero,
            childrenPadding: const EdgeInsets.symmetric(vertical: 8),
            title: const Text('Office payment and collection'),
            children: [
              row(
                  'Payment decision',
                  payment == 'paid'
                      ? 'Paid at the barangay office'
                      : payment == 'no_fee'
                          ? 'No fee required'
                          : 'Not yet settled at the office'),
              if (payment == 'paid') ...[
                row(
                    'Amount recorded',
                    request['fee_amount'] is num
                        ? 'PHP ${(request['fee_amount'] as num).toStringAsFixed(2)}'
                        : 'Not recorded'),
                row(
                    'Receipt reference',
                    value('office_receipt_reference').isEmpty
                        ? 'Not recorded'
                        : value('office_receipt_reference')),
              ],
              if (payment == 'no_fee' &&
                  value('office_no_fee_reason').isNotEmpty)
                row('No-fee reason', value('office_no_fee_reason')),
              row(
                  'Physical collection',
                  request['pickup_confirmed'] == true
                      ? 'Collection confirmed'
                      : 'Not confirmed'),
              if (request['pickup_confirmed'] == true)
                row(
                    'Collected by',
                    value('collected_by').isEmpty
                        ? 'Not recorded'
                        : value('collected_by')),
            ]),
      ],
      ExpansionTile(
          expansionAnimationStyle: appMotionStyle(context),
          tilePadding: EdgeInsets.zero,
          childrenPadding: const EdgeInsets.symmetric(vertical: 8),
          title: const Text('Recorded updates'),
          children: [
            row('Submitted', _date(value('created_at'))),
            if (value('updated_at').isNotEmpty)
              row('Latest update', _date(value('updated_at'))),
            const Text(
                'This shows the latest recorded update, not the full staff review history.'),
          ]),
    ]);
  }

  String _date(String raw) {
    final date = DateTime.tryParse(raw)?.toLocal();
    return date == null
        ? 'Not recorded'
        : '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')} ${TimeOfDay.fromDateTime(date).hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }
}
