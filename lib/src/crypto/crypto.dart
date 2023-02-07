import 'dart:async';
import 'dart:isolate';
import 'dart:typed_data';

import '/src/data/data.dart';

import 'worker.dart';

class P2PCrypto {
  late final P2PCryptoKeys cryptoKeys;
  late final SendPort _sendPort;
  final _recievePort = ReceivePort();
  final Map<int, Completer<P2PCryptoTask>> _completers = {
    0: Completer<P2PCryptoTask>(),
  };
  var _idCounter = 0;
  var operationTimeout = const Duration(seconds: 1);

  P2PCrypto() {
    _recievePort.listen(
      (message) {
        if (message is P2PCryptoTask) {
          message.payload is Exception
              ? _completers.remove(message.id)?.completeError(message.payload)
              : _completers.remove(message.id)?.complete(message);
        }
      },
    );
  }

  /// Will create key pair if seed is not empty else use key pair
  Future<P2PCryptoKeys> init([P2PCryptoKeys? keys]) async {
    final id = _idCounter++;
    await Isolate.spawn<P2PCryptoTask>(
      cryptoWorker,
      P2PCryptoTask(
        id: id,
        type: P2PCryptoTaskType.sign, // does not matter for initial task
        payload: _recievePort.sendPort,
        extra: keys,
      ),
    );
    final initResult = await _completers[id]!.future.timeout(operationTimeout);
    _sendPort = initResult.payload as SendPort;
    cryptoKeys = initResult.extra as P2PCryptoKeys;
    _completers.remove(id);
    return cryptoKeys;
  }

  /// Encrypt message`s payload and sign whole datagram
  Future<Uint8List> seal(final P2PMessage message) async {
    final id = _idCounter++;
    final completer = Completer<P2PCryptoTask>();
    _completers[id] = completer;
    _sendPort.send(P2PCryptoTask(
      id: id,
      type: P2PCryptoTaskType.seal,
      payload: message,
    ));
    try {
      final result = await completer.future.timeout(operationTimeout);
      if (result.payload is Uint8List) return result.payload as Uint8List;
      throw result.payload;
    } finally {
      _completers.remove(id);
    }
  }

  /// Returns unencrypted payload of message
  Future<Uint8List> unseal(final Uint8List datagram) async {
    final id = _idCounter++;
    final completer = Completer<P2PCryptoTask>();
    _completers[id] = completer;
    _sendPort.send(P2PCryptoTask(
      id: id,
      type: P2PCryptoTaskType.unseal,
      payload: datagram,
    ));
    try {
      final result = await completer.future.timeout(operationTimeout);
      if (result.payload is Uint8List) return result.payload as Uint8List;
      throw result.payload;
    } finally {
      _completers.remove(id);
    }
  }

  Future<Uint8List> sign(final Uint8List datagram) async {
    final id = _idCounter++;
    final completer = Completer<P2PCryptoTask>();
    _completers[id] = completer;
    _sendPort.send(P2PCryptoTask(
      id: id,
      type: P2PCryptoTaskType.sign,
      payload: datagram,
    ));
    try {
      final result = await completer.future.timeout(operationTimeout);
      if (result.payload is Uint8List) {
        final signed = BytesBuilder(copy: false)
          ..add(datagram)
          ..add(result.payload as Uint8List);
        return signed.toBytes();
      }
      throw result.payload;
    } finally {
      _completers.remove(id);
    }
  }

  Future<bool> verifySigned(
    final Uint8List pubKey,
    final Uint8List datagram,
  ) async {
    final id = _idCounter++;
    final completer = Completer<P2PCryptoTask>();
    _completers[id] = completer;
    _sendPort.send(P2PCryptoTask(
      id: id,
      type: P2PCryptoTaskType.verifySigned,
      payload: datagram,
      extra: pubKey,
    ));
    try {
      final result = await completer.future.timeout(operationTimeout);
      if (result.payload is bool) return result.payload as bool;
      throw result.payload;
    } finally {
      _completers.remove(id);
    }
  }
}
