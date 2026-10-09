import 'package:connectivity_plus/connectivity_plus.dart';

import '../../core/network/network_status.dart';

class ConnectivityNetworkStatus implements NetworkStatus {
  ConnectivityNetworkStatus([Connectivity? connectivity]) : _connectivity = connectivity ?? Connectivity();

  final Connectivity _connectivity;

  static bool _hasConnection(List<ConnectivityResult> results) => results.any((r) => r != ConnectivityResult.none);

  @override
  Stream<bool> get onlineChanges => _connectivity.onConnectivityChanged.map(_hasConnection);

  @override
  Future<bool> isOffline() async {
    try {
      return !_hasConnection(await _connectivity.checkConnectivity());
    } catch (_) {
      return false;
    }
  }
}
