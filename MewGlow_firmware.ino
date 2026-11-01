#include <WiFi.h>
#include <WebServer.h>
#include <ArduinoJson.h>
#include <Adafruit_GFX.h>
#include <Adafruit_ILI9341.h>

// ==================================================
// Wi-Fi credentials (replace these placeholders before uploading)
// ==================================================

const char* ssid = "YOUR_WIFI_NAME";
const char* password = "YOUR_WIFI_PASSWORD";

WebServer server(80);

// ==================================================
// Pin definitions
// ==================================================

// Five-color LEDs
const int PIN_RED    = 13;
const int PIN_YELLOW = 32;
const int PIN_GREEN  = 14;
const int PIN_BLUE   = 27;
const int PIN_WHITE  = 26;

// TB6612FNG motor driver
const int AIN1 = 16;
const int AIN2 = 17;
const int PWMA = 4;

const int BIN1 = 22;
const int BIN2 = 23;
const int PWMB = 19;

// PIR
const int PIR_PIN = 34;

// Physical reply button (GPIO 39 has no internal pull-up; use a 3-pin module or external pull-down)
const int BUTTON_PIN = 39;

// TFT ILI9341
#define TFT_CS   21
#define TFT_DC   25
#define TFT_MOSI 5
#define TFT_SCLK 18
#define TFT_RST  33
#define TFT_MISO -1

Adafruit_ILI9341 tft(
  TFT_CS,
  TFT_DC,
  TFT_MOSI,
  TFT_SCLK,
  TFT_RST,
  TFT_MISO
);

// PWM
const int PWM_FREQ = 5000;
const int PWM_RES  = 8;

// ==================================================
// Type definitions
// These types must be declared before the related functions
// ==================================================

enum MoodBucket {
  HAPPY,
  ANGRY,
  SLEEPY,
  SAD,
  LOVE,
  DEFAULT_MOOD
};

struct LedMix {
  int r;
  int y;
  int g;
  int b;
  int w;
};

struct MotionParams {
  int speed;
  int shakeCount;
  bool stepForward;
  int stepDuration;
};

// ==================================================
// Current app state
// ==================================================

int targetR = 255;
int targetG = 200;
int targetB = 100;
int brightnessPct = 70;

String currentEffect = "steady";
String currentEmoticon = "(^_^)";
String currentMessage = "waiting...";

// ==================================================
// Runtime state
// ==================================================

bool pirReady = false;
bool previousPirState = LOW;
bool isReacting = false;
bool blinkClosed = false;

unsigned long pirReadyAt = 0;
unsigned long reactionStartTime = 0;
unsigned long lastTriggerTime = 0;
unsigned long firstTriggerInWindow = 0;
unsigned long lastAnyMotion = 0;
unsigned long lastBlinkTime = 0;
unsigned long blinkClosedAt = 0;
unsigned long lastWiFiCheck = 0;

int recentTriggerCount = 0;

const unsigned long CURIOSITY_WINDOW = 8000;
const unsigned long MOTION_COOLDOWN = 3000;
const unsigned long PIR_WARMUP_TIME = 15000;

// ==================================================
// Wave detection, physical button, idle fidget, and response state
// ==================================================

unsigned long pirTriggerTimes[6] = {0, 0, 0, 0, 0, 0};
int pirTriggerIndex = 0;

const unsigned long WAVE_WINDOW = 3500;
const int WAVE_MIN_TRIGGERS = 3;

const unsigned long IDLE_FIDGET_TIMEOUT = 300000UL; // 5 minutes

bool respondedFlag = false;
unsigned long respondedAt = 0;

bool isRespondFeedback = false;
unsigned long respondFeedbackStart = 0;
int respondFeedbackStep = 0;

bool lastButtonState = LOW;
unsigned long lastButtonChangeTime = 0;
const unsigned long BUTTON_DEBOUNCE_MS = 50;

bool isFidgeting = false;
unsigned long fidgetStartTime = 0;

// ==================================================
// Mood detection
// ==================================================

MoodBucket getMoodBucket(const String& emoticon) {
  if (
    emoticon == "(^_^)" ||
    emoticon == "(^o^)"
  ) {
    return HAPPY;
  }

  if (emoticon == "(>_<)") {
    return ANGRY;
  }

  if (emoticon == "(-_-)") {
    return SLEEPY;
  }

  if (
    emoticon == "(T_T)" ||
    emoticon == ":'("
  ) {
    return SAD;
  }

  if (emoticon == "<3") {
    return LOVE;
  }

  return DEFAULT_MOOD;
}

