#include <Arduino.h>
#include <core_timers.h>
//#include <USI_TWI_Slave.h>
#include <TinyWireS.h>

#define MOTOR_FORWARD_PIN 2
#define MOTOR_BACKWARD_PIN 3
#define JUMPER_0_PIN 0
#define JUMPER_1_PIN 1
#define JUMPER_2_PIN 8
#define JUMPER_3_PIN 7
#define ENCODER_PIN 1 // Encoder A, ADC1
#define HOMING_PIN 0 // Encoder B, ADC0

uint8_t twiAddress = 0;

//#define SUM_READS_N 4

// Encoder
#define MIN_PEAK_PEAK_DIF 7
#define MIN_PEAK_RESET_DIF 35
#define MIN_PEAK_VALLEY_DIF 3
#define MAX_RETURN_DIF 10
#define MIN_DIF_FROM_AVG1 4
#define MIN_DIF_FROM_AVG2 10
// these are out of 100
#define AVG_RECENT_BETA1 1
#define AVG_RECENT_BETA2 10

uint8_t tickState = 0;
bool inValley = true;
uint8_t lastChange = 0;

int secondLastPeak = -1;
int lastPeak = -1;
int lastValley = -1;
int peak = -1;
int valley = -1;

int avgRecentVal1 = 0;
int avgRecentVal2 = 0;

int encoderValue = 0;

// modulate running average of speed, out of 100, 100 = 1.00
#define SPEED_MEASURE_BETA 40

int lastPeakMillis = 0;
int peakMillis = 0;

int targetSpeed = 0;
int measuredSpeed = 0;

/*#define ENCODER_BLACK_THRESHOLD 400
#define ENCODER_WHITE_THRESHOLD 900

byte lastEncoderA = false;
byte lastEncoderB = false;*/

// For homing to find a known angle in initialization
/*#define HOMING0_COUNTER_CLOCK 102
#define HOMING1_CLOCK_WISE 307
#define HOMING2_CENTER 512
#define HOMING3_LEFT_SIDE 717
#define HOMING4_RIGHT_SIDE 922*/
#define HOMING_0 102
#define HOMING_60 307
#define HOMING_120 512
#define HOMING_180 717
#define HOMING_240 922
#define HOMING_300 1000
#define HOMING_SPEED 30
#define HOMING_PASSED_THRESHOLD 100
#define HOMING_DELTA 32
int homingMinValue = 10000; // a large value
int homingMinAngle = 0;
int homingValue = 0;
//int lastHomingValue = 0;
int firstHomingValue = 0;
bool homingDirectionDecided = false;
bool isHoming = false;

// In 100ths of a degree (encoder ticks) so 0 to 35999
// In ticks of 1.8 degrees each.
int targetTicks = 0;
int ticks = 0;

// PID_MIN_OUT to PID_MAX_OUT
// Start ready to home
int motorOutput = 0;
byte motorDirection = 0;
// Keep track of last setting applied
int lastMotorOutput = -1;

// PID control constants and variables
#define PID_UPDATE_INTERVAL 100 // in ms
#define PID_MIN_OUT -160
#define PID_MAX_OUT 160
// These values are all in fixed point. 1024 is 1.000.
#define ANGLE_MOTOR_P 1024
#define ANGLE_MOTOR_I (10 * PID_UPDATE_INTERVAL)
#define ANGLE_MOTOR_D (300 / PID_UPDATE_INTERVAL)

#define SPEED_MOTOR_P 1024
#define SPEED_MOTOR_I (10 * PID_UPDATE_INTERVAL)
#define SPEED_MOTOR_D (300 / PID_UPDATE_INTERVAL)

uint16_t lastUpdateTime = 0;
int motorITerm = 0;
int lastTicks = 0;
int lastMeasuredSpeed = 0;

