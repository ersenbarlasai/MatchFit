import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:matchfit/core/theme.dart';
import 'package:matchfit/core/constants/sports_data.dart';
import 'package:matchfit/core/constants/location_data.dart';
import '../providers/coach_provider.dart';

class BecomeCoachScreen extends ConsumerStatefulWidget {
  const BecomeCoachScreen({super.key});

  @override
  ConsumerState<BecomeCoachScreen> createState() => _BecomeCoachScreenState();
}

class _BecomeCoachScreenState extends ConsumerState<BecomeCoachScreen> {
  int _currentStep = 1;
  bool _isLoading = false;

  // Step 1: Basic Info
  String? _selectedCategory;
  String? _selectedSport;
  int _experienceYears = 1;
  final _bioController = TextEditingController();

  // Step 2 & 3: Documents
  XFile? _idFrontImage;
  XFile? _idBackImage;
  XFile? _selfieImage;
  XFile? _certificateImage;

  // Step 4: Location
  String? _selectedProvince;
  String? _selectedDistrict;

  // Step 5: Video
  final _videoUrlController = TextEditingController();

  final _picker = ImagePicker();

  @override
  void dispose() {
    _bioController.dispose();
    _videoUrlController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(String type) async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    if (image == null) return;
    
    setState(() {
      if (type == 'idFront') _idFrontImage = image;
      else if (type == 'idBack') _idBackImage = image;
      else if (type == 'selfie') _selfieImage = image;
      else if (type == 'certificate') _certificateImage = image;
    });
  }

  void _nextStep() {
    if (_currentStep == 1) {
      if (_selectedSport == null || _bioController.text.trim().isEmpty) {
        _showError('Lütfen branş seçin ve kısa özgeçmişinizi doldurun.');
        return;
      }
    } else if (_currentStep == 2) {
      if (_idFrontImage == null || _idBackImage == null || _selfieImage == null) {
        _showError('Kimlik doğrulaması için ön, arka ve selfie fotoğrafları zorunludur.');
        return;
      }
    } else if (_currentStep == 3) {
      if (_certificateImage == null) {
        _showError('Antrenörlük belgesi veya sertifika yüklemeniz zorunludur.');
        return;
      }
    } else if (_currentStep == 4) {
      if (_selectedProvince == null || _selectedDistrict == null) {
        _showError('Lütfen görev yapacağınız şehri ve ilçeyi seçin.');
        return;
      }
    } else if (_currentStep == 5) {
      if (_videoUrlController.text.trim().isEmpty) {
        _showError('Tanıtım videosu linki güven için kritik bir adımdır.');
        return;
      }
    }

    if (_currentStep < 6) {
      setState(() => _currentStep++);
    }
  }

  void _prevStep() {
    if (_currentStep > 1) {
      setState(() => _currentStep--);
    } else {
      context.pop();
    }
  }

