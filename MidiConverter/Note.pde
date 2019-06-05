/*This class mostly just serves as a storage
structure for the information on a note, but
there is a little bit of handy functionality
built in as well */

public class Note implements Comparable {
  private int k; //key. 12 note scale, starting from 0 == C
  private long t; //tick. The timing of this note

  Note() {
    k = 0; 
    t = 0;
  }

  Note(int inK) {
    k = inK;
  }

  public void setK(int in) {
    k = in;
  }
  public int getK() {
    return k;
  }
  public void setT(long in) {
    t = in;
  }
  public long getT() {
    return t;
  }

  public int getNote() {
    return k % 12;
  }

  public String getNoteName() {
    String n = "";
    switch(k%12) {
    case 0:
      n="C";
      break;
    case 1:
      n="C#";
      break;
    case 2:
      n="D";
      break;
    case 3:
      n="D#";
      break;
    case 4:
      n="E";
      break;
    case 5:
      n="F";
      break;
    case 6:
      n="F#";
      break;
    case 7:
      n="G";
      break;
    case 8:
      n="G#";
      break;
    case 9:
      n="A";
      break;
    case 10:
      n="A#";
      break;
    case 11:
      n="B";
      break;
    }
    return n;
  }

  public int getOctave() {
    return (k / 12);
  }


  public int compareTo(Object comp) {
    long compareTime = ((Note)comp).getT();
    int compareKey = ((Note)comp).getK();

    int output = 0;

    if (this.t < compareTime)
      output = -1;
    else if (this.t > compareTime)
      output = 1;
    else {
      if (this.k < compareKey)
        output = -1;
      if (this.k > compareKey)
        output = 1;
    }

    return output;
  }
}