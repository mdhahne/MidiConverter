import controlP5.*;

import java.io.File;

/*
Matthew Hahne
Last maintained: May 12 2017
matthewhahne@gmail.com
*/

/*********** OVERVIEW / GENERAL NOTES *********\

This is a pretty hacked together little bit of UI.
It's pretty functional, but the coding style leaves
a bit to be desired.
Expect internal inconsistencies, some oddly named
variables, and suboptimal code.

I'll do my best to to document it well enough to be
understood though. 

Before digging into this code, it would be very useful
to understand how midi files are structured and how
javax.sound.midi handles them.  I don't claim to have
an entirely solid understanding of them myself, just
enough to get this thing up and running, but there are
some tricky concepts regarding timing that are well 
explained by other people.  Here's a good place
to start:
https://docs.oracle.com/javase/tutorial/sound/MIDI-messages.html#understanding_time

The trickiest thing that goes on in here is the fact
that the horizontal position of notes is considered 
in many different contexts, and with different units:

1. Position within the song in terms of midi ticks.
2. Position within the song in terms of proportion
   of the song.
3. Position on the screen in terms of pixel coordinates.
4. Position within the song in terms of absolute
   real world distance (cm, mm, um, etc).



Notes start their life in midi as #1, the view of
the note paper (zoom / pan) is handeld in terms of #2,
from here notes are translated into #3 for display.

Then when exporting the notes to be punched
they go from #1 directly to #4.  

*/



/*********  GUI STUFF **********/
ControlP5 cp5;
RadioButton noteCountRadio;
Textlabel noteCountLabel;
Slider scrollPosSlider;
Slider lenScaleSlider;
Textfield channelField;
Textfield trackField;
Button updateSongButton;


PImage background;

color paperColor = color(255, 255, 240);
color warningBGColor = color(0);
color warningTextColor = color(255);
color lineColor = color(0, 100, 255, 150);
color bgColor = color(220, 190, 150);
color errorBarColor = color(255, 0, 0);
color rulerColor = color(230, 230, 220);
color markColor = color(0);
color markTextColor = color(0);

color controlFgColor = lineColor;
color controlBgColor = paperColor;
color controlActiveColor = color(0, 100, 255);
color controlTextColor = color(50, 50, 50);
color textFieldBgColor = color(127);

float mmMarkH; //mm marks are not implemented
float cmMarkH;
float mmMarkScale = 0.4;
float cmMarkScale = 0.8;
int mmMarkWeight = 2;
int cmMarkWeight = 3;
int minCMMarkDist;
int minMMMarkDist;
int markTextSize;
int textXPadding = 4;

int errorLineWeight;

final int MAX_MARKS = 20;

int textFieldHeight;

ArrayList<Textfield> notesList20 = new ArrayList<Textfield>(20);
ArrayList<Textfield> notesList30 = new ArrayList<Textfield>(30);

int gridXCount;
int gridYCount;

int guiXSpace;
int guiYSpace;

float h;
int w;
float noteVMargin;
float noteHMargin;

float rulerHeight;



/*this is the length of the song used in this program's
internal representation for display purposes.  
No matter how long your input song is, it will be
quantized into ten million chunks for display.  For 
very long songs, this may cause display issues, but not
issues with the output instructions. If this becomes a
problem, just add up to 2 zeros*/
final int LOCAL_SONG_LENGTH = 10000000;

//our zoom and pan
int viewSize = LOCAL_SONG_LENGTH;
int scrollPosition = 0;


/********* Song Settings ********/
int noteCount = 20;

Song s;

int noteArr20[] = {48, 50, 52, 53, 55, 57, 59, 60, 62, 
  64, 65, 67, 69, 71, 72, 74, 76, 77, 79, 81};

int noteArr30[] = {48, 50, 55, 57, 59, 60, 62, 64, 65, 
  66, 67, 68, 69, 70, 71, 72, 73, 74, 75, 76, 
  77, 78, 79, 80, 81, 82, 83, 84, 86, 88};


boolean fileReadSuccess = false;
File readFile = null;

/*This is the value that defines how much physical length
the song with take up, in terms of how many seconds
there are per cm of paper.  Calculated using the
BPM of the song, which is assumed to be 120bpm
(see "Song" class).*/
float scalePower = 4;
float scale = 0.5;
float maxSecondsPerCM = 5;
float minSecondsPerCM = 0.01;
float secondsPerCM = 0.4;

