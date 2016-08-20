#include <Arduino.h>
#include <core_timers.h>
//#include <USI_TWI_Slave.h>
#include <TinyWireS.h>

#define MOTOR_FORWARD_PIN 0
#define MOTOR_BACKWARD_PIN 1
#define JUMPER_0_PIN 3
#define JUMPER_1_PIN 2
#define JUMPER_2_PIN 7
#define JUMPER_3_PIN 8
#define ENCODER_PIN 0 // ADC0
#define HOMING_PIN 1 // ADC1

uint8_t twiAddress = 0;

// Encoder values
#define ENCODER_HIGH_THRESHOLD 900
#define ENCODER_LOW_THRESHOLD 400
int encoderValue = 0;
int lastEncoderValue = 0;

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
bool isHoming = true;

// In 10ths of a degree (encoder ticks) so 0 to 3599
int setAngle = 0;
int currentAngle = 0;

// PID_MIN_OUT to PID_MAX_OUT
// Start ready to home
int motorOutput = HOMING_SPEED;
byte motorDirection = 0;

// PID control constants and variables
#define PID_UPDATE_INTERVAL 100 // in ms
#define PID_MIN_OUT -255
#define PID_MAX_OUT 255
// These values are all in fixed point. 1024 is 1.000.
int motorP = 1024;
int motorI = 10 * PID_UPDATE_INTERVAL;
int motorD = 300 / PID_UPDATE_INTERVAL;
uint16_t lastUpdateTime = 0;
int motorITerm = 0;
int lastCurrentAngle = 0;

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

bool receivingSetAngle = false;
bool hasHighByte = false;
byte setAngleHighByte;

void updatePid() {
    if (!isHoming) {
        // We do not need the full 32-bit resolution of millis, so we save space by doing 16-bit operations
        // Rollover is not a problem as the _unsigned_ subtraction will still work out.
        uint16_t now = (uint16_t)(millis() & 0xffff);
        if (now - lastUpdateTime > PID_UPDATE_INTERVAL) {
            int error = setAngle - currentAngle;
            motorITerm += motorI * error >> 10;
            if (motorITerm < PID_MIN_OUT) {
                motorITerm = PID_MIN_OUT;
            } else if (motorITerm > PID_MAX_OUT) {
                motorITerm = PID_MAX_OUT;
            }

            motorOutput = (motorP * error >> 10) + motorITerm + (motorD * (currentAngle - lastCurrentAngle) >> 10);
            // analogWrite will constrain the value for us to 255. Save 30 bytes here...
            /*if (motorOutput < PID_MIN_OUT) {
                motorOutput = PID_MIN_OUT;
            } else if (motorOutput > PID_MAX_OUT) {
                motorOutput = PID_MAX_OUT;
            }*/

            lastCurrentAngle = currentAngle;
            lastUpdateTime = now;
        }
    }
}

/*void setupTimerInterrupts() {
    Timer1_SetToPowerup(); // Turn all settings off!

    Timer1_SetWaveformGenerationMode(Timer1_Fast_PWM_FF); // Top is 0xFF, OCR1A is used to modify duty cycle
    Timer1_ClockSelect(Timer1_Prescale_Value_256);

    Timer1_SetOutputCompareMatchA(0); // Set pulse width

    Timer1_EnableOverflowInterrupt();
    Timer1_EnableOutputCompareInterruptA();
}

ISR(TIMER1_OVF_vect) {
    if (motorDirection == 0) {
        //digitalWrite(MOTOR_BACKWARD_PIN, HIGH);
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
}*/

void updateMotor() {
    if (motorOutput == 0) {
        motorDirection = 2;
        digitalWrite(MOTOR_FORWARD_PIN, LOW);
        digitalWrite(MOTOR_BACKWARD_PIN, LOW);
        pinMode(JUMPER_3_PIN, INPUT);
    } else if (motorOutput < 0) {
        motorDirection = 0;
        digitalWrite(MOTOR_FORWARD_PIN, LOW);
        //digitalWrite(MOTOR_BACKWARD_PIN, HIGH);
        Timer1_SetOutputCompareMatchA(-motorOutput);
        //analogWrite(MOTOR_FORWARD_PIN, 0);
        //analogWrite(MOTOR_BACKWARD_PIN, -motorOutput);
    } else {
        motorDirection = 1;
        digitalWrite(MOTOR_BACKWARD_PIN, LOW);
        digitalWrite(MOTOR_FORWARD_PIN, HIGH);
        pinMode(JUMPER_3_PIN, INPUT_PULLUP);
        Timer1_SetOutputCompareMatchA(motorOutput);
        //analogWrite(MOTOR_BACKWARD_PIN, 0);
        //analogWrite(MOTOR_FORWARD_PIN, motorOutput);
    }
}

