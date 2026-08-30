/**
 * Simple Live - 快手直播插件 (Kuaishou Live Plugin)
 * 运行环境: QuickJS 沙箱
 */

SimpleLive.registerSite({
  id: 'site_kuaishou',
  name: '快手直播',

  // 1. 获取全部分类列表
  getCategories: function() {
    return [
      {
        id: 'game',
        name: '游戏专区',
        children: [
          { id: '1001', name: '英雄联盟', pic: 'https://static.yximgs.com/udata/pkg/KS-FE/game_lol.png' },
          { id: '1002', name: '王者荣耀', pic: 'https://static.yximgs.com/udata/pkg/KS-FE/game_wzry.png' },
          { id: '1003', name: '和平精英', pic: 'https://static.yximgs.com/udata/pkg/KS-FE/game_hpjy.png' },
          { id: '1004', name: '穿越火线', pic: '' },
          { id: '1005', name: '绝地求生', pic: '' },
          { id: '1006', name: '原神', pic: '' },
          { id: '1007', name: '蛋仔派对', pic: '' },
          { id: '1008', name: '三角洲行动', pic: '' },
          { id: '1009', name: '永劫无间', pic: '' },
          { id: '1010', name: '无畏契约', pic: '' },
          { id: '1011', name: '金铲铲之战', pic: '' },
          { id: '1012', name: '第五人格', pic: '' },
          { id: '1013', name: '我的世界', pic: '' },
          { id: '1014', name: '炉石传说', pic: '' },
          { id: '1015', name: 'CS:GO', pic: '' },
          { id: '1016', name: 'DOTA2', pic: '' },
          { id: '1017', name: '崩坏：星穹铁道', pic: '' },
          { id: '1018', name: '单机主机', pic: '' },
          { id: '1019', name: '棋牌桌游', pic: '' }
        ]
      },
      {
        id: 'entertainment',
        name: '娱乐天地',
        children: [
          { id: '2001', name: '颜值才艺', pic: '' },
          { id: '2002', name: '音乐电台', pic: '' },
          { id: '2003', name: '舞蹈跳舞', pic: '' },
          { id: '2004', name: '户外生活', pic: '' },
          { id: '2005', name: '搞笑脱口秀', pic: '' },
          { id: '2006', name: '萌宠动物', pic: '' },
          { id: '2007', name: '美食吃播', pic: '' },
          { id: '2008', name: '二次元虚拟', pic: '' }
        ]
      },
      {
        id: 'lifestyle',
        name: '文化生活',
        children: [
          { id: '3001', name: '学习教育', pic: '' },
          { id: '3002', name: '情感心声', pic: '' },
          { id: '3003', name: '科技数码', pic: '' },
          { id: '3004', name: '体育运动', pic: '' },
          { id: '3005', name: '汽车驾趣', pic: '' }
        ]
      }
    ];
  },

  // 2. 获取推荐房间列表 (通过 GraphQL 接口)
  getRecommendRooms: function(page) {
    return {
      __type: 'http_request',
      url: 'https://live.kuaishou.com/graphql',
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
        'Referer': 'https://live.kuaishou.com/'
      },
      body: JSON.stringify({
        operationName: 'LiveSquareFeedQuery',
        variables: {
          count: 20,
          pcursor: String(page > 1 ? page : 0)
        },
        query: 'query LiveSquareFeedQuery($pcursor: String, $count: Int) { liveSquareFeed(pcursor: $pcursor, count: $count) { pcursor list { liveStream { caption coverUrl watchingCount author { id name avatar } } } } }'
      }),
      callback: '_onGetRecommendRooms'
    };
  },

  // 推荐与分类房间的统一回调解析
  _onGetRecommendRooms: function(respStr, statusCode) {
    try {
      var data = typeof respStr === 'string' ? JSON.parse(respStr) : respStr;
      var feed = (data.data && data.data.liveSquareFeed) 
        || (data.data && data.data.categoryDetailFeed) 
        || null;

      if (!feed || !feed.list) {
        return { hasMore: false, items: [] };
      }

      var items = [];
      for (var i = 0; i < feed.list.length; i++) {
        var stream = feed.list[i].liveStream;
        if (!stream || !stream.author) continue;
        items.push({
          roomId: stream.author.id || '',
          title: stream.caption || '',
          cover: stream.coverUrl || '',
          userName: stream.author.name || '',
          online: parseInt(stream.watchingCount || '0', 10)
        });
      }

      return {
        hasMore: !!feed.pcursor && feed.pcursor !== 'no_more',
        items: items
      };
    } catch (e) {
      return { hasMore: false, items: [] };
    }
  },

  // 3. 获取分类房间列表
  getCategoryRooms: function(category, page) {
    return {
      __type: 'http_request',
      url: 'https://live.kuaishou.com/graphql',
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
        'Referer': 'https://live.kuaishou.com/cate/' + category.id
      },
      body: JSON.stringify({
        operationName: 'CategoryDetailFeedQuery',
        variables: {
          categoryId: category.id,
          count: 20,
          pcursor: String(page > 1 ? page : 0)
        },
        query: 'query CategoryDetailFeedQuery($categoryId: String, $pcursor: String, $count: Int) { categoryDetailFeed(categoryId: $categoryId, pcursor: $pcursor, count: $count) { pcursor list { liveStream { caption coverUrl watchingCount author { id name avatar } } } } }'
      }),
      callback: '_onGetRecommendRooms'
    };
  },

  // 4. 搜索房间
  searchRooms: function(keyword, page) {
    return {
      hasMore: false,
      items: []
    };
  },

  // 5. 搜索主播
  searchAnchors: function(keyword, page) {
    return {
      hasMore: false,
      items: []
    };
  },

  // 6. 获取房间详情 (请求网页 SSR 提取 window.__INITIAL_STATE__)
  getRoomDetail: function(roomId) {
    return {
      __type: 'http_request',
      url: 'https://live.kuaishou.com/u/' + roomId,
      method: 'GET',
      headers: {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
        'Referer': 'https://live.kuaishou.com/'
      },
      callback: '_onGetRoomDetail'
    };
  },

  _onGetRoomDetail: function(respStr, statusCode) {
    try {
      var jsonStr = SimpleLive.regex.find(respStr, /window\.__INITIAL_STATE__\s*=\s*({[\s\S]*?});\s*\(?function/);
      if (!jsonStr) {
        jsonStr = SimpleLive.regex.find(respStr, /window\.__INITIAL_STATE__\s*=\s*({[\s\S]*?});/);
      }
      if (!jsonStr) {
        return {
          roomId: '',
          title: '未开播或房间不存在',
          cover: '',
          userName: '',
          userAvatar: '',
          online: 0,
          status: false,
          url: ''
        };
      }

      var state = JSON.parse(jsonStr);
      var liveroom = state.liveroom || {};
      var author = liveroom.author || {};
      var liveStream = liveroom.liveStream || {};
      var isLiving = liveStream.living === true || liveroom.isLiving === true;

      return {
        roomId: String(author.id || author.principalId || ''),
        title: liveStream.caption || liveroom.caption || (author.name + '的直播间'),
        cover: liveStream.coverUrl || liveroom.coverUrl || '',
        userName: author.name || '',
        userAvatar: author.avatar || '',
        online: parseInt(liveStream.watchingCount || liveroom.watchingCount || '0', 10),
        status: isLiving,
        introduction: author.description || '',
        notice: liveroom.notice || '',
        url: 'https://live.kuaishou.com/u/' + (author.id || ''),
        data: {
          playUrls: liveStream.playUrls || [],
          hlsPlayUrl: liveStream.hlsPlayUrl || '',
          httpFlvPlayUrls: liveStream.httpFlvPlayUrls || []
        }
      };
    } catch (e) {
      return {
        roomId: '',
        title: '解析异常',
        cover: '',
        userName: '',
        userAvatar: '',
        online: 0,
        status: false,
        url: ''
      };
    }
  },

  // 7. 读取清晰度列表
  getPlayQualities: function(detail) {
    var qualities = [
      { quality: '超清 1080P', data: '1080p', sort: 1 },
      { quality: '高清 720P', data: '720p', sort: 2 },
      { quality: '标清 540P', data: '540p', sort: 3 }
    ];

    try {
      var data = detail.data || {};
      if (data.playUrls && data.playUrls.length > 0) {
        var customQ = [];
        var firstGroup = data.playUrls[0];
        var repList = (firstGroup.freeTraffic && firstGroup.freeTraffic.adaptationSet && firstGroup.freeTraffic.adaptationSet.representation)
          || (firstGroup.hls && firstGroup.hls.adaptationSet && firstGroup.hls.adaptationSet.representation) 
          || [];
        
        for (var i = 0; i < repList.length; i++) {
          var rep = repList[i];
          customQ.push({
            quality: rep.name || ('清晰度 ' + (i + 1)),
            data: rep.id || String(i),
            sort: i + 1
          });
        }
        if (customQ.length > 0) {
          return customQ;
        }
      }
    } catch (e) {}

    return qualities;
  },

  // 8. 解析直播流播放地址
  getPlayUrls: function(detail, quality) {
    var urls = [];
    var headers = {
      'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
      'Referer': 'https://live.kuaishou.com/'
    };

    try {
      var data = detail.data || {};
      var playUrls = data.playUrls || [];
      for (var i = 0; i < playUrls.length; i++) {
        var group = playUrls[i];
        // 1. FLV 播放地址
        if (group.freeTraffic && group.freeTraffic.adaptationSet) {
          var flvReps = group.freeTraffic.adaptationSet.representation || [];
          for (var j = 0; j < flvReps.length; j++) {
            if (quality.data === '1080p' || flvReps[j].id === quality.data || flvReps[j].name === quality.quality) {
              if (flvReps[j].url) urls.push(flvReps[j].url);
            }
          }
        }
        // 2. HLS / m3u8 播放地址
        if (group.hls && group.hls.adaptationSet) {
          var hlsReps = group.hls.adaptationSet.representation || [];
          for (var k = 0; k < hlsReps.length; k++) {
            if (quality.data === '1080p' || hlsReps[k].id === quality.data || hlsReps[k].name === quality.quality) {
              if (hlsReps[k].url) urls.push(hlsReps[k].url);
            }
          }
        }
      }

      if (urls.length === 0 && data.hlsPlayUrl) {
        urls.push(data.hlsPlayUrl);
      }
    } catch (e) {}

    if (urls.length === 0) {
      urls.push('https://txmov2.a.yximgs.com/bs2/livestream/' + detail.roomId + '.flv');
      urls.push('https://txmov2.a.yximgs.com/bs2/livestream/' + detail.roomId + '.m3u8');
    }

    return {
      urls: urls,
      headers: headers
    };
  },

  // 9. 查询直播状态
  getLiveStatus: function(roomId) {
    return true;
  }
});