// ==================================================
// Convert RGB values to a five-color LED mix
// ==================================================

LedMix rgbToLedMix(int R, int G, int B) {
  float r = R / 255.0;
  float g = G / 255.0;
  float b = B / 255.0;

  float maxC = max(r, max(g, b));
  float minC = min(r, min(g, b));
  float delta = maxC - minC;

  float hue = 0;

  if (delta > 0.0001) {
    if (maxC == r) {
      hue = fmod((g - b) / delta, 6.0);
    } else if (maxC == g) {
      hue = ((b - r) / delta) + 2.0;
    } else {
      hue = ((r - g) / delta) + 4.0;
    }

    hue *= 60.0;

    if (hue < 0) {
      hue += 360.0;
    }
  }

  float saturation;

  if (maxC <= 0.0001) {
    saturation = 0;
  } else {
    saturation = delta / maxC;
  }

  LedMix mix = {0, 0, 0, 0, 0};
  int value255 = (int)(maxC * 255);

  if (hue < 25 || hue >= 335) {
    mix.r = value255;
  } else if (hue < 85) {
    float t = (hue - 25) / 60.0;

    mix.r = (int)(value255 * (1.0 - t));
    mix.y = (int)(value255 * t);
  } else if (hue < 170) {
    float t = (hue - 85) / 85.0;

    mix.y = (int)(value255 * (1.0 - t));
    mix.g = (int)(value255 * t);
  } else if (hue < 260) {
    float t = (hue - 170) / 90.0;

    mix.g = (int)(value255 * (1.0 - t));
    mix.b = (int)(value255 * t);
  } else {
    float t = (hue - 260) / 75.0;

    mix.b = value255;
    mix.r = (int)(value255 * t);
  }

  // Add white light when saturation is low
  mix.w = (int)((1.0 - saturation) * value255);

  return mix;
}

// ==================================================
// LED control
// ==================================================

void turnOffLEDs() {
  ledcWrite(PIN_RED, 0);
  ledcWrite(PIN_YELLOW, 0);
  ledcWrite(PIN_GREEN, 0);

  // Blue output is inverted: 255 means off
  ledcWrite(PIN_BLUE, 255);

  ledcWrite(PIN_WHITE, 0);
}

void applyLEDs() {
  // Let updateRespondFeedback() control the LEDs during response flashes
  if (isRespondFeedback) {
    return;
  }

  LedMix mix = rgbToLedMix(
    targetR,
    targetG,
    targetB
  );

  unsigned long now = millis();

  float brightnessScale =
    brightnessPct / 100.0;

  float intensity = 1.0;

  if (currentEffect == "breathing") {
    float phase =
      (now % 3000) /
      3000.0 *
      2.0 *
      PI;

    intensity =
      (sin(phase) + 1.0) /
      2.0;

    intensity =
      0.15 +
      intensity * 0.85;
  } else if (currentEffect == "blink") {
    intensity =
      ((now % 1000) < 500)
      ? 1.0
      : 0.0;
  } else if (currentEffect == "heartbeat") {
    unsigned long t = now % 1200;

    if (t < 120) {
      intensity = t / 120.0;
    } else if (t < 240) {
      intensity =
        1.0 -
        (t - 120) / 120.0;
    } else if (t < 320) {
      intensity = 0;
    } else if (t < 440) {
      intensity =
        (t - 320) / 120.0;
    } else if (t < 560) {
      intensity =
        1.0 -
        (t - 440) / 120.0;
    } else {
      intensity = 0;
    }
  }

  float scale =
    brightnessScale *
    intensity;

  int redValue = constrain(
    (int)(mix.r * scale),
    0,
    255
  );

  int yellowValue = constrain(
    (int)(mix.y * scale),
    0,
    255
  );

  int greenValue = constrain(
    (int)(mix.g * scale),
    0,
    255
  );

  int blueValue = constrain(
    (int)(mix.b * scale),
    0,
    255
  );

  int whiteValue = constrain(
    (int)(mix.w * scale),
    0,
    255
  );

  ledcWrite(PIN_RED, redValue);
  ledcWrite(PIN_YELLOW, yellowValue);
  ledcWrite(PIN_GREEN, greenValue);

  // Apply inverted output to the blue channel
  ledcWrite(PIN_BLUE, 255 - blueValue);

  ledcWrite(PIN_WHITE, whiteValue);
}

// ==================================================
// Motor control
// ==================================================

