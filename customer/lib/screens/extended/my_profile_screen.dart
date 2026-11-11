import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../models/account_security_action.dart';
import '../../models/auth_model.dart';
import '../../repositories/profile_repository.dart';
import '../../services/app_live_data.dart';
import '../../services/app_settings_controller.dart';
import '../../utils/customer_contact_phone.dart';
import 'account_security_screen.dart';

class MyProfileScreen extends StatefulWidget {
  const MyProfileScreen({super.key, this.repository});

  final ProfileRepository? repository;

  @override
  State<MyProfileScreen> createState() => _MyProfileScreenState();
}

class _MyProfileScreenState extends State<MyProfileScreen>
    with LiveDataState<MyProfileScreen> {
  static const wine = Color(0xFF80152C);
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _phone = TextEditingController();
  late final _repo = widget.repository ?? ProfileRepository();
  AuthModel? _profile;
  Uint8List? _photo;
  bool _loading = true, _saving = false, _picking = false;
  int _loadVersion = 0;

  bool get _busy => _saving || _picking;
  bool get _dirty =>
      _profile != null &&
      (_name.text.trim() != _profile!.name.trim() ||
          _phone.text.trim() != (_profile!.phone ?? '').trim() ||
          _photo != null);

  String t(String english, String tamil) =>
      AppSettingsScope.of(context).text(english, tamil);

  @override
  Set<String> get liveDatasets => {'own:customers', 'own:users'};

  @override
  bool get liveCanRefresh => !_busy;

  @override
  Future<void> onLiveData(Set<String> changed) async {
    if (!_dirty) await _load();
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    super.dispose();
  }

  void _apply(AuthModel profile) {
    _profile = profile;
    _name.text = profile.name;
    _phone.text = profile.phone ?? '';
    _photo = null;
    _loading = false;
  }

  Future<void> _load() async {
    final request = ++_loadVersion;
    try {
      final profile = await _repo.getProfile();
      if (!mounted || request != _loadVersion || _busy || _dirty) return;
      setState(() {
        if (profile != null) _apply(profile);
        _loading = false;
      });
    } catch (_) {
      if (mounted && request == _loadVersion) setState(() => _loading = false);
    }
  }

  Future<void> _pickPhoto() async {
    if (_busy) return;
    setState(() => _picking = true);
    try {
      final photo = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 1000,
        maxHeight: 1000,
        imageQuality: 85,
        requestFullMetadata: false,
      );
      if (!mounted || photo == null) return;
      final bytes = await photo.readAsBytes();
      if (bytes.isEmpty || bytes.length > ProfileRepository.maxPhotoBytes) {
        throw const FormatException();
      }
      if (mounted) {
        setState(() => _photo = bytes);
      }
    } catch (_) {
      if (mounted) {
        _message(
          t(
            'Choose a valid photo up to 5 MB.',
            '5 MB வரை உள்ள படத்தைத் தேர்ந்தெடுக்கவும்.',
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _picking = false);
    }
  }

  String? _validatePhone(String? value) {
    final phone = value?.trim() ?? '';
    if (phone.isEmpty ||
        phone == (_profile?.phone ?? '').trim() ||
        customerContactPhone(phone) != null) {
      return null;
    }
    return t(
      'Enter a valid phone number.',
      'சரியான தொலைபேசி எண்ணை உள்ளிடவும்.',
    );
  }

  Future<void> _save() async {
    if (_busy || !_dirty || !_form.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    final phone = _phone.text.trim();
    setState(() {
      _saving = true;
      ++_loadVersion;
    });
    try {
      final saved = await _repo.saveProfile(
        name: _name.text.trim(),
        phone: phone == (_profile?.phone ?? '').trim()
            ? phone
            : customerContactPhone(phone) ?? '',
        photo: _photo,
      );
      if (!mounted) return;
      setState(() => _apply(saved));
      _message(t('Profile updated.', 'சுயவிவரம் புதுப்பிக்கப்பட்டது.'));
    } catch (_) {
      if (mounted) {
        _message(
          t(
            'Could not save your profile. Try again.',
            'சுயவிவரத்தைச் சேமிக்க முடியவில்லை. மீண்டும் முயற்சிக்கவும்.',
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _message(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _confirmDiscard() async {
    if (_busy) return;
    final discard = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Text(t('Discard changes?', 'மாற்றங்களை நீக்கவா?')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialog, false),
            child: Text(t('Keep editing', 'தொடர்ந்து திருத்து')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialog, true),
            child: Text(
              t('Discard', 'நீக்கு'),
              style: const TextStyle(color: wine, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
    if (mounted && discard == true) Navigator.pop(context);
  }

  Widget _avatar(AuthModel profile) {
    final name = _name.text.trim();
    final fallback = CircleAvatar(
      radius: 49,
      backgroundColor: const Color(0xFFF4E5E9),
      child: Text(
        name.isEmpty ? 'C' : name.characters.first.toUpperCase(),
        style: const TextStyle(
          fontSize: 42,
          fontWeight: FontWeight.w700,
          color: wine,
        ),
      ),
    );
    final avatar = profile.avatarUrl;
    final photo = _photo;
    return Semantics(
      button: true,
      label: t('Change photo', 'படத்தை மாற்று'),
      child: InkWell(
        onTap: _busy ? null : _pickPhoto,
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: 112,
          height: 118,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: 108,
                height: 108,
                padding: const EdgeInsets.all(5),
                decoration: const BoxDecoration(
                  color: Color(0xFFFFCB48),
                  shape: BoxShape.circle,
                ),
                child: ClipOval(
                  child: photo != null
                      ? Image.memory(
                          photo,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => fallback,
                        )
                      : avatar != null && avatar.isNotEmpty
                      ? Image.network(
                          avatar,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => fallback,
                        )
                      : fallback,
                ),
              ),
              Positioned(
                right: 0,
                bottom: 2,
                child: Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: wine,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 3),
                  ),
                  child: _picking
                      ? const Padding(
                          padding: EdgeInsets.all(8),
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(
                          Icons.camera_alt_outlined,
                          size: 18,
                          color: Colors.white,
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _heading(String title) => Text(
    title,
    style: const TextStyle(
      fontSize: 17,
      fontWeight: FontWeight.w800,
      color: Color(0xFF202638),
    ),
  );

  InputDecoration _field(String label, IconData icon) => InputDecoration(
    labelText: label,
    prefixIcon: Icon(icon, color: const Color(0xFF73737D), size: 20),
    filled: true,
    fillColor: Colors.white,
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: Color(0xFFF0EDF0)),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: wine, width: 1.5),
    ),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
  );

  @override
  Widget build(BuildContext context) {
    final profile = _profile;
    return PopScope(
      canPop: !_busy && !_dirty,
      onPopInvokedWithResult: (popped, _) {
        if (!popped && _dirty) _confirmDiscard();
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF8F8FA),
        appBar: AppBar(title: Text(t('My Profile', 'எனது சுயவிவரம்'))),
        bottomNavigationBar: profile == null
            ? null
            : SafeArea(
                minimum: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                child: FilledButton.icon(
                  onPressed: _busy || !_dirty ? null : _save,
                  style: FilledButton.styleFrom(
                    backgroundColor: wine,
                    minimumSize: const Size.fromHeight(50),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(13),
                    ),
                  ),
                  icon: _saving
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.check_rounded),
                  label: Text(
                    _saving
                        ? t('Saving…', 'சேமிக்கிறது…')
                        : t('Save changes', 'மாற்றங்களைச் சேமி'),
                  ),
                ),
              ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : profile == null
            ? Center(
                child: TextButton(
                  onPressed: () {
                    setState(() => _loading = true);
                    _load();
                  },
                  child: Text(
                    t(
                      'Could not load profile. Retry',
                      'சுயவிவரத்தை ஏற்ற முடியவில்லை. மீண்டும் முயற்சிக்கவும்.',
                    ),
                  ),
                ),
              )
            : Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 540),
                  child: Form(
                    key: _form,
                    onChanged: () => setState(() {}),
                    child: ListView(
                      keyboardDismissBehavior:
                          ScrollViewKeyboardDismissBehavior.onDrag,
                      padding: const EdgeInsets.all(20),
                      children: [
                        Container(
                          padding: const EdgeInsets.fromLTRB(18, 18, 18, 22),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(22),
                            border: Border.all(color: const Color(0xFFF0EDF0)),
                            boxShadow: [
                              BoxShadow(
                                color: wine.withValues(alpha: 0.06),
                                blurRadius: 20,
                                offset: const Offset(0, 6),
                              ),
                            ],
                          ),
                          child: Material(
                            type: MaterialType.transparency,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Center(child: _avatar(profile)),
                                const SizedBox(height: 6),
                                Text(
                                  _name.text.trim().isEmpty
                                      ? t('Your name', 'உங்கள் பெயர்')
                                      : _name.text.trim(),
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.w800,
                                    color: wine,
                                  ),
                                ),
                                const SizedBox(height: 5),
                                Text(
                                  profile.email,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: Color(0xFF747783),
                                  ),
                                ),
                                const SizedBox(height: 20),
                                const Divider(
                                  height: 1,
                                  color: Color(0xFFE8E8ED),
                                ),
                                const SizedBox(height: 20),
                                _heading(
                                  t('Personal details', 'தனிப்பட்ட விவரங்கள்'),
                                ),
                                const SizedBox(height: 12),
                                TextFormField(
                                  controller: _name,
                                  enabled: !_busy,
                                  textCapitalization: TextCapitalization.words,
                                  textInputAction: TextInputAction.next,
                                  autofillHints: const [AutofillHints.name],
                                  decoration: _field(
                                    t('Full name', 'முழுப் பெயர்'),
                                    Icons.person_outline_rounded,
                                  ),
                                  validator: (value) =>
                                      (value ?? '').trim().isEmpty
                                      ? t(
                                          'Enter your name.',
                                          'உங்கள் பெயரை உள்ளிடவும்.',
                                        )
                                      : null,
                                ),
                                const SizedBox(height: 24),
                                _heading(
                                  t('Contact details', 'தொடர்பு விவரங்கள்'),
                                ),
                                const SizedBox(height: 12),
                                TextFormField(
                                  controller: _phone,
                                  enabled: !_busy,
                                  keyboardType: TextInputType.phone,
                                  autofillHints: const [
                                    AutofillHints.telephoneNumber,
                                  ],
                                  decoration: _field(
                                    t('Contact phone', 'தொடர்பு எண்'),
                                    Icons.phone_outlined,
                                  ),
                                  validator: _validatePhone,
                                ),
                                const SizedBox(height: 14),
                                ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  leading: const Icon(Icons.email_outlined, color: Color(0xFF73737D)),
                                  title: Text(
                                    t('Sign-in email', 'உள்நுழைவு மின்னஞ்சல்'),
                                    style: const TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF17171B)),
                                  ),
                                  subtitle: Text(profile.email, style: const TextStyle(color: Color(0xFF73737D))),
                                  trailing: const Icon(
                                    Icons.chevron_right_rounded,
                                    color: Color(0xFF73737D),
                                  ),
                                  onTap: _busy
                                      ? null
                                      : () async {
                                          await Navigator.of(
                                            context,
                                          ).push<void>(
                                            MaterialPageRoute(
                                              builder: (_) =>
                                                  const AccountSecurityScreen(
                                                    action:
                                                        AccountSecurityAction
                                                            .email,
                                                  ),
                                            ),
                                          );
                                          if (mounted && !_dirty) await _load();
                                        },
                                ),
                                if (profile.createdAt case final joined?)
                                  ListTile(
                                    contentPadding: EdgeInsets.zero,
                                    leading: const Icon(
                                      Icons.event_available_outlined,
                                      color: Color(0xFF73737D),
                                    ),
                                    title: Text(
                                      t('Member since', 'உறுப்பினரான நாள்'),
                                      style: const TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF17171B)),
                                    ),
                                    subtitle: Text(
                                      MaterialLocalizations.of(context)
                                          .formatMediumDate(joined.toLocal()),
                                      style: const TextStyle(color: Color(0xFF73737D)),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
      ),
    );
  }
}
