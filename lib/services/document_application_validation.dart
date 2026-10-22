class DocumentApplicationValidation {
  static const civilStatuses = [
    'Single',
    'Married',
    'Widowed',
    'Separated',
    'Annulled',
    'Divorced'
  ];
  static String? validate(
      {required String birthdate, required String civilStatus, DateTime? now}) {
    final raw = birthdate.trim();
    if (raw.isNotEmpty) {
      final parsed = DateTime.tryParse(raw);
      final today = now ?? DateTime.now();
      if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(raw) ||
          parsed == null ||
          parsed.year < 1900 ||
          raw !=
              '${parsed.year.toString().padLeft(4, '0')}-${parsed.month.toString().padLeft(2, '0')}-${parsed.day.toString().padLeft(2, '0')}' ||
          parsed.isAfter(DateTime(today.year, today.month, today.day))) {
        return 'Choose a valid date of birth that is not in the future.';
      }
    }
    if (civilStatus.trim().isNotEmpty &&
        !civilStatuses
            .any((v) => v.toLowerCase() == civilStatus.trim().toLowerCase())) {
      return 'Choose a civil status from the available options.';
    }
    return null;
  }
}