  Future<void> _submitApplication() async {
    setState(() => _isLoading = true);
    try {
      final repo = ref.read(coachEngineRepositoryProvider);

      // 1. Save Basic Info FIRST to create the coach record
      final payload = {
        'sub_branch': _selectedSport,
        'experience_years': _experienceYears,
        'bio': _bioController.text.trim(),
        'work_location': '$_selectedDistrict, $_selectedProvince',
        'intro_video_url': _videoUrlController.text.trim(),
      };
      await repo.saveBasicInfo(payload);

      // 2. Upload Documents (requires coach record to exist for foreign key)
      if (_idFrontImage != null) await repo.uploadDocument(_idFrontImage!, 'id_card_front');
      if (_idBackImage != null) await repo.uploadDocument(_idBackImage!, 'id_card_back');
      if (_selfieImage != null) await repo.uploadDocument(_selfieImage!, 'selfie');
      if (_certificateImage != null) await repo.uploadDocument(_certificateImage!, 'certificate');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Başvurunuz başarıyla alındı! İnceleme sürecine girdi.')),
        );
        context.pop();
      }
    } catch (e) {
      _showError('Bir hata oluştu: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.red));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: _prevStep,
        ),
        title: const Text(
          'Koç Başvurusu',
          style: TextStyle(color: MatchFitTheme.accentGreen, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          // Linear Progress indicator
          LinearProgressIndicator(
            value: _currentStep / 6,
            backgroundColor: Colors.white10,
            valueColor: const AlwaysStoppedAnimation<Color>(MatchFitTheme.accentGreen),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_currentStep == 1) _buildStep1(),
                  if (_currentStep == 2) _buildStep2(),
                  if (_currentStep == 3) _buildStep3(),
                  if (_currentStep == 4) _buildStep4(),
                  if (_currentStep == 5) _buildStep5(),
                  if (_currentStep == 6) _buildStep6(),
                  
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: SizedBox(
            height: 56,
            child: ElevatedButton(
              onPressed: _isLoading ? null : (_currentStep == 6 ? _submitApplication : _nextStep),
              style: ElevatedButton.styleFrom(
                backgroundColor: MatchFitTheme.accentGreen,
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
              ),
              child: _isLoading 
                  ? const CircularProgressIndicator(color: Colors.black)
                  : Text(
                      _currentStep == 6 ? 'Başvuruyu Gönder' : 'Sonraki Adım',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStep1() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Temel Bilgiler', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        const Text('Uzmanlık alanınızı ve deneyiminizi bizimle paylaşın.', style: TextStyle(color: Colors.white54, fontSize: 14)),
        const SizedBox(height: 32),
        
        _buildLabel('Ana Kategori'),
        _buildDropdown(
          value: _selectedCategory,
          hint: 'Kategori Seçin',
          items: sportsData.map((e) => e.name).toList(),
          onChanged: (val) => setState(() {
            _selectedCategory = val;
            _selectedSport = null;
          }),
        ),
        const SizedBox(height: 16),
        
        _buildLabel('Uzmanlık (Branş)'),
        _buildDropdown(
          value: _selectedSport,
          hint: 'Branş Seçin',
          items: _selectedCategory != null 
              ? sportsData.firstWhere((e) => e.name == _selectedCategory).subcategories 
              : [],
          onChanged: (val) => setState(() => _selectedSport = val),
        ),
        const SizedBox(height: 16),

        _buildLabel('Deneyim Yılı ($_experienceYears Yıl)'),
        Slider(
          value: _experienceYears.toDouble(),
          min: 1, max: 30, divisions: 29,
          activeColor: MatchFitTheme.accentGreen,
          onChanged: (val) => setState(() => _experienceYears = val.toInt()),
        ),
        const SizedBox(height: 16),

        _buildLabel('Kısa Biyografi (Bio)'),
        TextField(
          controller: _bioController,
          maxLines: 4,
          style: const TextStyle(color: Colors.white),
          decoration: _inputDecoration('Kendinizi kısaca tanıtın...'),
        ),
      ],
    );
  }

  Widget _buildStep2() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Kimlik Doğrulama', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        const Text('Güvenlik standartlarımız gereği kimlik doğrulaması zorunludur.', style: TextStyle(color: Colors.white54, fontSize: 14)),
        const SizedBox(height: 32),
        
        _buildImageUploadBox('Kimlik Ön Yüzü', _idFrontImage, () => _pickImage('idFront')),
        const SizedBox(height: 16),
        _buildImageUploadBox('Kimlik Arka Yüzü', _idBackImage, () => _pickImage('idBack')),
        const SizedBox(height: 16),
        _buildImageUploadBox('Net Bir Selfie', _selfieImage, () => _pickImage('selfie')),
      ],
    );
  }

  Widget _buildStep3() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Belge Yükleme', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        const Text('Antrenörlük belgesi, sertifika veya diplomalarınızı yükleyin.', style: TextStyle(color: Colors.white54, fontSize: 14)),
        const SizedBox(height: 32),
        
        _buildImageUploadBox('Sertifika / Belge', _certificateImage, () => _pickImage('certificate')),
      ],
    );
  }

  Widget _buildStep4() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Çalışma Alanı', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        const Text('Hangi bölgede ders vereceğinizi seçin.', style: TextStyle(color: Colors.white54, fontSize: 14)),
        const SizedBox(height: 32),
        
        _buildLabel('İl (Şehir)'),
        _buildDropdown(
          value: _selectedProvince,
          hint: 'Şehir Seçin',
          items: turkeyProvinces.keys.toList(),
          onChanged: (val) => setState(() {
            _selectedProvince = val;
            _selectedDistrict = null;
          }),
        ),
        const SizedBox(height: 16),
        
        _buildLabel('İlçe'),
        _buildDropdown(
          value: _selectedDistrict,
          hint: 'İlçe Seçin',
          items: _selectedProvince != null ? turkeyProvinces[_selectedProvince]! : [],
          onChanged: (val) => setState(() => _selectedDistrict = val),
        ),
      ],
    );
  }

  Widget _buildStep5() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Tanıtım Videosu', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        const Text('Öğrencilerin sizi seçmesinde video %80 daha etkilidir. 30-60 saniyelik bir Youtube veya Instagram Reels linki yapıştırın.', style: TextStyle(color: Colors.white54, fontSize: 14)),
        const SizedBox(height: 32),
        
        _buildLabel('Video URL (YouTube / Reels)'),
        TextField(
          controller: _videoUrlController,
          style: const TextStyle(color: Colors.white),
          decoration: _inputDecoration('https://...'),
        ),
      ],
    );
  }

  Widget _buildStep6() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const SizedBox(height: 40),
        const Icon(Icons.verified_user_outlined, color: MatchFitTheme.accentGreen, size: 80),
        const SizedBox(height: 24),
        const Text('Başvurunuz Hazır!', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        const Text(
          'Tüm belgeleriniz sisteme yüklenecek ve tarafımızdan incelenecektir. Sahte belge kullanımı tespit edilirse hesabınız kalıcı olarak silinecektir.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white54, fontSize: 14, height: 1.5),
        ),
        const SizedBox(height: 32),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.red.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.red.withOpacity(0.3)),
          ),
          child: const Row(
            children: [
              Icon(Icons.gavel, color: Colors.red),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Bu işlem hukuki bağlayıcılığa sahiptir. Paylaştığınız bilgilerin doğruluğunu taahhüt etmiş olursunuz.',
                  style: TextStyle(color: Colors.redAccent, fontSize: 12),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Text(text, style: const TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.w600)),
    );
  }

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: Colors.white24),
      filled: true,
      fillColor: const Color(0xFF1E1E1E),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
    );
  }

  Widget _buildDropdown({required String? value, required String hint, required List<String> items, required Function(String?) onChanged}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(12),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          hint: Text(hint, style: const TextStyle(color: Colors.white24)),
          dropdownColor: const Color(0xFF1E1E1E),
          isExpanded: true,
          style: const TextStyle(color: Colors.white),
          icon: const Icon(Icons.arrow_drop_down, color: MatchFitTheme.accentGreen),
          items: items.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }

  Widget _buildImageUploadBox(String title, XFile? file, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        height: 120,
        decoration: BoxDecoration(
          color: const Color(0xFF1E1E1E),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: file != null ? MatchFitTheme.accentGreen : Colors.white10),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(file != null ? Icons.check_circle : Icons.cloud_upload, color: file != null ? MatchFitTheme.accentGreen : Colors.white38, size: 32),
            const SizedBox(height: 8),
            Text(title, style: TextStyle(color: file != null ? Colors.white : Colors.white54, fontWeight: FontWeight.bold)),
            if (file != null) 
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Text('Seçildi: ${file.name}', style: const TextStyle(color: MatchFitTheme.accentGreen, fontSize: 12)),
              ),
          ],
        ),
      ),
    );
  }
}