//notes closer than 7.8mm will not play properly
final float MIN_NOTE_DIST = 7.8;

boolean spacingErrors = false;
boolean spacingResolved = true;

int selectedTrack = 1;
int selectedChannel = 0;

//for the tuning text fields
int tfx1;
int tfx2;

void settings() {
  size(1000, 500); 
  //fullScreen(2);
}

void setup() {

  gridXCount = 50;
  gridYCount = 25;

  /*all positions are in terms of these, so that if the
  window size is changed things will still be reasonble*/
  guiXSpace = width/gridXCount;
  guiYSpace = height/gridYCount;

  textFieldHeight = (int)(guiYSpace * 0.8);

  //h is the height of the note paper
  h = height*0.8;
  w = width;

  rulerHeight = h*0.1;

  mmMarkH = rulerHeight * mmMarkScale;
  cmMarkH = rulerHeight * cmMarkScale;

  markTextSize = (int)(rulerHeight*0.3);

  minCMMarkDist = markTextSize;

  noteVMargin = h/20;
  noteHMargin = w/10;

  errorLineWeight = 5;

  tfx1 = (int)(guiXSpace*0.75);
  tfx2 = (int)(guiXSpace*2.5);

  PFont pfont = createFont("Arial", 15, true);
  ControlFont cFont = new ControlFont(pfont, 10);

  //***** now to set up the gui *******\\

  cp5 = new ControlP5(this);

  cp5.addTab("thirty");

  //make tab labels invisible
  cp5.getTab("thirty").setLabel("").setHeight(0);
  cp5.getTab("default").setLabel("").setHeight(0);

  //change all the theme colors
  cp5.setColorForeground(controlFgColor);
  cp5.setColorBackground(controlBgColor);
  cp5.setColorActive(controlActiveColor);
  cp5.setColorCaptionLabel(controlTextColor);

  scrollPosSlider = cp5.addSlider("scrollPosition")
    .setPosition(noteHMargin, h+rulerHeight)
    .setWidth((int)(w-noteHMargin))
    .setRange(255, 0) // values can range from big to small as well
    .setValue(128)
    .setSliderMode(Slider.FLEXIBLE)
    .moveTo("global")
    ;

  cp5.addButton("Restore_Defaults")
    .setPosition((int)(guiXSpace*0.7), guiYSpace*20)
    .setWidth(80).moveTo("global")
    .getCaptionLabel()
    .setText("Restore Defaults")
    .toUpperCase(false)
    .setFont(cFont);
  ;


  cp5.addButton("Load_MIDI")
    .setPosition(guiXSpace*6, guiYSpace*23)
    .moveTo("global")    .getCaptionLabel()
    .setText("Load MIDI")
    .toUpperCase(false)
    .setFont(cFont);
  ;

  cp5.addButton("Export_Song")
    .setPosition(guiXSpace*10, guiYSpace * 23)
    .moveTo("global")
    .getCaptionLabel()
    .setText("Export Song")
    .toUpperCase(false)
    .setFont(cFont);
  ;

  cp5.addButton("Resolve_Spacing")
    .setPosition(guiXSpace * 20, guiYSpace * 23)
    .setWidth(80).moveTo("global")
    .getCaptionLabel()
    .setText("Resolve Spacing")
    .toUpperCase(false)
    .setFont(cFont);
  ;

  noteCountRadio = cp5.addRadioButton("Note_Count")
    .setPosition(guiXSpace*0.7, guiYSpace*22)
    .setSize(20, 20).setItemsPerRow(2).setSpacingColumn(20)
    .addItem("20", 20).addItem("30", 30)
    .activate(0).moveTo("global")
    ;


  noteCountLabel = cp5.addTextlabel("noteCountLabel")
    .setText("Note Count:")
    .setPosition(guiXSpace*0.7, guiYSpace*21.3)
    .moveTo("global")
    .setColorBackground(controlTextColor)
    .setFont(cFont);
  ;

  noteCountLabel.setColor(controlTextColor);

  lenScaleSlider = cp5.addSlider("scale")
    .setPosition(guiXSpace*25, guiYSpace*23)
    .setWidth(200).moveTo("global")
    .setRange(0.1, 0.99)
    .setSliderMode(Slider.FLEXIBLE)
    ;

  lenScaleSlider.getCaptionLabel()
    .setText("Scale")
    .toUpperCase(false)
    .setFont(cFont)
    ;

  channelField = cp5.addTextfield("channel")
    .setPosition(guiXSpace*40, guiYSpace*23)
    .setWidth(30)
    .moveTo("global")
    .setValue("0")
    ;
  customizeTF(channelField);

  trackField = cp5.addTextfield("track")
    .setPosition(guiXSpace*43, guiYSpace*23)
    .setWidth(30)
    .moveTo("global")
    .setValue("1")
    ;
  customizeTF(trackField);


  updateSongButton = cp5.addButton("update")
    .setPosition(guiXSpace * 45, guiYSpace * 23)
    .setWidth(40).moveTo("global")
    ;
  updateSongButton.getCaptionLabel()
    .setText("Update")
    .toUpperCase(false)
    .setFont(cFont);


  //**** Make 20 note textFields *****\\
  for (int i = 0; i < 20; i++) {
    float x = i%2==0 ? tfx1+2 : tfx2;
    float y = map(i, 19, 0, noteVMargin, h-noteVMargin)-textFieldHeight/2;

    notesList20.add(cp5.addTextfield("n20-"+(20-i))
      .setPosition(x, y)
      .moveTo("default")
      .setCaptionLabel("")
      .setHeight(textFieldHeight)
      .setValue(numberToNote(noteArr20[i]))
      );

    customizeTF(notesList20.get(i));
  }

  //**** Make 30 note textFields *****\\
  for (int i = 0; i < 30; i++) {
    float x = i%2==0 ? tfx1+2 : tfx2;
    float y = map(i, 29, 0, noteVMargin, h-noteVMargin)-textFieldHeight/2;

    notesList30.add(cp5.addTextfield("n30-"+(30-i))
      .setPosition(x, y)
      .moveTo("thirty")
      .setCaptionLabel("")
      .setHeight(textFieldHeight)
      .setValue(numberToNote(noteArr30[i]))
      .setColor(controlBgColor)
      );

    customizeTF(notesList30.get(i));
  }

  try {
    background = loadImage("WoodPanel1.jpg");
    if (width > height) {
      background.resize(width, 0);
    } else {
      background.resize(0, height);
    }
  }
  catch(Exception e) {
    background = null;
  }
}

