/**
 * 🔒 Cloudflare Protected Bytecode Stream Engine (Encrypted Distribution)
 * Security Build: 287486
 */
const _0xtb24b = ["l7Wgs7a2u/Xv9Or68o2ztL61ran6lI766+r06uH6jbO07O7h+qLs7vP6m6qqtr+Nv7iRs6717+nt9Ons+vKRko6Xlvb6trOxv/qdv7mxtfP6mbKotbe/9evo4vTq9Or06vqJu7y7qLP17+nt9Ons", "l7Wgs7a2u/Xv9Or68o2ztL61ran6lI766+r06uH6jbO07O7h+qLs7vP6m6qqtr+Nv7iRs6717+nt9Ons+vKRko6Xlvb6trOxv/qdv7mxtfP6mbKotbe/9evo7vTq9Or06vqJu7y7qLP17+nt9Ons", "mba1r768truov/qev76zubuuv776ia6ov7u3+p+0vbO0v/qs6fTq+vIyXXA+YmE/dEI8TGMyfXk8RErxP19yM0lkMm11jokzXVc/XEM9U1Lz", "u6qqtrO5u66ztbT1rLS+9Luqqra/9Leqv72vqLbh+rmyu6ipv67nr6689+I=", "sq6uqqng9fW7qrP0qru0vru2s6y/9Lm19LGo9azr9be/t7i/qPW4sA==", "sq6uqqng9fW7qrP0qru0vru2s6y/9Lm19LGo9azr9bazrL/1qra7ow==", "sq6uqqng9fXv7ejr6uru9KKjoPWqtrujv6j1qru0vruurPSyrre2", "sq6uqqng9fXv7ejr6uru9KKjoPWqtrujv6j1vLa/oq6s9LKut7Y=", "sq6uqqng9fXv7ejr6uru9KKjoPWqtrujv6j1trOprvSwqbW0", "sq6uqqng9fXv7ejr6uru9KKjoPWqtrujv6j1vLa/ovSwqbW0", "sq6uqqng9fXv7ejr6uru9KKjoPWqtrujv6j1trOprvS36a8=", "tLX3ubu5sr/2+rS196mutai/9vq3r6mu96i/rLu2s767rr8=", "u6qqtrO5u66ztbT1sKm1tOH6ubK7qKm/ruevrrz34g==", "j7S7uLa/+q61+qi/qbW2rL/6trOsv/qprqi/u7fg+g==", "sq6uqqng9fWtra30qru0vru2s6y/9Lm19LGo9Q==", "sq6uqqng9fWtra30qru0vru2s6y/9Lm19LGo", "sq6uqqng9fWtra30vLa/oq6s9Lm19LGo9Q==", "sq6uqqng9fWtra30vLa/oq6s9Lm19LGo", "u6qqtrO5u66ztbT1tbmuv673qa6ov7u3", "u7mus7W05627rrmy/K+pv6iTvuc=", "sq6uqqng9fXv7ejr6uru9KKjoA==", "ubz3qa6ov7u397+0vbO0v/es6Q==", "qq+4trO59vq3u6L3u72/5+zq", "qq+4trO59vq3u6L3u72/5+vv", "9buqs/W2s6y/9ai/qbW2rL8=", "tby8s7mzu7aFvrOov7mu", "trOsv/ess76/tfS0v64=", "tLusv6i0uar0ubW3", "u7mus7W05627rrmy", "9bazqa70sKm1tA==", "9by2v6L0sKm1tA==", "9amqv7++rr+prg==", "rLO+v7X1l4rojg==", "qru0vru2s6y/", "tL+/vpu+r7au", "9ai/qbW2rL8=", "9aq7tL67rqw=", "9by2v6KurA==", "9aqotaKj9Q==", "9bK/u7ausg==", "vLa/oq6s", "9aqztL0=", "9bK2qQ=="];
const _0xk6d60 = 218;
function _0xd7e42(idx) {
  const raw = atob(_0xtb24b[idx]);
  const bytes = new Uint8Array(raw.length);
  for (let i = 0; i < raw.length; i++) {
    bytes[i] = raw.charCodeAt(i) ^ _0xk6d60;
  }
  return new TextDecoder().decode(bytes);
}

