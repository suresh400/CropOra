import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/database_service.dart';

class AuthService extends ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  
  User? _user;
  User? get user => _user;
  
  bool _isLoading = false;
  bool get isLoading => _isLoading;
  
  String? _verificationId;

  AuthService() {
    _auth.authStateChanges().listen((User? user) {
      _user = user;
      notifyListeners();
    });
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  // Send OTP
  Future<void> signInWithPhone(String phoneNumber, Function(String) onError) async {
    _setLoading(true);
    try {
      // Save phone immediately so profile can display it before Firebase resolves
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('login_phone', phoneNumber);

      if (kIsWeb) {
        // Web requires reCAPTCHA which fails on unconfigured localhost.
        // Mock OTP send to allow testing and development.
        await Future.delayed(const Duration(milliseconds: 800));
        _verificationId = 'web_mock_id';
        _setLoading(false);
        return;
      }

      await _auth.verifyPhoneNumber(
        phoneNumber: phoneNumber,
        verificationCompleted: (PhoneAuthCredential credential) async {
          await _auth.signInWithCredential(credential);
          _setLoading(false);
        },
        verificationFailed: (FirebaseAuthException e) {
          _setLoading(false);
          onError(e.message ?? 'Verification Failed');
        },
        codeSent: (String verificationId, int? resendToken) {
          _verificationId = verificationId;
          _setLoading(false);
        },
        codeAutoRetrievalTimeout: (String verificationId) {
          _verificationId = verificationId;
        },
      );
    } catch (e) {
      _setLoading(false);
      onError(e.toString());
    }
  }

  // Verify OTP
  Future<bool> verifyOTP(String otp, Function(String) onError) async {
    if (_verificationId == null) return false;
    
    _setLoading(true);
    try {
      User? authUser;
      
      if (kIsWeb && _verificationId == 'web_mock_id') {
        // Mock verification for Web. Use anonymous auth to populate the Firebase User.
        await Future.delayed(const Duration(milliseconds: 800));
        final userCredential = await _auth.signInAnonymously();
        authUser = userCredential.user;
      } else {
        PhoneAuthCredential credential = PhoneAuthProvider.credential(
          verificationId: _verificationId!,
          smsCode: otp,
        );
        final userCredential = await _auth.signInWithCredential(credential);
        authUser = userCredential.user;
      }
      
      if (authUser != null) {
         final prefs = await SharedPreferences.getInstance();
         final phone = authUser.phoneNumber ?? prefs.getString('login_phone') ?? '+919999999999';
         
         // Save to MySQL database
         final dbService = DatabaseService();
         final userId = await dbService.saveUser(phone);
         
         if (userId != null) {
            await prefs.setInt('mysql_user_id', userId);
         }
      }
      
      _setLoading(false);
      return true;
    } on FirebaseAuthException catch (e) {
      _setLoading(false);
      onError(e.message ?? 'Invalid OTP');
      return false;
    } catch (e) {
      _setLoading(false);
      onError(e.toString());
      return false;
    }
  }

  Future<void> signOut() async {
    await _auth.signOut();
  }
}
