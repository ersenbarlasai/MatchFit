import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:matchfit/core/theme.dart';
import '../repositories/event_repository.dart';
import '../../auth/repositories/auth_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../referee/repositories/referee_repository.dart';
import 'package:matchfit/core/services/location_search_service.dart';
import 'package:matchfit/core/constants/location_data.dart';
import 'package:matchfit/core/constants/sports_data.dart';
import 'dart:async';

class CreateEventScreen extends ConsumerStatefulWidget {
  const CreateEventScreen({super.key});

  @override
  ConsumerState<CreateEventScreen> createState() => _CreateEventScreenState();
}

class _CreateEventScreenState extends ConsumerState<CreateEventScreen> {
  int _currentStep = 1;
  final _titleController = TextEditingController();
  final _venueController = TextEditingController();
  final _descriptionController = TextEditingController();
  
  String selectedCountry = 'Türkiye';
  String? selectedProvince;
  String? selectedDistrict;
  
  String? selectedCategory;
  String? selectedSport;
  String requiredLevel = 'Başlangıç';
  bool isIndoor = false;
  int maxParticipants = 12;
  DateTime? selectedDate;
  TimeOfDay? selectedTime;
  bool _isLoading = false;

  // Location search state
  final _searchService = LocationSearchService();
  List<LocationSuggestion> _suggestions = [];
  Timer? _debounce;
  double? _selectedLat;
  double? _selectedLng;

