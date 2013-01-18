Tankwars
========

Tankwars is a silly tank combat game for two players at a single keyboard. It
was my final project for my high school programming class in Pascal, before
the spread of consumer internet access, and my first program over 1000 lines.
From the good old days where if you want to play (or write) a video game 
you had to sneak it in during class time because that was
where the computers were...

This is essentially just an archival copy of the code, and unfortunately
not even the final version, which seems lost. The final version included 
a map editor and many maps, while this one appears to have a single harcoded
map.

I have been unable to build it; it uses the obsolete `graph` library
and also imports `dos` functions. I cannot yet be bothered to port it to
modern libraries. Since it was written with Borland Turbo Pascal,
it seems likely that within a couple hours it could
be built with [FreePascal](http://www.freepascal.org/).

On a DOS system with the graph unit working, it should be as simple as:

    $ fpc tankwars.pas

Note: [GNU Pascal](http://www.gnu-pascal.de/gpc/h-index.html) aims to 
be a portable POSIX-based Pascal compiler, which may require more 
porting work.


Playing
-------

Your tanks treads can rotate freely and independently of the turret; you will
need both hands and some coordination to play. Your tank can fire bullets
that bounce off the walls or special weapons, which you can pick up as they
appear.

The precise controls will be shown to you before starting (this is hardcoded behavior)
but I have reproduced the output here. You will need a keyboard with a number pad,
and it is up to the honor system that you do not reach over and mess with your
opponents keys.

```turbopascal
PROCEDURE DemoControls;
begin
   writeln( '                    PURPLE TANK  |  GREEN TANK  ' );
   writeln( 'Gun:                                            ' );
   writeln( '   left:                 H              4       ' );
   writeln( '   right:                K              6       ' );
   writeln( '   fire:                 J              5       ' );
   writeln( '   special weapon:       U              8       ' );
   writeln( '   change weapon:      space            0       ' );
   writeln;
   writeln( 'Treads:                                         ' );
   writeln( '   left:                 D            left      ' );
   writeln( '   right:                G            right     ' );
   writeln( '   speed up:             R             up       ' );
   writeln( '   speed down:           F            down      ' );
   writeln;
   writeln( 'Quit:                          esc              ' );
   writeln;
   writeln( '   (treads will go other way after excessive    ' );
   writeln( '   speed down, then speed controls are reversed)' );
   writeln;
   writeln;
end;
```


Copyright and License
---------------------

Copyright 2012- Kenneth Knowles

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