/*transpose was intended to allow for shifting all notes
an arbitrary number of half steps.  This was before we realized
that the music boxes do not come in arbitrary keys */
void initTextFields(int transpose) {
  //**** Make 20 note textFields *****\\
  for (int i = 0; i < 20; i++) {
    notesList20.get(i).setValue(numberToNote(noteArr20[i] + transpose));
  }

  //**** Make 30 note textFields *****\\
  for (int i = 0; i < 30; i++) {
    notesList30.get(i).setValue(numberToNote(noteArr30[i] + transpose));
  }
}

void customizeTF(Textfield tf) {
  tf.setColorBackground(textFieldBgColor);
  tf.setColorActive(controlBgColor);
  tf.setWidth((int)(guiXSpace*1.2));
  tf.setHeight(textFieldHeight);
}


void draw() {
  background(bgColor);
  if (background != null) {
    image(background, 0, 0);
  }
  //if we've read the file or just need to re-load the song
  if (fileReadSuccess) {

    s = new Song(selectedTrack, selectedChannel);
    if (s.ReadMidi(readFile)) {
    } else {
      println("MIDI file must be in PPQ timing");
    }

    fileReadSuccess = false;
  }

  /*if we are in the process of automatically re-scaling
  the song*/
  if (!spacingResolved) {
    if (spacingErrors && scale <= 0.99) {
      lenScaleSlider.setValue(lenScaleSlider.getValue() + 0.01);
    } else {
      spacingResolved = true;
    }
  }
  
  /*set the actual scaling based on the slider input
  exponent used to get the range nice */
  secondsPerCM = map(pow((1-scale), scalePower), 0, 1, minSecondsPerCM, maxSecondsPerCM);

  displayNotePaper();
  displayNotes(s);
  displayRuler();
  checkNoteFields();
  checkSettingsFields();
}