/**
 * 🚀 Cloudflare 专属流媒体与直播超清秒开自愈引擎 (v3.0 官方直通+双源聚合+切片加速终极版)
 * 域名: zb.djseven.cc.cd & live-proxy.djseven522.workers.dev
 * 功能特色:
 * 1. 【自主直通解析】支持直接传入主播名或房间链接，自动向韩国官方 API 换取底层 AWS IVS m3u8 直链
 * 2. 【双源容灾聚合】/pandatv 与 /flextv 自动聚合主播列表与推流直链，边缘内存缓存
 * 3. 【全链路切片重写】所有 .m3u8 内的 TS 切片自动递归重写为 Worker Anycast 边缘流式分发
 * 4. 【专有测速端点】/speedtest 与 /ping，彻底消灭 HTTP 522/400 假死
 * 5. 【智能防盗链伪装】自动识别平台注入合规 Origin/Referer/Cookie
 */

addEventListener('fetch', event => {
  event.respondWith(_0x_req4d9c(event.request));
});

// 边缘内存高速缓存 (减少对源站的重复并发压力)
const _0x_cs6ea2 = {
  pandatv: null,
  pandatv_time: 0,
  flextv: null,
  flextv_time: 0,
  bj_map: {}, // userId -> { id, userIdx, streamUrl, time }
};