  void _onLocationChanged(String value) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () async {
      if (value.length > 2) {
        final contextStr = '${selectedDistrict ?? ''} ${selectedProvince ?? ''} $selectedCountry';
        final results = await _searchService.search('$value $contextStr'.trim());
        setState(() => _suggestions = results);
      } else {
        setState(() => _suggestions = []);
      }
    });
  }

  void _nextStep() {
    if (_currentStep == 1) {
      if (selectedCategory == null || selectedSport == null) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Lütfen kategori ve alt branş seçin')));
        return;
      }
      setState(() => _currentStep = 2);
    } else if (_currentStep == 2) {
      if (selectedDate == null || selectedTime == null || _titleController.text.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Lütfen tarih, saat ve başlık girin')));
        return;
      }
      setState(() => _currentStep = 3);
    }
  }

  Future<void> _publishEvent() async {
    if (selectedProvince == null || selectedDistrict == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Lütfen konum bilgilerini tamamlayın')));
      return;
    }

    setState(() => _isLoading = true);
    try {
      final authRepo = ref.read(authRepositoryProvider);
      final currentUser = authRepo.currentUser;
      if (currentUser == null) throw Exception('You must be logged in to create an event');

      final refereeRepo = ref.read(refereeRepositoryProvider);
      final isRestricted = await refereeRepo.isUserRestricted(currentUser.id);
      if (isRestricted) {
        throw Exception('Hakem Temsilcisi: Ceza aldığınız için şu an etkinlik oluşturamazsınız.');
      }

      final sportResponse = await Supabase.instance.client
          .from('sports')
          .select('id')
          .ilike('name', selectedSport!)
          .maybeSingle();
          
      if (sportResponse == null) {
        throw Exception('"$selectedSport" branşı veritabanında bulunamadı. Lütfen SQL scriptini çalıştırın.');
      }

      final eventDate = DateTime(
        selectedDate!.year, selectedDate!.month, selectedDate!.day,
      );
      
      final formattedTime = '${selectedTime!.hour.toString().padLeft(2, '0')}:${selectedTime!.minute.toString().padLeft(2, '0')}:00';

      final fullLocationName = '$selectedDistrict, $selectedProvince, $selectedCountry${_venueController.text.isNotEmpty ? ' - ${_venueController.text}' : ''}';

      final eventData = {
        'title': _titleController.text,
        'description': _descriptionController.text,
        'event_date': eventDate.toIso8601String().split('T')[0],
        'start_time': formattedTime,
        'location_name': fullLocationName,
        'lat': _selectedLat,
        'lng': _selectedLng,
        'max_participants': maxParticipants,
        'required_level': requiredLevel,
        'is_indoor': isIndoor,
        'sport_id': sportResponse['id'],
        'host_id': currentUser.id,
        'status': 'open',
      };

      await ref.read(eventRepositoryProvider).createEvent(eventData);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Etkinlik başarıyla yayınlandı!')),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Hata: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
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
          onPressed: () {
            if (_currentStep > 1) {
              setState(() => _currentStep--);
            } else {
              context.pop();
            }
          },
        ),
        title: Row(
          children: [
            const Text(
              'MATCHFIT',
              style: TextStyle(
                color: MatchFitTheme.accentGreen,
                fontWeight: FontWeight.w900,
                fontStyle: FontStyle.italic,
                fontSize: 22,
              ),
            ),
            const Spacer(),
            const Icon(Icons.notifications_none, color: Colors.white),
            const SizedBox(width: 16),
            CircleAvatar(
              radius: 16,
              backgroundImage: NetworkImage(ref.read(authRepositoryProvider).currentUser?.userMetadata?['avatar_url'] ?? 'https://i.pravatar.cc/150?u=me'),
            ),
          ],
        ),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 16),
              // Progress Bar
              Row(
                children: [
                  Expanded(child: _buildProgressSegment(1)),
                  const SizedBox(width: 8),
                  Expanded(child: _buildProgressSegment(2)),
                  const SizedBox(width: 8),
                  Expanded(child: _buildProgressSegment(3)),
                ],
              ),
              const SizedBox(height: 32),
              
              if (_currentStep == 1) _buildStep1(),
              if (_currentStep == 2) _buildStep2(),
              if (_currentStep == 3) _buildStep3(),
              
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  Widget _buildProgressSegment(int step) {
    bool active = _currentStep >= step;
    return Container(
      height: 6,
      decoration: BoxDecoration(
        color: active ? MatchFitTheme.accentGreen : Colors.white12,
        borderRadius: BorderRadius.circular(3),
      ),
    );
  }

  Widget _buildStep1() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Etkinlik Oluştur',
          style: TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Text(
          'Performansını paylaşmak için ilk adımı at.',
          style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 16),
        ),
        const SizedBox(height: 32),
        
        _buildLabel('Kategori Seç'),
        _buildCustomDropdown(
          value: selectedCategory,
          hint: 'Kategori Seç',
          items: sportsData.map((c) => c.name).toList(),
          onChanged: (val) => setState(() {
            selectedCategory = val;
            selectedSport = null;
          }),
        ),
        const SizedBox(height: 24),
        
        _buildLabel('Alt Branş Seç'),
        _buildCustomDropdown(
          value: selectedSport,
          hint: 'Alt Branş Seç',
          items: selectedCategory != null 
            ? sportsData.firstWhere((c) => c.name == selectedCategory).subcategories 
            : [],
          onChanged: (val) => setState(() => selectedSport = val),
        ),
        const SizedBox(height: 24),
        
        _buildLabel('Seviye'),
        _buildSegmentedControl(
          options: ['Başlangıç', 'Orta', 'İleri'],
          current: requiredLevel,
          onSelect: (val) => setState(() => requiredLevel = val),
        ),
        const SizedBox(height: 24),
        
        // Mekan & Indoor/Outdoor Card
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A1A),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Mekan', style: TextStyle(color: Colors.white70, fontSize: 14)),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Açık / Kapalı', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                  Switch(
                    value: isIndoor,
                    onChanged: (val) => setState(() => isIndoor = val),
                    activeColor: MatchFitTheme.accentGreen,
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        
        // Katılımcı Sayısı Card
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A1A),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('KATILIMCI SAYISI', style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildCounterButton(Icons.remove, () {
                    if (maxParticipants > 2) setState(() => maxParticipants--);
                  }),
                  Text(
                    maxParticipants.toString(),
                    style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  _buildCounterButton(Icons.add, () {
                    if (maxParticipants < 50) setState(() => maxParticipants++);
                  }, isPrimary: true),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 32),
        
        _buildNextButton(),
        
        const SizedBox(height: 32),
        _buildProTip(),
      ],
    );
  }

  Widget _buildStep2() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Zaman ve Detaylar',
          style: TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Text(
          'Etkinliğin ne zaman ve ne hakkında olduğunu belirt.',
          style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 16),
        ),
        const SizedBox(height: 32),
        
        _buildLabel('Başlık'),
        _buildCustomTextField(
          controller: _titleController,
          hint: 'Etkinlik başlığı (örn: Sabah Tenisi)',
        ),
        const SizedBox(height: 24),
        
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildLabel('Tarih'),
                  _buildPickerTile(
                    label: selectedDate == null ? 'Seç' : '${selectedDate!.day}/${selectedDate!.month}',
                    icon: Icons.calendar_today,
                    onTap: () async {
                      final date = await showDatePicker(
                        context: context,
                        initialDate: DateTime.now(),
                        firstDate: DateTime.now(),
                        lastDate: DateTime.now().add(const Duration(days: 30)),
                      );
                      if (date != null) setState(() => selectedDate = date);
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildLabel('Saat'),
                  _buildPickerTile(
                    label: selectedTime == null ? 'Seç' : selectedTime!.format(context),
                    icon: Icons.access_time,
                    onTap: () async {
                      final time = await showTimePicker(
                        context: context,
                        initialTime: TimeOfDay.now(),
                      );
                      if (time != null) setState(() => selectedTime = time);
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        
        _buildLabel('Açıklama (Opsiyonel)'),
        _buildCustomTextField(
          controller: _descriptionController,
          hint: 'Etkinlik hakkında detaylar...',
          maxLines: 4,
        ),
        const SizedBox(height: 32),
        
        _buildNextButton(),
      ],
    );
  }

  Widget _buildStep3() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Konum Seç',
          style: TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Text(
          'Etkinliğin nerede gerçekleşeceğini belirle.',
          style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 16),
        ),
        const SizedBox(height: 32),
        
        _buildLabel('Ülke'),
        _buildCustomDropdown(
          value: selectedCountry,
          items: countries,
          onChanged: (val) => setState(() {
            selectedCountry = val!;
            selectedProvince = null;
            selectedDistrict = null;
          }),
        ),
        const SizedBox(height: 20),
        
        _buildLabel('Şehir (İl)'),
        _buildCustomDropdown(
          value: selectedProvince,
          hint: 'Şehir Seç',
          items: turkeyProvinces.keys.toList(),
          onChanged: (val) => setState(() {
            selectedProvince = val;
            selectedDistrict = null;
          }),
        ),
        const SizedBox(height: 20),
        
        _buildLabel('İlçe'),
        _buildCustomDropdown(
          value: selectedDistrict,
          hint: 'İlçe Seç',
          items: selectedProvince != null ? turkeyProvinces[selectedProvince]! : [],
          onChanged: (val) => setState(() => selectedDistrict = val),
        ),
        const SizedBox(height: 24),
        
        _buildLabel('Mekan Arama / Sokak'),
        _buildCustomTextField(
          controller: _venueController,
          hint: 'Park, saha, salon adı...',
          onChanged: _onLocationChanged,
          prefixIcon: Icons.place_outlined,
        ),
        
        if (_suggestions.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(top: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF1A1A1A),
              borderRadius: BorderRadius.circular(16),
            ),
            child: ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _suggestions.length,
              separatorBuilder: (_, __) => const Divider(color: Colors.white12, height: 1),
              itemBuilder: (context, index) {
                final s = _suggestions[index];
                return ListTile(
                  title: Text(s.description, style: const TextStyle(color: Colors.white70, fontSize: 13)),
                  onTap: () {
                    setState(() {
                      _venueController.text = s.description;
                      _selectedLat = s.lat;
                      _selectedLng = s.lng;
                      _suggestions = [];
                    });
                  },
                );
              },
            ),
          ),
        
        const SizedBox(height: 32),
        
        SizedBox(
          width: double.infinity,
          height: 64,
          child: ElevatedButton(
            onPressed: _isLoading ? null : _publishEvent,
            style: ElevatedButton.styleFrom(
              backgroundColor: MatchFitTheme.accentGreen,
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(32)),
              elevation: 8,
              shadowColor: MatchFitTheme.accentGreen.withOpacity(0.4),
            ),
            child: _isLoading 
              ? const CircularProgressIndicator(color: Colors.black)
              : const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('ETKİNLİĞİ YAYINLA', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                    SizedBox(width: 8),
                    Icon(Icons.check_circle_outline),
                  ],
                ),
          ),
        ),
      ],
    );
  }

  Widget _buildLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Text(text, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w500)),
    );
  }

  Widget _buildCustomDropdown({String? value, String? hint, required List<String> items, required Function(String?) onChanged}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white12),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: (value != null && items.contains(value)) ? value : null,
          hint: hint != null ? Text(hint, style: const TextStyle(color: Colors.white54)) : null,
          dropdownColor: const Color(0xFF1A1A1A),
          icon: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.keyboard_arrow_down, color: MatchFitTheme.accentGreen, size: 18),
              Icon(Icons.keyboard_arrow_down, color: Colors.white30, size: 18),
            ],
          ),
          isExpanded: true,
          style: const TextStyle(color: Colors.white, fontSize: 16),
          items: items.map((item) => DropdownMenuItem(value: item, child: Text(item))).toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }

  Widget _buildSegmentedControl({required List<String> options, required String current, required Function(String) onSelect}) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: options.map((o) {
          bool active = o == current;
          return Expanded(
            child: GestureDetector(
              onTap: () => onSelect(o),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: active ? MatchFitTheme.accentGreen : Colors.transparent,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  o,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: active ? Colors.black : Colors.white54,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildCounterButton(IconData icon, VoidCallback onTap, {bool isPrimary = false}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isPrimary ? MatchFitTheme.accentGreen : Colors.white.withOpacity(0.05),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: isPrimary ? Colors.black : Colors.white, size: 24),
      ),
    );
  }

  Widget _buildNextButton() {
    return SizedBox(
      width: double.infinity,
      height: 64,
      child: ElevatedButton(
        onPressed: _nextStep,
        style: ElevatedButton.styleFrom(
          backgroundColor: MatchFitTheme.accentGreen,
          foregroundColor: Colors.black,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(32)),
          elevation: 8,
          shadowColor: MatchFitTheme.accentGreen.withOpacity(0.4),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('SONRAKİ ADIM', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
            SizedBox(width: 8),
            Icon(Icons.arrow_forward),
          ],
        ),
      ),
    );
  }

  Widget _buildProTip() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(32),
        image: DecorationImage(
          image: const NetworkImage('https://images.unsplash.com/photo-1534438327276-14e5300c3a48?q=80&w=2070&auto=format&fit=crop'),
          fit: BoxFit.cover,
          colorFilter: ColorFilter.mode(Colors.black.withOpacity(0.7), BlendMode.darken),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.blue.withOpacity(0.3),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.blue.withOpacity(0.5)),
            ),
            child: const Text('PRO TİP', style: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold, fontSize: 12)),
          ),
          const SizedBox(height: 12),
          const Text(
            'Grup etkinlikleri %40 daha hızlı\neşleşme sağlar.',
            style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildCustomTextField({required TextEditingController controller, required String hint, int maxLines = 1, Function(String)? onChanged, IconData? prefixIcon}) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      onChanged: onChanged,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Colors.white30),
        prefixIcon: prefixIcon != null ? Icon(prefixIcon, color: Colors.white30) : null,
        filled: true,
        fillColor: const Color(0xFF1A1A1A),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none),
        contentPadding: const EdgeInsets.all(20),
      ),
    );
  }

  Widget _buildPickerTile({required String label, required IconData icon, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A1A),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white10),
        ),
        child: Row(
          children: [
            Icon(icon, color: Colors.white54, size: 20),
            const SizedBox(width: 12),
            Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomNav() {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.black,
        border: Border(top: BorderSide(color: Colors.white10)),
      ),
      child: BottomNavigationBar(
        backgroundColor: Colors.transparent,
        type: BottomNavigationBarType.fixed,
        selectedItemColor: MatchFitTheme.accentGreen,
        unselectedItemColor: Colors.white54,
        showSelectedLabels: true,
        showUnselectedLabels: true,
        currentIndex: 2, // Always highlight Create
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home_outlined), label: 'ANA SAYFA'),
          BottomNavigationBarItem(icon: Icon(Icons.explore_outlined), label: 'KEŞFET'),
          BottomNavigationBarItem(icon: Icon(Icons.add_circle, size: 40), label: 'OLUŞTUR'),
          BottomNavigationBarItem(icon: Icon(Icons.chat_bubble_outline), label: 'MESAJLAR'),
          BottomNavigationBarItem(icon: Icon(Icons.person_outline), label: 'PROFİL'),
        ],
      ),
    );
  }
}
