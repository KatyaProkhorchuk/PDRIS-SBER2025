import os
import json
from flask import Flask, request, jsonify

app = Flask(__name__)

LOG_FILE = os.getenv('LOG_FILE', '/app/logs/app.log')
WELCOME_MESSAGE = os.getenv('WELCOME_MESSAGE', 'Welcome to the custom app')
LOG_LEVEL = os.getenv('LOG_LEVEL', 'INFO')

os.makedirs(os.path.dirname(LOG_FILE), exist_ok=True)

@app.route('/')
def home():
    return f"{WELCOME_MESSAGE}"

@app.route('/status')
def status():
    return jsonify({"status": "ok"})

@app.route('/log', methods=['POST'])
def log_message():
    data = request.get_json()
    if not data or 'message' not in data:
        return jsonify({"error": "Invalid data"}), 400
    
    with open(LOG_FILE, 'a') as f:
        f.write(json.dumps(data) + '\n')
    
    return jsonify({"status": "logged"})

@app.route('/logs')
def get_logs():
    try:
        with open(LOG_FILE, 'r') as f:
            logs = f.readlines()
        return jsonify({"logs": [json.loads(line) for line in logs]})
    except FileNotFoundError:
        return jsonify({"logs": []})

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000, debug=(LOG_LEVEL == 'DEBUG'))