/// This file contains mock objects and utilities for testing the p2plib-dart library.
library;

import 'dart:io';
import 'dart:convert';
import 'dart:isolate';
import 'package:p2plib/p2plib.dart';

export 'package:p2plib/p2plib.dart';

const Duration initTime = Duration(milliseconds: 250);
final InternetAddress localAddress = InternetAddress.loopbackIPv4;
final PeerId randomPeerId = PeerId(value: getRandomBytes(PeerId.length));
final Uint8List randomPayload = getRandomBytes(1024);
final Token token = Token(value: randomPayload);
final Uint8List proxySeed =
    base64Decode('tuTfQVH3qgHZ751JtEja_ZbkY-EF0cbRzVDDO_HNrmY=');
final PeerId proxyPeerId = PeerId(
  value: base64Decode(
    'xD_eApw8bN2EDDirUzCoEsOpSbGXfFD0WYr7q7hWjVUARgW4EQ7CTjMT_SqAfItrfS4BGl6sU-rnSWCwuOtv3Q==',
  ),
);
final ({FullAddress ip, AddressProperties properties})
    proxyAddressWithProperties = (
  ip: FullAddress(address: localAddress, port: 2022),
  properties: AddressProperties(isStatic: true, isLocal: true),
);
final ({FullAddress ip, AddressProperties properties})
    aliceAddressWithProperties = (
  ip: FullAddress(address: localAddress, port: 3022),
  properties: AddressProperties(isLocal: true),
);
final ({FullAddress ip, AddressProperties properties})
    bobAddressWithProperties = (
  ip: FullAddress(address: localAddress, port: 4022),
  properties: AddressProperties(isLocal: true),
);

Route getProxyRoute() => Route(
    peerId: proxyPeerId, canForward: true, address: proxyAddressWithProperties);

/// Helper to log messages with a specific debug label.
void log(String debugLabel, String message) =>
    /// Explaining ignore.
    // ignore: avoid_print
    print('[$debugLabel] $message');

/// Creates a RouterL2 instance for testing.
Future<RouterL2> createRouter({
  required FullAddress address,
  Uint8List? seed,
  String? debugLabel,
}) async {
  final router = RouterL2(
    transports: [TransportUdp(bindAddress: address)],
    logger: (message) =>
        /// Explaining ignore.
    // ignore: avoid_print
        print('[$debugLabel] $message'),
  )
    ..messageTTL = const Duration(seconds: 2)
    ..peerOnlineTimeout = const Duration(seconds: 2);
  await router.init(seed);
  return router;
}

/// Creates a proxy isolate for testing.
Future<Isolate> createProxy({
  FullAddress? address,
  String? debugLabel = 'Proxy',
}) async {
  final isolate = await Isolate.spawn(
    (_) async {
      final router = RouterL0(
        transports: [
          TransportUdp(bindAddress: address ?? proxyAddressWithProperties.ip)
        ],
        logger: (message) =>
            /// Explaining ignore.
    // ignore: avoid_print
            print('[$debugLabel] $message'),
      )..messageTTL = const Duration(seconds: 2);
      await router.init(proxySeed);
      await router.start();
    },
    null,
    debugName: debugLabel,
  );
  await Future<void>.delayed(initTime);
  return isolate;
}
