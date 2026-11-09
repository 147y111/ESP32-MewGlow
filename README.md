# ESP32 MewGlow

**Platform:** ESP32 · **Development Environment:** Arduino IDE · **Language:** Arduino/C++

MewGlow is an interactive companion robot that combines movement, expressive lighting, a digital cat face, motion sensing, and Wi-Fi control. An ILI9341 TFT display shows animated eyes and emoticons, while five colored LEDs reproduce app-selected colors and visual effects. A PIR sensor detects nearby movement, and a TB6612FNG motor driver controls the two motors so the robot can physically respond.

The project was designed to make an embedded system feel more expressive than a conventional remote-controlled vehicle. Instead of using movement alone, the cat communicates through eye shapes, blinking, color, brightness, and motion. Different emoticons are interpreted as moods such as happy, angry, sleepy, sad, and love. These moods can influence the robot's display and movement behavior.

The companion iOS app was built with SwiftUI in Xcode. It provides separate Device, Control, and Profile screens so the user can connect to MewGlow, write a short message, choose an emoticon and color, adjust brightness, select a lighting effect, and manage basic preferences. The full Xcode project is included in [`app/MewGlow`](app/MewGlow).

The ESP32 runs a local HTTP server with three endpoints. `GET /ping` verifies the connection from the app, `GET /status` reports the Wi-Fi connection, current mood, message, IP address, PIR readiness, and reply state, and `POST /command` accepts JSON values for the displayed message, emoticon, RGB color, brightness, and lighting effect. Supported LED effects include steady light, breathing, blinking, and a heartbeat pattern.

The hardware uses an ESP32, an ILI9341 TFT display, a PIR motion sensor, a TB6612FNG dual-motor driver, two motors, and red, yellow, green, blue, and white LEDs. The firmware demonstrates Wi-Fi networking, HTTP request handling, JSON parsing, PWM output, RGB-to-five-channel color conversion, display graphics, non-blocking eye animation, sensor input, motor control, and automatic Wi-Fi reconnection.

The current firmware can connect to a local Wi-Fi network, receive app commands, update its face and lighting, and react to nearby activity. Repeated PIR triggers are interpreted as a wave, while ordinary motion starts a mood-based movement sequence. Multiple recent triggers activate a more curious response. The robot can also provide non-blocking visual feedback through a physical reply button on GPIO 39 and perform a small idle fidget after five minutes without activity.

The repository also preserves an earlier [Wi-Fi RGB control prototype](versions/wifi_rgb_control_prototype.ino). This smaller program demonstrates the original app-to-ESP32 communication flow, RGB PWM control, lighting effects, mood-command parsing, and compatibility with both ESP32 Arduino Core 2.x and 3.x. It is kept separate from the main firmware because both sketches define their own `setup()` and `loop()` functions.

AI tools were used to assist with parts of the coding process and documentation. The hardware integration, physical testing, troubleshooting, and final behavior were reviewed and refined as part of the project.

Before uploading the firmware, replace `YOUR_WIFI_NAME` and `YOUR_WIFI_PASSWORD` in `MewGlow_firmware.ino` with credentials for the local network. Update `LampService.host` in the iOS project to the IP address printed by the ESP32 Serial Monitor. The iPhone and ESP32 must be connected to the same local network. The public repository intentionally contains no real Wi-Fi credentials.

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

## Operating Flow

```mermaid
flowchart TD
    A[Power on ESP32] --> B[Connect to the local Wi-Fi network]
    B --> C[Start the HTTP server and initialize the display, LEDs, PIR sensor, and motors]
    D[iOS app sends text, emoticon, RGB, brightness, and effect values] --> E[POST /command]
    E --> F[ESP32 parses the JSON command]
    F --> G[Update the cat face and message on the TFT display]
    F --> H[Convert the selected color into five LED channels]
    H --> I[Run steady, breathing, blink, or heartbeat lighting]
    F --> J[Select mood-based movement behavior]
    K[PIR sensor detects nearby motion] --> L{Repeated triggers?}
    L -->|Ordinary motion| J
    L -->|Wave or multiple recent triggers| M[Run a more curious response]
    J --> N[TB6612FNG driver controls both motors]
    M --> N
    O[Physical reply button pressed] --> P[Show non-blocking visual feedback]
```

## Project Media

The app-interface images, physical prototype, and subsystem demonstrations are collected here so the technical description above remains continuous. The surrounding background of the prototype photograph has been blurred to protect the privacy of people in the original image.

### iOS Companion App

<table>
  <tr><th>Device Connection</th><th>Control</th><th>Profile and Settings</th></tr>
  <tr>
    <td align="center"><img src="images/mewglow-device.png" alt="MewGlow device connection screen" height="320"></td>
    <td align="center"><img src="images/mewglow-control.png" alt="MewGlow control screen" height="320"></td>
    <td align="center"><img src="images/mewglow-profile.png" alt="MewGlow profile and settings screen" height="320"></td>
  </tr>
</table>

### Completed Hardware Prototype

<img src="media/mewglow-hardware-prototype-anonymized.png" alt="Completed MewGlow hardware prototype" width="520">

### Subsystem Demonstrations

#### LED Breathing-Effect Test

<video src="https://github.com/user-attachments/assets/24e2c1ae-0854-4cec-bbbc-85fb8c29c850" controls width="620"></video>

#### Wheel-Motion Test

<video src="https://github.com/user-attachments/assets/a0053f77-e8b9-424d-b193-d262d148ab85" controls width="620"></video>

These clips document the lighting and motor subsystems separately; a full video of the assembled robot operating was not recorded.
