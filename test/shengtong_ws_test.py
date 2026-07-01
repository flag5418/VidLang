import websocket
import json
import hashlib
import time

APP_KEY = '17618890190005e3'
SECRET_KEY = '5d0b32c950794688f6caf0c797980cde'

def sha1_hex(text):
    return hashlib.sha1(text.encode('utf-8')).hexdigest()

def test_shengtong():
    url = 'ws://api.stkouyu.com:8080/sent.eval'
    print(f'连接: {url}')
    
    ws = websocket.create_connection(url, timeout=10)
    print('✅ 连接成功')
    
    # 1. 发送 connect
    timestamp = str(int(time.time() * 1000))
    connect_sig = sha1_hex(APP_KEY + timestamp + SECRET_KEY)
    connect_params = {
        "cmd": "connect",
        "param": {
            "sdk": {
                "version": 16777472,
                "source": 4,
                "protocol": 1
            },
            "app": {
                "applicationId": APP_KEY,
                "sig": connect_sig,
                "timestamp": timestamp
            }
        }
    }
    
    print(f'\n📤 发送 connect:')
    print(json.dumps(connect_params, indent=2))
    ws.send(json.dumps(connect_params))
    
    # 接收响应
    print('\n⏳ 等待 connect 响应...')
    try:
        response = ws.recv()
        print(f'📥 收到: {response}')
    except Exception as e:
        print(f'❌ 接收失败: {e}')
    
    # 2. 发送 start
    start_timestamp = str(int(time.time() * 1000))
    user_id = 'test_user_' + start_timestamp
    start_sig = sha1_hex(APP_KEY + start_timestamp + user_id + SECRET_KEY)
    start_params = {
        "cmd": "start",
        "param": {
            "app": {
                "applicationId": APP_KEY,
                "sig": start_sig,
                "userId": user_id,
                "timestamp": start_timestamp
            },
            "audio": {
                "audioType": "wav",
                "sampleRate": 16000,
                "channel": 1,
                "sampleBytes": 2
            },
            "request": {
                "coreType": "sent.eval",
                "refText": "Hello world",
                "tokenId": "TEST_TOKEN_123"
            }
        }
    }
    
    print(f'\n📤 发送 start:')
    print(json.dumps(start_params, indent=2))
    ws.send(json.dumps(start_params))
    
    # 接收响应
    print('\n⏳ 等待 start 响应...')
    try:
        response = ws.recv()
        print(f'📥 收到: {response}')
    except Exception as e:
        print(f'❌ 接收失败: {e}')
    
    # 3. 发送 stop
    print(f'\n📤 发送 stop')
    ws.send('{"cmd":"stop"}')
    
    print('\n⏳ 等待最终响应...')
    try:
        while True:
            response = ws.recv()
            print(f'📥 收到: {response}')
    except:
        pass
    
    ws.close()
    print('\n🔌 连接已关闭')

if __name__ == '__main__':
    test_shengtong()
