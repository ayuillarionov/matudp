int inByte = 0;         // incoming serial byte
int outPin = 2;         // transistor connected to digital pin 2

void setup() {
  // start serial port at 1000000 bps:
  Serial.begin(1000000);
  while (!Serial) {
    ; // wait for serial port to connect. Needed for native USB port only
  }

  pinMode(outPin, OUTPUT);  // sets the digital pin 2 as output
  //Serial.println("Ready");
  //establishContact();  // send a byte to establish contact until receiver responds
}

void loop() {
  // if we get a valid byte, read analog ins:
  if (Serial.available() > 0) {
    // get incoming byte:
    inByte = Serial.read(); // avoid line endings

    if (inByte == 1 || inByte == 49) { // uint8('1') = 49
      digitalWrite(outPin, HIGH);      // sets the digital pin 2 on
      Serial.write(1);                 // send a byte with the value 1
      //Serial.println("Pin HIGH");
    } else if (inByte != 10){          // unit8('\n') = 10
      digitalWrite(outPin, LOW);       // sets the digital pin 2 off
      Serial.write(0);                 // send a byte with the value 0
      //Serial.println("Pin LOW");
    }
  }
}

void establishContact() {
  while (Serial.available() <= 0) {
    Serial.print('A');   // send a capital A
    delay(300);
  }
}
