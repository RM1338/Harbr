#include <Servo.h>

// ── Pin definitions ──────────────────────────────────────────
#define FIXED_TRIG   2
#define FIXED_ECHO   3
#define SERVO_TRIG   4
#define SERVO_ECHO   5
#define SERVO_PIN    9
#define BUZZER_PIN   8

const int SLOT_LED_GREEN[] = {10, 12, A0};
const int SLOT_LED_RED[]   = {6,  7,  A1};

// ── Distance ranges (tune after physical measurement) ────────
#define SLOT1_MAX_CM   20
#define SLOT2_MAX_CM   45
#define SLOT3_MAX_CM   70

// Servo angles (moving sensor at RIGHT, faces LEFT toward slots)
#define ANGLE_SLOT1  130
#define ANGLE_SLOT2  90
#define ANGLE_SLOT3  50

// ── Constants ────────────────────────────────────────────────
#define OCCUPIED_THRESHOLD_CM  25
#define SCAN_DELAY_MS          400
#define LOOP_INTERVAL_MS       1000

// ── Globals ──────────────────────────────────────────────────
Servo scanServo;
int slotState[3]     = {0, 0, 0};
int prevSlotState[3] = {-1, -1, -1};

// ── Helpers ──────────────────────────────────────────────────
long readDistance(int trigPin, int echoPin) {
  digitalWrite(trigPin, LOW);
  delayMicroseconds(2);
  digitalWrite(trigPin, HIGH);
  delayMicroseconds(10);
  digitalWrite(trigPin, LOW);
  long duration = pulseIn(echoPin, HIGH, 30000);
  if (duration == 0) return 999;
  return duration * 0.034 / 2;
}

int inferSlotFromDistance(long dist) {
  if (dist < SLOT1_MAX_CM) return 1;
  if (dist < SLOT2_MAX_CM) return 2;
  if (dist < SLOT3_MAX_CM) return 3;
  return 0;
}

long readServoSlot(int angle) {
  scanServo.write(angle);
  delay(SCAN_DELAY_MS);
  return readDistance(SERVO_TRIG, SERVO_ECHO);
}

int isOccupied(long distCm) {
  return (distCm > 0 && distCm < OCCUPIED_THRESHOLD_CM) ? 1 : 0;
}

void setSlotLED(int slot, int occupied) {
  digitalWrite(SLOT_LED_GREEN[slot], occupied ? LOW  : HIGH);
  digitalWrite(SLOT_LED_RED[slot],   occupied ? HIGH : LOW);
}

void triggerBuzzer() {
  digitalWrite(BUZZER_PIN, HIGH);
  delay(200);
  digitalWrite(BUZZER_PIN, LOW);
}

// ── Setup ────────────────────────────────────────────────────
void setup() {
  Serial.begin(9600);

  pinMode(FIXED_TRIG, OUTPUT);
  pinMode(FIXED_ECHO, INPUT);
  pinMode(SERVO_TRIG, OUTPUT);
  pinMode(SERVO_ECHO, INPUT);
  pinMode(BUZZER_PIN, OUTPUT);

  for (int i = 0; i < 3; i++) {
    pinMode(SLOT_LED_GREEN[i], OUTPUT);
    pinMode(SLOT_LED_RED[i],   OUTPUT);
    digitalWrite(SLOT_LED_GREEN[i], HIGH);
    digitalWrite(SLOT_LED_RED[i],   LOW);
  }

  scanServo.attach(SERVO_PIN);
  scanServo.write(ANGLE_SLOT2);
  delay(500);

  Serial.println("=== Smart Parking System ===");
  Serial.println("Layout: [FIXED] | S1 | S2 | S3 | [SERVO]");
  Serial.println("============================");
}

// ── Main loop ────────────────────────────────────────────────
void loop() {
  long fixedDist    = readDistance(FIXED_TRIG, FIXED_ECHO);
  int  detectedSlot = inferSlotFromDistance(fixedDist);

  Serial.println("\n--- Parking Status ---");
  Serial.print("Fixed sensor dist: ");
  Serial.print(fixedDist);
  Serial.print(" cm  →  nearest car at: ");
  Serial.println(detectedSlot == 0 ? "none" : "Slot " + String(detectedSlot));

  // ── Conditional sweep logic ───────────────────────────────

  if (detectedSlot == 3) {
    // Slot 3 confirmed by fixed sensor — servo does nothing
    slotState[0] = 0;
    slotState[1] = 0;
    slotState[2] = 1;
    Serial.println("[SERVO] Idle — slot 3 confirmed by fixed sensor");

  } else if (detectedSlot == 0) {
    // No car at all — servo does nothing
    slotState[0] = 0;
    slotState[1] = 0;
    slotState[2] = 0;
    Serial.println("[SERVO] Idle — no cars detected");

  } else if (detectedSlot == 2) {
    // Slot 2 confirmed by fixed sensor
    // Servo locks onto slot 3 permanently to monitor it
    slotState[0] = 0;
    slotState[1] = 1;
    scanServo.write(ANGLE_SLOT3);
    delay(SCAN_DELAY_MS);
    long d3 = readDistance(SERVO_TRIG, SERVO_ECHO);
    slotState[2] = isOccupied(d3);
    Serial.print("[SERVO] Fixed at slot 3 — dist: ");
    Serial.print(d3);
    Serial.println(" cm");

  } else if (detectedSlot == 1) {
    // Slot 1 confirmed by fixed sensor
    // Servo sweeps slot 2 and slot 3 at equal intervals
    slotState[0] = 1;
    long d2 = readServoSlot(ANGLE_SLOT2);
    slotState[1] = isOccupied(d2);
    long d3 = readServoSlot(ANGLE_SLOT3);
    slotState[2] = isOccupied(d3);
    Serial.print("[SERVO] Checked slots 2 & 3 — dist2: ");
    Serial.print(d2);
    Serial.print(" cm, dist3: ");
    Serial.print(d3);
    Serial.println(" cm");
  }

  // Return servo to center only if not locked on slot 3
  if (detectedSlot != 2) {
    scanServo.write(ANGLE_SLOT2);
  }

  // ── Update LEDs, buzzer, print status ─────────────────────
  bool anyChange = false;
  for (int i = 0; i < 3; i++) {
    if (slotState[i] != prevSlotState[i]) {
      anyChange = true;
      setSlotLED(i, slotState[i]);
      if (slotState[i] == 1) triggerBuzzer();
      prevSlotState[i] = slotState[i];
    }
  }

  for (int i = 0; i < 3; i++) {
    Serial.print("Slot ");
    Serial.print(i + 1);
    Serial.print(": ");
    Serial.println(slotState[i] ? "OCCUPIED" : "FREE");
  }

  int freeCount = 0;
  for (int i = 0; i < 3; i++) if (!slotState[i]) freeCount++;
  Serial.print("Free slots: ");
  Serial.print(freeCount);
  Serial.println("/3");
  if (anyChange) Serial.println("[STATE CHANGED]");

  delay(LOOP_INTERVAL_MS);
}