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
      PhoneAuthCredential credential = PhoneAuthProvider.credential(
        verificationId: _verificationId!,
        smsCode: otp,
      );
      final userCredential = await _auth.signInWithCredential(credential);
      final user = userCredential.user;
      
      if (user != null && user.phoneNumber != null) {
         // Save to MySQL database
         final dbService = DatabaseService();
         final userId = await dbService.saveUser(user.phoneNumber!);
         
         if (userId != null) {
            final prefs = await SharedPreferences.getInstance();
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
