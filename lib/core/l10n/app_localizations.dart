import 'package:flutter/material.dart';
import 'app_tr.dart';
import 'app_en.dart';

/// MatchFit Localization System
/// Default: Turkish (tr)
/// Optional: English (en)
///
/// Usage: final t = AppLocalizations.of(context);
///        Text(t.welcomeBack)

class AppLocalizations {
  final Locale locale;
  
  AppLocalizations(this.locale);

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations) 
        ?? AppLocalizations(const Locale('tr'));
  }

  static const LocalizationsDelegate<AppLocalizations> delegate = _AppLocalizationsDelegate();

  static final Map<String, Map<String, String>> _localizedValues = {
    'tr': trTranslations,
    'en': enTranslations,
  };

  String _t(String key) {
    return _localizedValues[locale.languageCode]?[key] 
        ?? _localizedValues['tr']?[key] 
        ?? key;
  }

  // ══════════════════════════════════════════════════════════════
  // APP GENERAL
  // ══════════════════════════════════════════════════════════════
  String get appName => _t('app_name');
  String get loading => _t('loading');
  String get error => _t('error');
  String get success => _t('success');
  String get cancel => _t('cancel');
  String get save => _t('save');
  String get delete => _t('delete');
  String get edit => _t('edit');
  String get confirm => _t('confirm');
  String get close => _t('close');
  String get back => _t('back');
  String get next => _t('next');
  String get done => _t('done');
  String get retry => _t('retry');
  String get search => _t('search');
  String get settings => _t('settings');
  String get share => _t('share');
  String get yes => _t('yes');
  String get no => _t('no');

  // ══════════════════════════════════════════════════════════════
  // BOTTOM NAVIGATION
  // ══════════════════════════════════════════════════════════════
  String get navHome => _t('nav_home');
  String get navDiscover => _t('nav_discover');
  String get navCreate => _t('nav_create');
  String get navMessages => _t('nav_messages');
  String get navProfile => _t('nav_profile');

  // ══════════════════════════════════════════════════════════════
  // AUTH - LOGIN
  // ══════════════════════════════════════════════════════════════
  String get welcomeBack => _t('welcome_back');
  String get signInSubtitle => _t('sign_in_subtitle');
  String get emailAddress => _t('email_address');
  String get enterEmail => _t('enter_email');
  String get password => _t('password');
  String get enterPassword => _t('enter_password');
  String get forgotPassword => _t('forgot_password');
  String get signIn => _t('sign_in');
  String get orContinueWith => _t('or_continue_with');
  String get dontHaveAccount => _t('dont_have_account');
  String get signUp => _t('sign_up');
  String get loginError => _t('login_error');
  String get pleaseEnterEmailPassword => _t('please_enter_email_password');

  // ══════════════════════════════════════════════════════════════
  // AUTH - SIGNUP
  // ══════════════════════════════════════════════════════════════
  String get joinCommunity => _t('join_community');
  String get signUpSubtitle => _t('sign_up_subtitle');
  String get fullName => _t('full_name');
  String get confirmPassword => _t('confirm_password');
  String get createAccount => _t('create_account');
  String get agreeToTerms => _t('agree_to_terms');
  String get termsAndConditions => _t('terms_and_conditions');
  String get privacyPolicy => _t('privacy_policy');
  String get and => _t('and');
  String get alreadyHaveAccount => _t('already_have_account');
  String get logIn => _t('log_in');
  String get mustAgreeTerms => _t('must_agree_terms');
  String get pleaseFillAllFields => _t('please_fill_all_fields');
  String get passwordsDontMatch => _t('passwords_dont_match');
  String get signUpError => _t('sign_up_error');

  // ══════════════════════════════════════════════════════════════
  // AUTH - RESET PASSWORD
  // ══════════════════════════════════════════════════════════════
  String get resetPassword => _t('reset_password');
  String get resetPasswordSubtitle => _t('reset_password_subtitle');
  String get sendResetLink => _t('send_reset_link');
  String get resetLinkSent => _t('reset_link_sent');
  String get backToLogin => _t('back_to_login');
  String get pleaseEnterEmail => _t('please_enter_email');

  // ══════════════════════════════════════════════════════════════
  // AUTH - UPDATE PASSWORD
  // ══════════════════════════════════════════════════════════════
  String get createNewPassword => _t('create_new_password');
  String get updatePasswordSubtitle => _t('update_password_subtitle');
  String get newPassword => _t('new_password');
  String get confirmNewPassword => _t('confirm_new_password');
  String get updatePassword => _t('update_password');
  String get securityTip => _t('security_tip');
  String get securityTipDesc => _t('security_tip_desc');
  String get passwordUpdated => _t('password_updated');
  String get pleaseFillBothFields => _t('please_fill_both_fields');
  String get passwordMinLength => _t('password_min_length');

  // ══════════════════════════════════════════════════════════════
  // AUTH - PROFILE SETUP
  // ══════════════════════════════════════════════════════════════
  String get completeProfile => _t('complete_profile');
  String get nameAndSurname => _t('name_and_surname');
  String get city => _t('city');
  String get aboutYou => _t('about_you');
  String get continueToSportSelection => _t('continue_to_sport_selection');
  String get pleaseEnterNameCity => _t('please_enter_name_city');
  String get profileSaveError => _t('profile_save_error');

  // ══════════════════════════════════════════════════════════════
  // ONBOARDING - SPORT SELECTION
  // ══════════════════════════════════════════════════════════════
  String get stepOf => _t('step_of');
  String get chooseSportsCategories => _t('choose_sports_categories');
  String get chooseSubBranches => _t('choose_sub_branches');
  String get whatIsYourSkillLevel => _t('what_is_your_skill_level');
  String get finish => _t('finish');
  String get beginner => _t('beginner');
  String get intermediate => _t('intermediate');
  String get advanced => _t('advanced');
  String get selectAtLeastOneCategory => _t('select_at_least_one_category');
  String get selectAtLeastOneSubBranch => _t('select_at_least_one_sub_branch');
  String get selectSkillLevelFor => _t('select_skill_level_for');
  String get errorSavingPreferences => _t('error_saving_preferences');

  // ══════════════════════════════════════════════════════════════
  // HOME SCREEN
  // ══════════════════════════════════════════════════════════════
  String get hello => _t('hello');
  String get readyToMove => _t('ready_to_move');
  String get weeklyProgress => _t('weekly_progress');
  String get details => _t('details');
  String get dayStreak => _t('day_streak');
  String get goalPercent => _t('goal_percent');
  String get run => _t('run');
  String get match => _t('match');
  String get points => _t('points');
  String get recommendedForYou => _t('recommended_for_you');
  String get aiRecommended => _t('ai_recommended');
  String get suggestedMembers => _t('suggested_members');
  String get nearbyEvents => _t('nearby_events');
  String get viewMap => _t('view_map');
  String get join => _t('join');
  String get noEventsNearby => _t('no_events_nearby');

  // ══════════════════════════════════════════════════════════════
  // CREATE EVENT
  // ══════════════════════════════════════════════════════════════
  String get createEvent => _t('create_event');
  String get createEventSubtitle => _t('create_event_subtitle');
  String get selectCategory => _t('select_category');
  String get selectSubBranch => _t('select_sub_branch');
  String get level => _t('level');
  String get venue => _t('venue');
  String get openClosed => _t('open_closed');
  String get participantCount => _t('participant_count');
  String get nextStep => _t('next_step');
  String get proTip => _t('pro_tip');
  String get proTipDesc => _t('pro_tip_desc');
  String get timeAndDetails => _t('time_and_details');
  String get timeAndDetailsSubtitle => _t('time_and_details_subtitle');
  String get title => _t('title');
  String get eventTitleHint => _t('event_title_hint');
  String get date => _t('date');
  String get time => _t('time');
  String get select => _t('select');
  String get descriptionOptional => _t('description_optional');
  String get descriptionHint => _t('description_hint');
  String get selectLocation => _t('select_location');
  String get selectLocationSubtitle => _t('select_location_subtitle');
  String get country => _t('country');
  String get province => _t('province');
  String get district => _t('district');
  String get selectProvince => _t('select_province');
  String get selectDistrict => _t('select_district');
  String get venueSearch => _t('venue_search');
  String get venueSearchHint => _t('venue_search_hint');
  String get publishEvent => _t('publish_event');
  String get eventPublished => _t('event_published');
  String get pleaseSelectCategoryAndSport => _t('please_select_category_and_sport');
  String get pleaseEnterDateTimeTitle => _t('please_enter_date_time_title');
  String get pleaseCompleteLocation => _t('please_complete_location');

  // ══════════════════════════════════════════════════════════════
  // EVENT DETAIL
  // ══════════════════════════════════════════════════════════════
  String get eventDetail => _t('event_detail');
  String get hosted => _t('hosted');
  String get participants => _t('participants');
  String get joinRequest => _t('join_request');
  String get sendJoinRequest => _t('send_join_request');
  String get requestSent => _t('request_sent');
  String get alreadyJoined => _t('already_joined');
  String get eventFull => _t('event_full');
  String get shareEvent => _t('share_event');
  String get editEvent => _t('edit_event');
  String get deleteEvent => _t('delete_event');
  String get host => _t('host');
  String get indoor => _t('indoor');
  String get outdoor => _t('outdoor');

  // ══════════════════════════════════════════════════════════════
  // EXPLORE / DISCOVER
  // ══════════════════════════════════════════════════════════════
  String get discover => _t('discover');
  String get searchEvents => _t('search_events');
  String get filters => _t('filters');
  String get allCategories => _t('all_categories');
  String get noResults => _t('no_results');
  String get mapView => _t('map_view');
  String get listView => _t('list_view');

  // ══════════════════════════════════════════════════════════════
  // PROFILE
  // ══════════════════════════════════════════════════════════════
  String get profile => _t('profile');
  String get trustScore => _t('trust_score');
  String get followers => _t('followers');
  String get following => _t('following');
  String get events => _t('events');
  String get follow => _t('follow');
  String get unfollow => _t('unfollow');
  String get followRequested => _t('follow_requested');
  String get block => _t('block');
  String get unblock => _t('unblock');
  String get report => _t('report');
  String get editProfile => _t('edit_profile');
  String get logOut => _t('log_out');
  String get myEvents => _t('my_events');
  String get joinedEvents => _t('joined_events');
  String get pastEvents => _t('past_events');
  String get bio => _t('bio');
  String get memberSince => _t('member_since');
  String get blockedUsers => _t('blocked_users');

  // ══════════════════════════════════════════════════════════════
  // NOTIFICATIONS
  // ══════════════════════════════════════════════════════════════
  String get notifications => _t('notifications');
  String get unread => _t('unread');
  String get read => _t('read');
  String get markAllRead => _t('mark_all_read');
  String get deleteAll => _t('delete_all');
  String get noUnreadNotifications => _t('no_unread_notifications');
  String get great => _t('great');
  String get noNotifications => _t('no_notifications');
  String get accept => _t('accept');
  String get reject => _t('reject');
  String get accepted => _t('accepted');
  String get rejected => _t('rejected');
  String get justNow => _t('just_now');
  String get minutesAgo => _t('minutes_ago');
  String get hoursAgo => _t('hours_ago');

  // ══════════════════════════════════════════════════════════════
  // PRIVACY SETTINGS
  // ══════════════════════════════════════════════════════════════
  String get privacySettings => _t('privacy_settings');
  String get privacyAndSecurity => _t('privacy_and_security');
  String get profileVisibility => _t('profile_visibility');
  String get publicProfile => _t('public_profile');
  String get privateProfile => _t('private_profile');
  String get locationSharing => _t('location_sharing');
  String get activityStatus => _t('activity_status');

  // ══════════════════════════════════════════════════════════════
  // SETTINGS
  // ══════════════════════════════════════════════════════════════
  String get language => _t('language');
  String get turkish => _t('turkish');
  String get english => _t('english');
  String get theme => _t('theme');
  String get darkMode => _t('dark_mode');
  String get lightMode => _t('light_mode');
  String get systemDefault => _t('system_default');
  String get about => _t('about');
  String get version => _t('version');
  String get helpAndSupport => _t('help_and_support');
  String get languageChanged => _t('language_changed');

  // ══════════════════════════════════════════════════════════════
  // REFEREE / RESTRICTION
  // ══════════════════════════════════════════════════════════════
  String get refereeRestriction => _t('referee_restriction');
}

class _AppLocalizationsDelegate extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) => ['tr', 'en'].contains(locale.languageCode);

  @override
  Future<AppLocalizations> load(Locale locale) async {
    return AppLocalizations(locale);
  }

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}
