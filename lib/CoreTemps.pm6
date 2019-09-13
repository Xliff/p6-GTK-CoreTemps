use v6.c;

use Color;

use GTK::Compat::Types;
use GTK::Raw::Types;

use GDK::Threads;

use GTK::Application;
use GTK::Box;
use GTK::ProgressBar;
use GTK::Label;

constant minHue = 50;
constant maxHue = 310;

my (@pb, @l);

sub coreTemps {
  my $so = qx{sensors};
  my $m = $so ~~ m:g/^^ Core \s \d+\: \s* \+(\d+)/;
  $m.Array.map( *[0].Int );
}

sub updateTemps(@t) {
  GDK::Threads.add-idle(-> *@a --> gboolean {
    for @t.kv -> $k, $v {
      # cw: -YYY- Naked value!
      # This works well as a STUB because most procs have a TjMax of around
      # 100 deg C.
      @pb[$k].fraction = $v / 100;
      @l[$k].text = $v.fmt('%2d');
    }
    G_SOURCE_CONTINUE;
  });
}

sub MAIN (
  Int :$interval = 2      #= Interval between updates
)
  is export
{
  my @numCores = coreTemps;

  my $hues =
  (minHue, minHue + ((maxHue - minHue) / (+@numCores - 1)).Int ... maxHue );

  my $a = GTK::Application.new( title => 'org.genex.coreTemps' );

  $a.activate.tap({
    $a.wait-for-init;

    # cw; YYY - Take a reasonable portion of the screen with max of 300 pixels.
    #           Right now we use a static with of 300.
    $a.window.set-size-request(300, -1);
    $a.window.destroy-signal.tap({ $a.exit });

    my $vbox = GTK::Box.new-vbox;

    for @numCores {
      my $hbox = GTK::Box.new-hbox(2);
      @pb.push: GTK::ProgressBar.new;

      # cw: -YYY- Naked value!
      # This works well as a STUB because most procs have a TjMax of around
      # 100 deg C.
      @pb[* - 1].fraction = $_ / 100;

      # Use 2/3rds of the width. See YYY note above.
      @l.push: GTK::Label.new( .Str );
      @l[* - 1].text = .fmt('%2d');
      @l[* - 1].valign = GTK_ALIGN_END;
      @l[* - 1].margin-right = 10;

      $hbox.pack-start(@pb[* - 1], True);
      $hbox.pack-start(@l[* - 1]);
      $vbox.pack-start($hbox, True);
    }
    $vbox.margin-bottom = 20;

    $a.window.add($vbox);
    $a.window.show-all;

    $*SCHEDULER.cue({ updateTemps(coreTemps) }, every => $interval);
  });

  $a.run;
}