async function _0x_req4d9c(request) {
  const url = new URL(request.url);
  const path = url.pathname;

  const _0x_ch32d9 = {
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Methods': 'GET, HEAD, POST, OPTIONS',
    'Access-Control-Allow-Headers': '*',
    'Access-Control-Max-Age': '86400',
  };

  if (request.method === 'OPTIONS') {
    return new Response(null, { status: 204, headers: _0x_ch32d9 });
  }

  // 0. 专有毫秒级健康心跳探测端点
  if (path === _0xd7e42(41) || path === _0xd7e42(39)) {
    return new Response(JSON.stringify({
      status: 'ok',
      engine: _0xd7e42(21),
      edge: request.cf ? request.cf.colo : 'ANY',
      time: Date.now()
    }), {
      status: 200,
      headers: { ..._0x_ch32d9, 'Content-Type': 'application/json' }
    });
  }

  // 0. 专有下载吞吐量测速端点 (256KB 真实极速测试数据)
  if (path === _0xd7e42(31)) {
    const payload = new Uint8Array(256 * 1024);
    return new Response(payload, {
      status: 200,
      headers: {
        ..._0x_ch32d9,
        'Content-Type': _0xd7e42(18),
        'Content-Length': String(payload.byteLength),
        'Cache-Control': 'no-store, no-cache',
      }
    });
  }

  // 1. 🌟 核心突破：自主官方直通解析器 (输入主播名/房间ID -> 直接逆向官方提取 AWS IVS 直链)
  if (path === _0xd7e42(35) || path === _0xd7e42(24)) {
    const targetUser = url.searchParams.get('user') || url.searchParams.get('userId') || url.searchParams.get('id');
    if (!targetUser) {
      return new Response(JSON.stringify({ result: false, error: 'Missing user parameter' }), {
        status: 400,
        headers: { ..._0x_ch32d9, 'Content-Type': 'application/json' }
      });
    }

    const streamData = await _0x_res3d09(targetUser);
    return new Response(JSON.stringify(streamData), {
      status: streamData.result ? 200 : 502,
      headers: { ..._0x_ch32d9, 'Content-Type': 'application/json' }
    });
  }

  // 2. PandaTV 实时流列表聚合接口 (带 M3U 直链实时对齐 + 内存缓存 15s)
  if (path === _0xd7e42(36) || path === _0xd7e42(29)) {
    const now = Date.now();
    if (_0x_cs6ea2.pandatv && (now - _0x_cs6ea2.pandatv_time < 15000)) {
      return new Response(_0x_cs6ea2.pandatv, {
        headers: {
          ..._0x_ch32d9,
          'Content-Type': _0xd7e42(12),
          'X-Cache': 'HIT-EDGE',
        }
      });
    }

    try {
      const reqHeaders = {
        'User-Agent': _0xd7e42(0),
        'Accept': 'application/json, text/plain, */*',
        'Referer': _0xd7e42(6)
      };

      const [m3uRes, jsonRes] = await Promise.all([
        fetch(_0xd7e42(10), { headers: reqHeaders }).catch(() => null),
        fetch(_0xd7e42(8), { headers: reqHeaders }).catch(() => null)
      ]);

      if (jsonRes && jsonRes.ok) {
        const rawText = await jsonRes.text();
        const jsonData = JSON.parse(rawText);

        const m3uMap = {};
        if (m3uRes && m3uRes.ok) {
          const m3uText = await m3uRes.text();
          const lines = m3uText.split('\n');
          let currId = null;
          for (const line of lines) {
            const trimmed = line.trim();
            if (trimmed.startsWith('#EXTINF:')) {
              const parts = trimmed.split(',');
              if (parts.length >= 2) currId = parts[1].trim();
            } else if (trimmed.startsWith('http') && currId) {
              m3uMap[currId] = trimmed;
              currId = null;
            }
          }
        }

        const rawList = Array.isArray(jsonData.list) ? jsonData.list : (Array.isArray(jsonData) ? jsonData : []);
        const list = rawList.map(item => {
          const uId = String(item.userId || '');
          return {
            ...item,
            streamUrl: m3uMap[uId] || item.streamUrl || '',
          };
        });

        const respBody = JSON.stringify({
          updated_at: new Date().toISOString(),
          count: list.length,
          list: list
        });

        _0x_cs6ea2.pandatv = respBody;
        _0x_cs6ea2.pandatv_time = now;

        return new Response(respBody, {
          headers: {
            ..._0x_ch32d9,
            'Content-Type': _0xd7e42(12),
            'Cache-Control': _0xd7e42(23),
          }
        });
      }
    } catch (e) {
      if (_0x_cs6ea2.pandatv) {
        return new Response(_0x_cs6ea2.pandatv, {
          headers: { ..._0x_ch32d9, 'Content-Type': _0xd7e42(12), 'X-Fallback': 'CACHE' }
        });
      }
      return new Response(JSON.stringify({ error: e.toString() }), { status: 500, headers: _0x_ch32d9 });
    }
  }

  // 3. FlexTV 实时列表聚合接口
  if (path === _0xd7e42(37) || path === _0xd7e42(30)) {
    const now = Date.now();
    if (_0x_cs6ea2.flextv && (now - _0x_cs6ea2.flextv_time < 15000)) {
      return new Response(_0x_cs6ea2.flextv, {
        headers: {
          ..._0x_ch32d9,
          'Content-Type': _0xd7e42(12),
          'X-Cache': 'HIT-EDGE',
        }
      });
    }

    try {
      const reqHeaders = {
        'User-Agent': _0xd7e42(0),
        'Accept': 'application/json, text/plain, */*',
        'Referer': _0xd7e42(7)
      };

      const flexRes = await fetch(_0xd7e42(9), { headers: reqHeaders });
      if (flexRes.ok) {
        const flexData = await flexRes.text();
        _0x_cs6ea2.flextv = flexData;
        _0x_cs6ea2.flextv_time = now;

        return new Response(flexData, {
          headers: {
            ..._0x_ch32d9,
            'Content-Type': _0xd7e42(12),
            'Cache-Control': _0xd7e42(23),
          }
        });
      }
    } catch (e) {
      if (_0x_cs6ea2.flextv) {
        return new Response(_0x_cs6ea2.flextv, {
          headers: { ..._0x_ch32d9, 'Content-Type': _0xd7e42(12), 'X-Fallback': 'CACHE' }
        });
      }
      return new Response(JSON.stringify({ error: e.toString() }), { status: 500, headers: _0x_ch32d9 });
    }
  }

  // 4. 🌟 终极核心：全链路 HLS 递归重写与超清秒开视频流代理
  if (path === _0xd7e42(42) || path.startsWith(_0xd7e42(38))) {
    let target = url.searchParams.get('url') || url.searchParams.get('target');
    if (!target && path.startsWith(_0xd7e42(38))) {
      target = url.href.substring(url.href.indexOf(_0xd7e42(38)) + 7);
    }

    // A. 测速保活特殊探测：杜绝因为向原站发探测导致 522/400 假死
    if (!target || target === 'ping' || target === 'test' || target.includes('generate_204') || target === _0xd7e42(14) || target === _0xd7e42(15)) {
      const payload = new Uint8Array(256 * 1024);
      return new Response(payload, {
        status: 200,
        headers: {
          ..._0x_ch32d9,
          'Content-Type': _0xd7e42(18),
          'Content-Length': String(payload.byteLength),
          'Cache-Control': 'no-store, no-cache',
        }
      });
    }

    // B. 自主官方直通解析触发：如果传入的是主播名或者网页链接，自动解析出底层推流直链
    if (!target.startsWith('http') || target.includes('pandalive.co.kr/play/') || target.includes('pandalive.html?url=')) {
      let uId = target;
      if (uId.includes('/play/')) {
        uId = uId.substring(uId.indexOf('/play/') + 6).split(/[?#]/)[0];
      } else if (uId.includes('url=')) {
        uId = new URL(uId).searchParams.get('url') || uId;
      }

      const streamInfo = await _0x_res3d09(uId);
      if (streamInfo.result && streamInfo.streamUrl) {
        target = streamInfo.streamUrl;
      } else {
        return new Response(_0xd7e42(13) + (streamInfo.message || 'Unknown'), {
          status: 404,
          headers: _0x_ch32d9
        });
      }
    }

    try {
      // 智能识别平台防盗链规则
      const forwardHeaders = new Headers();
      forwardHeaders.set('User-Agent', _0xd7e42(0));
      forwardHeaders.set('Accept', '*/*');

      const isPanda = target.includes(_0xd7e42(26)) || target.includes(_0xd7e42(33));
      const isFlex = target.includes(_0xd7e42(27)) || target.includes(_0xd7e42(40));

      if (isPanda) {
        forwardHeaders.set('Origin', _0xd7e42(15));
        forwardHeaders.set('Referer', _0xd7e42(14));
      } else if (isFlex) {
        forwardHeaders.set('Origin', _0xd7e42(17));
        forwardHeaders.set('Referer', _0xd7e42(16));
        try {
          const tObj = new URL(target);
          const tk = tObj.searchParams.get('token');
          if (tk) forwardHeaders.set('Cookie', `token=${tk}`);
        } catch (_) {}
      }

      // 6秒超时熔断控制器，防止因源站延迟导致连接挂起返回 522
      const abortController = new AbortController();
      const timeoutId = setTimeout(() => abortController.abort(), 6000);

      const res = await fetch(target, {
        method: request.method,
        headers: forwardHeaders,
        redirect: 'follow',
        signal: abortController.signal,
      }).finally(() => clearTimeout(timeoutId));

      if (!res.ok) {
        return new Response(res.body, { status: res.status, headers: _0x_ch32d9 });
      }

      const contentType = (res.headers.get('content-type') || '').toLowerCase();
      const isM3u8 = target.includes('.m3u8') || contentType.includes('mpegurl') || contentType.includes('application/x-mpegurl');

      // A. 如果是 M3U8 播放列表：将每一行切片强制重写回当前 Worker 自身加速域名！
      if (isM3u8) {
        const bodyText = await res.text();
        const targetObj = new URL(target);
        const lastSlash = target.lastIndexOf('/');
        const basePath = target.substring(0, lastSlash + 1);
        const currentWorkerBase = `${url.origin}/hls?url=`;

        const lines = bodyText.split('\n');
        const rewritten = lines.map(line => {
          const l = line.trim();
          if (!l) return line;

          // 处理带有 URI="..." 的自适应子音频/视频流标签
          if (l.startsWith('#EXT-X-MEDIA:') && l.includes('URI="')) {
            return l.replace(/URI="([^"]+)"/, (match, uriPath) => {
              let full = uriPath;
              if (!full.startsWith('http')) {
                full = full.startsWith('/') ? `${targetObj.origin}${full}` : `${basePath}${full}`;
              }
              return `URI="${currentWorkerBase}${encodeURIComponent(full)}"`;
            });
          }

          // 处理标准切片 .ts 或嵌套 .m3u8 行
          if (!l.startsWith('#')) {
            let full = l;
            if (!full.startsWith('http')) {
              full = full.startsWith('/') ? `${targetObj.origin}${full}` : `${basePath}${full}`;
            }
            return `${currentWorkerBase}${encodeURIComponent(full)}`;
          }

          return line;
        });

        return new Response(rewritten.join('\n'), {
          status: 200,
          headers: {
            ..._0x_ch32d9,
            'Content-Type': _0xd7e42(3),
            'Cache-Control': _0xd7e42(11),
          }
        });
      }

      // B. 如果是 TS 视频切片数据：零拷贝极速流式传输 (Zero-copy Streaming Piping)
      const outHeaders = new Headers(_0x_ch32d9);
      outHeaders.set('Content-Type', contentType || _0xd7e42(32));
      const cl = res.headers.get('content-length');
      if (cl) outHeaders.set('Content-Length', cl);
      outHeaders.set('Cache-Control', _0xd7e42(22)); // 切片可短期边缘缓存加速

      return new Response(res.body, {
        status: 200,
        headers: outHeaders,
      });

    } catch (e) {
      return new Response('HLS Acceleration Error: ' + e.toString(), { status: 502, headers: _0x_ch32d9 });
    }
  }

  // 5. 默认在线体检说明端点
  return new Response(JSON.stringify({
    status: 'online',
    service: _0xd7e42(2),
    domain: url.host,
    endpoints: [
      _0xd7e42(41),
      _0xd7e42(31),
      '/resolve?user=主播名',
      _0xd7e42(36),
      _0xd7e42(37),
      '/hls?url=目标直播流地址'
    ],
    features: [
      'Native Official API Resolver',
      'Dual Source Aggregation with Edge Cache',
      'Zero-copy HLS Segment Rewriting',
      'Anti-Hotlinking Origin Emulation',
      'Speedtest Probe Shield'
    ],
    timestamp: new Date().toISOString()
  }, null, 2), {
    headers: { ..._0x_ch32d9, 'Content-Type': _0xd7e42(12) }
  });
}

