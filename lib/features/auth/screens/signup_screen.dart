import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:matchfit/core/theme.dart';
import 'package:matchfit/core/l10n/app_localizations.dart';
import 'package:matchfit/core/constants/location_data.dart';
import 'package:matchfit/core/constants/sports_data.dart';
import '../repositories/auth_repository.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SignupScreen extends ConsumerStatefulWidget {
  const SignupScreen({super.key});

  @override
  ConsumerState<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends ConsumerState<SignupScreen> {
  final PageController _pageController = PageController();
  int _currentStep = 0;
  bool _isLoading = false;

  // Step 1 Controllers
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _birthDateController = TextEditingController();
  DateTime? _selectedBirthDate;
  String? _selectedCity;
  String? _selectedDistrict;
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  
  bool _agreeToTerms = false;
  bool _agreeToKvkk = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  // Step 2 State
  final _searchController = TextEditingController();
  final Set<String> _selectedSports = {};
  String _searchQuery = '';

  @override
  void dispose() {
    _pageController.dispose();
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _birthDateController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _nextStep() {
    final t = AppLocalizations.of(context);
    
    if (_currentStep == 0) {
      // Validate Step 1
      if (_firstNameController.text.isEmpty || 
          _lastNameController.text.isEmpty || 
          _emailController.text.isEmpty || 
          _selectedCity == null || 
          _selectedDistrict == null || 
          _passwordController.text.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(t.pleaseFillAllFields)),
        );
        return;
      }

      if (_passwordController.text != _confirmPasswordController.text) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(t.passwordsDontMatch)),
        );
        return;
      }

      if (!_agreeToTerms || !_agreeToKvkk) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(t.mustAgreeTerms)),
        );
        return;
      }

      // Telefon formatı kontrolü (0 ile başlamalı ve 11 hane olmalı)
      final phone = _phoneController.text.trim();
      if (!phone.startsWith('0') || phone.length != 11) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(t.phoneFormatError)),
        );
        return;
      }

      // Yaş kontrolü (En az 18 yaş)
      if (_selectedBirthDate != null) {
        final today = DateTime.now();
        var age = today.year - _selectedBirthDate!.year;
        if (today.month < _selectedBirthDate!.month || 
           (today.month == _selectedBirthDate!.month && today.day < _selectedBirthDate!.day)) {
          age--;
        }
        
        if (age < 18) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(t.ageError)),
          );
          return;
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(t.pleaseFillAllFields)),
        );
        return;
      }

      setState(() => _currentStep = 1);
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  Future<void> _submit() async {
    final t = AppLocalizations.of(context);
    
    if (_selectedSports.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(t.selectAtLeastOneCategory)),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      final authRepo = ref.read(authRepositoryProvider);
      
      // 1. Sign Up
      final response = await authRepo.signUpWithEmail(
        _emailController.text.trim(),
        _passwordController.text.trim(),
      );
      
      if (response.user != null) {
        // 2. Save Profile
        await authRepo.upsertProfile({
          'full_name': '${_firstNameController.text.trim()} ${_lastNameController.text.trim()}',
          'first_name': _firstNameController.text.trim(),
          'last_name': _lastNameController.text.trim(),
          'phone': _phoneController.text.trim(),
          'birth_date': _selectedBirthDate?.toIso8601String(),
          'city': _selectedCity,
          'district': _selectedDistrict,
          'trust_score': 0,
        });

        // 3. Save Sports Interests
        final supabase = Supabase.instance.client;
        try {
          // Fetch all sports to map names to IDs
          final sportsResponse = await supabase.from('sports').select('id, name');
          final sportsMap = {
            for (var s in (sportsResponse as List)) (s['name'] as String): s['id'] as String
          };

          final inserts = _selectedSports.map((sportName) {
            final sportId = sportsMap[sportName];
            return {
              'user_id': response.user!.id,
              'sport_id': sportId,
              'skill_level': 'beginner',
            };
          }).where((e) => e['sport_id'] != null).toList();
          
          if (inserts.isNotEmpty) {
            await supabase.from('user_sports_preferences').upsert(inserts);
          }
        } catch (e) {
          debugPrint('Error saving sports: $e');
        }

        if (mounted) context.go('/home');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${t.signUpError}: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F1111),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () {
            if (_currentStep > 0) {
              setState(() => _currentStep = 0);
              _pageController.previousPage(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
              );
            } else {
              context.pop();
            }
          },
        ),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Kayıt Ol',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
            ),
            const Spacer(),
            const Text(
              'MATCHFIT',
              style: TextStyle(
                color: MatchFitTheme.accentGreen,
                fontWeight: FontWeight.w900,
                fontStyle: FontStyle.italic,
                fontSize: 20,
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          _buildProgressIndicator(),
          Expanded(
            child: PageView(
              controller: _pageController,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                _buildStep1(),
                _buildStep2(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressIndicator() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: 4,
              decoration: BoxDecoration(
                color: MatchFitTheme.accentGreen,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Container(
              height: 4,
              decoration: BoxDecoration(
                color: _currentStep >= 1 ? MatchFitTheme.accentGreen : Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStep1() {
    final t = AppLocalizations.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'ADIM 1 / 2',
            style: TextStyle(color: MatchFitTheme.accentGreen, fontWeight: FontWeight.bold, fontSize: 12),
          ),
          const SizedBox(height: 8),
          Text(
            t.personalInfo,
            style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 32),
          
          Row(
            children: [
              Expanded(
                child: _buildFieldLabel(t.firstName),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildFieldLabel(t.lastName),
              ),
            ],
          ),
          Row(
            children: [
              Expanded(
                child: _buildTextField(
                  controller: _firstNameController,
                  hint: 'Can',
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildTextField(
                  controller: _lastNameController,
                  hint: 'Yılmaz',
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          
          _buildFieldLabel(t.emailAddress),
          _buildTextField(
            controller: _emailController,
            hint: 'ornek@mail.com',
            icon: Icons.mail_outline,
            keyboardType: TextInputType.emailAddress,
          ),
          const SizedBox(height: 20),
          
          _buildFieldLabel(t.phoneNumber),
          _buildTextField(
            controller: _phoneController,
            hint: t.phoneHint,
            icon: Icons.phone_outlined,
            keyboardType: TextInputType.phone,
          ),
          const SizedBox(height: 20),
          
          _buildFieldLabel(t.birthDate),
          GestureDetector(
            onTap: _showDatePicker,
            child: AbsorbPointer(
              child: _buildTextField(
                controller: _birthDateController,
                hint: 'mm/dd/yyyy',
                icon: Icons.calendar_today_outlined,
              ),
            ),
          ),
          const SizedBox(height: 20),
          
          Row(
            children: [
              Expanded(child: _buildFieldLabel(t.province)),
              const SizedBox(width: 16),
              Expanded(child: _buildFieldLabel(t.district)),
            ],
          ),
          Row(
            children: [
              Expanded(
                child: _buildDropdownField(
                  value: _selectedCity,
                  hint: 'Seçiniz',
                  items: turkeyProvinces.keys.toList(),
                  onChanged: (val) {
                    setState(() {
                      _selectedCity = val;
                      _selectedDistrict = null;
                    });
                  },
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildDropdownField(
                  value: _selectedDistrict,
                  hint: 'Seçiniz',
                  items: _selectedCity != null ? turkeyProvinces[_selectedCity]! : [],
                  onChanged: (val) => setState(() => _selectedDistrict = val),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          
          _buildFieldLabel(t.password),
          _buildTextField(
            controller: _passwordController,
            hint: '********',
            icon: _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
            obscureText: _obscurePassword,
            onIconTap: () => setState(() => _obscurePassword = !_obscurePassword),
            prefixIcon: Icons.lock_outline,
          ),
          const SizedBox(height: 20),
          
          _buildFieldLabel(t.passwordRepeat),
          _buildTextField(
            controller: _confirmPasswordController,
            hint: '********',
            icon: _obscureConfirmPassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
            obscureText: _obscureConfirmPassword,
            onIconTap: () => setState(() => _obscureConfirmPassword = !_obscureConfirmPassword),
            prefixIcon: Icons.refresh,
          ),
          const SizedBox(height: 24),
          
          _buildCheckboxRow(
            value: _agreeToTerms,
            onChanged: (val) => setState(() => _agreeToTerms = val ?? false),
            child: RichText(
              text: TextSpan(
                style: const TextStyle(color: Colors.white, fontSize: 13, height: 1.4),
                children: [
                  TextSpan(text: t.termsConsentPrefix, style: const TextStyle(color: MatchFitTheme.accentGreen, decoration: TextDecoration.underline, fontWeight: FontWeight.bold)),
                  TextSpan(text: t.termsConsentMiddle),
                  TextSpan(text: t.privacyPolicy, style: const TextStyle(color: MatchFitTheme.accentGreen, decoration: TextDecoration.underline, fontWeight: FontWeight.bold)),
                  TextSpan(text: t.termsConsentSuffix),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          _buildCheckboxRow(
            value: _agreeToKvkk,
            onChanged: (val) => setState(() => _agreeToKvkk = val ?? false),
            child: Text(
              t.kvkkConsent,
              style: const TextStyle(color: Colors.white, fontSize: 13, height: 1.4),
            ),
          ),
          
          const SizedBox(height: 40),
          
          ElevatedButton(
            onPressed: _nextStep,
            style: ElevatedButton.styleFrom(
              backgroundColor: MatchFitTheme.accentGreen,
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(vertical: 18),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(t.nextStepButton, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(width: 8),
                const Icon(Icons.arrow_forward, size: 20),
              ],
            ),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildStep2() {
    final t = AppLocalizations.of(context);
    
    // Filter sports based on search query
    final filteredSports = sportsData
        .expand((cat) => cat.subcategories)
        .where((s) => s.toLowerCase().contains(_searchQuery.toLowerCase()))
        .toList();

    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'ADIM 2 / 2',
            style: TextStyle(color: MatchFitTheme.accentGreen, fontWeight: FontWeight.bold, fontSize: 12),
          ),
          const SizedBox(height: 8),
          Text(
            t.selectInterests,
            style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            t.selectInterestsSubtitle,
            style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 14),
          ),
          const SizedBox(height: 24),
          
          // Search Box
          TextField(
            controller: _searchController,
            onChanged: (val) => setState(() => _searchQuery = val),
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: t.searchSportsHint,
              hintStyle: TextStyle(color: Colors.white.withOpacity(0.3)),
              prefixIcon: Icon(Icons.search, color: Colors.white.withOpacity(0.3)),
              filled: true,
              fillColor: const Color(0xFF1E2020),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(30), borderSide: BorderSide.none),
            ),
          ),
          const SizedBox(height: 16),
          
          // Selected Sports Tags
          if (_selectedSports.isNotEmpty)
            SizedBox(
              height: 40,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: _selectedSports.map((sport) => Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Chip(
                    label: Text(sport, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    backgroundColor: MatchFitTheme.primaryBlue,
                    onDeleted: () => setState(() => _selectedSports.remove(sport)),
                    deleteIconColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  ),
                )).toList(),
              ),
            ),
          
          const SizedBox(height: 24),
          
          Expanded(
            child: ListView(
              children: [
                if (_searchQuery.isNotEmpty) ...[
                  const Text('Arama Sonuçları', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    children: filteredSports.map((sport) => _buildSportActionChip(sport)).toList(),
                  ),
                ] else ...[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(t.popularSports, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
                      Text(t.viewAll, style: const TextStyle(color: MatchFitTheme.accentGreen, fontSize: 14)),
                    ],
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 200,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: [
                        _buildPopularSportCard('Fitness', '1.2k+ Aktif', 'https://images.unsplash.com/photo-1534438327276-14e5300c3a48?q=80&w=400&h=600&auto=format&fit=crop'),
                        const SizedBox(width: 16),
                        _buildPopularSportCard('Yüzme', '840 Aktif', 'https://images.unsplash.com/photo-1530549387074-dcf69c11b052?q=80&w=400&h=600&auto=format&fit=crop'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),
                  Text(t.otherCategories, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
                  const SizedBox(height: 16),
                  GridView.count(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisCount: 2,
                    childAspectRatio: 1.5,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    children: sportsData.map((cat) => _buildCategoryCard(cat)).toList(),
                  ),
                ],
              ],
            ),
          ),
          
          const SizedBox(height: 24),
          
          ElevatedButton(
            onPressed: _isLoading ? null : _submit,
            style: ElevatedButton.styleFrom(
              backgroundColor: MatchFitTheme.accentGreen,
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(vertical: 18),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
            ),
            child: _isLoading
                ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2))
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(t.finishRegistration, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      const SizedBox(width: 8),
                      const Icon(Icons.chevron_right),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildFieldLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        label,
        style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 14),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    IconData? icon,
    IconData? prefixIcon,
    bool obscureText = false,
    TextInputType keyboardType = TextInputType.text,
    VoidCallback? onIconTap,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: Colors.white.withOpacity(0.2)),
        filled: true,
        fillColor: const Color(0xFF1E2020),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        prefixIcon: prefixIcon != null ? Icon(prefixIcon, color: Colors.white.withOpacity(0.3), size: 20) : null,
        suffixIcon: onIconTap != null 
            ? IconButton(icon: Icon(icon, color: Colors.white.withOpacity(0.3), size: 20), onPressed: onIconTap)
            : (icon != null ? Icon(icon, color: Colors.white.withOpacity(0.3), size: 20) : null),
      ),
    );
  }

  Widget _buildDropdownField({
    required String? value,
    required String hint,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E2020),
        borderRadius: BorderRadius.circular(16),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          hint: Text(hint, style: TextStyle(color: Colors.white.withOpacity(0.2))),
          dropdownColor: const Color(0xFF1E2020),
          icon: Icon(Icons.keyboard_arrow_down, color: Colors.white.withOpacity(0.3)),
          isExpanded: true,
          items: items.map((String item) {
            return DropdownMenuItem<String>(
              value: item,
              child: Text(item, style: const TextStyle(color: Colors.white)),
            );
          }).toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }

  Widget _buildCheckboxRow({required bool value, required ValueChanged<bool?> onChanged, required Widget child}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 24,
          height: 24,
          child: Checkbox(
            value: value,
            onChanged: onChanged,
            fillColor: WidgetStateProperty.resolveWith((states) {
              if (states.contains(WidgetState.selected)) return MatchFitTheme.accentGreen;
              return Colors.transparent;
            }),
            checkColor: Colors.black,
            side: BorderSide(color: Colors.white.withOpacity(0.2)),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(child: child),
      ],
    );
  }

  void _showDatePicker() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedBirthDate ?? DateTime(2000),
      firstDate: DateTime(1950),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: MatchFitTheme.accentGreen,
              onPrimary: Colors.black,
              surface: Color(0xFF1E2020),
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
        _birthDateController.text = DateFormat('MM/dd/yyyy').format(picked);
      });
    }
  }

  Widget _buildPopularSportCard(String title, String activeCount, String imageUrl) {
    final isSelected = _selectedSports.contains(title);
    return GestureDetector(
      onTap: () {
        setState(() {
          if (isSelected) _selectedSports.remove(title);
          else _selectedSports.add(title);
        });
      },
      child: Container(
        width: 140,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          image: DecorationImage(
            image: NetworkImage(imageUrl),
            fit: BoxFit.cover,
            colorFilter: ColorFilter.mode(Colors.black.withOpacity(isSelected ? 0.2 : 0.5), BlendMode.darken),
          ),
          border: isSelected ? Border.all(color: MatchFitTheme.accentGreen, width: 2) : null,
        ),
        child: Stack(
          children: [
            Positioned(
              bottom: 12,
              left: 12,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                  Text(activeCount, style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 10)),
                ],
              ),
            ),
            if (isSelected)
              const Positioned(
                top: 12,
                right: 12,
                child: Icon(Icons.check_circle, color: MatchFitTheme.accentGreen),
              )
            else
              Positioned(
                bottom: 12,
                right: 12,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), shape: BoxShape.circle),
                  child: const Icon(Icons.add, color: Colors.white, size: 16),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryCard(SportCategory cat) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1E2020),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(_getIconData(cat.icon), color: MatchFitTheme.primaryBlue, size: 28),
          const SizedBox(height: 8),
          Text(cat.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14), textAlign: TextAlign.center),
          const SizedBox(height: 4),
          Text('${cat.subcategories.length} Branş', style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 10)),
        ],
      ),
    );
  }

  Widget _buildSportActionChip(String sport) {
    final isSelected = _selectedSports.contains(sport);
    return ActionChip(
      label: Text(sport),
      onPressed: () {
        setState(() {
          if (isSelected) _selectedSports.remove(sport);
          else _selectedSports.add(sport);
        });
      },
      backgroundColor: isSelected ? MatchFitTheme.primaryBlue : const Color(0xFF1E2020),
      labelStyle: TextStyle(color: Colors.white, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide.none),
    );
  }

  IconData _getIconData(String name) {
    switch (name) {
      case 'sports_tennis': return Icons.sports_tennis;
      case 'groups': return Icons.groups;
      case 'directions_run': return Icons.directions_run;
      case 'directions_bike': return Icons.directions_bike;
      case 'fitness_center': return Icons.fitness_center;
      case 'terrain': return Icons.terrain;
      case 'waves': return Icons.waves;
      case 'sports_mma': return Icons.sports_mma;
      case 'self_improvement': return Icons.self_improvement;
      case 'ac_unit': return Icons.ac_unit;
      case 'motorcycle': return Icons.motorcycle;
      default: return Icons.sports;
    }
  }
}
