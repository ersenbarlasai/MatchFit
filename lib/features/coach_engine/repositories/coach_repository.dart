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

      await _supabase.rpc('submit_coach_application', params: {
        'p_sub_branch': data['sub_branch'],
        'p_experience_years': data['experience_years'],
        'p_bio': data['bio'],
        'p_work_location': data['work_location'],
        'p_intro_video_url': data['intro_video_url'],
        'p_price_min': data['price_min'],
        'p_price_max': data['price_max'],
      });
      
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

      // Save using RPC for hardening
      await _supabase.rpc('submit_coach_document', params: {
        'p_doc_type': docType,
        'p_file_url': fileUrl,
        'p_idempotency_key': '${user.id}_${docType}_${file.name}_${DateTime.now().millisecondsSinceEpoch}',
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
      await _supabase.rpc('log_coach_verification_event', params: {
        'p_coach_id': coachId,
        'p_agent_name': agentName,
        'p_action_type': actionType,
        'p_details': details,
      });
    } catch (e) {
      debugPrint('[@CoachEngine] Failed to log agent action: $e');
    }
  }

  Future<List<Map<String, dynamic>>> getActiveCoaches() async {
    try {
      final response = await _supabase
          .from('coaches')
          .select()
          .eq('is_active', true)
          .inFilter('verification_level', ['basic', 'certified', 'elite'])
          .order('verification_level', ascending: false)
          .order('rating_avg', ascending: false);

      final coaches = List<Map<String, dynamic>>.from(response);

      for (final coach in coaches) {
        final profileResponse = await _supabase
            .from('profiles')
            .select('full_name, avatar_url, city, district, trust_score, bio')
            .eq('id', coach['user_id'])
            .maybeSingle();
        coach['profiles'] = profileResponse;
      }

      return coaches;
    } catch (e) {
      debugPrint('[@CoachEngine] Error fetching active coaches: $e');
      return [];
    }
  }

  Future<Map<String, dynamic>?> getCoachDetail(String userId) async {
    try {
      final response = await _supabase
          .from('coaches')
          .select('*, coach_documents(*)')
          .eq('user_id', userId)
          .maybeSingle();

      if (response == null) return null;

      final coach = Map<String, dynamic>.from(response);
      final profileResponse = await _supabase
          .from('profiles')
          .select('full_name, avatar_url, city, district, trust_score, bio')
          .eq('id', userId)
          .maybeSingle();
      coach['profiles'] = profileResponse;
      return coach;
    } catch (e) {
      debugPrint('[@CoachEngine] Error fetching coach detail: $e');
      return null;
    }
  }

  // ── Availability & Booking Methods ────────────────────────────────────────

  Future<List<Map<String, dynamic>>> getCoachAvailability(String coachId) async {
    try {
      final response = await _supabase.rpc('get_coach_availability', params: {
        'p_coach_id': coachId,
      });
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('[@CoachEngine] Error fetching availability: $e');
      return [];
    }
  }

  Future<void> upsertCoachAvailability(List<Map<String, dynamic>> slots) async {
    try {
      await _supabase.rpc('upsert_coach_availability', params: {
        'p_slots': slots,
      });
    } catch (e) {
      debugPrint('[@CoachEngine] Error upserting availability: $e');
      rethrow;
    }
  }

  Future<String> requestCoachSession({
    required String coachId,
    required String date,
    required String startTime,
    required String endTime,
    String? idempotencyKey,
  }) async {
    try {
      final response = await _supabase.rpc('request_coach_session', params: {
        'p_coach_id': coachId,
        'p_session_date': date,
        'p_start_time': startTime,
        'p_end_time': endTime,
        'p_idempotency_key': idempotencyKey,
      });
      return response as String;
    } catch (e) {
      debugPrint('[@CoachEngine] Error requesting session: $e');
      rethrow;
    }
  }

  Future<void> handleCoachSessionRequest({
    required String sessionId,
    required String action,
    String? reason,
  }) async {
    try {
      await _supabase.rpc('handle_coach_session_request', params: {
        'p_session_id': sessionId,
        'p_action': action,
        'p_reason': reason,
      });
    } catch (e) {
      debugPrint('[@CoachEngine] Error handling session request: $e');
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> getMyCoachSessions() async {
    try {
      final response = await _supabase.rpc('get_my_coach_sessions');
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('[@CoachEngine] Error fetching my sessions: $e');
      return [];
    }
  }

  Future<void> submitCoachReview({
    required String sessionId,
    required int rating,
    String? comment,
    String? idempotencyKey,
  }) async {
    try {
      await _supabase.rpc('submit_coach_review', params: {
        'p_session_id': sessionId,
        'p_rating': rating,
        'p_comment': comment,
        'p_idempotency_key': idempotencyKey,
      });
    } catch (e) {
      debugPrint('[@CoachEngine] Error submitting review: $e');
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> getCoachReviews(String coachId) async {
    try {
      final response = await _supabase.rpc('get_coach_reviews', params: {
        'p_coach_id': coachId,
      });
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('[@CoachEngine] Error fetching reviews: $e');
      return [];
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
      await _supabase.rpc('handle_coach_verification', params: {
        'p_user_id': userId,
        'p_level': level,
        'p_is_active': isActive,
        'p_reason': reason,
      });
    } catch (e) {
      debugPrint('[@CoachEngine] Error updating coach status: $e');
      rethrow;
    }
  }

  /// Update individual document status
  Future<void> updateDocumentStatus(String docId, String status, {String? reason}) async {
    try {
      await _supabase.rpc('handle_coach_document_review', params: {
        'p_doc_id': docId,
        'p_status': status,
        'p_reason': reason,
      });
    } catch (e) {
      debugPrint('[@CoachEngine] Error updating document status: $e');
      rethrow;
    }
  }
}