void setLeftMotor(int motorSpeed) {
  if (motorSpeed >= 0) {
    digitalWrite(AIN1, HIGH);
    digitalWrite(AIN2, LOW);
  } else {
    digitalWrite(AIN1, LOW);
    digitalWrite(AIN2, HIGH);

    motorSpeed = -motorSpeed;
  }

  ledcWrite(
    PWMA,
    constrain(motorSpeed, 0, 255)
  );
}

void setRightMotor(int motorSpeed) {
  if (motorSpeed >= 0) {
    digitalWrite(BIN1, HIGH);
    digitalWrite(BIN2, LOW);
  } else {
    digitalWrite(BIN1, LOW);
    digitalWrite(BIN2, HIGH);

    motorSpeed = -motorSpeed;
  }

  ledcWrite(
    PWMB,
    constrain(motorSpeed, 0, 255)
  );
}

void stopMotors() {
  ledcWrite(PWMA, 0);
  ledcWrite(PWMB, 0);

  digitalWrite(AIN1, LOW);
  digitalWrite(AIN2, LOW);
  digitalWrite(BIN1, LOW);
  digitalWrite(BIN2, LOW);
}

// ==================================================
// Display
// ==================================================

void drawEyes(
  bool wide,
  bool closed
) {
  tft.fillRect(
    0,
    60,
    320,
    125,
    ILI9341_BLACK
  );

  int leftEyeX = 100;
  int rightEyeX = 220;
  int eyeY = 125;
  int radius = wide ? 30 : 22;

  MoodBucket mood =
    getMoodBucket(currentEmoticon);

  if (closed) {
    tft.drawFastHLine(
      leftEyeX - radius,
      eyeY,
      radius * 2,
      ILI9341_WHITE
    );

    tft.drawFastHLine(
      rightEyeX - radius,
      eyeY,
      radius * 2,
      ILI9341_WHITE
    );

    return;
  }

  switch (mood) {
    case HAPPY:
      tft.drawCircle(
        leftEyeX,
        eyeY,
        radius,
        ILI9341_WHITE
      );

      tft.drawCircle(
        rightEyeX,
        eyeY,
        radius,
        ILI9341_WHITE
      );
      break;

    case ANGRY:
      tft.drawLine(
        leftEyeX - radius,
        eyeY - 12,
        leftEyeX + radius,
        eyeY + 12,
        ILI9341_RED
      );

      tft.drawLine(
        rightEyeX - radius,
        eyeY + 12,
        rightEyeX + radius,
        eyeY - 12,
        ILI9341_RED
      );
      break;

    case SLEEPY:
      tft.drawFastHLine(
        leftEyeX - radius,
        eyeY,
        radius * 2,
        ILI9341_CYAN
      );

      tft.drawFastHLine(
        rightEyeX - radius,
        eyeY,
        radius * 2,
        ILI9341_CYAN
      );
      break;

    case SAD:
      tft.drawLine(
        leftEyeX - radius,
        eyeY,
        leftEyeX + radius,
        eyeY + 12,
        ILI9341_BLUE
      );

      tft.drawLine(
        rightEyeX - radius,
        eyeY + 12,
        rightEyeX + radius,
        eyeY,
        ILI9341_BLUE
      );
      break;

    case LOVE:
      tft.fillCircle(
        leftEyeX,
        eyeY,
        radius,
        ILI9341_MAGENTA
      );

      tft.fillCircle(
        rightEyeX,
        eyeY,
        radius,
        ILI9341_MAGENTA
      );
      break;

    default:
      tft.fillCircle(
        leftEyeX,
        eyeY,
        radius,
        ILI9341_WHITE
      );

      tft.fillCircle(
        rightEyeX,
        eyeY,
        radius,
        ILI9341_WHITE
      );
      break;
  }
}

void updateScreen() {
  tft.fillScreen(ILI9341_BLACK);
  tft.setTextWrap(true);

  // Display the emoticon at the top
  tft.setTextColor(ILI9341_YELLOW);
  tft.setTextSize(2);
  tft.setCursor(120, 20);
  tft.print(currentEmoticon);

  // Display the eyes in the center
  drawEyes(false, false);

  // Display the app message at the bottom
  tft.setTextColor(ILI9341_WHITE);
  tft.setTextSize(1);
  tft.setCursor(10, 205);
  tft.print(currentMessage);
}

// ==================================================
// Non-blocking blinking
// ==================================================

