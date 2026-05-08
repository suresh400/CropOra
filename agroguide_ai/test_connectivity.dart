import 'package:connectivity_plus/connectivity_plus.dart';

void main() async {
  final result = await Connectivity().checkConnectivity();
  print("Result type: \${result.runtimeType}");
  print("Result value: \$result");
}
