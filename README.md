# ESP32 Cat Car

**Platform:** ESP32 · **Development Environment:** Arduino IDE · **Language:** Arduino/C++

ESP32 Cat Car, also called MewGlow, is an interactive robot that combines movement, expressive lighting, a digital cat face, motion sensing, and Wi-Fi control. An ILI9341 TFT display shows animated eyes and emoticons, while five colored LEDs reproduce app-selected colors and visual effects. A PIR sensor detects nearby movement, and a TB6612FNG motor driver controls the two motors so the robot can physically respond.

The project was designed to make an embedded system feel more expressive than a conventional remote-controlled vehicle. Instead of using movement alone, the cat communicates through eye shapes, blinking, color, brightness, and motion. Different emoticons are interpreted as moods such as happy, angry, sleepy, sad, and love. These moods can influence the robot's display and movement behavior.

The ESP32 runs a local HTTP server with two endpoints. `GET /status` reports the Wi-Fi connection, current mood, message, IP address, and PIR readiness. `POST /command` accepts JSON values for the displayed message, emoticon, RGB color, brightness, and lighting effect. Supported LED effects include steady light, breathing, blinking, and a heartbeat pattern.

The hardware uses an ESP32, an ILI9341 TFT display, a PIR motion sensor, a TB6612FNG dual-motor driver, two motors, and red, yellow, green, blue, and white LEDs. The firmware demonstrates Wi-Fi networking, HTTP request handling, JSON parsing, PWM output, RGB-to-five-channel color conversion, display graphics, non-blocking eye animation, sensor input, motor control, and automatic Wi-Fi reconnection.

The current firmware can connect to a local Wi-Fi network, receive app commands, update its face and lighting, and react to nearby activity. Repeated PIR triggers are interpreted as a wave, while ordinary motion starts a mood-based movement sequence. Multiple recent triggers activate a more curious response. The robot can also provide non-blocking visual feedback through a physical reply button on GPIO 39 and perform a small idle fidget after five minutes without activity.

AI tools were used to assist with parts of the coding process and documentation. The hardware integration, physical testing, troubleshooting, and final behavior were reviewed and refined as part of the project.

Before uploading the firmware, replace `YOUR_WIFI_NAME` and `YOUR_WIFI_PASSWORD` in `MewGlow_firmware.ino` with credentials for the local network. The public repository intentionally contains no real Wi-Fi credentials.

Required Arduino libraries:

- ESP32 board support package
- ArduinoJson
- Adafruit GFX Library
- Adafruit ILI9341

Main wiring:

| Component | ESP32 pins |
| --- | --- |
| Red, yellow, green, blue, white LEDs | 13, 32, 14, 27, 26 |
| TB6612FNG motor A | AIN1 16, AIN2 17, PWMA 4 |
| TB6612FNG motor B | BIN1 22, BIN2 23, PWMB 19 |
| PIR sensor | 34 |
| Physical reply button | 39 |
| ILI9341 display | CS 21, DC 25, MOSI 5, SCLK 18, RST 33 |
