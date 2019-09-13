# p6-GTK-coreTemps

![Screenshot](grabs/CoreTemps.png?raw=true "CoreTemps Screenshot")

## Installation

Make a directory to contain the p6-Gtk-based projects. Once made, then set the P6_GTK_HOME environment variable to that directory:

```
$ export P6_GTK_HOME=/path/to/projects
```

Switch to that directory and clone both p6-GtkPlus and p6-WebkitGTK

```
$ git clone https://github.com/Xliff/p6-Pango.git
$ git clone https://github.com/Xliff/p6-GtkPlus.git
$ git clone https://github.com/Xliff/p6-GTK-CoreTemps.git
$ cd p6-GtkPlus
$ zef install --deps-only .
```

Then run the script by:

```
cd ../p6-GTK-CoreTemps
./p6gtkexec -Ilib coretemps.pl6
```

If you have any comments, suggestions or errors. Please feel free and open
an issue using the Github ticketing system for this project.
