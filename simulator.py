import asyncio
import websockets
import json
import time
import random

DEVICE_STATE = {
    "connected": False,
    "last_command": None,
    "is_running": False,
    "remaining_time": 60,
    "pause_event": asyncio.Event()
}

DEVICE_STATE["pause_event"].set()  # Not paused initially

async def handle_client(websocket):
    global DEVICE_STATE

    async def send_stop_later():
        start_time = time.time()
        while DEVICE_STATE["remaining_time"] > 0:
            await DEVICE_STATE["pause_event"].wait()
            await asyncio.sleep(1)
            DEVICE_STATE["remaining_time"] -= 1

        if DEVICE_STATE["is_running"]:
            await websocket.send(json.dumps({"status": "stop"}))
            DEVICE_STATE["is_running"] = False
            DEVICE_STATE["last_command"] = "stop"
            DEVICE_STATE["remaining_time"] = 60

    try:
        async for message in websocket:
            try:
                data = json.loads(message)
            except json.JSONDecodeError:
                await websocket.send(json.dumps({"error": "Invalid JSON"}))
                continue

            cmd = data.get("command")

            # Simulate 20% command loss
            if random.random() < 0.2:
                print(f"[DROP] Command '{cmd}' dropped (no response sent)")
                continue

            if cmd == "pair":
                DEVICE_STATE["connected"] = True
                await websocket.send(json.dumps({"status": "connected"}))

            elif not DEVICE_STATE["connected"]:
                await websocket.send(json.dumps({"status": "not_connected"}))
                continue

            elif cmd == "start":
                if not DEVICE_STATE["is_running"]:
                    DEVICE_STATE["is_running"] = True
                    DEVICE_STATE["remaining_time"] = 60
                    DEVICE_STATE["pause_event"].set()
                    asyncio.create_task(send_stop_later())

                DEVICE_STATE["last_command"] = "start"
                await websocket.send(json.dumps({"status": "start"}))

            elif cmd == "pause":
                if DEVICE_STATE["is_running"]:
                    DEVICE_STATE["pause_event"].clear()
                    DEVICE_STATE["last_command"] = "pause"
                    await websocket.send(json.dumps({"status": "pause"}))
                else:
                    await websocket.send(json.dumps({"status": "not_running"}))

            elif cmd == "continue":
                if DEVICE_STATE["is_running"] and not DEVICE_STATE["pause_event"].is_set():
                    DEVICE_STATE["pause_event"].set()
                    DEVICE_STATE["last_command"] = "continue"
                    await websocket.send(json.dumps({"status": "continue"}))
                else:
                    await websocket.send(json.dumps({"status": "not_paused"}))

            elif cmd == "stop":
                DEVICE_STATE["is_running"] = False
                DEVICE_STATE["pause_event"].set()
                DEVICE_STATE["remaining_time"] = 60
                DEVICE_STATE["last_command"] = "stop"
                await websocket.send(json.dumps({"status": "stop"}))

            else:
                await websocket.send(json.dumps({"error": "Unknown command"}))

    except websockets.exceptions.ConnectionClosed:
        print("Client disconnected.")

async def main():
    async with websockets.serve(handle_client, "localhost", 8000):
        print("Simulator running on ws://localhost:8000")
        await asyncio.Future()

if __name__ == "__main__":
    asyncio.run(main())
