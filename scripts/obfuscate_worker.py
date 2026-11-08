import re
import random
import base64
import json

def obfuscate_worker(src_path, dest_path):
    with open(src_path, 'r', encoding='utf-8') as f:
        src = f.read()

    def rand_hex(prefix="_0x", length=4):
        return prefix + ''.join(random.choices("abcdef0123456789", k=length))

    table_name = rand_hex("_0xt")
    key_name = rand_hex("_0xk")
    dec_fn = rand_hex("_0xd")

    xor_key = random.randint(40, 220)
    strings = []
    
    # 敏感目标列表
    sensitive_targets = [
        "https://api.pandalive.co.kr/v1/member/bj",
        "https://api.pandalive.co.kr/v1/live/play",
        "https://www.pandalive.co.kr/",
        "https://www.pandalive.co.kr",
        "https://www.flextv.co.kr/",
        "https://www.flextv.co.kr",
        "https://5721004.xyz/player/list.m3u",
        "https://5721004.xyz/player/list.json",
        "https://5721004.xyz/player/flex.json",
        "https://5721004.xyz/player/pandatv.html",
        "https://5721004.xyz/player/flextv.html",
        "https://5721004.xyz",
        "live-video.net",
        "pandalive",
        "naverncp.com",
        "flextv",
        "/resolve",
        "/api/live/resolve",
        "/pandatv",
        "/list.json",
        "/flextv",
        "/flex.json",
        "/hls",
        "/proxy/",
        "/speedtest",
        "/ping",
        "/health",
        "action=watch&userId=",
        "action=watch",
        "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/128.0.0.0 Safari/537.36",
        "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36",
        "Cloudflare Dedicated Stream Engine v3.0 (自主官方解析+全链路TS重写版)",
        "application/vnd.apple.mpegurl; charset=utf-8",
        "video/MP2T",
        "application/octet-stream",
        "application/json; charset=utf-8",
        "no-cache, no-store, must-revalidate",
        "public, max-age=60",
        "public, max-age=15",
        "cf-stream-engine-v3",
        "official_direct",
        "needAdult",
        "Unable to resolve live stream: "
    ]

    sensitive_targets.sort(key=len, reverse=True)

    code = src
    for target in sensitive_targets:
        idx = len(strings)
        # UTF-8 字节编码后再进行异或
        target_bytes = target.encode('utf-8')
        enc_bytes = bytes([b ^ xor_key for b in target_bytes])
        b64 = base64.b64encode(enc_bytes).decode('ascii')
        strings.append(b64)
        
        pattern = re.compile(re.escape(f'"{target}"') + r'|' + re.escape(f"'{target}'"))
        code = pattern.sub(f"{dec_fn}({idx})", code)

    strings_json = json.dumps(strings)
    header = f"""/**
 * 🔒 Cloudflare Protected Bytecode Stream Engine (Encrypted Distribution)
 * Security Build: {random.randint(100000, 999999)}
 */
const {table_name} = {strings_json};
const {key_name} = {xor_key};
function {dec_fn}(idx) {{
  const raw = atob({table_name}[idx]);
  const bytes = new Uint8Array(raw.length);
  for (let i = 0; i < raw.length; i++) {{
    bytes[i] = raw.charCodeAt(i) ^ {key_name};
  }}
  return new TextDecoder().decode(bytes);
}}
"""

    var_map = {
        'CACHE_STORE': rand_hex('_0x_cs'),
        'resolveOfficialStream': rand_hex('_0x_res'),
        'handleRequest': rand_hex('_0x_req'),
        'corsHeaders': rand_hex('_0x_ch'),
    }
    for old_v, new_v in var_map.items():
        code = re.sub(r'\b' + old_v + r'\b', new_v, code)

    final_output = header + "\n" + code

    with open(dest_path, 'w', encoding='utf-8') as f:
        f.write(final_output)

    print(f"✅ 加密成功！加密核心敏感特征数: {len(strings)}")
    print(f"输出文件: {dest_path}, 文件大小: {len(final_output)} 字节")

if __name__ == '__main__':
    obfuscate_worker(
        '/vol1/@apphome/GoogleAntigravityCLI/home/.gemini/antigravity-cli/scratch/cf_worker_v3.js',
        '/vol1/@apphome/GoogleAntigravityCLI/home/.gemini/antigravity-cli/scratch/cf_worker_v3_encrypted.js'
    )
