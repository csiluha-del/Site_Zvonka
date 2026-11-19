# ВАЖНО: Эти две строки должны быть самыми первыми в файле!
import eventlet
eventlet.monkey_patch()

from flask import Flask, render_template, request
from flask_socketio import SocketIO, join_room, leave_room, emit
import re

app = Flask(__name__)
app.config["SECRET_KEY"] = "voice-room-local-key"
# Используем eventlet для асинхронной работы
socketio = SocketIO(app, cors_allowed_origins="*", async_mode="eventlet")

# Словарь для хранения комнат: { "1234": ["sid1", "sid2"] }
rooms = {}

@app.route("/")
def index():
    return render_template("index.html")

def clean_room(value):
    value = re.sub(r"[^a-zA-Z0-9_-]", "", str(value or ""))[:32]
    return value or "main"

# Проверка статуса комнаты
@socketio.on("check_room")
def on_check_room(data):
    room = clean_room((data or {}).get("room"))
    is_occupied = room in rooms and len(rooms[room]) > 0
    emit("room_status", {"room": room, "occupied": is_occupied})

@socketio.on("join")
def on_join(data):
    room = clean_room((data or {}).get("room"))
    name = str((data or {}).get("name") or "Гость")[:24]
    
    members = rooms.setdefault(room, [])
    
    # Если в комнате уже 2 человека, не пускаем
    if len(members) >= 2:
        emit("room_full")
        return
        
    if request.sid in members:
        return
        
    was_occupied = len(members) > 0
    members.append(request.sid)
    join_room(room)
    
    # Отправляем подтверждение входа
    emit("joined", {"room": room, "peer_present": was_occupied})
    
    # Если кто-то уже был, сообщаем ему, что мы зашли
    if was_occupied:
        emit("peer_joined", {"name": name}, room=room, include_self=False)

@socketio.on("signal")
def on_signal(data):
    room = clean_room((data or {}).get("room"))
    payload = (data or {}).get("payload")
    emit("signal", payload, room=room, include_self=False)

@socketio.on("leave")
def on_leave(data=None):
    remove_client(request.sid)

@socketio.on("disconnect")
def on_disconnect():
    remove_client(request.sid)

def remove_client(sid):
    for room, members in list(rooms.items()):
        if sid in members:
            members.remove(sid)
            leave_room(room, sid=sid)
            emit("peer_left", room=room, include_self=False)
            # Если комната опустела, удаляем её из памяти
            if not members:
                rooms.pop(room, None)
            break

if __name__ == "__main__":
    print("\nVoice Room запущен. Для микрофона используйте HTTPS-ссылку.\n")
    socketio.run(app, host="0.0.0.0", port=5000)