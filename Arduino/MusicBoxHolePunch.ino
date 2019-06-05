// SD READING + MENU NAVIGATION
#include <SPI.h>
#include <SD.h>
#define MAX_FILES 10
String fileNames[MAX_FILES];
File root;
File file;
String key;
long val;
int numFiles = 0;
int currentFileSelection = 0;
int windowPosition = 0;
int currentMenu = 0;
boolean fileIsValid;

// LCD DISPLAY
#include <EEPROM.h>
#include <LiquidCrystal_I2C.h>
LiquidCrystal_I2C lcd(0x27, 2, 1, 0, 4, 5, 6, 7, 3, POSITIVE);
#define SYMBOL_DOWNARROW 1
#define SYMBOL_RIGHTARROW 2
#define SYMBOL_PLAY 3
#define SYMBOL_PAUSE 4
byte rightArrow[] = {0x00,0x04,0x06,0x1F,0x1F,0x06,0x04,0x00};
byte downArrow[] = {0x00,0x04,0x04,0x04,0x04,0x15,0x0E,0x04};
byte play[] = {0x08,0x0C,0x0E,0x0F,0x0E,0x0C,0x08,0x00};
byte pause[] = {  0x1B,0x1B,0x1B,0x1B,0x1B,0x1B,0x1B,0x00};

// INPUTS
#define UP_BUTTON A0
#define DOWN_BUTTON A1
#define SELECT_BUTTON A2
#define RIGHT_LIMIT A3
#define LEFT_LIMIT A4
#define PUNCH_LIMIT A5
boolean depressedButtons[5];

// OUTPUTS
#define PULLER_DIR 2
#define PULLER_STEP 3
#define CARRIAGE_DIR 4
#define CARRIAGE_STEP 5
#define STEPPERS_ENABLE 6
#define PUNCH_DOWN 9
#define PUNCH_UP 8

// PRINTING
#define CARRIAGE_STEP_PER_MM 100
#define PULLER_STEP_PER_MM 41.8 // 41.99 //42.30124578722308 // 43.07634877920 // 40.05344711049
#define FARTHEST_LEFT_POS 4.8 // distance from edge of paper to punch in the calibrated 0 position.
#define MAX_PAPER_WIDTH 65
#define CALIBRATION_FREQUENCY 300 // carriage will recalibrate position every this number of notes

// stepper acceleration
#define START_STEPPER_DELAY 2000 // slow start speed
#define MIN_STEPPER_DELAY 180 // max speed
#define ACCELERATION_TIME 400000 // microseconds to reach max speed

int printingFile = -1;
long carriageStepPos = 0;
unsigned long paperStepPos = 0;
int notesPunched = 0;
int numNotes;
int songNoteQuantity;
int marginWidth = 0;
int noteRangeWidth;
int paperLengthEstimate;


void setup() {
  Serial.begin(9600);
  
  lcd.begin(20,4);
  lcd.createChar(SYMBOL_RIGHTARROW, rightArrow);
  lcd.createChar(SYMBOL_DOWNARROW, downArrow);
  lcd.createChar(SYMBOL_PLAY, play);
  lcd.createChar(SYMBOL_PAUSE, pause);
  lcd.clear();
  lcd.backlight();
   
  while (!SD.begin(10)) {
    lcd.setCursor(2,1);
    lcd.print("INSERT SD CARD!!");
    lcd.setCursor(9,2);
    lcd.print(">:(");
    delay(100);
  }
  lcd.clear();

  root = SD.open("/");
  populateDirectory(root);

  drawDirectory();

 
  
}

