import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:matchfit/core/theme.dart';
import 'package:image_picker/image_picker.dart';
import 'package:matchfit/core/providers/profile_provider.dart';
import 'package:matchfit/core/l10n/app_localizations.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:matchfit/core/constants/location_data.dart';

class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({super.key});

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();

  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _birthDateController = TextEditingController();

  String? _selectedCity;
  String? _selectedDistrict;
  DateTime? _selectedBirthDate;

  bool _isLoading = false;
  bool _isUploading = false;
  String? _avatarUrl;
  String? _coverUrl;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  void _loadInitialData() {
    final profile = ref.read(currentUserProfileProvider).value;
    if (profile != null) {
      _firstNameController.text = profile['first_name'] ?? '';
      _lastNameController.text = profile['last_name'] ?? '';
      _phoneController.text = profile['phone'] ?? '';

      final bDate = profile['birth_date'];
      if (bDate != null) {
        _selectedBirthDate = DateTime.tryParse(bDate);
        if (_selectedBirthDate != null) {
          _birthDateController.text =
              "${_selectedBirthDate!.day}/${_selectedBirthDate!.month}/${_selectedBirthDate!.year}";
        }
      }

      _selectedCity = profile['city'];
      _selectedDistrict = profile['district'];
      _avatarUrl = profile['avatar_url'];
      _coverUrl = profile['cover_url'];
    }
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _phoneController.dispose();
    _birthDateController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(bool isAvatar) async {
    final picker = ImagePicker();
    final image = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1024,
      maxHeight: 1024,
      imageQuality: 80,
    );

    if (image != null) {
      setState(() => _isUploading = true);
      try {
        final supabase = Supabase.instance.client;
        final userId = supabase.auth.currentUser?.id;
        if (userId == null) return;

        final bytes = await image.readAsBytes();
        final fileExt = image.name.split('.').last.toLowerCase();
        final mimeType = (fileExt == 'jpg' || fileExt == 'jpeg')
            ? 'image/jpeg'
            : 'image/$fileExt';
        final fileName = '${DateTime.now().millisecondsSinceEpoch}.$fileExt';
        final path = '$userId/$fileName';

        await supabase.storage
            .from('avatars')
            .uploadBinary(
              path,
              bytes,
              fileOptions: FileOptions(upsert: true, contentType: mimeType),
            );

        final imageUrl = supabase.storage.from('avatars').getPublicUrl(path);

        await supabase
            .from('profiles')
            .update({isAvatar ? 'avatar_url' : 'cover_url': imageUrl})
            .eq('id', userId);

        setState(() {
          if (isAvatar) {
            _avatarUrl = imageUrl;
          } else {
            _coverUrl = imageUrl;
          }
        });

        ref.invalidate(currentUserProfileProvider);

        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Profil güncellendi')));
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Hata: $e'), backgroundColor: Colors.red),
          );
        }
      } finally {
        if (mounted) setState(() => _isUploading = false);
      }
    }
  }

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate:
          _selectedBirthDate ??
          DateTime.now().subtract(const Duration(days: 365 * 18)),
      firstDate: DateTime(1950),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: MatchFitTheme.accentGreen,
              onPrimary: Colors.black,
              surface: Color(0xFF1A1A1A),
              onSurface: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _selectedBirthDate = picked;
        _birthDateController.text =
            "${picked.day}/${picked.month}/${picked.year}";
      });
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      final supabase = Supabase.instance.client;
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) return;

      final fullName =
          "${_firstNameController.text.trim()} ${_lastNameController.text.trim()}";

      await supabase
          .from('profiles')
          .update({
            'full_name': fullName,
            'first_name': _firstNameController.text.trim(),
            'last_name': _lastNameController.text.trim(),
            'phone': _phoneController.text.trim(),
            'birth_date': _selectedBirthDate?.toIso8601String(),
            'city': _selectedCity,
            'district': _selectedDistrict,
          })
          .eq('id', userId);

      ref.invalidate(currentUserProfileProvider);

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Profil güncellendi')));
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Hata: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(
          color: Colors.white54,
          fontSize: 12,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0, top: 16.0),
      child: Text(
        text,
        style: const TextStyle(color: Colors.white, fontSize: 14),
      ),
    );
  }

  Widget _buildTextField(
    TextEditingController controller,
    String hint, {
    TextInputType? keyboardType,
    String? Function(String?)? validator,
    IconData? suffixIcon,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      validator: validator,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Colors.white24),
        filled: true,
        fillColor: const Color(0xFF1A1A1A),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
        suffixIcon: suffixIcon != null
            ? Icon(suffixIcon, color: MatchFitTheme.accentGreen)
            : null,
      ),
    );
  }

  Widget _buildDropdown({
    String? value,
    required List<String> items,
    required String hint,
    required Function(String?) onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(12),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: items.contains(value) ? value : null,
          hint: Text(hint, style: const TextStyle(color: Colors.white24)),
          isExpanded: true,
          dropdownColor: const Color(0xFF1A1A1A),
          icon: const Icon(
            Icons.keyboard_arrow_down,
            color: MatchFitTheme.accentGreen,
          ),
          style: const TextStyle(color: Colors.white),
          items: items
              .map((item) => DropdownMenuItem(value: item, child: Text(item)))
              .toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);

    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          t.editProfile,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          TextButton(
            onPressed: _isLoading ? null : _saveProfile,
            child: _isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(
                    t.save,
                    style: const TextStyle(
                      color: MatchFitTheme.accentGreen,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            GestureDetector(
              onTap: () => _pickImage(false),
              child: Stack(
                children: [
                  Container(
                    height: 160,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: const Color(0xFF1A1A1A),
                      image: _coverUrl != null
                          ? DecorationImage(
                              image: NetworkImage(_coverUrl!),
                              fit: BoxFit.cover,
                            )
                          : null,
                    ),
                    child: _coverUrl == null
                        ? const Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.add_a_photo_outlined,
                                color: Colors.white54,
                                size: 32,
                              ),
                              SizedBox(height: 8),
                              Text(
                                'Kapak Fotoğrafı Ekle',
                                style: TextStyle(
                                  color: Colors.white54,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          )
                        : null,
                  ),
                  if (_isUploading)
                    const Positioned.fill(
                      child: Center(
                        child: CircularProgressIndicator(
                          color: MatchFitTheme.accentGreen,
                        ),
                      ),
                    ),
                ],
              ),
            ),

            Transform.translate(
              offset: const Offset(0, -50),
              child: GestureDetector(
                onTap: () => _pickImage(true),
                child: Stack(
                  children: [
                    Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: const Color(0xFF0A0A0A),
                          width: 4,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.5),
                            blurRadius: 10,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: CircleAvatar(
                        radius: 48,
                        backgroundColor: const Color(0xFF1E1E1E),
                        backgroundImage: _avatarUrl != null
                            ? NetworkImage(_avatarUrl!)
                            : null,
                        child: _avatarUrl == null
                            ? const Icon(
                                Icons.person,
                                color: Colors.white54,
                                size: 40,
                              )
                            : null,
                      ),
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: MatchFitTheme.accentGreen,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.camera_alt,
                          color: Colors.black,
                          size: 18,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSectionHeader(t.personalInfo),

                    _buildLabel(t.firstName),
                    _buildTextField(
                      _firstNameController,
                      t.firstName,
                      validator: (v) =>
                          v!.isEmpty ? t.pleaseFillAllFields : null,
                    ),

                    _buildLabel(t.lastName),
                    _buildTextField(
                      _lastNameController,
                      t.lastName,
                      validator: (v) =>
                          v!.isEmpty ? t.pleaseFillAllFields : null,
                    ),

                    _buildLabel(t.phoneNumber),
                    _buildTextField(
                      _phoneController,
                      "05xx xxx xx xx",
                      keyboardType: TextInputType.phone,
                    ),

                    _buildLabel(t.birthDate),
                    GestureDetector(
                      onTap: _selectDate,
                      child: AbsorbPointer(
                        child: _buildTextField(
                          _birthDateController,
                          t.select,
                          suffixIcon: Icons.calendar_month,
                        ),
                      ),
                    ),

                    const SizedBox(height: 32),
                    _buildSectionHeader(t.city),

                    _buildLabel(t.province),
                    _buildDropdown(
                      value: _selectedCity,
                      items: turkeyProvinces.keys.toList()..sort(),
                      hint: t.selectProvince,
                      onChanged: (val) => setState(() {
                        _selectedCity = val;
                        _selectedDistrict = null;
                      }),
                    ),

                    _buildLabel(t.district),
                    _buildDropdown(
                      value: _selectedDistrict,
                      items: _selectedCity != null
                          ? (turkeyProvinces[_selectedCity]!.toList()..sort())
                          : [],
                      hint: t.selectDistrict,
                      onChanged: (val) =>
                          setState(() => _selectedDistrict = val),
                    ),

                    const SizedBox(height: 48),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
