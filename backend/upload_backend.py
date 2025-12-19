"""
Upload backend të përditësuar në VPS
"""
import requests

API_URL = "http://194.163.165.198:8000"
BACKEND_FILE = r"C:\Users\DELL\Desktop\signals_app\backend\main_full.py"

print("📤 Duke upload-uar main_full.py të përditësuar...")

try:
    with open(BACKEND_FILE, 'rb') as f:
        # Upload si bot file (do shkojë në /bots/ por pastaj do e lëvizim)
        files = {'file': ('main_full_new.py', f, 'text/x-python')}
        response = requests.post(f"{API_URL}/upload_bot", files=files, timeout=30)
    
    if response.status_code == 200:
        print("✅ File u upload-ua!")
        print("\n📋 Tani bëj këto në Contabo Web Console:")
        print("1. Lidhu me VPS")
        print("2. mv /var/www/signals_backend/bots/main_full_new.py /var/www/signals_backend/main_full.py")
        print("3. systemctl restart signals-api")
    else:
        print(f"❌ Error: {response.text}")

except Exception as e:
    print(f"❌ Exception: {e}")
