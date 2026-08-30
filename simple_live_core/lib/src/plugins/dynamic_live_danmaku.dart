import 'dart:async';
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../common/core_log.dart';
import '../interface/live_danmaku.dart';
import '../model/live_message.dart';

/// 动态弹幕适配器
class DynamicLiveDanmaku extends LiveDanmaku {
  WebSocketChannel? _channel;
  Timer? _heartbeatTimer;
  final String? wsUrl;
  final dynamic heartbeatMsg;

  DynamicLiveDanmaku({
    this.wsUrl,
    this.heartbeatMsg,
  });

  @override
  Future start(dynamic args) async {
    try {
      String? targetUrl = wsUrl;
      if (args is Map && args['wsUrl'] != null) {
        targetUrl = args['wsUrl'].toString();
      }

      if (targetUrl == null || targetUrl.isEmpty) {
        CoreLog.i('DynamicLiveDanmaku: No WebSocket URL configured, skip WS danmaku');
        onReady?.call();
        return;
      }

      _channel = WebSocketChannel.connect(Uri.parse(targetUrl));
      await _channel!.ready;
      onReady?.call();

      _channel!.stream.listen(
        (data) {
          try {
            if (data is String) {
              var json = jsonDecode(data);
              if (json is Map) {
                var typeStr = json['type']?.toString();
                if (typeStr == 'chat' || json['message'] != null) {
                  onMessage?.call(LiveMessage(
                    type: LiveMessageType.chat,
                    userName: json['userName']?.toString() ?? '',
                    message: json['message']?.toString() ?? '',
                    color: LiveMessageColor.white,
                  ));
                }
              }
            }
          } catch (e) {
            CoreLog.error('DynamicLiveDanmaku parse message error: $e');
          }
        },
        onDone: () => onClose?.call('Connection closed'),
        onError: (e) => onClose?.call(e.toString()),
      );

      if (heartbeatTime > 0) {
        _heartbeatTimer?.cancel();
        _heartbeatTimer = Timer.periodic(Duration(seconds: heartbeatTime), (_) {
          heartbeat();
        });
      }
    } catch (e) {
      onClose?.call(e.toString());
    }
  }

  @override
  void heartbeat() {
    if (_channel != null && heartbeatMsg != null) {
      _channel!.sink.add(heartbeatMsg is String ? heartbeatMsg : jsonEncode(heartbeatMsg));
    }
  }

  @override
  Future stop() async {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
    await _channel?.sink.close();
    _channel = null;
  }
}