void loop() {
  switch(currentMenu)
  {
    case 0: // DIRECTORY NAVIGATION
      if (buttonDown(UP_BUTTON))
      {
        currentFileSelection = max(currentFileSelection - 1, 0);
        drawDirectory();
      }
      if (buttonDown(DOWN_BUTTON))
      {
        currentFileSelection = min(currentFileSelection + 1, numFiles - 1);
        drawDirectory();
      }
      if (buttonDown(SELECT_BUTTON))
      {
        currentMenu = 1;
        debugFileRedout();
        readHeader();
        fileIsValid = isValidFile();
        drawSelectionMenu();
      }
    break;

    case 1: // SELECTION MENU
      if (buttonDown(DOWN_BUTTON))
      {
        currentMenu = 0;
        printingFile = -1;
        drawDirectory();
      }
      if (fileIsValid && buttonDown(SELECT_BUTTON))
      {
        currentMenu = 2;
        printPlayed();
        drawRunningMenu();
      }
      break;
      
    case 2: // RUNNING MENU
      if (buttonDown(SELECT_BUTTON))
      {
        currentMenu = 1;
        drawSelectionMenu();
      }
      else
      {
        printFile();
      }
      break;
  }
}

// ------------------------------------
// ----------- PRINTING ---------------

void printPlayed(){
  if (printingFile != currentFileSelection) // if first play, will already be set if this is a resume.
  {
    printingFile = currentFileSelection;
    notesPunched = 0;
    printCalibration();
    drawRunningMenu();
    selectFile();
  }
}

void printFile(){
  readNextCommand();
  drawProgress();
  
  if (key.equals("PUNCH NOTE"))
  {
    punchNote(val);
    notesPunched ++;
    if (notesPunched % CALIBRATION_FREQUENCY == 0)
    {
      carriageCalibrate();
    }
  }
  else if (key.equals("ADVANCE PAPER"))
  {
    pullPaper(val);
  }
  else if (key.equals("PROGRAM END"))
  {
    currentMenu = 0;
    printingFile = -1;
    drawDirectory();
  }
}


void punchNote(int noteIndex){
  long desiredStepPos = 1.0 * noteIndex / (numNotes - 1) * noteRangeWidth * CARRIAGE_STEP_PER_MM;
  stepMotorWithAcceleration(CARRIAGE_STEP, CARRIAGE_DIR, desiredStepPos - carriageStepPos);
  carriageStepPos = desiredStepPos;
  punch();
}

void pullPaper(long desiredPositionMicrometers){
  unsigned long desiredStepPos = desiredPositionMicrometers * PULLER_STEP_PER_MM / 1000;
  stepMotor(PULLER_STEP, PULLER_DIR, desiredStepPos - paperStepPos, 350);
  paperStepPos = desiredStepPos;
}



void printCalibration(){
  lcd.clear();
  lcd.setCursor(0,0);
  lcd.print("Calibrating!");

  pinMode(PULLER_DIR, OUTPUT);
  pinMode(PULLER_STEP, OUTPUT);
  pinMode(CARRIAGE_DIR, OUTPUT);
  pinMode(CARRIAGE_STEP, OUTPUT);
  pinMode(STEPPERS_ENABLE, OUTPUT);

  carriageCalibrate();
  paperStepPos = 0;

  pinMode(PUNCH_DOWN, OUTPUT);
  digitalWrite(PUNCH_DOWN, HIGH);
  pinMode(PUNCH_UP, OUTPUT);
  digitalWrite(PUNCH_UP, HIGH);
}

void carriageCalibrate()
{
  digitalWrite(STEPPERS_ENABLE, HIGH);

  while (!buttonDownState(LEFT_LIMIT)){
    stepMotor(CARRIAGE_STEP, CARRIAGE_DIR, -1, 250);
  }
  delay(500);
  while (buttonDownState(LEFT_LIMIT)){
    stepMotor(CARRIAGE_STEP, CARRIAGE_DIR, 1, 900);
  }
  delay(500);
  carriageStepPos = (FARTHEST_LEFT_POS  - marginWidth) * CARRIAGE_STEP_PER_MM; 
}


