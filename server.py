import os
import re
import glob
import tempfile
from flask import Flask, request, jsonify, send_file, render_template_string
import yt_dlp

app = Flask(__name__)

TEMP_DIR = os.path.join(tempfile.gettempdir(), "video_downloader_cache")
os.makedirs(TEMP_DIR, exist_ok=True)

def extract_url_from_text(text: str) -> str:
    """Bóc tách URL nếu người dùng chia sẻ cả đoạn text kèm link"""
    if not text:
        return ""
    urls = re.findall(r'https?://[^\s<>"]+|www\.[^\s<>"]+', text)
    return urls[0] if urls else text.strip()

INDEX_HTML = """
<!DOCTYPE html>
<html lang="vi">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Trình Tải Video Riêng Cho iPhone & Android</title>
    <style>
        body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; background: #0f172a; color: #f8fafc; display: flex; justify-content: center; align-items: center; min-height: 100vh; margin: 0; padding: 20px; box-sizing: border-box; }
        .card { background: #1e293b; border-radius: 16px; padding: 32px; width: 100%; max-width: 500px; box-shadow: 0 10px 25px rgba(0,0,0,0.5); text-align: center; }
        h1 { font-size: 24px; margin-bottom: 8px; color: #38bdf8; }
        p { color: #94a3b8; font-size: 14px; margin-bottom: 24px; }
        input[type="text"] { width: 100%; padding: 14px; border-radius: 8px; border: 1px solid #334155; background: #0f172a; color: #fff; font-size: 15px; box-sizing: border-box; margin-bottom: 16px; }
        button { width: 100%; padding: 14px; border-radius: 8px; border: none; background: #0284c7; color: #fff; font-size: 16px; font-weight: 600; cursor: pointer; transition: 0.2s; }
        button:hover { background: #0369a1; }
        .badge { display: inline-block; background: #0369a1; color: #e0f2fe; padding: 4px 10px; border-radius: 20px; font-size: 12px; margin-bottom: 16px; }
        .note { margin-top: 24px; font-size: 13px; color: #64748b; line-height: 1.5; }
    </style>
</head>
<body>
    <div class="card">
        <span class="badge">100% Sạch & Không Quảng Cáo</span>
        <h1>Trình Tải Video Đa Năng</h1>
        <p>Hỗ trợ YouTube, TikTok, Facebook, Instagram, Twitter/X, Threads...</p>
        <form action="/download" method="get">
            <input type="text" name="url" placeholder="Dán link video vào đây..." required autocomplete="off">
            <button type="submit">Tải Video Về Máy</button>
        </form>
        <div class="note">
            💡 <b>Mẹo cho iPhone:</b> Bạn có thể dùng phím tắt trên iPhone để gọi thẳng vào API này và tự lưu vào Album Ảnh chỉ với 1 chạm!
        </div>
    </div>
</body>
</html>
"""

@app.route("/")
def home():
    return render_template_string(INDEX_HTML)

@app.route("/api/info")
def get_video_info():
    """Lấy thông tin video dạng JSON"""
    raw_url = request.args.get("url", "")
    clean_url = extract_url_from_text(raw_url)
    if not clean_url:
        return jsonify({"success": False, "error": "Thiếu tham số url"}), 400

    ydl_opts = {
        'quiet': True,
        'no_warnings': True,
        'format': 'best[ext=mp4]/best',
    }
    try:
        with yt_dlp.YoutubeDL(ydl_opts) as ydl:
            info = ydl.extract_info(clean_url, download=False)
            return jsonify({
                "success": True,
                "title": info.get('title', 'video'),
                "direct_url": info.get('url'),
                "thumbnail": info.get('thumbnail'),
                "duration": info.get('duration'),
                "platform": info.get('extractor_key', 'Unknown')
            })
    except Exception as e:
        return jsonify({"success": False, "error": str(e)}), 400

@app.route("/download")
def download_video():
    """
    Endpoint tải file trực tiếp về máy.
    Tự động ghép âm thanh + hình ảnh chuẩn MP4 cho iPhone/Android.
    """
    raw_url = request.args.get("url", "")
    clean_url = extract_url_from_text(raw_url)
    if not clean_url:
        return jsonify({"error": "Vui lòng cung cấp url"}), 400

    # Dọn dẹp cache cũ nếu đầy quá 100 files
    cached_files = glob.glob(os.path.join(TEMP_DIR, "*"))
    if len(cached_files) > 100:
        for f in cached_files[:50]:
            try:
                os.remove(f)
            except Exception:
                pass

    out_pattern = os.path.join(TEMP_DIR, "%(id)s.%(ext)s")
    
    ydl_opts = {
        'format': 'bestvideo[ext=mp4]+bestaudio[ext=m4a]/best[ext=mp4]/best',
        'outtmpl': out_pattern,
        'merge_output_format': 'mp4',
        'quiet': True,
        'no_warnings': True,
        'noplaylist': True,
    }

    try:
        with yt_dlp.YoutubeDL(ydl_opts) as ydl:
            info = ydl.extract_info(clean_url, download=True)
            video_id = info.get('id', 'video')
            raw_title = info.get('title', 'video')
            clean_title = re.sub(r'[^\w\s-]', '', raw_title).strip()[:50] or "video"

            # Tìm file vừa tải
            matched_files = glob.glob(os.path.join(TEMP_DIR, f"{video_id}.*"))
            if not matched_files:
                return jsonify({"error": "Không tìm thấy file video sau khi tải"}), 500
            
            target_file = matched_files[0]
            for mf in matched_files:
                if mf.endswith(".mp4"):
                    target_file = mf
                    break

            return send_file(
                target_file,
                mimetype="video/mp4",
                as_attachment=True,
                download_name=f"{clean_title}.mp4"
            )
    except Exception as e:
        return jsonify({"error": f"Lỗi tải video: {str(e)}"}), 400

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=8000, debug=True)
