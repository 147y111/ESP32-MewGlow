#include <WiFi.h>
#include <WebServer.h>
#include <ArduinoJson.h>

const char* WIFI_SSID = "YOUR_WIFI_NAME";
const char* WIFI_PASS = "YOUR_WIFI_PASSWORD";

const int PIN_R = 25;
const int PIN_G = 26;
const int PIN_B = 27;

WebServer server(80);

int cmdR = 255;
int cmdG = 180;
int cmdB = 80;
int cmdBrightness = 0;
String cmdEffect = "steady";
String cmdEmoticon = "";
String cmdText = "";

#if defined(ESP_ARDUINO_VERSION_MAJOR) && ESP_ARDUINO_VERSION_MAJOR >= 3
void pwmBegin() {
  ledcAttach(PIN_R, 5000, 8);
  ledcAttach(PIN_G, 5000, 8);
  ledcAttach(PIN_B, 5000, 8);
}
void pwmWrite(int pin, int value) {
  ledcWrite(pin, value);
}
#else
void pwmBegin() {
  ledcSetup(0, 5000, 8);
  ledcSetup(1, 5000, 8);
  ledcSetup(2, 5000, 8);
  ledcAttachPin(PIN_R, 0);
  ledcAttachPin(PIN_G, 1);
  ledcAttachPin(PIN_B, 2);
}
void pwmWrite(int pin, int value) {
  int channel = (pin == PIN_R) ? 0 : (pin == PIN_G ? 1 : 2);
  ledcWrite(channel, value);
}
#endif

void playMood(const String& emoticon) {
  if (emoticon == "(^_^)") {
    Serial.println("mood: happy");
  } else if (emoticon == "(-_-)") {
    Serial.println("mood: calm");
  } else if (emoticon == "(^o^)") {
    Serial.println("mood: excited");
  } else if (emoticon == "(>_<)") {
    Serial.println("mood: upset");
  } else if (emoticon == "(;_;)") {
    Serial.println("mood: crying");
  } else {
    Serial.println("mood: custom -> default action");
  }
}

float effectLevel(const String& effect, unsigned long t) {
  if (effect == "breathing") {
    float phase = (t % 3000) / 3000.0f;
    return 0.08f + 0.92f * 0.5f * (1.0f - cosf(phase * 2.0f * PI));
  }
  if (effect == "blink") {
    return (t % 1000) < 500 ? 1.0f : 0.0f;
  }
  if (effect == "heartbeat") {
    unsigned long p = t % 1200;
    if (p < 120) return 1.0f;
    if (p >= 240 && p < 360) return 1.0f;
    return 0.08f;
  }
  return 1.0f;
}

void updateLight() {
  float level = effectLevel(cmdEffect, millis());
  float scale = level * (cmdBrightness / 100.0f);
  pwmWrite(PIN_R, (int)(cmdR * scale));
  pwmWrite(PIN_G, (int)(cmdG * scale));
  pwmWrite(PIN_B, (int)(cmdB * scale));
}

void handlePing() {
  server.send(200, "text/plain", "pong");
}

void handleCommand() {
  if (!server.hasArg("plain")) {
    server.send(400, "text/plain", "no body");
    return;
  }

  String body = server.arg("plain");
  Serial.println("Received: " + body);

  JsonDocument doc;
  DeserializationError err = deserializeJson(doc, body);
  if (err) {
    server.send(400, "text/plain", "bad json");
    return;
  }

  cmdText = doc["text"] | "";
  cmdEmoticon = doc["emoticon"] | "";
  cmdR = constrain((int)(doc["red"] | 255), 0, 255);
  cmdG = constrain((int)(doc["green"] | 255), 0, 255);
  cmdB = constrain((int)(doc["blue"] | 255), 0, 255);
  cmdBrightness = constrain((int)(doc["brightness"] | 70), 0, 100);
  cmdEffect = String((const char*)(doc["effect"] | "steady"));

  Serial.println("text: " + cmdText);
  Serial.println("emoticon: " + cmdEmoticon);
  Serial.printf(
    "rgb: %d %d %d  brightness: %d  effect: %s\n",
    cmdR,
    cmdG,
    cmdB,
    cmdBrightness,
    cmdEffect.c_str()
  );

  playMood(cmdEmoticon);

  server.send(200, "text/plain", "OK");
}

void setup() {
  Serial.begin(115200);
  pwmBegin();

  WiFi.begin(WIFI_SSID, WIFI_PASS);
  Serial.print("Connecting");
  while (WiFi.status() != WL_CONNECTED) {
    delay(500);
    Serial.print(".");
  }
  Serial.println();
  Serial.print("ESP32 IP: ");
  Serial.println(WiFi.localIP());

  server.on("/ping", HTTP_GET, handlePing);
  server.on("/command", HTTP_POST, handleCommand);
  server.begin();
}

void loop() {
  server.handleClient();
  updateLight();
}