void updateBlink() {
  // Pause blinking during response feedback, PIR reactions, and idle fidgets
  if (isRespondFeedback || isReacting || isFidgeting) {
    return;
  }

  unsigned long now = millis();

  if (
    !blinkClosed &&
    now - lastBlinkTime >= 4000
  ) {
    blinkClosed = true;
    blinkClosedAt = now;
    lastBlinkTime = now;

    drawEyes(false, true);
  }

  if (
    blinkClosed &&
    now - blinkClosedAt >= 150
  ) {
    blinkClosed = false;

    drawEyes(false, false);
  }
}

// ==================================================
// PIR sensing and motion
// ==================================================

MotionParams getMotionParams(
  MoodBucket mood,
  bool curious
) {
  switch (mood) {
    case HAPPY:
      return {
        170,
        curious ? 4 : 2,
        true,
        200
      };

    case ANGRY:
      return {
        200,
        2,
        false,
        0
      };

    case SLEEPY:
      return {
        90,
        1,
        false,
        0
      };

    case SAD:
      return {
        100,
        2,
        false,
        0
      };

    case LOVE:
      return {
        150,
        curious ? 4 : 2,
        true,
        180
      };

    default:
      return {
        130,
        2,
        true,
        250
      };
  }
}

// Record PIR triggers for wave detection and curiosity-mode counting
void recordPirTrigger(unsigned long now) {
  pirTriggerTimes[pirTriggerIndex] = now;
  pirTriggerIndex = (pirTriggerIndex + 1) % 6;
}

int countTriggersWithin(unsigned long windowMs, unsigned long now) {
  int count = 0;

  for (int i = 0; i < 6; i++) {
    if (
      pirTriggerTimes[i] != 0 &&
      (now - pirTriggerTimes[i]) <= windowMs
    ) {
      count++;
    }
  }

  return count;
}

void startRespondFeedback() {
  isRespondFeedback = true;
  respondFeedbackStart = millis();
  respondFeedbackStep = 0;

  respondedFlag = true;
  respondedAt = millis();

  drawEyes(true, false);
}

// Advance non-blocking double-flash response feedback from the main loop
void updateRespondFeedback() {
  if (!isRespondFeedback) {
    return;
  }

  unsigned long elapsed = millis() - respondFeedbackStart;
  const unsigned long slot = 150;
  int step = elapsed / slot;

  if (step >= 4) {
    isRespondFeedback = false;
    drawEyes(false, false);
    return;
  }

  if (step != respondFeedbackStep) {
    respondFeedbackStep = step;
  }

  bool ledOn = (step % 2 == 0);

  if (ledOn) {
    ledcWrite(PIN_RED, 0);
    ledcWrite(PIN_YELLOW, 0);
    ledcWrite(PIN_GREEN, 0);
    ledcWrite(PIN_BLUE, 0);   // Inverted blue output: 0 means on
    ledcWrite(PIN_WHITE, 0);
  } else {
    ledcWrite(PIN_RED, 0);
    ledcWrite(PIN_YELLOW, 0);
    ledcWrite(PIN_GREEN, 0);
    ledcWrite(PIN_BLUE, 255); // off
    ledcWrite(PIN_WHITE, 0);
  }
}

void readPIR() {
  if (!pirReady) {
    return;
  }

  bool pirState = digitalRead(PIR_PIN) == HIGH;

  if (pirState && !previousPirState) {
    unsigned long now = millis();

    recordPirTrigger(now);
    lastAnyMotion = now;

    // Ignore new triggers while another reaction, response, or idle fidget is active
    if (isReacting || isRespondFeedback || isFidgeting) {
      previousPirState = pirState;
      return;
    }

    // Three triggers within the wave window are treated as an intentional greeting
    int wavesInWindow = countTriggersWithin(WAVE_WINDOW, now);

    if (wavesInWindow >= WAVE_MIN_TRIGGERS) {
      Serial.println("PIR: wave detected, responding");
      startRespondFeedback();
      previousPirState = pirState;
      return;
    }

    // Otherwise start the normal mood-based reaction sequence
    recentTriggerCount = countTriggersWithin(CURIOSITY_WINDOW, now);

    Serial.println("PIR: motion detected, starting mood reaction");

    isReacting = true;
    reactionStartTime = now;
  }

  previousPirState = pirState;
}

