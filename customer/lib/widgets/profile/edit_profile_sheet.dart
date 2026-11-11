import 'package:eventor_customer/services/app_settings_controller.dart';
import '../../core/theme/app_icon_colors.dart';
import 'package:flutter/material.dart';

import '../../models/edit_profile_result.dart';

class EditProfileSheet extends StatefulWidget {
  final String initialName;
  final String initialPhone;
  final String email;

  const EditProfileSheet({
    super.key,
    required this.initialName,
    required this.initialPhone,
    required this.email,
  });

  @override
  State<EditProfileSheet> createState() => _EditProfileSheetState();
}

class _EditProfileSheetState extends State<EditProfileSheet> {
  late final TextEditingController _nameController;
  late final TextEditingController _phoneController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initialName);
    _phoneController = TextEditingController(text: widget.initialPhone);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
  }) {
    const Color primaryRed = Color(0xFF80152C);

    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      textInputAction: TextInputAction.next,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: AppIconColors.standard, size: 22),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFF0EDF0)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFF0EDF0)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: primaryRed, width: 1.5),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const Color primaryRed = Color(0xFF80152C);
    const Color textDark = Color(0xFF17171B);

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFE0E0E0),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              AppSettingsScope.translate(
                context,
                "customer.edit_profile.fec2ac0f",
              ),
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: textDark,
              ),
            ),
            const SizedBox(height: 20),
            _buildTextField(
              controller: _nameController,
              label: AppSettingsScope.translate(
                context,
                "customer.full_name.8e00cdf7",
              ),
              icon: Icons.person_outline,
            ),
            const SizedBox(height: 14),
            _buildTextField(
              controller: _phoneController,
              label: AppSettingsScope.translate(
                context,
                "customer.phone_number.72dba9ae",
              ),
              icon: Icons.phone_outlined,
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 14),
            TextField(
              enabled: false,
              controller: TextEditingController(text: widget.email),
              decoration: InputDecoration(
                labelText: AppSettingsScope.translate(
                  context,
                  "customer.email.969ccbd3",
                ),
                prefixIcon: const Icon(
                  Icons.email_outlined,
                  color: AppIconColors.standard,
                  size: 22,
                ),
                filled: true,
                fillColor: const Color(0xFFFAF9FA),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: Color(0xFFF0EDF0)),
                ),
                disabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: Color(0xFFF0EDF0)),
                ),
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: FilledButton(
                onPressed: () {
                  final String name = _nameController.text.trim();
                  final String phone = _phoneController.text.trim();

                  if (name.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          AppSettingsScope.translate(
                            context,
                            "customer.please_enter_your_name.a286aa34",
                          ),
                        ),
                        backgroundColor: primaryRed,
                      ),
                    );
                    return;
                  }

                  Navigator.of(context).pop(
                    EditProfileResult(saved: true, name: name, phone: phone),
                  );
                },
                style: FilledButton.styleFrom(
                  backgroundColor: primaryRed,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(13),
                  ),
                  textStyle: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                child: Text(
                  AppSettingsScope.translate(
                    context,
                    "customer.save_changes.35322b5b",
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}
