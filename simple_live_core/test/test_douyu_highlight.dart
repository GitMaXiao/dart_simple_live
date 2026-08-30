import 'package:simple_live_core/simple_live_core.dart';

void main() async {
  var site = DouyuSite();
  print('--- Testing Room 475252 highlights ---');
  var list1 = await site.getHighlights(roomId: '475252');
  print('Room 475252 highlights count: ${list1.length}');
  for (var h in list1.take(3)) {
    print('  - [${h.tag}] [${h.duration}] ${h.title} (heat: ${h.viewCount}, danmu: ${h.danmuCount})');
    print('    desc: ${h.description}');
  }

  print('\n--- Testing Room 9999 highlights ---');
  var list2 = await site.getHighlights(roomId: '9999');
  print('Room 9999 highlights count: ${list2.length}');
  for (var h in list2.take(3)) {
    print('  - [${h.tag}] [${h.duration}] ${h.title} (heat: ${h.viewCount}, danmu: ${h.danmuCount})');
    print('    desc: ${h.description}');
  }
}

