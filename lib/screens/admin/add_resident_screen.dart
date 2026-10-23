import '../../widgets/form_feedback.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../widgets/top_toast.dart';
import '../../services/basic_account_service.dart';
import '../../services/document_application_validation.dart';

class AddResidentScreen extends StatefulWidget {
  const AddResidentScreen({super.key});

  @override
  State<AddResidentScreen> createState() => _AddResidentScreenState();
}

class _AddResidentScreenState extends State<AddResidentScreen>
    with FormFeedback<AddResidentScreen> {
  final supabase = Supabase.instance.client;

  final fullNameController = TextEditingController();
  final birthdateController = TextEditingController();
  final addressController = TextEditingController();
  final contactController = TextEditingController();

  String civilStatus = 'Single';
  bool isLoading = false;

  void _showTopToast(String message) {
    if (!mounted) return;
    TopToast.show(context, message);
  }

  /*--------------------- ADD RESIDENT -------------------------------*/

  Future<void> addResident() async {
    if (isLoading) return;
    if (!validateFields({
      'resident_name': fullNameController.text.trim().isEmpty
          ? 'Enter the resident’s full name.'
          : null,
      'resident_birthdate': birthdateController.text.trim().isEmpty
          ? 'Choose a birthdate.'
          : DocumentApplicationValidation.validate(
              birthdate: birthdateController.text, civilStatus: ''),
      'resident_address': addressController.text.trim().isEmpty
          ? 'Enter the residential address.'
          : null,
      'resident_phone':
          BasicAccountService.normalizePhone(contactController.text) == null
              ? 'Enter a valid Philippine mobile number.'
              : null,
    })) {
      return;
    }

    setState(() => isLoading = true);

    try {
      final response = await supabase
          .from('residents')
          .insert({
            'full_name': fullNameController.text.trim(),
            'birthdate': birthdateController.text.trim(),
            'address': addressController.text.trim(),
            'contact_number': contactController.text.trim(),
            'civil_status': civilStatus,
            'status': 'pending',
          })
          .select()
          .single();

      if (!mounted) return;
      Navigator.pop(context, response);
    } catch (e) {
      if (!mounted) return;

      _showTopToast('Unable to add resident right now. Please try again.');
    } finally {
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  /*------------------------------------------------------------------*/

  Future<void> pickDate() async {
    DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime(2000),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
    );

    if (picked != null) {
      birthdateController.text = picked.toIso8601String().split('T')[0];
    }
  }

  @override
  void dispose() {
    fullNameController.dispose();
    birthdateController.dispose();
    addressController.dispose();
    contactController.dispose();
    super.dispose();
  }

  /*-------------------------- UI --------------------------*/

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Add Resident')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              key: fieldAnchor('resident_name'),
              focusNode: fieldFocus('resident_name', fullNameController),
              controller: fullNameController,
              decoration: decorateField('resident_name',
                  const InputDecoration(labelText: 'Full Name')),
            ),
            const SizedBox(height: 12),
            TextField(
              key: fieldAnchor('resident_birthdate'),
              focusNode: fieldFocus('resident_birthdate', birthdateController),
              controller: birthdateController,
              readOnly: true,
              onTap: pickDate,
              decoration: decorateField('resident_birthdate',
                  const InputDecoration(labelText: 'Birthdate')),
            ),
            const SizedBox(height: 12),
            TextField(
              key: fieldAnchor('resident_address'),
              focusNode: fieldFocus('resident_address', addressController),
              controller: addressController,
              decoration: decorateField('resident_address',
                  const InputDecoration(labelText: 'Address')),
            ),
            const SizedBox(height: 12),
            TextField(
              key: fieldAnchor('resident_phone'),
              focusNode: fieldFocus('resident_phone', contactController),
              controller: contactController,
              keyboardType: TextInputType.phone,
              decoration: decorateField('resident_phone',
                  const InputDecoration(labelText: 'Contact Number')),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              isExpanded: true,
              menuMaxHeight: 320,
              borderRadius: BorderRadius.circular(12),
              icon: const Icon(Icons.keyboard_arrow_down_rounded),
              initialValue: civilStatus,
              decoration: const InputDecoration(labelText: 'Civil Status'),
              items: ['Single', 'Married', 'Widowed', 'Separated']
                  .map(
                    (status) =>
                        DropdownMenuItem(value: status, child: Text(status)),
                  )
                  .toList(),
              onChanged: (value) {
                setState(() {
                  civilStatus = value!;
                });
              },
            ),
            const SizedBox(height: 24),
            isLoading
                ? const CircularProgressIndicator()
                : ElevatedButton(
                    onPressed: addResident,
                    child: const Text('Save'),
                  ),
          ],
        ),
      ),
    );
  }
}