void updateMotion() {
  if (!isReacting) {
    return;
  }

  unsigned long now = millis();
  unsigned long elapsed =
    now - reactionStartTime;

  bool curious =
    recentTriggerCount >= 2;

  MotionParams params =
    getMotionParams(
      getMoodBucket(currentEmoticon),
      curious
    );

  int actionStart = 0;

  // Step 1: move forward
  if (params.stepForward) {
    if (
      elapsed <
      (unsigned long)params.stepDuration
    ) {
      setLeftMotor(params.speed);
      setRightMotor(params.speed);
      return;
    }

    actionStart = params.stepDuration;
  }

  // Step 2: shake from side to side
  const int shakeSlot = 200;

  int shakesEnd =
    actionStart +
    params.shakeCount *
    shakeSlot;

  if (
    elapsed <
    (unsigned long)shakesEnd
  ) {
    int phase =
      (elapsed - actionStart) /
      shakeSlot;

    if (phase % 2 == 0) {
      setLeftMotor(-params.speed);
      setRightMotor(params.speed);
    } else {
      setLeftMotor(params.speed);
      setRightMotor(-params.speed);
    }

    return;
  }

  // Step 3: return to the starting position
  if (
    params.stepForward &&
    elapsed <
    (unsigned long)(
      shakesEnd +
      params.stepDuration
    )
  ) {
    setLeftMotor(-params.speed);
    setRightMotor(-params.speed);
    return;
  }

  stopMotors();

  isReacting = false;
  lastTriggerTime = now;
  lastAnyMotion = now;

  drawEyes(false, false);
}

// ==================================================
// Idle fidget: make a small movement after five minutes without PIR activity
// ==================================================

void updateIdleFidget() {
  if (isReacting || isRespondFeedback) {
    return;
  }

  unsigned long now = millis();

  if (!isFidgeting) {
    if (now - lastAnyMotion >= IDLE_FIDGET_TIMEOUT) {
      isFidgeting = true;
      fidgetStartTime = now;
    }
    return;
  }

  unsigned long elapsed = now - fidgetStartTime;
  const int fidgetSpeed = 90;
  const int fidgetSlot = 150;
  const int fidgetShakes = 2;

  int fidgetEnd = fidgetShakes * fidgetSlot;

  if ((int)elapsed < fidgetEnd) {
    int phase = elapsed / fidgetSlot;

    if (phase % 2 == 0) {
      setLeftMotor(-fidgetSpeed);
      setRightMotor(fidgetSpeed);
    } else {
      setLeftMotor(fidgetSpeed);
      setRightMotor(-fidgetSpeed);
    }
    return;
  }

  stopMotors();
  isFidgeting = false;
  lastAnyMotion = now; // Reset the timer to prevent repeated triggering
}

// ==================================================
// Physical reply button (GPIO 39)
// ==================================================

void updateButton() {
  bool raw = digitalRead(BUTTON_PIN) == HIGH; // Reverse this level if required by the button module wiring
  unsigned long now = millis();

  if (
    raw != lastButtonState &&
    (now - lastButtonChangeTime) > BUTTON_DEBOUNCE_MS
  ) {
    lastButtonChangeTime = now;
    lastButtonState = raw;

    if (raw && !isReacting && !isRespondFeedback && !isFidgeting) {
      Serial.println("Button: reply pressed");
      startRespondFeedback();
    }
  }
}

// ==================================================
// HTTP API
// ==================================================

void handlePing() {
  server.send(
    200,
    "text/plain",
    "pong"
  );
}

void handleStatus() {
  StaticJsonDocument<256> doc;

  doc["connected"] =
    WiFi.status() == WL_CONNECTED;

  doc["mood"] =
    currentEmoticon;

  doc["message"] =
    currentMessage;

  doc["ip"] =
    WiFi.localIP().toString();

  doc["pirReady"] =
    pirReady;

  doc["responded"] =
    respondedFlag;

  doc["respondedAt"] =
    respondedAt;

  String output;
  serializeJson(doc, output);

  server.send(
    200,
    "application/json",
    output
  );

  // Clear the flag after one app poll to avoid reporting the same response repeatedly
  respondedFlag = false;
}