/*void updateEncoder() {
    if (isHoming) {
        int encoderCValue = analogRead(ENCODER_C_PIN);
        if (encoderCValue >= HOMING4_RIGHT_SIDE) {
            currentAngle = 900;
            isHoming = false;
        } else if (encoderCValue >= HOMING3_LEFT_SIDE) {
            currentAngle = 2700;
            isHoming = false;
        } else if (encoderCValue >= HOMING2_CENTER) {
            currentAngle = 0;
            isHoming = false;
        } else if (encoderCValue >= HOMING1_CLOCK_WISE) {
            motorOutput = 100;
        } else if (encoderCValue >= HOMING0_COUNTER_CLOCK) {
            motorOutput = -100;
        }
    } else {
        int encoderAValue = analogRead(ENCODER_PIN);
        int encoderBValue = analogRead(ENCODER_B_PIN);

        if ((!lastEncoderA && encoderAValue > ENCODER_WHITE_THRESHOLD) ||
            (lastEncoderA && encoderAValue < ENCODER_BLACK_THRESHOLD)) {
            if (lastEncoderB == lastEncoderA) {
                currentAngle++;
            } else {
                currentAngle--;
            }
            lastEncoderA = !lastEncoderA;
        }

        if ((!lastEncoderB && encoderBValue > ENCODER_WHITE_THRESHOLD) ||
            (lastEncoderB && encoderBValue < ENCODER_BLACK_THRESHOLD)) {
            if (lastEncoderA == lastEncoderB) {
                currentAngle--;
            } else {
                currentAngle++;
            }
            lastEncoderB = !lastEncoderB;
        }
    }
}*/

void updateEncoder() {
    // Count encoder ticks
    encoderValue = analogRead(ENCODER_PIN);

    if (lastEncoderValue >= ENCODER_HIGH_THRESHOLD &&
        encoderValue <= ENCODER_LOW_THRESHOLD) {
        currentAngle++;
    } else if (encoderValue >= ENCODER_HIGH_THRESHOLD &&
               lastEncoderValue <= ENCODER_LOW_THRESHOLD) {
        currentAngle--;
    }
    lastEncoderValue = encoderValue;

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
                homingMinAngle = currentAngle;
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
                currentAngle = currentAngle - homingMinValue + 60 * homedOnIndex;
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

        if (receivingSetAngle) {
            if (!hasHighByte) {
                setAngleHighByte = newByte;
                hasHighByte = true;
            } else {
                setAngle = (setAngleHighByte << 8) + newByte;
                receivingSetAngle = false;
            }
        } else {
            switch (newByte) {
                case READ_ANGLE_MSG:
                    // Send a "no angle" signal when we haven't homed to find out yet
                    if (isHoming) {
                        TinyWireS.send(0xff);
                        TinyWireS.send(0xff);
                    } else {
                        TinyWireS.send((currentAngle >> 8) & 0xff);
                        TinyWireS.send(currentAngle & 0xff);
                    }
                    break;
                case SET_ANGLE_MSG:
                    receivingSetAngle = true;
                    hasHighByte = false;
                    break;
                case READ_SET_ANGLE_MSG:
                    TinyWireS.send((setAngle >> 8) & 0xff);
                    TinyWireS.send(setAngle & 0xff);
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

    if ((twiAddress - 8) & 1) {
        pinMode(JUMPER_0_PIN, INPUT);
    }
    if ((twiAddress - 8) & 2) {
        pinMode(JUMPER_1_PIN, INPUT);
    }
    if ((twiAddress - 8) & 4) {
        pinMode(JUMPER_2_PIN, INPUT);
    }
    if ((twiAddress - 8) & 8) {
        pinMode(JUMPER_3_PIN, INPUT);
    }

    TinyWireS.begin(twiAddress);

    pinMode(MOTOR_FORWARD_PIN, OUTPUT);
    pinMode(MOTOR_BACKWARD_PIN, OUTPUT);

    //setupTimerInterrupts();
    motorOutput = 0;
    digitalWrite(MOTOR_FORWARD_PIN, LOW);
    digitalWrite(MOTOR_BACKWARD_PIN, LOW);
    //updateMotor();

    // 5V internal analog reference
    analogReference(DEFAULT);
}

void loop() {
    updateControl();
    updateEncoder();
    //updatePid();
    //updateMotor();
}
