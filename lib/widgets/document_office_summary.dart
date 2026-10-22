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
  Widget _checkCard(String kind, String title, IconData icon) {
    final checked = request['${kind}_checked'] == true;
    final closed = ['rejected', 'completed'].contains(status);
    final method = value('${kind}_evidence_method');
    final explanation = checked
        ? 'Staff have completed this check.'
        : closed
            ? 'This check was not completed before the request closed.'
            : method == 'in_person'
                ? 'You chose to show original documents at the barangay office.'
                : method == 'upload'
                    ? 'Your photo was submitted. Staff still need to review it.'
                    : 'Staff still need to review the supporting documents.';
    return Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
            border: Border.all(color: const Color(0xFFE1E8F0)),
            borderRadius: BorderRadius.circular(12)),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icon, color: const Color(0xFF0B4F94), size: 22),
          const SizedBox(width: 12),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(title,
                    style: const TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                Row(children: [
                  Icon(checked ? Icons.check_circle_outline : Icons.schedule,
                      size: 16,
                      color: checked
                          ? const Color(0xFF237547)
                          : const Color(0xFF64748B)),
                  const SizedBox(width: 6),
                  Expanded(
                      child: Text(
                          checked
                              ? 'Checked by staff'
                              : closed
                                  ? 'Not completed'
                                  : 'Waiting for staff review',
                          style: TextStyle(
                              color: checked
                                  ? const Color(0xFF237547)
                                  : const Color(0xFF526274))))
                ]),
                const SizedBox(height: 8),
                Text(explanation,
                    style:
                        const TextStyle(color: Color(0xFF526274), height: 1.4)),
              ])),
        ]));
  }

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
            expandedCrossAxisAlignment: CrossAxisAlignment.stretch,
            expandedAlignment: Alignment.centerLeft,
            shape: const Border(bottom: BorderSide(color: Color(0xFFE7EEF5))),
            collapsedShape:
                const Border(bottom: BorderSide(color: Color(0xFFE7EEF5))),
            tilePadding: EdgeInsets.zero,
            childrenPadding: const EdgeInsets.symmetric(vertical: 8),
            title: const Text('Staff document review'),
            subtitle: const Text('ID, address and permission checks'),
            children: [
              const Padding(
                  padding: EdgeInsets.only(bottom: 14),
                  child: Text(
                      'Barangay staff complete these checks for this document request.')),
              _checkCard('identity', 'ID check', Icons.badge_outlined),
              _checkCard('residency', 'Address check', Icons.home_outlined),
              if (value('requester_capacity') == 'representative')
                _checkCard(
                    'authorization',
                    'Permission to apply for someone else',
                    Icons.assignment_ind_outlined),
              if (!['rejected', 'completed'].contains(status) &&
                  [
                    'identity',
                    'residency',
                    if (value('requester_capacity') == 'representative')
                      'authorization'
                  ].any((kind) =>
                      value('${kind}_evidence_method') == 'in_person' &&
                      request['${kind}_checked'] != true))
                const Padding(
                    padding: EdgeInsets.only(bottom: 12),
                    child: Text(
                        'You chose to present originals in person. Contact the barangay office about when to bring them for checking.')),
            ]),
        ExpansionTile(
            expansionAnimationStyle: appMotionStyle(context),
            expandedCrossAxisAlignment: CrossAxisAlignment.stretch,
            expandedAlignment: Alignment.centerLeft,
            shape: const Border(bottom: BorderSide(color: Color(0xFFE7EEF5))),
            collapsedShape:
                const Border(bottom: BorderSide(color: Color(0xFFE7EEF5))),
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
          expandedCrossAxisAlignment: CrossAxisAlignment.stretch,
          expandedAlignment: Alignment.centerLeft,
          shape: const Border(bottom: BorderSide(color: Color(0xFFE7EEF5))),
          collapsedShape:
              const Border(bottom: BorderSide(color: Color(0xFFE7EEF5))),
          tilePadding: EdgeInsets.zero,
          childrenPadding: const EdgeInsets.symmetric(vertical: 8),
          title: const Text('Recorded updates'),
          children: [
            row('Submitted', _date(value('created_at'))),
            if (value('updated_at').isNotEmpty)
              row('Latest update', _date(value('updated_at'))),
          ]),
    ]);
  }

  String _date(String raw) {
    final date = DateTime.tryParse(raw)?.toLocal();
    return date == null
        ? 'Not recorded'
        : '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')} ${date.hour % 12 == 0 ? 12 : date.hour % 12}:${date.minute.toString().padLeft(2, '0')} ${date.hour < 12 ? 'AM' : 'PM'}';
  }
}
