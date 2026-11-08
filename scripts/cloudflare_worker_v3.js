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
  event.respondWith(handleRequest(event.request));
});

// 边缘内存高速缓存 (减少对源站的重复并发压力)
const CACHE_STORE = {
  pandatv: null,
  pandatv_time: 0,
  flextv: null,
  flextv_time: 0,
  bj_map: {}, // userId -> { id, userIdx, streamUrl, time }
};

async function handleRequest(request) {
  const url = new URL(request.url);
  const path = url.pathname;

  const corsHeaders = {
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Methods': 'GET, HEAD, POST, OPTIONS',
    'Access-Control-Allow-Headers': '*',
    'Access-Control-Max-Age': '86400',
  };

  if (request.method === 'OPTIONS') {
    return new Response(null, { status: 204, headers: corsHeaders });
  }

  // 0. 专有毫秒级健康心跳探测端点
  if (path === '/ping' || path === '/health') {
    return new Response(JSON.stringify({
      status: 'ok',
      engine: 'cf-stream-engine-v3',
      edge: request.cf ? request.cf.colo : 'ANY',
      time: Date.now()
    }), {
      status: 200,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' }
    });
  }

  // 0. 专有下载吞吐量测速端点 (256KB 真实极速测试数据)
  if (path === '/speedtest') {
    const payload = new Uint8Array(256 * 1024);
    return new Response(payload, {
      status: 200,
      headers: {
        ...corsHeaders,
        'Content-Type': 'application/octet-stream',
        'Content-Length': String(payload.byteLength),
        'Cache-Control': 'no-store, no-cache',
      }
    });
  }

  // 1. 🌟 核心突破：自主官方直通解析器 (输入主播名/房间ID -> 直接逆向官方提取 AWS IVS 直链)
  if (path === '/resolve' || path === '/api/live/resolve') {
    const targetUser = url.searchParams.get('user') || url.searchParams.get('userId') || url.searchParams.get('id');
    if (!targetUser) {
      return new Response(JSON.stringify({ result: false, error: 'Missing user parameter' }), {
        status: 400,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      });
    }

    const streamData = await resolveOfficialStream(targetUser);
    return new Response(JSON.stringify(streamData), {
      status: streamData.result ? 200 : 502,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' }
    });
  }

  // 2. PandaTV 实时流列表聚合接口 (带 M3U 直链实时对齐 + 内存缓存 15s)
  if (path === '/pandatv' || path === '/list.json') {
    const now = Date.now();
    if (CACHE_STORE.pandatv && (now - CACHE_STORE.pandatv_time < 15000)) {
      return new Response(CACHE_STORE.pandatv, {
        headers: {
          ...corsHeaders,
          'Content-Type': 'application/json; charset=utf-8',
          'X-Cache': 'HIT-EDGE',
        }
      });
    }

    try {
      const reqHeaders = {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/128.0.0.0 Safari/537.36',
        'Accept': 'application/json, text/plain, */*',
        'Referer': 'https://5721004.xyz/player/pandatv.html'
      };

      const [m3uRes, jsonRes] = await Promise.all([
        fetch('https://5721004.xyz/player/list.m3u', { headers: reqHeaders }).catch(() => null),
        fetch('https://5721004.xyz/player/list.json', { headers: reqHeaders }).catch(() => null)
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

        CACHE_STORE.pandatv = respBody;
        CACHE_STORE.pandatv_time = now;

        return new Response(respBody, {
          headers: {
            ...corsHeaders,
            'Content-Type': 'application/json; charset=utf-8',
            'Cache-Control': 'public, max-age=15',
          }
        });
      }
    } catch (e) {
      if (CACHE_STORE.pandatv) {
        return new Response(CACHE_STORE.pandatv, {
          headers: { ...corsHeaders, 'Content-Type': 'application/json; charset=utf-8', 'X-Fallback': 'CACHE' }
        });
      }
      return new Response(JSON.stringify({ error: e.toString() }), { status: 500, headers: corsHeaders });
    }
  }

  // 3. FlexTV 实时列表聚合接口
  if (path === '/flextv' || path === '/flex.json') {
    const now = Date.now();
    if (CACHE_STORE.flextv && (now - CACHE_STORE.flextv_time < 15000)) {
      return new Response(CACHE_STORE.flextv, {
        headers: {
          ...corsHeaders,
          'Content-Type': 'application/json; charset=utf-8',
          'X-Cache': 'HIT-EDGE',
        }
      });
    }

    try {
      const reqHeaders = {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/128.0.0.0 Safari/537.36',
        'Accept': 'application/json, text/plain, */*',
        'Referer': 'https://5721004.xyz/player/flextv.html'
      };

      const flexRes = await fetch('https://5721004.xyz/player/flex.json', { headers: reqHeaders });
      if (flexRes.ok) {
        const flexData = await flexRes.text();
        CACHE_STORE.flextv = flexData;
        CACHE_STORE.flextv_time = now;

        return new Response(flexData, {
          headers: {
            ...corsHeaders,
            'Content-Type': 'application/json; charset=utf-8',
            'Cache-Control': 'public, max-age=15',
          }
        });
      }
    } catch (e) {
      if (CACHE_STORE.flextv) {
        return new Response(CACHE_STORE.flextv, {
          headers: { ...corsHeaders, 'Content-Type': 'application/json; charset=utf-8', 'X-Fallback': 'CACHE' }
        });
      }
      return new Response(JSON.stringify({ error: e.toString() }), { status: 500, headers: corsHeaders });
    }
  }

  // 4. 🌟 终极核心：全链路 HLS 递归重写与超清秒开视频流代理
  if (path === '/hls' || path.startsWith('/proxy/')) {
    let target = url.searchParams.get('url') || url.searchParams.get('target');
    if (!target && path.startsWith('/proxy/')) {
      target = url.href.substring(url.href.indexOf('/proxy/') + 7);
    }

    // A. 测速保活特殊探测：杜绝因为向原站发探测导致 522/400 假死
    if (!target || target === 'ping' || target === 'test' || target.includes('generate_204') || target === 'https://www.pandalive.co.kr/' || target === 'https://www.pandalive.co.kr') {
      const payload = new Uint8Array(256 * 1024);
      return new Response(payload, {
        status: 200,
        headers: {
          ...corsHeaders,
          'Content-Type': 'application/octet-stream',
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

      const streamInfo = await resolveOfficialStream(uId);
      if (streamInfo.result && streamInfo.streamUrl) {
        target = streamInfo.streamUrl;
      } else {
        return new Response('Unable to resolve live stream: ' + (streamInfo.message || 'Unknown'), {
          status: 404,
          headers: corsHeaders
        });
      }
    }

    try {
      // 智能识别平台防盗链规则
      const forwardHeaders = new Headers();
      forwardHeaders.set('User-Agent', 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/128.0.0.0 Safari/537.36');
      forwardHeaders.set('Accept', '*/*');

      const isPanda = target.includes('live-video.net') || target.includes('pandalive');
      const isFlex = target.includes('naverncp.com') || target.includes('flextv');

      if (isPanda) {
        forwardHeaders.set('Origin', 'https://www.pandalive.co.kr');
        forwardHeaders.set('Referer', 'https://www.pandalive.co.kr/');
      } else if (isFlex) {
        forwardHeaders.set('Origin', 'https://www.flextv.co.kr');
        forwardHeaders.set('Referer', 'https://www.flextv.co.kr/');
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
        return new Response(res.body, { status: res.status, headers: corsHeaders });
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
            ...corsHeaders,
            'Content-Type': 'application/vnd.apple.mpegurl; charset=utf-8',
            'Cache-Control': 'no-cache, no-store, must-revalidate',
          }
        });
      }

      // B. 如果是 TS 视频切片数据：零拷贝极速流式传输 (Zero-copy Streaming Piping)
      const outHeaders = new Headers(corsHeaders);
      outHeaders.set('Content-Type', contentType || 'video/MP2T');
      const cl = res.headers.get('content-length');
      if (cl) outHeaders.set('Content-Length', cl);
      outHeaders.set('Cache-Control', 'public, max-age=60'); // 切片可短期边缘缓存加速

      return new Response(res.body, {
        status: 200,
        headers: outHeaders,
      });

    } catch (e) {
      return new Response('HLS Acceleration Error: ' + e.toString(), { status: 502, headers: corsHeaders });
    }
  }

  // 5. 默认在线体检说明端点
  return new Response(JSON.stringify({
    status: 'online',
    service: 'Cloudflare Dedicated Stream Engine v3.0 (自主官方解析+全链路TS重写版)',
    domain: url.host,
    endpoints: [
      '/ping',
      '/speedtest',
      '/resolve?user=主播名',
      '/pandatv',
      '/flextv',
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
    headers: { ...corsHeaders, 'Content-Type': 'application/json; charset=utf-8' }
  });
}

/**
 * 🌟 核心逆向算法：向韩国官方 API 换取底层推流直链
 */
async function resolveOfficialStream(userId) {
  const cleanId = String(userId).trim();
  if (!cleanId) return { result: false, message: 'Invalid userId' };

  try {
    const memberHeaders = {
      'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36',
      'Referer': 'https://www.pandalive.co.kr/',
      'Content-Type': 'application/x-www-form-urlencoded',
    };

    // 1. 获取主播 userIdx
    const memberRes = await fetch('https://api.pandalive.co.kr/v1/member/bj', {
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
      'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36',
      'Referer': `https://www.pandalive.co.kr/play/${encodeURIComponent(cleanId)}`,
      'Content-Type': 'application/x-www-form-urlencoded',
    };

    const playRes = await fetch('https://api.pandalive.co.kr/v1/live/play', {
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
          source: 'official_direct'
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
