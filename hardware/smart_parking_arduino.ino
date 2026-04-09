// ================================================================
//  SMART PARKING SYSTEM — Arduino Code
//  Hardware: 1x HC-SR04 Ultrasonic + 1x IR Sensor (Minimal Setup)
// ================================================================

#include <WiFiS3.h>
#include <PubSubClient.h>
#include <Servo.h>

// ── WiFi & MQTT ──────────────────────────────────────────────────
const char* ssid       = "YOUR_WIFI_SSID";
const char* password   = "YOUR_WIFI_PASSWORD";
const char* mqttServer = "192.168.x.x";   // ← your laptop's local IP
const int   mqttPort   = 1883;

// ── Pin Definitions ──────────────────────────────────────────────
#define TRIG_PIN     2    // HC-SR04 Trigger
#define ECHO_PIN     3    // HC-SR04 Echo
#define IR_PIN       6    // IR Sensor output
#define GATE_SERVO   10   // Gate servo (PWM)
#define LED_SLOT1    11   // Slot 1 LED (220Ω resistor in series)
#define BUZZER_PIN   8    // Buzzer

// ── Thresholds ───────────────────────────────────────────────────3cd5c
#define OCCUPIED_CM  50   // Distance below this = car present
#define GATE_OPEN    90   // Servo angle for open gate
#define GATE_CLOSED  0    // Servo angle for closed gate
#define GATE_DELAY   3000 // Gate stays open for 3 seconds

// ── State ────────────────────────────────────────────────────────
int prevSlotStatus    = -1;   // -1 = uninitialized
int prevIRStatus      = -1;
int vehicleCount      = 0;
bool gateOpen         = false;
unsigned long gateOpenTime = 0;

WiFiClient    wifiClient;
PubSubClient  mqttClient(wifiClient);
Servo         gateServo;

// ================================================================
//  SETUP
// ================================================================
void setup() {
  Serial.begin(9600);

  // Pin modes
  pinMode(TRIG_PIN,  OUTPUT);
  pinMode(ECHO_PIN,  INPUT);
  pinMode(IR_PIN,    INPUT);
  pinMode(LED_SLOT1, OUTPUT);
  pinMode(BUZZER_PIN, OUTPUT);

  // Gate servo
  gateServo.attach(GATE_SERVO);
  gateServo.write(GATE_CLOSED);

  // Connect WiFi
  Serial.print("Connecting to WiFi");
  WiFi.begin(ssid, password);
  while (WiFi.status() != WL_CONNECTED) {
    delay(500);
    Serial.print(".");
  }
  Serial.println("\nWiFi connected! IP: " + WiFi.localIP().toString());

  // Connect MQTT
  mqttClient.setServer(mqttServer, mqttPort);
  connectMQTT();
}

// ================================================================
//  LOOP
// ================================================================
void loop() {
  if (!mqttClient.connected()) connectMQTT();
  mqttClient.loop();

  // 1) Read sensors
  int slotStatus = readUltrasonic();   // 0 = free, 1 = occupied
  int irStatus   = readIR();           // 0 = no detection, 1 = detected

  // 2) Handle slot state change
  if (slotStatus != prevSlotStatus) {
    updateSlotLED(slotStatus);
    publishSlotState(slotStatus);
    prevSlotStatus = slotStatus;
    Serial.println("Slot 1: " + String(slotStatus == 1 ? "OCCUPIED" : "FREE"));
  }

  // 3) Handle IR detection (entry/exit toggle — single sensor mode)
  if (irStatus == 1 && prevIRStatus == 0) {
    // Rising edge: car detected at entry/exit
    handleVehicleDetected();
  }
  prevIRStatus = irStatus;

  // 4) Auto-close gate after delay
  if (gateOpen && (millis() - gateOpenTime >= GATE_DELAY)) {
    closeGate();
  }

  delay(200);  // Loop every 200ms — fast enough, not spammy
}

// ================================================================
//  SENSOR FUNCTIONS
// ================================================================

// Returns 1 if car detected (distance < OCCUPIED_CM), else 0
int readUltrasonic() {
  digitalWrite(TRIG_PIN, LOW);
  delayMicroseconds(2);
  digitalWrite(TRIG_PIN, HIGH);
  delayMicroseconds(10);
  digitalWrite(TRIG_PIN, LOW);

  long duration = pulseIn(ECHO_PIN, HIGH, 30000); // 30ms timeout
  if (duration == 0) return 0;                    // No echo = assume free

  int distanceCm = duration * 0.034 / 2;
  Serial.println("Distance: " + String(distanceCm) + " cm");

  return (distanceCm > 0 && distanceCm < OCCUPIED_CM) ? 1 : 0;
}

// Returns 1 if IR beam is broken (car present), else 0
// Note: Most IR modules output LOW when object detected — adjust if needed
int readIR() {
  return (digitalRead(IR_PIN) == LOW) ? 1 : 0;
}

// ================================================================
//  ACTUATOR FUNCTIONS
// ================================================================

void updateSlotLED(int status) {
  // HIGH = occupied (red LED), LOW = free (green LED)
  // If you have two separate LEDs: adjust accordingly
  digitalWrite(LED_SLOT1, status == 1 ? HIGH : LOW);
}

void handleVehicleDetected() {
  vehicleCount++;
  Serial.println("Vehicle detected! Count: " + String(vehicleCount));
  openGate();
  publishVehicleCount();
}

void openGate() {
  gateServo.write(GATE_OPEN);
  gateOpen = true;
  gateOpenTime = millis();
  Serial.println("Gate OPEN");
}

void closeGate() {
  gateServo.write(GATE_CLOSED);
  gateOpen = false;
  Serial.println("Gate CLOSED");
}

void triggerBuzzer(int beeps) {
  for (int i = 0; i < beeps; i++) {
    digitalWrite(BUZZER_PIN, HIGH);
    delay(200);
    digitalWrite(BUZZER_PIN, LOW);
    delay(200);
  }
}

// ================================================================
//  MQTT FUNCTIONS
// ================================================================

void connectMQTT() {
  Serial.print("Connecting to MQTT...");
  while (!mqttClient.connect("ArduinoParking")) {
    Serial.print(".");
    delay(2000);
  }
  Serial.println(" connected!");
}

// Publish slot occupancy state
void publishSlotState(int status) {
  String payload = "{\"slot\":1,\"status\":" + String(status) + "}";
  mqttClient.publish("parking/slots", payload.c_str());
  Serial.println("Published: " + payload);
}

// Publish vehicle entry count
void publishVehicleCount() {
  String payload = "{\"entries\":" + String(vehicleCount) + "}";
  mqttClient.publish("parking/counts", payload.c_str());
  Serial.println("Published count: " + payload);
}