/*show the blank paper with lines according to
number of notes selected */
void displayNotePaper() {
  pushStyle();
  fill(paperColor);
  rect(noteHMargin, 0, w, h);

  strokeWeight(3);
  stroke(lineColor);
  for (int i = 0; i < noteCount; i++) {
    float y = map(i, 0, noteCount-1, noteVMargin, h-noteVMargin);
    line(noteHMargin, y, width, y);

    pushStyle();
    stroke(1);
    float x1 = i%2==0 ? tfx2+5 : tfx1+5;
    line(x1, y, noteHMargin, y);
    popStyle();
  }
  popStyle();
}


void displayNotes(Song s) {
  spacingErrors = false;
  if (s != null) {
    for (Note n : s.getNotes()) {
      displayNote(n);
    }
  } else {
    pushStyle();
    textAlign(CENTER);
    rectMode(CENTER);
    fill(warningBGColor);
    rect(width/2, h/2 - 5, 125, 20);
    fill(warningTextColor);
    text("NO SONG LOADED", width/2, h/2);
    popStyle();
  }
}

void displayNote(Note n) {
  float tps = s.getTicksPerSec();
  float tpcm = secondsPerCM * tps;
  float tpmm = tpcm/10;
  float mmpt = 1/tpmm;

  pushStyle();
  String curNote = numberToNote(n.getK());
  
  //Which line does this note belong on?
  int curNoteIndex = searchNoteList(curNote);
  
  
  /*get position of note in terms of proportion of song length, so that
  it's in the same terms as the zoom / pan info */
  float songX = map(n.getT(), 0, s.getTickLength(), 0, LOCAL_SONG_LENGTH);

  //if note is visible on screen
  if (songX >= scrollPosition && songX < scrollPosition + viewSize)
  {
    //get note into pixel position on screen
    float x = map(songX, scrollPosition, scrollPosition + viewSize, noteHMargin, width);

    if (curNoteIndex != -1) {
      float y = map(curNoteIndex, 0, noteCount-1, noteVMargin, h-noteVMargin);

      fill(0);
      ellipse(x, y, 10, 10);

      //check for minimum cleareance with other notes
      for (Note otherN : s.getNotes()) {
        if (otherN != n && otherN.getK() == n.getK()) {

          float otherMMPos = otherN.getT() * mmpt;
          float mmPos = n.getT() * mmpt;
          
          if (abs(otherMMPos - mmPos) < MIN_NOTE_DIST) {
            spacingErrors = true;

            float otherSongX = map(otherN.getT(), 0, s.getTickLength(), 0, LOCAL_SONG_LENGTH);
            float otherX = map(otherSongX, scrollPosition, scrollPosition + viewSize, noteHMargin, width);

            pushStyle();
            fill(errorBarColor);
            stroke(errorBarColor);
            ellipse(x, y, 10, 10);
            strokeWeight(errorLineWeight);
            if (otherSongX < scrollPosition) {
              line(noteHMargin + (errorLineWeight/2), y, x, y);
            } else if (otherSongX > scrollPosition + viewSize) {
              line(width, y, x, y);
            } else {
              line(otherX, y, x, y);
            }
            popStyle();
          }
        }
      }
    } else { //if (note index == -1), display and label error bar
      stroke(errorBarColor);
      strokeWeight(errorLineWeight);
      line(x, 0, x, h);
      fill(errorBarColor);
      text(curNote, x + textXPadding, 15);
    }
  }
  popStyle();
}


