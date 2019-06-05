*********** MIDI Converter Instructions **************

First, select the correct number of notes for
your music box using the "Note Count" buttons.
Currently the only supported boxes are the Grand
Illusions 20 and 30 note models.  However models
with fewer notes could be used, just manually enter
the notes of your box, and leave all the other spaces
blank. This feature can also be used if you've customized
the tuning of your music box.

Next, hit "Load Midi".  Choose your MIDI file and
look at the note paper display to check for correctness.

Use the "Channel" and "Track" inputs to select the midi
channel and track you want to view, and hit "Update" to
submit these inputs.

You can zoom the view with your scroll wheel or by right
clicking and dragging horizontally.  When zoomed in, you
can pan the display by left clicking and dragging the
display, or by dragging the scroll bar at the bottom of
the display.

A red vertical bar will show everywhere there is a note
in the MIDI file that is not on your music box, with a label
at the top showing the troublesome note.

The Grand Illusions 30 note music box has a limit of 7.75mm
between holes for repeated notes, any closer and the first
note will not play.  We assumed this was true of all paper
punch boxes, and built in detection for this spacing.  Notes
that are too close to other notes will be shown in red, with
a red bar connecting the pair.  To automatically scale the
song such that all visible notes will be spaced safely, 
press "Resolve Spacing".  You can also manually adjust the spacing
of the notes with the "Scale" slider.  Note that the automatic
spacing feature will scale the entire song, but will only
check the notes in view for spacing errors.  To check the whole
song, just zoom all the way out.
This can be used to your advantage if you don't care about
certain notes repeating correctly.  Just zoom and pan so that
you're viewing the closest notes you care about, and
press "Resolve Spacing".

The ruler display at the bottom of the note paper shows 
centimeters. Note how this changes as you scale the song.

If the scale adjustment range is insufficient for your song, 
try changing the bpm of your midi file.

When you are happy with your notes, hit "Export Song" to save
the file in the proper format for the Arduino to read.  A ".txt"
suffix will be appended regardless of what you call the file, so
leave if off when you enter the name, otherwise you'll get
"name.txt.txt".


**************** KNOWN BUGS with MIDI converter **************

1. Occasionally, adjusting the song scale will not effect the
song scale at all, and will instead change the position of the
scale slider itself.  When this happens, pressing the "Resolve
Spacing" button will "zoom out" the entire display within the
window.  These behaviors have no relation to the song scale 
that we know of, so this is a very perplexing bug.  For us,
restarting the program has always solved this problem.


********************* Text File Format ***********************

The command text file is a series of commands for the puncher
to execute.  There is a required header with general information
the puncher needs.  The header also has an estimate of the
length of paper that will be needed.  The header is ended by a 

PROGRAM START:0

From here, there are two commands that can be issued:

ADVANCE PAPER:<advancement length in micrometers>

PUNCH NOTE:<note index to punch, starting from 0>

Any number of these commands can be issued in any order to punch
the full song, then after the final note the song is ended with a

PROGRAM END:0

command