// Communication
#define READ_ANGLE_MSG 1
#define SET_ANGLE_MSG 2
#define READ_SET_ANGLE_MSG 3
#define READ_ENCODER_MSG 4
#define READ_HOMING_MSG 5
#define DIAGNOSTIC_MSG 6
#define ADDRESS_MSG 7
#define VALUE_TEST_MSG 8
#define READ_ADC0_MSG 9
#define READ_ADC1_MSG 10
#define READ_ADC2_MSG 11
#define READ_ADC3_MSG 12
#define READ_ADC4_MSG 13
#define READ_ADC5_MSG 14
#define READ_ADC6_MSG 15
#define READ_ADC7_MSG 16
#define SET_RAW_MOTOR_MSG 17
#define READ_RAW_MOTOR_MSG 18
#define SET_TARGET_SPEED_MSG 19
#define READ_TARGET_SPEED_MSG 20
#define READ_MEASURED_SPEED_MSG 21
#define DO_HOMING_MSG 22

// Control modes
#define RAW_MOTOR_CONTROL 0
#define SPEED_CONTROL 1
#define ANGLE_CONTROL 2
byte controlMode = RAW_MOTOR_CONTROL;

bool receivingSetRawMotor = false;
bool receivingSetAngle = false;
bool receivingSetSpeed = false;
bool hasHighByte = false;
byte setValueHighByte;

// We do not need the full 32-bit resolution of millis, so we save space by doing 16-bit operations
// Rollover is not a problem as the _unsigned_ subtraction will still work out.
uint16_t millis16() {
    return (uint16_t)(millis() & 0xffff);
}

void updatePid() {
    if (controlMode == RAW_MOTOR_CONTROL || isHoming) {
        return; // no PID for these
    }

    uint16_t now = millis16();
    if (now - lastUpdateTime > PID_UPDATE_INTERVAL) {
        int motorP;
        int motorI;
        int motorD;
        int error;
        int derivative;
        if (controlMode == SPEED_CONTROL) {
            motorP = SPEED_MOTOR_P;
            motorI = SPEED_MOTOR_I;
            motorD = SPEED_MOTOR_D;
            error = targetSpeed - measuredSpeed;
            derivative = measuredSpeed - lastMeasuredSpeed;
        } else {
            motorP = ANGLE_MOTOR_P;
            motorI = ANGLE_MOTOR_I;
            motorD = ANGLE_MOTOR_D;
            error = targetTicks - ticks;
            derivative = ticks - lastTicks;
        }

        // Remember that here we use fixed point 1024 as 1.0, hence the 10-bit shifts.
        motorITerm += motorI * error >> 10;
        if (motorITerm < PID_MIN_OUT) {
            motorITerm = PID_MIN_OUT;
        } else if (motorITerm > PID_MAX_OUT) {
            motorITerm = PID_MAX_OUT;
        }

        motorOutput = (motorP * error >> 10) + motorITerm + (motorD * derivative >> 10);
        
        lastTicks = ticks;
        lastMeasuredSpeed = measuredSpeed;
        lastUpdateTime = now;
    }
}

void setupTimerInterrupts() {
    Timer1_SetToPowerup(); // Turn all settings off!

    Timer1_SetWaveformGenerationMode(Timer1_Fast_PWM_FF); // Top is 0xFF, OCR1A is used to modify duty cycle
    Timer1_ClockSelect(Timer1_Prescale_Value_256);

    Timer1_SetOutputCompareMatchA(0); // Set pulse width

    Timer1_EnableOverflowInterrupt();
    Timer1_EnableOutputCompareInterruptA();
}

ISR(TIMER1_OVF_vect) {
    if (motorDirection == 0) {
        digitalWrite(MOTOR_BACKWARD_PIN, HIGH);
    } else if (motorDirection == 1) {
        digitalWrite(MOTOR_FORWARD_PIN, HIGH);
    }
}

