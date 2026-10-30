#!/usr/bin/env python3
import os
import json
import time
import urllib.request
import urllib.parse
import subprocess
from http.server import HTTPServer, BaseHTTPRequestHandler

PORT = 18188
NOTIF_ID = 48188  # Fixed notification ID for progress updates

def format_size(num_bytes):
    """Human-readable file size."""
    for unit in ['B', 'KB', 'MB', 'GB']:
        if abs(num_bytes) < 1024.0:
            return f"{num_bytes:.1f} {unit}"
        num_bytes /= 1024.0
    return f"{num_bytes:.1f} TB"

def send_notification(title, message, replace=False, progress=-1):
    """Send a system notification.
    
    Args:
        title: Notification title
        message: Notification body
        replace: If True, replace the existing GravityDrop notification
        progress: 0-100 for progress bar hint, -1 to disable
    """
    try:
        cmd = ["notify-send", "-a", "GravityDrop"]
        if replace:
            cmd += ["-r", str(NOTIF_ID)]
        if 0 <= progress <= 100:
            cmd += ["-h", f"int:value:{progress}"]
        cmd += [title, message]
        subprocess.run(cmd, check=True)
    except Exception as e:
        print(f"[!] Failed to send notification: {e}")

# Mapped folders - customizable local targets
FOLDERS = {
    "tooown": "/mnt/storage/usr/mooon/vault/REPOSITORY/audio/Collections/TOoOwn: The First/Vocals/Storys",
    "rvc": "/mnt/storage/usr/mooon/vault/REPOSITORY/audio/Collections/TOoOwn: The First/Vocals/Storys",
    "voices": "/mnt/storage/usr/mooon/vault/REPOSITORY/audio/Collections/TOoOwn: The First/Vocals/Storys",
    "downloads": "/home/caesar/Downloads",
    "music": "/home/caesar/Music",
    "videos": "/home/caesar/Videos",
    "documents": "/home/caesar/Documents"
}

CATEGORY_LABELS = {
    "tooown": "🗣️ TOoOwn Vocals",
    "rvc": "🎭 RVC Models",
    "voices": "🎙️ ComfyUI Voices",
    "downloads": "📥 Downloads",
    "music": "🎵 Music",
    "videos": "🎬 Videos",
    "documents": "📄 Documents"
}

class GravityDropHandler(BaseHTTPRequestHandler):
    def do_OPTIONS(self):
        self.send_response(200)
        self.send_header('Access-Control-Allow-Origin', '*')
        self.send_header('Access-Control-Allow-Methods', 'POST, OPTIONS')
        self.send_header('Access-Control-Allow-Headers', 'Content-Type')
        self.end_headers()

    def do_POST(self):
        if self.path != '/download':
            self.send_error(404, "Not Found")
            return

        content_length = int(self.headers.get('Content-Length', 0))
        post_data = self.rfile.read(content_length)
        
        try:
            data = json.loads(post_data.decode('utf-8'))
            url = data.get('url')
            filename = data.get('filename')
            category = data.get('category', 'downloads')
            custom_path = data.get('custom_path')

            if not url:
                self.send_json_response(400, {"error": "Missing url"})
                return

            # Resolve target directory
            if custom_path:
                target_dir = custom_path
            else:
                target_dir = FOLDERS.get(category, FOLDERS["downloads"])

            # Clean and parse URL to get a default filename if none is provided
            parsed_url = urllib.parse.urlparse(url)
            url_filename = os.path.basename(parsed_url.path)
            
            if not filename:
                filename = url_filename if url_filename else "downloaded_file"
            
            # Clean filename to prevent path traversal
            filename = os.path.basename(filename)

            os.makedirs(target_dir, exist_ok=True)
            target_path = os.path.join(target_dir, filename)

            print(f"\n[+] Starting download: {url}")
            print(f"[+] Saving to: {target_path}")
            send_notification("☄️ Download Starting", f"{filename}\n{CATEGORY_LABELS.get(category, category)}")

            # Custom User-Agent to prevent some websites from blocking Python's urllib
            req = urllib.request.Request(
                url, 
                headers={'User-Agent': 'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36'}
            )

            # Open connection and save
            with urllib.request.urlopen(req) as response, open(target_path, 'wb') as out_file:
                total_size = int(response.info().get('Content-Length', -1))
                block_size = 1024 * 8
                downloaded = 0

                while True:
                    block = response.read(block_size)
                    if not block:
                        break
                    out_file.write(block)
                    downloaded += len(block)

                    # Terminal-only progress
                    if total_size > 0:
                        percent = min(100, int(downloaded * 100 / total_size))
                        filled = int(percent / 5)
                        bar = "█" * filled + "░" * (20 - filled)
                        print(f"\r[~] {bar} {percent}% ({format_size(downloaded)}/{format_size(total_size)})", end="")
                    else:
                        print(f"\r[~] Downloaded: {format_size(downloaded)}", end="")

            print(f"\n[+] Successfully saved {filename}!")
            size_str = format_size(os.path.getsize(target_path))
            send_notification("✅ Download Complete", f"{filename} ({size_str})\n📂 {target_dir}")
            self.send_json_response(200, {"status": "success", "path": target_path})

        except Exception as e:
            print(f"\n[!] Error: {str(e)}")
            send_notification("❌ Download Failed", f"{filename}\n{str(e)}")
            self.send_json_response(500, {"error": str(e)})

    def send_json_response(self, status, data):
        self.send_response(status)
        self.send_header('Access-Control-Allow-Origin', '*')
        self.send_header('Content-Type', 'application/json')
        self.end_headers()
        self.wfile.write(json.dumps(data).encode('utf-8'))

def run():
    server = HTTPServer(('127.0.0.1', PORT), GravityDropHandler)
    print(f"====================================================")
    print(f"   GRAVITYDROP Server is running on port {PORT}")
    print(f"====================================================")
    print(f" Mapped Categories:")
    for cat, path in FOLDERS.items():
        print(f"   • {cat:<10} -> {path}")
    print(f"====================================================")
    print(f" Press Ctrl+C to stop the helper server")
    print(f"====================================================")
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        print("\n[+] Stopping server...")

if __name__ == '__main__':
    run()