void displayRuler() {
  pushStyle();
  fill(rulerColor);
  rect(noteHMargin, h, width-noteHMargin, rulerHeight);
  popStyle();

  if (s != null) {
    ArrayList<Mark> marks = new ArrayList<Mark>();
    float tps = s.getTicksPerSec();
    float tpcm = secondsPerCM * tps;
    float tpmm = tpcm/10;
    //float mmpt = 1/tpmm;

    //populate list with a mark each centimeter
    for (int i = 0; i<s.getTickLength()/tpcm; i++) {
      float songX = map(i*tpcm, 0, s.getTickLength(), 0, LOCAL_SONG_LENGTH);
      marks.add(new Mark((int)(i*tpcm), i, songX));
    }

    //cull list of visible marks down to not overcrowd the ruler
    int visibleCount = 0;
    do {
      if (visibleCount > MAX_MARKS) {
        for (int i = 1; i < marks.size(); i++) {
          marks.remove(i);
        }
      }
      visibleCount = 0;
      for (Mark m : marks) {
        if (m.screenX > scrollPosition && m.screenX < scrollPosition + viewSize) {
          visibleCount++;
        }
      }
    } while (visibleCount > MAX_MARKS);

    pushStyle();
    stroke(markColor);
    textAlign(LEFT, BOTTOM);
    fill(markTextColor);
    textSize(markTextSize);

    //display marks
    for (Mark m : marks) {
      if (m.screenX > scrollPosition && m.screenX < scrollPosition + viewSize)
      {
        float x = map(m.screenX, scrollPosition, scrollPosition + viewSize, noteHMargin, width);
        m.screenX = x;
        line(m.screenX, h, m.screenX, h+cmMarkH);
        text(m.songPosCM, m.screenX + textXPadding, h+cmMarkH);
      }
    }

    popStyle();
  }
}

/* check to see that we have valid input on the text
fields defining the tuning of the music box*/
void checkNoteFields() {
  String temp;
  for (Textfield tf : notesList20) {
    temp = tf.getText().trim().toUpperCase();
    if (!(temp.matches("[ACDFG]#?-[0-9][0-9]?") || temp.matches("[BE]-[0-9][0-9]?")) && !tf.isActive()) {
      tf.setText("");
    } else {
      tf.setText(tf.getText().toUpperCase());
    }
  }
  for (Textfield tf : notesList30) {
    temp = tf.getText().trim().toUpperCase();
    if (!(temp.matches("[ACDFG]#?-[0-9][0-9]?") || temp.matches("[BE]-[0-9][0-9]?")) && !tf.isActive()) {
      tf.setText("");
    } else {
      tf.setText(tf.getText().toUpperCase());
    }
  }
}

/* check to see that we have valid input on the text
fields defining the channel and track of the midi file*/
void checkSettingsFields() {
  String temp;
  temp = channelField.getText().trim().toUpperCase();
  if (!temp.matches("[0-9]+") && !channelField.isActive()) {
    channelField.setText("");
  } else {
    channelField.setText(temp);
  }

  temp = trackField.getText().trim().toUpperCase();
  if (!temp.matches("[0-9]+") && !trackField.isActive()) {
    trackField.setText("");
  } else {
    trackField.setText(temp);
  }
}


//searches active note list for given note
//returns index of note, or -1 if not present
int searchNoteList(String searchNote) {
  int result = -1;
  ArrayList<Textfield> list = null;

  //default to 20, set to others if needed
  list = notesList20;

  if (noteCount == 30) {
    list = notesList30;
  }

  for (int i = 0; i < list.size(); i++) {
    if ( list.get(i).getText().equals(searchNote)) {
      result = noteCount - i - 1;
    }
  }
  return result;
}


void mouseWheel(MouseEvent event) {
  float e = event.getCount();
  changeZoom(e);
}

int dragStartX = 0;
int startPos = 0;
int startViewSize = 0;
boolean validScroll = true;

void mousePressed() {
  if (mouseButton == LEFT && mouseX > noteHMargin && mouseX < width && mouseY < h) {
    validScroll = true;
    dragStartX = mouseX;
    startPos = scrollPosition;
  } else if (mouseButton == RIGHT && mouseX > noteHMargin && mouseX < width && mouseY < h) {
    validScroll = true;
    dragStartX = mouseX;
    startViewSize = viewSize;
  } else {
    validScroll = false;
  }
}

void mouseDragged() {
  if (mouseButton == LEFT && validScroll) {
    scrollPosition = startPos + (int)map(dragStartX - mouseX, 0, width-noteHMargin, 0, viewSize);
    scrollPosSlider.setValue(scrollPosition);
  }
  if (mouseButton == RIGHT && validScroll) {
    setZoom(startViewSize + (int)map(dragStartX - mouseX, 0, width-noteHMargin, 0, LOCAL_SONG_LENGTH));
    scrollPosSlider.setRange(0, LOCAL_SONG_LENGTH - viewSize);
  }
}