ISR(TIMER1_COMPA_vect) {
    if (!Timer1_IsOverflowSet()) {
        if (motorDirection == 0) {
            digitalWrite(MOTOR_BACKWARD_PIN, LOW);
        } else if(motorDirection == 1) {
            digitalWrite(MOTOR_FORWARD_PIN, LOW);
        }
    }
}

void updateMotor() {
    if (motorOutput < PID_MIN_OUT) {
        motorOutput = PID_MIN_OUT;
    } else if (motorOutput > PID_MAX_OUT) {
        motorOutput = PID_MAX_OUT;
    }

    if (motorOutput != lastMotorOutput) {
        lastMotorOutput = motorOutput;
        digitalWrite(MOTOR_FORWARD_PIN, LOW);
        digitalWrite(MOTOR_BACKWARD_PIN, LOW);
        if (motorOutput == 0) {
            motorDirection = 2;
        } else if (motorOutput < 0) {
            motorDirection = 0;
            Timer1_SetOutputCompareMatchA(-motorOutput);
        } else {
            motorDirection = 1;
            Timer1_SetOutputCompareMatchA(motorOutput);
        }
    }
}

/*int sumAnalogRead(uint8_t pin) {
    int sum = 0;
    for(uint8_t i = 0; i < SUM_READS_N; i++) {
        sum += analogRead(pin);
    }
    return sum;
}*/

// The encoder has holes of three different sizes. Because of 3d-printing, they are not extremely
// consistent. So we try to use as much good reason here as possible!
// We keep track of valleys (the space between holes with little light passing through)
// and peaks (the center of the holes where the most light gets through)
// and basically look to see if the pattern of hole size is small-medium-big or big-medium-small.
void updateEncoder() {
    encoderValue = analogRead(ENCODER_PIN);

    if (avgRecentVal1 == 0) {
        avgRecentVal1 = encoderValue;
        avgRecentVal2 = encoderValue;
    } else {
        avgRecentVal1 = (avgRecentVal1 * (100 - AVG_RECENT_BETA1) + encoderValue * AVG_RECENT_BETA1) / 100;
        avgRecentVal2 = (avgRecentVal2 * (100 - AVG_RECENT_BETA2) + encoderValue * AVG_RECENT_BETA2) / 100;
    }

    if (abs(avgRecentVal1 - encoderValue) >= MIN_DIF_FROM_AVG1 || abs(avgRecentVal2 - encoderValue) >= MIN_DIF_FROM_AVG2) {
        if (inValley && encoderValue >= valley + MIN_PEAK_VALLEY_DIF) {
            if (valley != -1) {
                lastValley = valley;
                valley = -1;
            }
            inValley = false;
        } else if (!inValley && peak != -1 && encoderValue <= peak - MIN_PEAK_VALLEY_DIF) {
            uint8_t ticksChange = 0;
            int absReturnDiff = abs(secondLastPeak - peak);
            if (peak >= lastValley + MIN_PEAK_VALLEY_DIF) {
                if (peak >= lastPeak + MIN_PEAK_PEAK_DIF && tickState < 2 &&
                        (lastChange != -1 || absReturnDiff <= MAX_RETURN_DIF)) {
                    tickState = tickState + 1;
                    ticks++;
                    ticksChange = 1;
                    // allow next peak to go either way
                    lastChange = lastChange == -1 ? 0 : 1;
                } else if (peak <= lastPeak - MIN_PEAK_RESET_DIF && tickState == 2 &&
                        (lastChange != -1 || absReturnDiff <= MAX_RETURN_DIF)) {
                    tickState = 0;
                    ticks++;
                    ticksChange = 1;
                    lastChange = lastChange == -1 ? 0 : 1;
                } else if (peak <= lastPeak - MIN_PEAK_PEAK_DIF && tickState > 0 &&
                        (lastChange != 1 || absReturnDiff <= MAX_RETURN_DIF)) {
                    tickState = tickState - 1;
                    ticks--;
                    ticksChange = -1;
                    lastChange = lastChange == 1 ? 0 : -1;
                } else if (peak >= lastPeak + MIN_PEAK_RESET_DIF && tickState == 0 &&
                        (lastChange != 1 || absReturnDiff <= MAX_RETURN_DIF)) {
                    tickState = 2;
                    ticks--;
                    ticksChange = -1;
                    lastChange = lastChange == 1 ? 0 : -1;
                }
            }
            
            secondLastPeak = lastPeak;
            lastPeak = peak;
            if (ticksChange != 0) {
                lastPeakMillis = peakMillis;
                peakMillis = millis16();
                if (lastPeakMillis != 0) {
                    measuredSpeed = (measuredSpeed * (100 - SPEED_MEASURE_BETA) + (ticksChange * 18 * 1000 / (peakMillis - lastPeakMillis)) * SPEED_MEASURE_BETA) / 100;
                }
            }
        
            peak = -1;
            inValley = true;
        }
    
        if (!inValley && (peak == -1 || encoderValue > peak)) {
            peak = encoderValue;
        } else if (inValley && (valley == -1 || encoderValue < valley)) {
            valley = encoderValue;
        }
    }
}

