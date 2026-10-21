import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Evidence is a claim for staff review, never automatic identity verification.
class DocumentEvidenceScreen extends StatefulWidget {
  const DocumentEvidenceScreen({super.key, required this.requesterName});
  final String requesterName;
  @override
  State<DocumentEvidenceScreen> createState() => _DocumentEvidenceScreenState();
}

class _DocumentEvidenceScreenState extends State<DocumentEvidenceScreen> {
  final _idType = TextEditingController();
  final _methods = <String, String>{
    'identity': 'in_person',
    'residency': 'in_person',
    'authorization': 'in_person'
  };
  final _files = <String, XFile>{};
  final _previews = <String, Uint8List>{};
  final _fileErrors = <String, String>{};
  String _capacity = 'self';
  bool _busy = false;
  String? _error;
  @override
  void dispose() {
    _idType.dispose();
    super.dispose();
  }

  Future<void> _pick(String kind) async {
    try {
      final file = await ImagePicker()
          .pickImage(source: ImageSource.gallery, imageQuality: 80);
      if (file == null || !mounted) return;
      if (!RegExp(r'\.(jpe?g|png|webp)$', caseSensitive: false)
              .hasMatch(file.name) ||
          await file.length() > 10 * 1024 * 1024) {
        if (mounted) {
          setState(() => _fileErrors[kind] =
              'Choose a JPEG, PNG or WebP image up to 10 MB.');
        }
        return;
      }
      final bytes = await file.readAsBytes();
      if (!mounted) return;
      setState(() {
        _files[kind] = file;
        _previews[kind] = bytes;
        _fileErrors.remove(kind);
        _error = null;
      });
    } catch (_) {
      if (mounted) {
        setState(() =>
            _fileErrors[kind] = 'Unable to open that photo. Please try again.');
      }
    }
  }

  Future<void> _continue() async {
    if (_busy) return;
    final requiredKinds = [
      'identity',
      'residency',
      if (_capacity == 'representative') 'authorization'
    ];
    if (requiredKinds.any(
            (kind) => _methods[kind] == 'upload' && _files[kind] == null) ||
        (_methods['identity'] == 'upload' && _idType.text.trim().isEmpty)) {
      setState(() => _error =
          'Choose the required image and identify the uploaded ID, or choose to present originals at the office.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final client = Supabase.instance.client;
      final user = client.auth.currentUser;
      if (user == null) throw StateError('Sign in first');
      final payload = <String, dynamic>{
        'workflow_version': 2,
        'requester_name': widget.requesterName,
        'requester_capacity': _capacity,
        'evidence_id_type':
            _methods['identity'] == 'upload' ? _idType.text.trim() : null
      };
      for (final kind in requiredKinds) {
        payload['${kind}_evidence_method'] = _methods[kind];
        if (_methods[kind] != 'upload') continue;
        final Uint8List bytes = await _files[kind]!.readAsBytes();
        final name = _files[kind]!.name.toLowerCase();
        final ext = name.endsWith('.png')
            ? 'png'
            : name.endsWith('.webp')
                ? 'webp'
                : name.endsWith('.jpg') || name.endsWith('.jpeg')
                    ? 'jpg'
                    : null;
        if (ext == null || bytes.length > 10 * 1024 * 1024) {
          throw StateError('Use a JPEG, PNG or WebP image up to 10 MB.');
        }
        final path =
            '${user.id}/document-evidence/${DateTime.now().microsecondsSinceEpoch}-$kind.$ext';
        await client.storage.from('resident-files').uploadBinary(path, bytes,
            fileOptions: FileOptions(
                contentType: ext == 'jpg' ? 'image/jpeg' : 'image/$ext'));
        payload['${kind}_evidence_url'] = 'resident-files/$path';
      }
      if (mounted) Navigator.pop(context, payload);
    } catch (_) {
      if (mounted) {
        setState(() => _error =
            'Unable to prepare evidence. Use JPEG, PNG or WebP up to 10 MB and check your connection. You can also present originals at the office.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _choices(String group, String selected, Map<String, String> options,
          ValueChanged<String> onChanged) =>
      RadioGroup<String>(
          groupValue: selected,
          onChanged: (value) {
            if (value != null && !_busy) onChanged(value);
          },
          child: Column(
              children: options.entries
                  .map((option) => Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                            color: option.key == selected
                                ? const Color(0xFFEFF6FF)
                                : Colors.white,
                            border: Border.all(
                                color: option.key == selected
                                    ? const Color(0xFF00549C)
                                    : const Color(0xFFD8E3EF)),
                            borderRadius: BorderRadius.circular(12)),
                        child: RadioListTile<String>(
                            key: ValueKey('$group-${option.key}'),
                            value: option.key,
                            enabled: !_busy,
                            title: Text(option.value),
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4)),
                      )))
                  .toList()));