void handleCommand() {
  if (!server.hasArg("plain")) {
    server.send(
      400,
      "text/plain",
      "No body"
    );

    return;
  }

  StaticJsonDocument<512> doc;

  DeserializationError error =
    deserializeJson(
      doc,
      server.arg("plain")
    );

  if (error) {
    server.send(
      400,
      "text/plain",
      "Bad JSON"
    );

    return;
  }

  currentMessage =
    doc["text"] |
    currentMessage;

  currentEmoticon =
    doc["emoticon"] |
    currentEmoticon;

  targetR =
    doc["red"] |
    targetR;

  targetG =
    doc["green"] |
    targetG;

  targetB =
    doc["blue"] |
    targetB;

  brightnessPct =
    doc["brightness"] |
    brightnessPct;

  currentEffect =
    doc["effect"] |
    currentEffect;

  targetR = constrain(
    targetR,
    0,
    255
  );

  targetG = constrain(
    targetG,
    0,
    255
  );

  targetB = constrain(
    targetB,
    0,
    255
  );

  brightnessPct = constrain(
    brightnessPct,
    0,
    100
  );

  updateScreen();

  server.send(
    200,
    "application/json",
    "{\"status\":\"ok\"}"
  );
}

// ==================================================
// Wi-Fi reconnection
// ==================================================

void checkWiFi() {
  unsigned long now = millis();

  if (
    now - lastWiFiCheck <
    5000
  ) {
    return;
  }

  lastWiFiCheck = now;

  if (
    WiFi.status() !=
    WL_CONNECTED
  ) {
    Serial.println(
      "WiFi disconnected. Reconnecting..."
    );

    WiFi.disconnect();
    WiFi.begin(ssid, password);
  }
}

// ==================================================
// Setup
// ==================================================

void setup() {
  Serial.begin(115200);
  delay(500);

  // LED
  ledcAttach(
    PIN_RED,
    PWM_FREQ,
    PWM_RES
  );

  ledcAttach(
    PIN_YELLOW,
    PWM_FREQ,
    PWM_RES
  );

  ledcAttach(
    PIN_GREEN,
    PWM_FREQ,
    PWM_RES
  );

  ledcAttach(
    PIN_BLUE,
    PWM_FREQ,
    PWM_RES
  );

  ledcAttach(
    PIN_WHITE,
    PWM_FREQ,
    PWM_RES
  );

  turnOffLEDs();

  // Motors
  pinMode(AIN1, OUTPUT);
  pinMode(AIN2, OUTPUT);
  pinMode(BIN1, OUTPUT);
  pinMode(BIN2, OUTPUT);

  ledcAttach(
    PWMA,
    PWM_FREQ,
    PWM_RES
  );

  ledcAttach(
    PWMB,
    PWM_FREQ,
    PWM_RES
  );

  stopMotors();

  // PIR
  pinMode(PIR_PIN, INPUT);

  // Physical reply button
  pinMode(BUTTON_PIN, INPUT);

  // Display
  tft.begin();
  tft.setRotation(1);
  updateScreen();

  // Wi-Fi
  WiFi.mode(WIFI_STA);
  WiFi.setAutoReconnect(true);
  WiFi.begin(ssid, password);

  Serial.print("Connecting to WiFi");

  int attempts = 0;

  while (
    WiFi.status() !=
    WL_CONNECTED &&
    attempts < 40
  ) {
    delay(500);
    Serial.print(".");
    attempts++;
  }

  Serial.println();

  if (
    WiFi.status() ==
    WL_CONNECTED
  ) {
    Serial.println("WiFi connected!");

    Serial.print("ESP32 IP address: ");
    Serial.println(WiFi.localIP());

    Serial.print("Signal strength: ");
    Serial.print(WiFi.RSSI());
    Serial.println(" dBm");
  } else {
    Serial.println(
      "Initial WiFi connection failed."
    );

    Serial.println(
      "The ESP32 will keep retrying."
    );
  }

  // HTTP API
  server.on(
    "/ping",
    HTTP_GET,
    handlePing
  );

  server.on(
    "/status",
    HTTP_GET,
    handleStatus
  );

  server.on(
    "/command",
    HTTP_POST,
    handleCommand
  );

  server.begin();

  Serial.println("HTTP server started.");
  Serial.println("PIR warming up...");

  // Start the 15-second PIR warmup without blocking the loop
  pirReadyAt =
    millis() +
    PIR_WARMUP_TIME;

  lastAnyMotion = millis();
}

// ==================================================
// Loop
// ==================================================

void loop() {
  server.handleClient();
  checkWiFi();
  applyLEDs();
  updateBlink();
  updateButton();

  if (
    !pirReady &&
    millis() >= pirReadyAt
  ) {
    pirReady = true;
    previousPirState =
      digitalRead(PIR_PIN);

    Serial.println("PIR ready.");
    Serial.println("Robot ready.");
  }

  readPIR();
  updateMotion();
  updateRespondFeedback();
  updateIdleFidget();
}


