import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';

class CoachEngineRepository {
  final _supabase = Supabase.instance.client;

  /// Get current coach profile (if exists)
  Future<Map<String, dynamic>?> getCoachProfile(String userId) async {
    try {
      final response = await _supabase
          .from('coaches')
          .select()
          .eq('user_id', userId)
          .maybeSingle();
      return response;
    } catch (e) {
      debugPrint('[@CoachEngine] Error fetching coach profile: $e');
      return null;
    }
  }

  /// Get dynamic landing page content for coach onboarding
  Future<Map<String, dynamic>?> getCoachLandingContent() async {
    try {
      final response = await _supabase
          .from('coach_landing_content')
          .select()
          .eq('id', 1)
          .maybeSingle();
      return response;
    } catch (e) {
      debugPrint('[@CoachEngine] Error fetching landing content: $e');
      return null;
    }
  }

  /// Create or update coach application (Basic Info)
  Future<void> saveBasicInfo(Map<String, dynamic> data) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) throw Exception('Kullanıcı bulunamadı');

      final payload = {
        ...data,
        'user_id': user.id,
        'verification_level': 'pending', // Starts pending
        'updated_at': DateTime.now().toIso8601String(),
      };

      await _supabase.from('coaches').upsert(payload);
      
      // Log for Verification Agent
      await _logAgentAction(
        user.id, 
        '@CoachVerificationAgent', 
        'application_started', 
        {'step': 'basic_info'}
      );
    } catch (e) {
      debugPrint('[@CoachEngine] Error saving basic info: $e');
      rethrow;
    }
  }

  /// Upload verification document
  Future<String> uploadDocument(XFile file, String docType) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) throw Exception('Kullanıcı bulunamadı');

      final ext = file.name.split('.').last;
      final fileName = '${user.id}_${docType}_${DateTime.now().millisecondsSinceEpoch}.$ext';
      final path = 'coach_documents/$fileName';

      // Upload to storage using bytes for web/desktop compatibility
      final bytes = await file.readAsBytes();
      await _supabase.storage.from('documents').uploadBinary(
        path, 
        bytes,
        fileOptions: FileOptions(contentType: 'image/$ext'),
      );
      final fileUrl = _supabase.storage.from('documents').getPublicUrl(path);

      // Save to coach_documents table
      await _supabase.from('coach_documents').insert({
        'coach_id': user.id,
        'doc_type': docType,
        'file_url': fileUrl,
        'status': 'pending',
      });

      // Log for Verification Agent
      await _logAgentAction(
        user.id, 
        '@CoachVerificationAgent', 
        'document_uploaded', 
        {'doc_type': docType, 'url': fileUrl}
      );

      return fileUrl;
    } catch (e) {
      debugPrint('[@CoachEngine] Error uploading document: $e');
      rethrow;
    }
  }

  /// Internal log function for Agent memory
  Future<void> _logAgentAction(String coachId, String agentName, String actionType, Map<String, dynamic> details) async {
    try {
      await _supabase.from('coach_verification_logs').insert({
        'coach_id': coachId,
        'agent_name': agentName,
        'action_type': actionType,
        'details': details,
      });
    } catch (e) {
      debugPrint('[@CoachEngine] Failed to log agent action: $e');
    }
  }

  // ── Admin Methods ─────────────────────────────────────────────────────────

  /// Fetch all coaches regardless of status for full administration
  Future<List<Map<String, dynamic>>> getAllCoaches() async {
    try {
      final response = await _supabase
          .from('coaches')
          .select('*, coach_documents(*)')
          .order('updated_at', ascending: false);
      
      final coaches = List<Map<String, dynamic>>.from(response);

      for (var coach in coaches) {
        final profileResponse = await _supabase
            .from('profiles')
            .select('full_name, avatar_url, role')
            .eq('id', coach['user_id'])
            .maybeSingle();
        
        coach['profiles'] = profileResponse;
      }

      return coaches;
    } catch (e) {
      debugPrint('[@CoachEngine] Error fetching all coaches: $e');
      return [];
    }
  }

  /// Fetch all coaches with 'pending' verification status
  Future<List<Map<String, dynamic>>> getPendingCoaches() async {
    try {
      final response = await _supabase
          .from('coaches')
          .select('*, coach_documents(*)')
          .eq('verification_level', 'pending')
          .order('created_at', ascending: false);
      
      final coaches = List<Map<String, dynamic>>.from(response);

      for (var coach in coaches) {
        final profileResponse = await _supabase
            .from('profiles')
            .select('full_name, avatar_url')
            .eq('id', coach['user_id'])
            .maybeSingle();
        
        coach['profiles'] = profileResponse;
      }

      return coaches;
    } catch (e) {
      debugPrint('[@CoachEngine] Error fetching pending coaches: $e');
      return [];
    }
  }

  /// Update coach verification level and active status
  Future<void> updateCoachStatus({
    required String userId,
    required String level,
    required bool isActive,
    String? reason,
  }) async {
    try {
      await _supabase.from('coaches').update({
        'verification_level': level,
        'is_active': isActive,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('user_id', userId);

      // Log the decision
      await _logAgentAction(
        userId, 
        '@CoachVerificationAgent', 
        isActive ? 'coach_approved' : 'coach_rejected', 
        {'level': level, 'reason': reason}
      );
    } catch (e) {
      debugPrint('[@CoachEngine] Error updating coach status: $e');
      rethrow;
    }
  }

  /// Update individual document status
  Future<void> updateDocumentStatus(String docId, String status, {String? reason}) async {
    try {
      await _supabase.from('coach_documents').update({
        'status': status,
        'rejection_reason': reason,
        'reviewed_at': DateTime.now().toIso8601String(),
        'reviewed_by': _supabase.auth.currentUser?.id,
      }).eq('id', docId);
    } catch (e) {
      debugPrint('[@CoachEngine] Error updating document status: $e');
      rethrow;
    }
  }
}
