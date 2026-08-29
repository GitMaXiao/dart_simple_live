import 'dart:async';

import 'package:web_socket_channel/io.dart';

enum SocketStatus {
  connecting,
  connected,
  failed,
  closed,
}

class WebScoketUtils {
  SocketStatus status = SocketStatus.closed;

  /// 链接
  final String url;

  /// 备用链接
  final String? backupUrl;

  /// 心跳时间
  final int heartBeatTime;

  /// 接收到信息
  final Function(dynamic)? onMessage;

  /// 连接关闭
  final Function(String msg)? onClose;

  /// 尝试重连
  final Function()? onReconnect;

  /// 准备就绪
  final Function()? onReady;

  /// 心跳
  final Function()? onHeartBeat;

  /// 请求头
  Map<String, dynamic>? headers;
  WebScoketUtils({
    required this.url,
    required this.heartBeatTime,
    this.onMessage,
    this.onClose,
    this.onReconnect,
    this.onReady,
    this.onHeartBeat,
    this.headers,
    this.backupUrl,
  });
  IOWebSocketChannel? webSocket;
  Timer? heartBeatTimer;

  /// 重连次数
  int reconnectTime = 0;
  Timer? reconnectTimer;

  /// 最大重连次数
  int maxReconnectTime = 8;
  bool isDisposed = false;

  StreamSubscription<dynamic>? streamSubscription;

  void connect({bool retry = false}) async {
    if (isDisposed) return;
    status = SocketStatus.connecting;
    _cleanSocket();

    try {
      var wsurl = url;
      if (backupUrl != null && backupUrl!.isNotEmpty && (retry || reconnectTime > 0)) {
        wsurl = backupUrl!;
      }
      webSocket = IOWebSocketChannel.connect(
        wsurl,
        connectTimeout: const Duration(seconds: 10),
        headers: headers,
      );

      await webSocket?.ready;
      if (isDisposed) {
        _cleanSocket();
        return;
      }
      ready();
    } catch (e) {
      if (!retry && !isDisposed) {
        connect(retry: true);
        return;
      }
      onError(e, StackTrace.current);
    }
  }

  /// 连接完成
  void ready() {
    status = SocketStatus.connected;
    reconnectTimer?.cancel();
    reconnectTimer = null;

    streamSubscription = webSocket?.stream.listen(
      (data) => receiveMessage(data),
      onError: (e, s) => onError(e, s),
      onDone: onDone,
      cancelOnError: true,
    );

    onReady?.call();
    initHeartBeat();
  }

  void initHeartBeat() {
    heartBeatTimer?.cancel();
    heartBeatTimer = Timer.periodic(
      Duration(milliseconds: heartBeatTime > 0 ? heartBeatTime : 30000),
      (timer) {
        if (status == SocketStatus.connected) {
          onHeartBeat?.call();
        }
      },
    );
  }

  void receiveMessage(dynamic data) {
    // 接受到信息说明连接通畅
    reconnectTime = 0;
    onMessage?.call(data);
  }

  void onError(e, s) {
    if (isDisposed) return;
    status = SocketStatus.failed;
    onClose?.call("弹幕连接异常: $e");
    handleReconnect();
  }

  void onDone() {
    if (isDisposed || status == SocketStatus.closed) {
      return;
    }
    status = SocketStatus.failed;
    onReconnect?.call();
    handleReconnect();
  }

  void handleReconnect() {
    if (isDisposed) return;
    _cleanSocket();

    if (reconnectTime < maxReconnectTime) {
      reconnectTime++;
      final delaySeconds = reconnectTime <= 3 ? 3 : (reconnectTime * 2);
      onClose?.call("弹幕已断开，正在尝试第 $reconnectTime 次重连...");
      
      reconnectTimer?.cancel();
      reconnectTimer = Timer(Duration(seconds: delaySeconds), () {
        if (!isDisposed) {
          connect();
        }
      });
    } else {
      onClose?.call("弹幕重连超过最大次数，已停止自动重连（可手动点击重连）");
      reconnectTimer?.cancel();
      reconnectTimer = null;
    }
  }

  void sendMessage(dynamic message) {
    if (status == SocketStatus.connected && webSocket != null) {
      try {
        webSocket?.sink.add(message);
      } catch (e) {
        onError(e, StackTrace.current);
      }
    }
  }

  void _cleanSocket() {
    streamSubscription?.cancel();
    streamSubscription = null;

    heartBeatTimer?.cancel();
    heartBeatTimer = null;

    try {
      webSocket?.sink.close();
    } catch (_) {}
    webSocket = null;
  }

  /// 外部主动重连（重置重试计数）
  void manualReconnect() {
    isDisposed = false;
    reconnectTime = 0;
    reconnectTimer?.cancel();
    reconnectTimer = null;
    connect();
  }

  void close() {
    isDisposed = true;
    status = SocketStatus.closed;

    reconnectTimer?.cancel();
    reconnectTimer = null;

    _cleanSocket();
  }
}
