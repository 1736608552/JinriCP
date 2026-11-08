#!/usr/bin/env python3
import json
import urllib.request
import urllib.error
import os

HEADERS = {
    'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36',
    'Accept': 'application/json, text/plain, */*',
}

DATA_DIR = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), 'data')
os.makedirs(DATA_DIR, exist_ok=True)

def fetch_json(url, headers=None):
    req_headers = HEADERS.copy()
    if headers:
        req_headers.update(headers)
    req = urllib.request.Request(url, headers=req_headers)
    try:
        with urllib.request.urlopen(req, timeout=15) as res:
            return json.loads(res.read().decode('utf-8'))
    except Exception as e:
        print(f"Error fetching {url}: {e}")
        return None

def fetch_text(url, headers=None):
    req_headers = HEADERS.copy()
    if headers:
        req_headers.update(headers)
    req = urllib.request.Request(url, headers=req_headers)
    try:
        with urllib.request.urlopen(req, timeout=15) as res:
            return res.read().decode('utf-8')
    except Exception as e:
        print(f"Error fetching text {url}: {e}")
        return None

def sync_pandatv():
    print("Syncing PandaTV streams...")
    # 抓取当前公有推流映射
    m3u_map = {}
    m3u_text = fetch_text('https://5721004.xyz/player/list.m3u') or fetch_text('https://jinricp.azurewebsites.net/player/list.m3u')
    if m3u_text:
        lines = m3u_text.split('\n')
        curr_id = None
        for line in lines:
            trimmed = line.strip()
            if trimmed.startsWith if hasattr(trimmed, 'startsWith') else trimmed.startswith('#EXTINF:'):
                parts = trimmed.split(',')
                if len(parts) >= 2:
                    curr_id = parts[1].strip()
            elif trimmed.startswith('http') and curr_id:
                m3u_map[curr_id] = trimmed
                curr_id = None

    json_data = fetch_json('https://5721004.xyz/player/list.json') or fetch_json('https://jinricp.azurewebsites.net/player/list.json')
    streams = []
    if json_data and 'list' in json_data:
        for item in json_data['list']:
            user_id = str(item.get('userId', ''))
            direct_url = m3u_map.get(user_id, '')
            item['streamUrl'] = direct_url
            streams.append(item)

    output_path = os.path.join(DATA_DIR, 'pandatv_live.json')
    with open(output_path, 'w', encoding='utf-8') as f:
        json.dump({'updated_at': json_data.get('time', '') if json_data else '', 'count': len(streams), 'list': streams}, f, ensure_ascii=False, indent=2)
    print(f"PandaTV synced {len(streams)} streams to {output_path}")

def sync_flextv():
    print("Syncing FlexTV streams...")
    json_data = fetch_json('https://5721004.xyz/player/flex.json') or fetch_json('https://jinricp.azurewebsites.net/player/flex.json')
    streams = []
    if json_data and 'data' in json_data:
        streams = json_data['data']

    output_path = os.path.join(DATA_DIR, 'flextv_live.json')
    with open(output_path, 'w', encoding='utf-8') as f:
        json.dump({'count': len(streams), 'data': streams}, f, ensure_ascii=False, indent=2)
    print(f"FlexTV synced {len(streams)} streams to {output_path}")

if __name__ == '__main__':
    sync_pandatv()
    sync_flextv()