  Widget _section(String kind, String label, String help) => Container(
      key: ValueKey('section-$kind'),
      margin: const EdgeInsets.only(top: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: const Color(0xFFD8E3EF)),
          borderRadius: BorderRadius.circular(16)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label,
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        Text(help),
        const SizedBox(height: 8),
        _choices(
            kind,
            _methods[kind]!,
            const {
              'in_person': 'Bring originals to the office',
              'upload': 'Upload a photo'
            },
            (value) => setState(() {
                  _methods[kind] = value;
                  _error = null;
                })),
        if (_methods[kind] == 'upload') ...[
          const SizedBox(height: 16),
          Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                  border: Border.all(color: const Color(0xFFD8E3EF)),
                  borderRadius: BorderRadius.circular(12)),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('JPEG, PNG or WebP · Up to 10 MB per photo'),
                    if (_previews[kind] != null) ...[
                      const SizedBox(height: 12),
                      Semantics(
                          label: 'Selected photo for $label',
                          image: true,
                          child: ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.memory(_previews[kind]!,
                                  height: 150,
                                  width: double.infinity,
                                  fit: BoxFit.contain,
                                  cacheWidth: 640,
                                  errorBuilder: (_, __, ___) => const Text(
                                      'Preview unavailable. Replace this photo if it cannot be opened.')))),
                      const SizedBox(height: 8),
                      Text(_files[kind]!.name,
                          maxLines: 2, overflow: TextOverflow.ellipsis),
                    ],
                    Wrap(spacing: 8, children: [
                      TextButton.icon(
                          key: ValueKey('choose-$kind'),
                          onPressed: _busy ? null : () => _pick(kind),
                          icon: const Icon(Icons.add_photo_alternate_outlined),
                          label: Text(_files[kind] == null
                              ? 'Choose photo'
                              : 'Replace photo')),
                      if (_files[kind] != null)
                        TextButton(
                            onPressed: _busy
                                ? null
                                : () => setState(() {
                                      _files.remove(kind);
                                      _previews.remove(kind);
                                      _fileErrors.remove(kind);
                                    }),
                            child: const Text('Remove')),
                    ]),
                    if (_fileErrors[kind] != null)
                      Semantics(
                          liveRegion: true,
                          child: Text(_fileErrors[kind]!,
                              style: TextStyle(
                                  color: Theme.of(context).colorScheme.error))),
                  ])),
          if (kind == 'identity') ...[
            const SizedBox(height: 20),
            const Text('What document are you uploading?'),
            const SizedBox(height: 8),
            TextField(
                controller: _idType,
                enabled: !_busy,
                textCapitalization: TextCapitalization.sentences,
                maxLength: 120,
                decoration: const InputDecoration(
                    labelText: 'Document name',
                    hintText: 'Enter the document name',
                    counterText: '')),
            const SizedBox(height: 8),
            const Text('Check accepted documents with the barangay office.'),
          ],
        ],
      ]));

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
            toolbarHeight:
                MediaQuery.textScalerOf(context).scale(1) > 1.3 ? 112 : 64,
            title: const Text('Document requirements', maxLines: 2)),
        bottomNavigationBar: Padding(
            padding: EdgeInsets.only(
                bottom: MediaQuery.viewInsetsOf(context).bottom),
            child: SafeArea(
                top: false,
                child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
                    child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (_error != null) ...[
                            const SizedBox(height: 16),
                            Semantics(
                                liveRegion: true,
                                child: Text(_error!,
                                    style: TextStyle(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .error)))
                          ],
                          FilledButton(
                            key: const ValueKey('continue-submission'),
                            onPressed: _busy ? null : _continue,
                            style: FilledButton.styleFrom(
                                minimumSize: const Size.fromHeight(52)),
                            child: Text(
                                _busy ? 'Preparing…' : 'Continue to submission',
                                textAlign: TextAlign.center),
                          ),
                        ])))),
        body: SafeArea(
            bottom: false,
            child: ListView(
                key: const ValueKey('requirements-list'),
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
                children: [
                  Text('Prepare your documents',
                      style: Theme.of(context)
                          .textTheme
                          .titleLarge
                          ?.copyWith(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  const Text(
                      'Choose how you’ll provide your documents. Barangay staff will review them before release.'),
                  const SizedBox(height: 12),
                  const Text(
                      'Uploads remain private. Staff may still ask to inspect originals at the office. Uploading does not automatically verify your identity or approve release.'),
                  const SizedBox(height: 24),
                  Text('Who are you applying for?',
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.w600)),
                  _choices(
                      'capacity',
                      _capacity,
                      const {
                        'self': 'Myself',
                        'representative': 'Someone else'
                      },
                      (value) => setState(() {
                            _capacity = value;
                            _error = null;
                          })),
                  _section('identity', 'Proof of identity',
                      'Provide the applicant’s ID, or ask the barangay office about alternative documents.'),
                  _section('residency', 'Proof of address',
                      'Staff will check the applicant’s address against barangay records or accepted documents. Ask which documents your service requires.'),
                  if (_capacity == 'representative')
                    _section(
                        'authorization',
                        'Permission to apply for someone else',
                        'Provide the person’s authorization and supporting documents. Being a family member does not automatically give permission.'),
                  const SizedBox(height: 20),
                  const Text(
                      'Payment and collection happen at the barangay office. Staff will confirm any applicable fees. There is no online payment.'),
                ])),
      );
}
