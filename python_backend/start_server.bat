@echo off
echo Installing Python dependencies...
pip install -r requirements.txt
echo.
echo Starting CryptWhisper backend server...
echo For Android emulator: use http://10.0.2.2:8765
echo For physical device:  run 'adb reverse tcp:8765 tcp:8765' then use http://localhost:8765
echo.
python server.py
pause
