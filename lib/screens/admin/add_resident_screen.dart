import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AddResidentScreen extends StatefulWidget {
  const AddResidentScreen({super.key});

  @override
  State<AddResidentScreen> createState() => _AddResidentScreenState();
}

class _AddResidentScreenState extends State<AddResidentScreen> {
  final supabase = Supabase.instance.client;

  final fullNameController = TextEditingController();
  final birthdateController = TextEditingController();
  final addressController = TextEditingController();
  final contactController = TextEditingController();

  String civilStatus = 'Single';
  bool isLoading = false;

  /*--------------------- ADD RESIDENT -------------------------------*/

  Future<void> addResident() async {
    // ✅ INPUT VALIDATION
    if (fullNameController.text.trim().isEmpty ||
        birthdateController.text.trim().isEmpty ||
        addressController.text.trim().isEmpty ||
        contactController.text.trim().isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please fill all fields')));
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

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
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
              controller: fullNameController,
              decoration: const InputDecoration(labelText: 'Full Name'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: birthdateController,
              readOnly: true,
              onTap: pickDate,
              decoration: const InputDecoration(labelText: 'Birthdate'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: addressController,
              decoration: const InputDecoration(labelText: 'Address'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: contactController,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(labelText: 'Contact Number'),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
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