void updateHoming() {
    homingValue = analogRead(HOMING_PIN);
    if (isHoming) {
        // Just turn on motor forward, slow, for initialization
        if (firstHomingValue) { // != 0
            // The homing targets are local minima if the value is not decreasing, use the other direction
            if (!homingDirectionDecided) {
                if (homingValue > firstHomingValue + HOMING_DELTA) {
                    motorOutput = -HOMING_SPEED;
                    homingDirectionDecided = true;
                } else if (homingValue < firstHomingValue - HOMING_DELTA) {
                    homingDirectionDecided = true;
                }
            }
            if (homingValue < homingMinValue) {
                homingMinValue = homingValue;
                homingMinAngle = ticks;
            } else if (homingValue > homingMinValue + HOMING_PASSED_THRESHOLD) {
                // The minimum is the homed on value
                byte homedOnIndex = 0;
                if (homingMinValue <= HOMING_0) {
                    homedOnIndex = 0;
                } else if (homingMinValue <= HOMING_60) {
                    homedOnIndex = 1;
                } else if (homingMinValue <= HOMING_120) {
                    homedOnIndex = 2;
                } else if (homingMinValue <= HOMING_180) {
                    homedOnIndex = 3;
                } else if (homingMinValue <= HOMING_240) {
                    homedOnIndex = 4;
                } else if (homingMinValue <= HOMING_300) {
                    homedOnIndex = 5;
                }
                ticks = ticks - homingMinValue + 60 * homedOnIndex;
                isHoming = false;
            }
        } else {
            firstHomingValue = homingValue;
        }
    }
}

