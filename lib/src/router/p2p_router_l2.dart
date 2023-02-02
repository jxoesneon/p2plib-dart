part of 'router.dart';

/// Enhanced router with more high level API for building rich client
class P2PRouterL2 extends P2PRouterL1 {
  final _messageController = StreamController<P2PMessage>();
  final _lastSeenController =
      StreamController<MapEntry<P2PPeerId, bool>>.broadcast();

  Stream<P2PMessage> get messageStream => _messageController.stream;

  Stream<MapEntry<P2PPeerId, bool>> get lastSeenStream =>
      _lastSeenController.stream;

  P2PRouterL2({super.crypto, super.transports, super.logger}) {
    // More convenient for endpoint client
    preserveLocalAddress = true;
  }

  /// returns null if message is processed and children have to return
  @override
  Future<P2PPacket?> onMessage(final P2PPacket packet) async {
    // exit if parent done all needed work
    if (await super.onMessage(packet) == null) return null;
    // update peer status
    _lastSeenController
        .add(MapEntry<P2PPeerId, bool>(packet.message!.srcPeerId, true));
    // drop empty messages (keepalive)
    if (packet.message!.isEmpty) return null;
    // message is for user, send it to subscriber
    if (_messageController.hasListener) _messageController.add(packet.message!);
    return packet;
  }

  /// Add Address with port and timestamp for PeerId into cache
  void addPeerAddress({
    required final P2PPeerId peerId,
    required final P2PFullAddress address,
    bool? canForward,
    int? timestamp,
  }) {
    if (peerId == selfId) return;
    timestamp ??= DateTime.now().millisecondsSinceEpoch;
    if (routes.containsKey(peerId)) {
      routes[peerId]!.addAddress(
        address: address,
        timestamp: timestamp,
        canForward: canForward,
      );
    } else {
      routes[peerId] = P2PRoute(
        peerId: peerId,
        canForward: canForward ?? false,
        addresses: {address: timestamp},
      );
    }
  }

  /// Add Addresses with port and timestamp for PeerId into cache
  void addPeerAddresses({
    required final P2PPeerId peerId,
    required final Iterable<P2PFullAddress> addresses,
    bool? canForward,
    int? timestamp,
  }) {
    if (addresses.isEmpty) return;
    if (peerId == selfId) return;
    timestamp ??= DateTime.now().millisecondsSinceEpoch;
    if (routes.containsKey(peerId)) {
      routes[peerId]!.addAddresses(
        addresses: addresses,
        timestamp: timestamp,
        canForward: canForward,
      );
    } else {
      routes[peerId] = P2PRoute(
        peerId: peerId,
        canForward: canForward ?? false,
        addresses: {for (final a in addresses) a: timestamp},
      );
    }
  }

  P2PRoute? forgetPeerId(final P2PPeerId peerId) => routes.remove(peerId);

  bool getPeerStatus(final P2PPeerId peerId) =>
      (routes[peerId]?.lastSeen ?? 0) + requestTimeout.inMilliseconds >
      DateTime.now().millisecondsSinceEpoch;

  Future<bool> pingPeer(final P2PPeerId peerId) async {
    try {
      await sendMessage(isConfirmable: true, dstPeerId: peerId);
      _lastSeenController.add(MapEntry<P2PPeerId, bool>(peerId, true));
      return true;
    } catch (_) {}
    _lastSeenController.add(MapEntry<P2PPeerId, bool>(
      peerId,
      getPeerStatus(peerId),
    ));
    return false;
  }
}
