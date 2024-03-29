use v6.c;

use Color;

use GTK::Compat::Types;
use GTK::Raw::Types;

use GDK::Threads;

use GTK::Application;
use GTK::Box;
use GTK::CSSProvider;
use GTK::ProgressBar;
use GTK::Label;

constant minHue = 50;
constant maxHue = 310;

my (@pb, @l);

my %labels;

my $cssStyle;

my $temp-dir = "/sys/bus/platform/drivers/coretemp/coretemp.0/hwmon/hwmon0".IO;
my @tf = $temp-dir.dir( test => *.Str.ends-with('_input') );

sub coreTemps {
  my @temps;
  # This will eventually be abstracted out into a detection routine.

  when $temp-dir.d {
    @temps = do gather for @tf {
      my @parts = .Str.split('_');

      # Remove label code to its own routine that gets called FIRST!
      # ...or they can be removed.
      #
      # Consider letting the user make this decision via config?
      #
      # when ( @parts[1] eq 'label', %labels{ @parts[0] }:exists ).all {
      # }
      #
      # when @parts[1] eq 'label' {
      #   %label{ @parts[0] } = .IO.slurp.chomp;
      # }
      #
      # when @parts[1] eq <max crit crit_alarm>.any {
      # }

      when @parts[1] eq 'input' {
        # The divider may not always be 1000. This will need to be abstracted
        # if more chips are added!
        take Pair.new(@parts[0], .IO.slurp.chomp.Int / 1000);
      }

      default {
        warn "Don't know how to handle the '{ .IO.absolute }' file";
      }
    };

    # Don't take the package temp.
    @temps .= skip(1).sort( *.key ).map( *.value );
  }

  default {
    my $so = qx{sensors};
    my $m = $so ~~ m:g/^^ Core \s \d+\: \s* \+(\d+)/;
    $m.Array.map( *[0].Int );
  }
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

sub styleBar($n, $b, $l) {
  my $c = Color.new( hsv => (@*hues[$n - 1], 50, 100) );

  $b.name = 'progress'     ~ $n.fmt('%02d');
  $l.name = 'progresLabel' ~ $n.fmt('%02d');
  $cssStyle ~= qq:to/BAR/;
    #{$l.name} \{
      color: white;
      font-weight: bold;
      text-shadow: 1px 1px black;
    \}
    #{$b.name} trough, #{$b.name} trough progress\{
      min-height: 20px;
    \}
    #{$b.name} trough progress \{
      background-color: { $c.to-string('hex') }
    \}
    BAR

}


sub MAIN (
  Int :$interval = 2      #= Interval between updates
)
  is export
{
  my @numCores = coreTemps;

  die 'No core temperatures found. Please check that lm-sensors is setup correctly!'
    unless @numCores;

  my @*hues =
    (minHue, minHue + ((maxHue - minHue) / (+@numCores - 1)).Int ... maxHue );

  my $a = GTK::Application.new( title => 'org.genex.coreTemps' );

  $a.activate.tap({
    $a.wait-for-init;

    # cw; YYY - Take a reasonable portion of the screen with max of 300 pixels.
    #           Right now we use a static with of 300.
    $a.window.set-size-request(300, -1);
    $a.window.destroy-signal.tap({ $a.exit });

    my $vbox = GTK::Box.new-vbox(5);

    for @numCores {
      my $hbox = GTK::Box.new-hbox(2);

      @pb.push: (my $pb = GTK::ProgressBar.new   );
      @l.push:  (my $l  = GTK::Label.new( .Str ) );
      # cw: -YYY- Naked value!
      # This works well as a STUB because most procs have a TjMax of around
      # 100 deg C.
      $pb.fraction = $_ / 100;

      $l.text = .fmt('%2d');
      $l.valign = GTK_ALIGN_END;
      $l.margin-right = 10;

      styleBar( @pb.elems, $pb, $l);

      $hbox.pack-start($pb, True);
      $hbox.pack-start($l);
      $vbox.pack-start($hbox, True);
    }
    ($vbox.margin-top, $vbox.margin-bottom) = 20 xx 2;

    my $css = GTK::CSSProvider.new( style => $cssStyle );

    my $out-focus;
    sub setOutFocus {
      $out-focus = $*SCHEDULER.cue(in => 5, {
        GDK::Threads.add-idle(-> *@a --> gboolean {
          $a.window.decorated = False;
          $out-focus = Nil;
          G_SOURCE_REMOVE;
        });
      });
    }

    $a.window.enter-notify-event.tap(-> *@a {
      $out-focus.cancel if $out-focus;
      $a.window.decorated = True;
      @a[* - 1].r = 1;
    });
    $a.window.leave-notify-event.tap(-> *@a {
      setOutFocus;
      @a[* - 1].r = 1;
    });

    $a.window.app-paintable = True;
    $a.window.visual = $a.window.screen.get-rgba-visual;
    $a.window.add($vbox);
    $a.window.show-all;

    $*SCHEDULER.cue({ updateTemps(coreTemps) }, every => $interval);
  });

  $a.run;
}