void updateControl() {
    while (TinyWireS.available()) {
        byte newByte = TinyWireS.receive();

        if (receivingSetAngle || receivingSetRawMotor || receivingSetSpeed) {
            if (!hasHighByte) {
                setValueHighByte = newByte;
                hasHighByte = true;
            } else {
                int value = (setValueHighByte << 8) + newByte;
                if (receivingSetAngle) {
                    controlMode = ANGLE_CONTROL;
                    motorITerm = 0;
                    targetTicks = (value + 9) / 18;
                    receivingSetAngle = false;
                } else if (receivingSetRawMotor) {
                    controlMode = RAW_MOTOR_CONTROL;
                    motorOutput = value;
                    receivingSetRawMotor = false;
                } else if (receivingSetSpeed) {
                    controlMode = SPEED_CONTROL;
                    motorITerm = 0;
                    targetSpeed = value;
                    receivingSetSpeed = false;
                }
                hasHighByte = false;
            }
        } else {
            int setAngle;
            switch (newByte) {
                case READ_ANGLE_MSG:
                    // Send a "no angle" signal when we haven't homed to find out yet
                    if (isHoming) {
                        TinyWireS.send(0xff);
                        TinyWireS.send(0xff);
                    } else {
                        TinyWireS.send((ticks >> 8) & 0xff);
                        TinyWireS.send(ticks & 0xff);
                    }
                    break;
                case SET_ANGLE_MSG:
                    receivingSetAngle = true;
                    break;
                case READ_SET_ANGLE_MSG:
                    setAngle = targetTicks * 18;
                    TinyWireS.send((targetTicks >> 8) & 0xff);
                    TinyWireS.send(targetTicks & 0xff);
                    break;
                case READ_ENCODER_MSG:
                    TinyWireS.send((encoderValue >> 8) & 0xff);
                    TinyWireS.send(encoderValue & 0xff);
                    break;
                case READ_HOMING_MSG:
                    TinyWireS.send((homingValue >> 8) & 0xff);
                    TinyWireS.send(homingValue & 0xff);
                    break;
                case DIAGNOSTIC_MSG:
                    TinyWireS.send('H');
                    TinyWireS.send('I');
                    break;
                case ADDRESS_MSG:
                    TinyWireS.send(0);
                    TinyWireS.send(twiAddress);
                    break;
                case VALUE_TEST_MSG:
                    TinyWireS.send((1023 >> 8) & 0xff);
                    TinyWireS.send(1023 & 0xff);
                    break;
                case SET_RAW_MOTOR_MSG:
                    receivingSetRawMotor = true;
                    break;
                case READ_RAW_MOTOR_MSG:
                    TinyWireS.send((motorOutput >> 8) & 0xff);
                    TinyWireS.send(motorOutput & 0xff);
                    break;
                case SET_TARGET_SPEED_MSG:
                    receivingSetSpeed = true;
                    break;
                case READ_TARGET_SPEED_MSG:
                    TinyWireS.send((targetSpeed >> 8) & 0xff);
                    TinyWireS.send(targetSpeed & 0xff);
                    break;
                case READ_MEASURED_SPEED_MSG:
                    TinyWireS.send((measuredSpeed >> 8) & 0xff);
                    TinyWireS.send(measuredSpeed & 0xff);
                    break;
                case DO_HOMING_MSG:
                    isHoming = true;
                    break;
            }
            if (newByte >= READ_ADC0_MSG && newByte <= READ_ADC7_MSG) {
                int adcValue = analogRead(newByte - READ_ADC0_MSG);
                TinyWireS.send((adcValue >> 8) & 0xff);
                TinyWireS.send(adcValue & 0xff);
            }
        }
    }
}

void setup() {
    // We start with one high bit, because the low addresses
    // from 0 to 7 or so are reserved.
    // Our address range is 8 to 23
    twiAddress = 8;
    pinMode(JUMPER_0_PIN, INPUT_PULLUP);
    twiAddress += digitalRead(JUMPER_0_PIN);
    pinMode(JUMPER_1_PIN, INPUT_PULLUP);
    twiAddress += digitalRead(JUMPER_1_PIN) << 1;
    pinMode(JUMPER_2_PIN, INPUT_PULLUP);
    twiAddress += digitalRead(JUMPER_2_PIN) << 2;
    pinMode(JUMPER_3_PIN, INPUT_PULLUP);
    twiAddress += digitalRead(JUMPER_3_PIN) << 3;

    TinyWireS.begin(twiAddress);

    pinMode(MOTOR_FORWARD_PIN, OUTPUT);
    pinMode(MOTOR_BACKWARD_PIN, OUTPUT);

    setupTimerInterrupts();
    motorOutput = 0;
    digitalWrite(MOTOR_FORWARD_PIN, LOW);
    digitalWrite(MOTOR_BACKWARD_PIN, LOW);
    updateMotor();

    // 5V internal analog reference
    analogReference(DEFAULT);
}

void loop() {
    updateControl();
    updateEncoder();
    updateHoming();
    updatePid();
    updateMotor();
}