void stepMotor(int stepPin, int dirPin, int numSteps, int stepMicros){
  digitalWrite(dirPin, numSteps > 0);
  numSteps = abs(numSteps);
  for (int i = 0; i < numSteps; i++)
  {
    digitalWrite(stepPin, HIGH);
    delayMicroseconds(stepMicros);
    digitalWrite(stepPin, LOW);
    delayMicroseconds(stepMicros);
  }
}

void stepMotorWithAcceleration(int stepPin, int dirPin, int numSteps){
  digitalWrite(dirPin, numSteps > 0);
  numSteps = abs(numSteps);

  int stepMicros;
  int stepsToPeak = -1;
  long timeToPeak = -1;
  long dropStartTime = -1;
  long currentTime = 0;
  for (int i = 0; i < numSteps; i++)
  {
    if (stepsToPeak == -1) // going up
    {
      stepMicros = max(sinMap(currentTime, 0, ACCELERATION_TIME, START_STEPPER_DELAY, MIN_STEPPER_DELAY), MIN_STEPPER_DELAY);
      if (currentTime >= ACCELERATION_TIME || i >= numSteps / 2)
      {
        stepsToPeak = i;
        timeToPeak = currentTime;
      }
    }
    else if (i >= numSteps - stepsToPeak) // going down
    {
      if (dropStartTime == -1)
      {
        dropStartTime = currentTime;
      }
      stepMicros = max(sinMap(dropStartTime + timeToPeak - currentTime, 0, ACCELERATION_TIME, START_STEPPER_DELAY, MIN_STEPPER_DELAY), MIN_STEPPER_DELAY);
    }
    currentTime += stepMicros;
    digitalWrite(stepPin, HIGH);
    delayMicroseconds(stepMicros);
    digitalWrite(stepPin, LOW);
    delayMicroseconds(stepMicros);
  }
}

long sinMap(long x, long in_min, long in_max, long out_min, long out_max)
{
  return (out_max - out_min) * (1 - cos(PI * (x - in_min) / (in_max - in_min))) / 2.0 + out_min;
}

void punch(){
  digitalWrite(PUNCH_DOWN, LOW);
  digitalWrite(PUNCH_UP, HIGH);
  for (int i = 0; i < 1200; i++)
  {
    delay(1);
    if (buttonDownState(PUNCH_LIMIT))
    {
      break;
    }
  }
  digitalWrite(PUNCH_DOWN, HIGH);
  digitalWrite(PUNCH_UP, LOW);
  delay(1000);
  digitalWrite(PUNCH_DOWN, HIGH);
  digitalWrite(PUNCH_UP, HIGH);
}


// ------------------------------------
// ----------- RUNNING MENU -----------

void drawRunningMenu(){
  lcd.clear();
  lcd.setCursor(0,0);
  lcd.print(fileNames[currentFileSelection]);

  lcd.setCursor(15, 3);
  lcd.write(SYMBOL_PAUSE);
  lcd.print("paus");

  
  drawProgress();
}

void drawProgress(){
  lcd.setCursor(0,1);
  if (currentMenu == 1)
  {
    lcd.print("    PAUSED: ");
  }
  else if (currentMenu == 2)
  {
    lcd.print("  PRINTING: ");
  }
  lcd.print(notesPunched);
  lcd.print("/");
  lcd.print(songNoteQuantity);
  //lcd.print((String)((int)(100.0 * notesPunched / songNoteQuantity)));
  //lcd.print("%  ");
}

// ------------------------------------
// ----------- SELECTION MENU ---------

void drawSelectionMenu(){
  lcd.clear();
  lcd.setCursor(0,0);
  lcd.print(fileNames[currentFileSelection]);

  lcd.setCursor(4,3);
  lcd.write(SYMBOL_DOWNARROW);
  lcd.print("back");

  if (!fileIsValid)
  {
    lcd.setCursor(4, 1);
    lcd.print("Invalid file");
  }
  else if (marginWidth + noteRangeWidth > MAX_PAPER_WIDTH)
  {
    lcd.setCursor(4, 1);
    lcd.print("Paper width too wide"); 
  }
  else if (fileIsValid)
  {
    lcd.setCursor(15,3);
    lcd.write(SYMBOL_PLAY);
    lcd.print("play");

    lcd.setCursor(2, 1);
    lcd.print("MBox Notes: ");
    lcd.print(numNotes);
    lcd.setCursor(2, 2);
    lcd.print("Paper len: ");
    lcd.print(paperLengthEstimate);
  }
}


