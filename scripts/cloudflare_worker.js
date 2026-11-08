addEventListener('fetch', event => {
  event.respondWith(handleRequest(event.request));
});

async function handleRequest(request) {
  const url = new URL(request.url);
  const path = url.pathname;

  const corsHeaders = {
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Methods': 'GET, HEAD, POST, OPTIONS',
    'Access-Control-Allow-Headers': '*',
  };

  if (request.method === 'OPTIONS') {
    return new Response(null, { headers: corsHeaders });
  }

  // 1. PandaTV 实时流聚合接口
  if (path === '/pandatv' || path === '/list.json') {
    try {
      const reqHeaders = {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36',
        'Accept': 'application/json, text/plain, */*',
        'Referer': 'https://5721004.xyz/player/pandatv.html'
      };

      const m3uRes = await fetch('https://5721004.xyz/player/list.m3u', { headers: reqHeaders });
      const jsonRes = await fetch('https://5721004.xyz/player/list.json', { headers: reqHeaders });

      if (jsonRes.ok) {
        let rawText = await jsonRes.text();
        let jsonData = JSON.parse(rawText);

        const m3uMap = {};
        if (m3uRes.ok) {
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

        return new Response(JSON.stringify({
          updated_at: new Date().toISOString(),
          count: list.length,
          list: list
        }), {
          headers: {
            ...corsHeaders,
            'Content-Type': 'application/json; charset=utf-8',
            'Cache-Control': 'public, max-age=15, s-maxage=15',
          }
        });
      }
    } catch (e) {
      return new Response(JSON.stringify({ error: e.toString() }), { status: 500, headers: corsHeaders });
    }
  }

  // 2. FlexTV 实时列表接口（从官方 live-list-main 和 live-list-top 实时聚合）
  if (path === '/flextv' || path === '/flex.json') {
    try {
      const reqHeaders = {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36',
        'Accept': 'application/json, text/plain, */*',
        'Referer': 'https://www.flextv.co.kr/',
        'Origin': 'https://www.flextv.co.kr'
      };

      const [mainRes, topRes] = await Promise.allSettled([
        fetch('https://www.flextv.co.kr/api/channels/live-list-main', { headers: reqHeaders }),
        fetch('https://www.flextv.co.kr/api/channels/live-list-top', { headers: reqHeaders })
      ]);

      const seenIds = new Set();
      const mergedList = [];

      for (const res of [topRes, mainRes]) {
        if (res.status === 'fulfilled' && res.value.ok) {
          try {
            const data = await res.value.json();
            const items = data.data || [];
            for (const item of items) {
              const cid = item.channelId || (item.owner && item.owner.loginId);
              if (cid && !seenIds.has(cid)) {
                seenIds.add(cid);
                mergedList.push(item);
              }
            }
          } catch (_) {}
        }
      }

      if (mergedList.length > 0) {
        return new Response(JSON.stringify({ data: mergedList }), {
          headers: {
            ...corsHeaders,
            'Content-Type': 'application/json; charset=utf-8',
            'Cache-Control': 'public, max-age=10, s-maxage=10',
          }
        });
      }

      // 兜底回退
      const flexRes = await fetch('https://5721004.xyz/player/flex.json', { headers: reqHeaders });
      if (flexRes.ok) {
        const flexData = await flexRes.text();
        return new Response(flexData, {
          headers: {
            ...corsHeaders,
            'Content-Type': 'application/json; charset=utf-8',
            'Cache-Control': 'public, max-age=15, s-maxage=15',
          }
        });
      }
    } catch (e) {
      return new Response(JSON.stringify({ error: e.toString() }), { status: 500, headers: corsHeaders });
    }
  }

  // 3. 🌟 HLS 流自愈代理（彻底解决 Naver NCP 403 / Token 丢失导致的播放报错）
  if (path === '/hls') {
    const target = url.searchParams.get('url');
    if (!target) return new Response('Missing target url', { status: 400, headers: corsHeaders });

    try {
      const targetObj = new URL(target);
      const tokenStr = targetObj.search; // e.g. "?token=st=..."
      const lastSlashIdx = targetObj.pathname.lastIndexOf('/');
      const basePath = targetObj.origin + targetObj.pathname.substring(0, lastSlashIdx + 1);

      const res = await fetch(target, {
        headers: {
          'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36',
          'Referer': 'https://www.flextv.co.kr/',
          'Origin': 'https://www.flextv.co.kr',
        }
      });

      if (!res.ok) {
        return new Response(res.body, { status: res.status, headers: corsHeaders });
      }

      const bodyText = await res.text();
      if (bodyText.startsWith('#EXTM3U')) {
        const lines = bodyText.split('\n');
        const rewritten = lines.map(line => {
          let l = line.trim();
          if (l.startsWith('#EXT-X-MEDIA:') && l.includes('URI="')) {
            return l.replace(/URI="([^"]+)"/, (match, uriPath) => {
              const full = uriPath.startsWith('http') ? uriPath : (basePath + uriPath);
              const finalUri = full.includes('?') ? full : (full + tokenStr);
              return `URI="${finalUri}"`;
            });
          } else if (!l.startsWith('#') && l.length > 0) {
            const full = l.startsWith('http') ? l : (basePath + l);
            const finalUri = full.includes('?') ? full : (full + tokenStr);
            return finalUri;
          }
          return line;
        });

        return new Response(rewritten.join('\n'), {
          headers: {
            ...corsHeaders,
            'Content-Type': 'application/vnd.apple.mpegurl',
            'Cache-Control': 'no-cache',
          }
        });
      }

      return new Response(bodyText, {
        headers: {
          ...corsHeaders,
          'Content-Type': 'application/vnd.apple.mpegurl',
        }
      });
    } catch (e) {
      return new Response('HLS Proxy Error: ' + e.toString(), { status: 502, headers: corsHeaders });
    }
  }

  // 4. 🌟 短剧海报图片防盗链极速代理（彻底解决 Android Image 403 / 防盗链 / AVIF / SSL 握手问题）
  if (path === '/img' || path === '/image') {
    const targetUrl = url.searchParams.get('url');
    if (!targetUrl) return new Response('Missing target url', { status: 400, headers: corsHeaders });

    try {
      const imgRes = await fetch(targetUrl, {
        headers: {
          'User-Agent': 'Mozilla/5.0 (Linux; Android 14; Mobile) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/128.0.0.0 Mobile Safari/537.36',
          'Referer': 'https://huangguoai.com/',
          'Origin': 'https://huangguoai.com',
          'Accept': 'image/webp,image/png,image/jpeg,image/*;q=0.8',
        }
      });

      if (!imgRes.ok) {
        return new Response(imgRes.body, { status: imgRes.status, headers: corsHeaders });
      }

      const resHeaders = new Headers(imgRes.headers);
      resHeaders.set('Access-Control-Allow-Origin', '*');
      resHeaders.set('Cache-Control', 'public, max-age=86400, s-maxage=86400');

      return new Response(imgRes.body, {
        status: 200,
        headers: resHeaders,
      });
    } catch (e) {
      return new Response('Image Proxy Error: ' + e.toString(), { status: 502, headers: corsHeaders });
    }
  }

  // 5. 🌟 短剧网页源码极速穿透代理
  if (path === '/drama' || path === '/drama-proxy') {
    const targetUrl = url.searchParams.get('url');
    if (!targetUrl) return new Response('Missing url', { status: 400, headers: corsHeaders });

    try {
      const pageRes = await fetch(targetUrl, {
        headers: {
          'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/128.0.0.0 Safari/537.36',
          'Referer': 'https://huangguoai.com/',
          'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8',
          'Accept-Language': 'zh-CN,zh;q=0.9,en;q=0.8',
        }
      });

      const bodyText = await pageRes.text();
      return new Response(bodyText, {
        status: pageRes.status,
        headers: {
          ...corsHeaders,
          'Content-Type': 'text/html; charset=utf-8',
          'Cache-Control': 'no-cache, no-store',
        }
      });
    } catch (e) {
      return new Response('Drama Proxy Error: ' + e.toString(), { status: 502, headers: corsHeaders });
    }
  }

  // 6. 服务在线说明
  return new Response(JSON.stringify({
    status: 'online',
    service: 'PandaLive & FlexTV Dedicated Stream Engine',
    endpoints: ['/pandatv', '/flextv', '/hls', '/img', '/drama'],
    timestamp: new Date().toISOString()
  }, null, 2), {
    headers: { ...corsHeaders, 'Content-Type': 'application/json' }
  });
}
