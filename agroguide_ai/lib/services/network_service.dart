import 'package:connectivity_plus/connectivity_plus.dart';

class NetworkService {
  Future<bool> hasInternet() async {
    final connectivityResult = await Connectivity().checkConnectivity();
    // In connectivity_plus > 6.x, checkConnectivity returns List<ConnectivityResult>
    if (connectivityResult is List) {
       return !connectivityResult.contains(ConnectivityResult.none);
    }
    return connectivityResult != ConnectivityResult.none;
  }
}
