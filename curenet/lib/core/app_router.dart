import 'package:flutter/material.dart';
import '../screens/splash_screen.dart';
import '../screens/language_select_screen.dart';
import '../screens/login_options_screen.dart';
import '../screens/login_mobile_screen.dart';
import '../screens/login_otp_screen.dart';
import '../screens/home_screen.dart';
import '../screens/profile_screen.dart';
import '../screens/notifications_screen.dart';
import '../screens/health_locker_screen.dart';
import '../screens/chat_screen.dart';
import '../screens/records_screen.dart';
import '../screens/qr_share_screen.dart';
import '../screens/emergency_snapshot_screen.dart';
import '../screens/access_request_screen.dart';
import '../screens/access_granted_screen.dart';
import '../screens/doc_scan_screen.dart';
import '../screens/register_abha_screen.dart';
import '../screens/register_options_screen.dart';
import '../screens/create_abha_mobile_screen.dart';
import '../screens/privacy_notice_screen.dart';
import '../screens/register_mobile_details_screen.dart';
import '../screens/mobile_otp_verify_screen.dart';
import '../screens/forgot_abha_screen.dart';
import '../screens/create_abha_aadhaar_screen.dart';
import '../screens/login_aadhaar_screen.dart';
import '../screens/login_abha_num_screen.dart';
import '../screens/login_abha_addr_screen.dart';

class AppRouter {
  static const String splash = '/splash';
  static const String languageSelect = '/language-select';
  static const String loginOptions = '/login-options';
  static const String loginMobile = '/login-mobile';
  static const String createAbhaAadhaar = '/create-abha-aadhaar';
  static const String loginOtp = '/login-otp';
  static const String home = '/home';
  static const String profile = '/profile';
  static const String notifications = '/notifications';
  static const String healthLocker = '/health-locker';
  static const String chat = '/chat';
  static const String records = '/records';
  static const String qrShare = '/qr-share';
  static const String accessReq = '/access-req';
  static const String accessOk = '/access-ok';
  static const String docScan = '/doc-scan';
  static const String emergencySnapshot = '/emergency-snapshot';
  static const String registerOptions = '/register-options';
  static const String createAbhaMobile = '/create-abha-mobile';
  static const String mobileOtpVerify = '/mobile-otp-verify';
  static const String registerMobileDetails = '/register-mobile-details';
  static const String privacyNotice = '/privacy-notice';
  static const String registerAbha = '/register-abha';
  static const String forgotAbha = '/forgot-abha';
  static const String loginAadhaar = '/login-aadhaar';
  static const String loginAbhaNum = '/login-abha-num';
  static const String loginAbhaAddr = '/login-abha-addr';

  static Map<String, WidgetBuilder> get routes => {
    splash: (context) => const SplashScreen(),
    languageSelect: (context) => const LanguageSelectScreen(),
    loginOptions: (context) => const LoginOptionsScreen(),
    loginMobile: (context) => const LoginMobileScreen(),
    createAbhaAadhaar: (context) => const CreateAbhaAadhaarScreen(),
    loginOtp: (context) => const LoginOtpScreen(),
    home: (context) => const HomeScreen(),
    profile: (context) => const ProfileScreen(),
    notifications: (context) => const NotificationsScreen(),
    healthLocker: (context) => const HealthLockerScreen(),
    chat: (context) => const ChatScreen(),
    records: (context) => const RecordsScreen(),
    qrShare: (context) => const QrShareScreen(),
    accessReq: (context) => const AccessRequestScreen(),
    accessOk: (context) => const AccessGrantedScreen(),
    docScan: (context) => const DocScanScreen(),
    emergencySnapshot: (context) => const EmergencySnapshotScreen(),
    registerOptions: (context) => const RegisterOptionsScreen(),
    createAbhaMobile: (context) => const CreateAbhaMobileScreen(),
    mobileOtpVerify: (context) => const MobileOtpVerifyScreen(),
    registerMobileDetails: (context) => const RegisterMobileDetailsScreen(),
    privacyNotice: (context) => const PrivacyNoticeScreen(),
    registerAbha: (context) => const RegisterAbhaScreen(),
    forgotAbha: (context) => const ForgotAbhaScreen(),
    loginAadhaar: (context) => const LoginAadhaarScreen(),
    loginAbhaNum: (context) => const LoginAbhaNumScreen(),
    loginAbhaAddr: (context) => const LoginAbhaAddrScreen(),
  };
}