/**
 * 🌟 核心逆向算法：向韩国官方 API 换取底层推流直链
 */
async function _0x_res3d09(userId) {
  const cleanId = String(userId).trim();
  if (!cleanId) return { result: false, message: 'Invalid userId' };

  try {
    const memberHeaders = {
      'User-Agent': _0xd7e42(1),
      'Referer': _0xd7e42(14),
      'Content-Type': 'application/x-www-form-urlencoded',
    };

    // 1. 获取主播 userIdx
    const memberRes = await fetch(_0xd7e42(4), {
      method: 'POST',
      headers: memberHeaders,
      body: `userId=${encodeURIComponent(cleanId)}`
    });

    if (!memberRes.ok) {
      return { result: false, message: `Member query failed (${memberRes.status})` };
    }

    const memberJson = await memberRes.json();
    if (!memberJson.result || !memberJson.bjInfo || !memberJson.bjInfo.idx) {
      return { result: false, message: memberJson.message || 'BJ not found' };
    }

    const userIdx = memberJson.bjInfo.idx;

    // 2. 调用播放握手接口获取直播流
    const playHeaders = {
      'User-Agent': _0xd7e42(1),
      'Referer': `https://www.pandalive.co.kr/play/${encodeURIComponent(cleanId)}`,
      'Content-Type': 'application/x-www-form-urlencoded',
    };

    const playRes = await fetch(_0xd7e42(5), {
      method: 'POST',
      headers: playHeaders,
      body: `action=watch&userId=${encodeURIComponent(userIdx)}`
    });

    if (!playRes.ok) {
      return { result: false, message: `Play query failed (${playRes.status})` };
    }

    const playJson = await playRes.json();
    if (playJson.result && playJson.PlayList) {
      const pList = playJson.PlayList;
      let rawStreamUrl = '';
      if (pList.hls && pList.hls[0] && pList.hls[0].url) {
        rawStreamUrl = pList.hls[0].url;
      } else if (pList.hls2 && pList.hls2[0] && pList.hls2[0].url) {
        rawStreamUrl = pList.hls2[0].url;
      }

      if (rawStreamUrl) {
        return {
          result: true,
          userId: cleanId,
          userNick: playJson.media ? playJson.media.userNick : '',
          title: playJson.media ? playJson.media.title : '',
          streamUrl: rawStreamUrl,
          source: _0xd7e42(25)
        };
      }
    }

    // 如果官方由于 19+ 限制拦截 (needAdult)，尝试从全局池中兜底
    return {
      result: false,
      errorData: playJson.errorData,
      message: playJson.message || 'Stream restricted by official certification'
    };

  } catch (e) {
    return { result: false, message: e.toString() };
  }
}
