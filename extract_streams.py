#!/usr/bin/env python3
# -*- coding: utf-8 -*-

"""
=============================================================================
🎬 AI短剧全集真实播放源 (m3u8) 提取脚本
=============================================================================
"""

import sys
import os
import re
import json
import argparse
import urllib.request

HEADERS = {
    'User-Agent': 'Mozilla/5.0 (Linux; Android 14; Mobile) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/128.0.0.0 Mobile Safari/537.36',
    'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8',
    'Accept-Language': 'zh-CN,zh;q=0.9,en;q=0.8',
}

def make_request(url, referer=None, timeout=10):
    headers = dict(HEADERS)
    if referer:
        headers['Referer'] = referer
    req = urllib.request.Request(url, headers=headers)
    try:
        with urllib.request.urlopen(req, timeout=timeout) as resp:
            return resp.read().decode('utf-8', errors='ignore')
    except Exception as e:
        return None

def extract_m3u8_from_embed(base_url, drama_id, episode_num=1):
    """从 Embed 播放页面提取底层的 .m3u8 视频直链"""
    embed_url = f"{base_url}/videos/embed/{drama_id}?ep={episode_num}" if episode_num > 1 else f"{base_url}/videos/embed/{drama_id}"
    referer = f"{base_url}/video/{drama_id}/"
    html = make_request(embed_url, referer=referer)
    if not html:
        return None

    # 正则提取 <source src="xxx.m3u8">
    m = re.search(r'''<source\s+src=["']([^"']+\.m3u8[^"']*)["']''', html, re.IGNORECASE)
    if m:
        stream_url = m.group(1).replace('&amp;', '&')
        if stream_url.startswith('//'):
            stream_url = 'https:' + stream_url
        elif stream_url.startswith('/'):
            stream_url = base_url + stream_url
        return stream_url

    # 正则提取 video src
    m2 = re.search(r'''<video[^>]+src=["']([^"']+)["']''', html, re.IGNORECASE)
    if m2:
        stream_url = m2.group(1).replace('&amp;', '&')
        if stream_url.startswith('//'):
            stream_url = 'https:' + stream_url
        elif stream_url.startswith('/'):
            stream_url = base_url + stream_url
        return stream_url

    return None

def extract_drama_detail(base_url, drama_id):
    """解析短剧标题、封面、总集数"""
    detail_url = f"{base_url}/detail/{drama_id}/"
    html = make_request(detail_url)
    if not html:
        return {"id": drama_id, "title": f"短剧_{drama_id}", "total_episodes": 1, "cover": ""}

    # 标题
    title_match = re.search(r'<h1[^>]*>([^<]+)</h1>', html)
    title = title_match.group(1).strip() if title_match else f"短剧_{drama_id}"

    # 封面
    cover_match = re.search(r'class="[^"]*poster[^"]*"[^>]*src=["\']([^"\']+)["\']', html)
    cover = cover_match.group(1) if cover_match else ""

    # 总集数
    ep_ids = re.findall(r'data-ep-id=["\'](\d+)["\']', html)
    if ep_ids:
        total_episodes = max([int(x) for x in ep_ids])
    else:
        ep_count_match = re.search(r'(\d+)集', html)
        total_episodes = int(ep_count_match.group(1)) if ep_count_match else 5

    return {
        "id": drama_id,
        "title": title,
        "total_episodes": total_episodes,
        "cover": cover
    }

def extract_full_drama(base_url, drama_id, max_eps=None):
    """提取某部短剧的真实播放源"""
    info = extract_drama_detail(base_url, drama_id)
    total = info['total_episodes']
    if max_eps and max_eps < total:
        total = max_eps

    print(f"🎬 正在提取: {info['title']} (共 {total} 集)")
    
    episodes = []
    for ep in range(1, total + 1):
        m3u8_url = extract_m3u8_from_embed(base_url, drama_id, ep)
        episodes.append({
            "episode": ep,
            "title": f"第 {ep} 集",
            "m3u8_url": m3u8_url or "解析失败/无源"
        })
        print(f"  └─ 第 {ep:02d} 集: {m3u8_url}")

    info["episodes"] = episodes
    return info

def main():
    parser = argparse.ArgumentParser(description="AI短剧播放源 (m3u8) 提取工具")
    parser.add_argument("--url", required=True, help="源站点 Base URL (例: https://example.com)")
    parser.add_argument("--id", default="12", help="短剧 ID (例: 12, 117, 3075)")
    parser.add_argument("--eps", type=int, default=5, help="提取前多少集")
    parser.add_argument("--out", default="drama_sources.json", help="输出 JSON 文件路径")
    parser.add_argument("--m3u", default="drama_sources.m3u", help="输出 M3U 播放列表路径")
    
    args = parser.parse_args()
    base_url = args.url.rstrip('/')

    print("=" * 60)
    print(f"🚀 开始提取播放源: 目标站点={base_url}, 短剧ID={args.id}")
    print("=" * 60)

    result = extract_full_drama(base_url, args.id, max_eps=args.eps)

    # 导出为 JSON
    with open(args.out, 'w', encoding='utf-8') as f:
        json.dump(result, f, ensure_ascii=False, indent=2)
    print(f"\n✅ 已保存 JSON 播放源数据到: {args.out}")

    # 导出为标准 M3U 播放列表
    with open(args.m3u, 'w', encoding='utf-8') as f:
        f.write("#EXTM3U\n")
        f.write(f"#PLAYLIST:{result['title']}\n\n")
        for ep in result['episodes']:
            if ep['m3u8_url'] and ep['m3u8_url'].startswith('http'):
                f.write(f"#EXTINF:-1 tvg-logo=\"{result['cover']}\" group-title=\"{result['title']}\",{result['title']} {ep['title']}\n")
                f.write(f"{ep['m3u8_url']}\n\n")
    print(f"✅ 已生成 M3U 播放列表: {args.m3u} (支持 VLC / PotPlayer 一键秒播)")

if __name__ == "__main__":
    main()
