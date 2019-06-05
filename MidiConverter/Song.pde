/* This class handles reading a midi file and
extracting the note information, then storing
that note information internally in an arraylist
of Note objects for the rest of the program to
access conveniently*/

import javax.sound.midi.*;
import java.util.*;

public class Song {
  ArrayList<Note> notes;
  private int track;
  private int channel;

  float divType;
  int resolution;
  long lengthInTicks = 0;
  
  //we assume a tempo of 120bpm for all songs
  int tempo = 120;

  Song(int t, int c) {
    notes = new ArrayList<Note>();
    track = t;
    channel = c;
  }

  public void setTrack(int in) {
    track = in;
  }
  public void setChannel(int in) {
    channel = in;
  }
  public ArrayList<Note> getNotes() {
    return notes;
  }

  public long getLastNoteTime() {
    long out = 0;
    if (notes != null && notes.size() > 0) {
      out = notes.get(notes.size() - 1).getT();
    }
    return out;
  }

  public float getTicksPerSec() {
    return resolution * (tempo / 60.0);
  }

  public int getResolution() {
    return resolution;
  }

  public long getTickLength() {
    return lengthInTicks;
  }


  public boolean ReadMidi(File midFile) {
    boolean output = true;
    try {
      Sequence seq = MidiSystem.getSequence(midFile);
      Track curTrack = seq.getTracks()[track];

      divType = seq.getDivisionType();
      if (divType != Sequence.PPQ) {
        output = false;
        return output;
      }

      resolution = seq.getResolution();
      lengthInTicks = seq.getTickLength();

      for (int i = 0; i < curTrack.size(); i++) {
        Note newNote = new Note();
        MidiEvent event = curTrack.get(i);
        newNote.setT(event.getTick());
        MidiMessage message = event.getMessage();

        if (message instanceof ShortMessage) {
          ShortMessage sm = (ShortMessage) message;

          if (sm.getCommand() == ShortMessage.NOTE_ON && sm.getChannel() == channel) {
            newNote.setK(sm.getData1());
            notes.add(newNote);
          }
        } else {
          println("Unexpected message type: " + message.getClass());
        }
      }
    }
    catch(Exception e) {
      println("ReadMidi broke");
      output = false;
    }

    Collections.sort(notes);

    //remove duplicate notes
    ArrayList<Note> uniqueNotes = new ArrayList<Note>();
    for (Note n : notes) {
      if(!containsDuplicate(uniqueNotes,n)){
         uniqueNotes.add(n);
      }
    }
    notes = uniqueNotes;

    return output;
  }

  public void printNotes() {
    for (Note n : notes) {
      println(n.getK() + ", " + n.getNoteName() + "|" + n.getOctave() + ", " + n.getT());
    }
  }
}

private boolean containsDuplicate(ArrayList<Note> list, Note n) {
  boolean output = false;

  for (Note note : list) {
    if (note.k == n.k && note.t == n.t) {
      return true;
    }
  }

  return output;
}