// ------------------------------------
// ----------- FILE READING -----------

void readHeader(){
  selectFile();
  while (readNextCommand())
  {
    if (key.equals("PROGRAM START"))
    {
      break;
    }
    else if (key.equals("NUM NOTES"))
    {
      numNotes = val;
    }
    else if (key.equals("MARGIN WIDTH"))
    {
      marginWidth = val;
    }
    else if (key.equals("NOTE RANGE WIDTH"))
    {
      noteRangeWidth = val;
    }
    else if (key.equals("SONG NOTE QUANTITY"))
    {
      songNoteQuantity = val;
    }
    else if (key.equals("PAPER LENGTH"))
    {
      paperLengthEstimate = val;
    }
  }
  file.close();
}

boolean isValidFile(){
  selectFile();
  while (readNextCommand())
  {
    if (key.equals("PROGRAM END"))
    {
      file.close();
      return true;
    }
  }
  file.close();
  return false;
}

boolean readNextCommand(){
  key = "";
  String stringVal = "";
  boolean seperatorFound = false;
  while (file.available()) {
    byte in = file.read();
    if (in == 58) // colon
    {
      seperatorFound = true;
    }
    else if (in == 13 or in == 10) // new line
    {
      if (file.peek() == 13 or file.peek() == 10) // why are there two!
      {
        file.read();
      }
      if (!seperatorFound)
      {
        // Newline but no colon
        return false;
      }
      val = stringVal.toInt();
      if (val == 0 && !stringVal.equals("0")) // toInt failed
      {
        return false;
      }
      return true;
    }
    else
    {
      if (seperatorFound)
      {
        stringVal = stringVal + (char)in;
        if (file.peek() == -1)
        {
          val = stringVal.toInt();
          if (val == 0 && !stringVal.equals("0")) // toInt failed
          {
            return false;
          }
          return true;
        }
      }
      else
      {
        key = key + (char)in;
      }
    }
  }
  return false;
}

void debugFileRedout(){
  // temp debug readout
  selectFile();
  while (readNextCommand()) {
    Serial.println(key + ": " + val);
  }
  file.close();
}
// ------------------------------------
// ----------- DIRECTORY MENU ---------

boolean buttonDownState(int pin){
  return analogRead(pin) < 500;
}

boolean buttonDown(int pin){
  if (buttonDownState(pin))
  {
    if (!depressedButtons[pin])
    {
      depressedButtons[pin] = true;
      delay(100);
      return true;
    }
  }
  else
  {
    depressedButtons[pin] = false;
  }
  return false;
}

void drawDirectory(){
  lcd.clear();
  windowPosition = constrain(windowPosition, currentFileSelection - 3, currentFileSelection);

  for (int index = windowPosition; index < windowPosition + 4; index++)
  {
    lcd.setCursor(2, index - windowPosition);
    lcd.print(fileNames[index]);
    if (index == currentFileSelection){
      lcd.setCursor(0, index - windowPosition);
      lcd.write(SYMBOL_RIGHTARROW);
    }
  }
}

void populateDirectory(File dir) {
  for (int index = 0; index < MAX_FILES; index ++)
  {
    File entry =  dir.openNextFile();
    if (! entry) {
      // no more files
      break;
    }
    
    if (!entry.isDirectory())
    {
      fileNames[index] = entry.name();
      numFiles++;
    }
    entry.close();
  }
}

void selectFile(){
  root.rewindDirectory();
  for (int index = 0; index < currentFileSelection; index ++)
  {
    file =  root.openNextFile();
    file.close();
  }
  file =  root.openNextFile();
}