void changeZoom(float in) {
  float d = log(viewSize) * in * 1000;
  if (viewSize + d > 100 && viewSize + d < LOCAL_SONG_LENGTH) {
    viewSize += d;
    scrollPosSlider.setRange(0, LOCAL_SONG_LENGTH - viewSize);
  }
}

void setZoom(float in) {
  if (in > 100 && in < LOCAL_SONG_LENGTH) {
    viewSize = (int)in;
    scrollPosSlider.setRange(0, LOCAL_SONG_LENGTH - viewSize);
  }
}


String numberToNote(int num) {
  Note n = new Note(num);
  return n.getNoteName() + "-" + n.getOctave();
}


/******** GUI / File IO callbacks *********/
public void Restore_Defaults(int i) {
  initTextFields(0);
}

public void Load_MIDI(int i) {
  selectInput("Select a midi file: ", "inputFileSelected");
}

public void Export_Song(int i) {
  if (s != null) {
    selectOutput("Select an output file name: ", "outputFileSelected");
  }
}

public void Resolve_Spacing(int i) {
  spacingResolved = false;
}

public void update(int i) {
  if (s!= null) {
    selectedChannel = (Integer.parseInt(channelField.getText()));
    selectedTrack = (Integer.parseInt(trackField.getText()));
    fileReadSuccess = true;
  }
}

/* save the song to a text file for punching! 
The note is communicated with an index from 0-19 for
20 note boxes, 0-29 for 30 note boxes.  Timing 
information is given in micrometers of paper.

The text file is formatted as a series


PUNCH NOTE: <note number>
ADVANCE PAPER: <distance in micrometers>


*/
void outputFileSelected(File selection) {
  ArrayList<String> output = new ArrayList<String>();

  float tps = s.getTicksPerSec();  //ticks per second
  float tpcm = secondsPerCM * tps;  //ticks per centimeter
  float tpmicm = tpcm/10000;        //ticks per micrometer
  float micmpt = 1/tpmicm;         //micrometers per tick

  //estimate of the cm of lead in paper needed by the punch
  float leadInDist = 15;
  float paperLength = s.getTickLength()/tpcm + leadInDist;

  //write header
  output.add("NUM NOTES:" + noteCount);
  output.add("MARGIN WIDTH:"+ (noteCount == 20 ? "6" : "6"));
  output.add("NOTE RANGE WIDTH:" + (noteCount == 20 ? "58" : "58"));
  output.add("SONG NOTE QUANTITY:" + s.getNotes().size());
  output.add("PAPER LENGTH:" + paperLength);
  output.add("PROGRAM START:0");

  float initPosition = s.getNotes().get(0).getT() * micmpt;
  float paperPosition = initPosition;
  for (Note n : s.getNotes()) {
    int index = searchNoteList(numberToNote(n.getK()));
    float notePos = (int)(n.getT() * micmpt);
    println(notePos);
    if (index != -1) {
      if (paperPosition != notePos) {
        int pos = (int)(notePos - initPosition);
        output.add("ADVANCE PAPER:" + (pos > 0 ? pos : 0));
        paperPosition = notePos;
      }
      output.add("PUNCH NOTE:" + (noteCount - index - 1));
    }
  }

  output.add("PROGRAM END:0");

  String[] outArr = output.toArray(new String[0]);

  saveStrings(selection.getAbsoluteFile() + ".txt", outArr);
}


void inputFileSelected(File selection) {
  if (selection == null) {
    println("error with the file business");
  } else {

    //extract file extension
    String ext = "";
    int i = selection.getAbsolutePath().lastIndexOf('.');
    if (i >= 0) {
      ext = selection.getAbsolutePath().substring(i+1);
    }

    if (ext.equals("mid") || ext.equals("midi") ||
      ext.equals("MID") || ext.equals("MIDI") ) {

      fileReadSuccess = true;
      readFile = selection;
    } else {
      println("that's not midi");
    }
  }
}

void controlEvent(ControlEvent e) {
  if (e.isFrom(noteCountRadio)) {
    noteCount = (int)noteCountRadio.getValue();
    if (noteCount == 20) {
      cp5.getTab("default").setActive(true);
      cp5.getTab("thirty").setActive(false);
    } else if (noteCount == 30) {
      cp5.getTab("thirty").setActive(true);
      cp5.getTab("default").setActive(false);
    }
  }
}