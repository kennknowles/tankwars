{$r+}
PROGRAM Tankwars;
{Written by Kenn Knowles "RazorHair[TLK]"
co-tested with Sebastian Ligeti "Felix[TLK]" during
a second semester AP computer class}

{
Useful definitions:
Item = Items on battlefield to be collected by Tanks
Weap = any item that is triggered by the Tanks' special
Weapon button
bottom = display bar at bottom of screen
wall = any of a variety of bar shaped structures with
varying visibility and permeability


note:i have removed all "efficient" code for only refreshing when
necessary, because, heck, are you joking? this game is not processor
intense
}


USES crt, graph, dos, drivers;

CONST 
   pi =  3.1415926535897932385;
   TotMaxShots = 400;
   maxbounces = 5;  {3}
   maxwraps = 2;    {2}
   speed : longint = 5; {5}
   exringsize = 10;
   rotsteps = 20;  {20}
   fuselength = 20;
   shieldlength = 100;
   invislength = 200;
   shotIncrease = 4;
   MaxWeap = 99;
   MaxSpeed = 6;
   MinSpeed = -MaxSpeed;
   shotmag = 9;       {7}
   rotconst = round( 360 / rotsteps ); {360/rotsteps}
   
{ foreground and background colors }
   BLACK        = 0;
   BLUE         = 1;
   GREEN        = 2;
   CYAN         = 3;
   RED          = 4;
   MAGENTA      = 5;
   BROWN        = 6;
   LIGHTGRAY    = 7;
   
{ foreground colors }
   DARKGRAY     = 8;
   LIGHTBLUE    = 9;
   LIGHTGREEN   = 10;
   LIGHTCYAN    = 11;
   LIGHTRED     = 12;
   LIGHTMAGENTA = 13;
   YELLOW       = 14;
   WHITE        = 15;

TYPE
   ShotEdgeType = (kill, bounce, wrap);
   HitType = (side, top, nohit, inwall);  {inwall : occasionally shots
                                          from the tip of the barrel
                                          start inside a wall,
                                          this takes special treatment}
   WallVisType = (invis, outline, norm, cloud);
   ItemType =  (none, explosion, tripleshot, allshot, missile, bomb, mine,
                proxy, teleport, HeavyGun, shield, invisible,
                health, shotup );
   WeapType = none..HeavyGun;
   ShotWallType = kill..bounce;    {possible events when a shot hitsa wall}
   AngleType = 0..359;

{-- Record types --}
   
CoordType = record
               x,
               y :integer;
            end;
   
SpecType = record
              x{horizontal radius},
              y{vertical radius} : integer
           end;
   
VectorType = record
                mag : real;
                dir: AngleType;
             end;

ItemRectype = record       {for items on playing field, before they are
                           collected}
                 removed : boolean;  {if one has just been removed}
                 old,loc: CoordType;
                 size: SpecType;
                 Weap: itemtype;        {what type of Weapon the item gives}
              end;

WeapRecType = record  {for special Weapons}
                 move,
                 old,
                 hyp,
                 loc : CoordType;
                 
                 JustShot,
                 Removed : boolean;
                    
                 smudge,
                 size : SpecType;

                 ex : record
                         width,           {width of explosion in rings}
                         count,           {counter for how much it has exploded so far}
                         dam : longint;   {damage per ring of explosion}
                      end; {record}

                 source : byte;
                 count2,
                 counter : integer; {miscelaneous counter in case the item
                                    needs one}

                 kind : WeapType;   {what type of special Weapon it is}

                 vec : VectorType;
              end;

VidType = record
             MaxX,
             MinY,
             MaxY,
             MaxFightY,
             TextCols,
             TextRows : longint;
          end;
   
TankCounterType = record
                     shield,
                     invis,
                     life : integer;
                     hit,
                     shots,
                     Weapons : byte;
                  end;
   
Shottype = record
              move,
              old,
              hyp,
              loc : CoordType;
              
              source,   {that shot it, for keeping track of max shots allowed}
              
              wraps,             {how many times it has wrapped around screen}
              bounces : byte;         {how many times it has bounced}
              
              multi, {if it is part of a multishot, then should not
                     treat as part of  shot limit}
              
              
              JustShot,
              Removed : boolean;
              dir : AngleType;
           end;
   
TankType = record
              move,
              loc  : CoordType;
              smudge,
              hit,
              size : SpecType;
              vec  : VectorType;
              
              {----------------MOVEMENT----------------}

              teleported,
              moved : boolean;

              {--------------LOCATION-----------------}
              old,
              hyp, {hypothetical future coords, for checking hits etc.}

              front, {coords of front center}
              back, {   "      back center}
              mid,
              Guntip {coords of tip of Gun}
              : CoordType;


              {---------------SIZE--------------------}

              TreadWidth,
              TurretRad : integer; {radius of the turret}

              Gun : VectorType; {where magnitude is length, and angle is
                                rotation}

              {---------------COLORS--------------------}
              
              TurretColor,   {colors of parts of Tanks}
              GunColor,
              TreadColor : byte;

              {----------------OTHER--------------------}

              Count : TankCounterType;
              MaxShots : byte;
              MaxLife : byte;
              Weapons : array[Weaptype] of byte;
              ActiveWeap : Weaptype;
              num : byte;
              MissileFired : boolean;

           end;

ColorType = record
               Missile,
               HeavyGun,
               Shot,
               Null : integer;     {bg color for game area}
            end;

WallType = record
              loc : CoordType;
              size : SpecType;
              visible : WallVisType;
              ShotBlock : boolean;
           end;


{* Array Types ***************************************}
   Wallarray = array[1..50] of WallType;
   Tankarray = array[1..2] of TankType;
   shotarray = array[1..TotMaxShots] of shottype;
   Weaparray = array[1..100] of Weaprectype;
   
TrigType = array[AngleType] of real;  {trigonometry functions}
   {stored to increase speed}
   
iBitmap = array[0..20,0..20] of byte; {one 20by20 bitmap}
   
iImagetype = array[none..shotup] of iBitmap;
   {array of bitmaps for items on battlefield}
   
probarray = array[Itemtype] of byte;


VAR
   Tanks : Tankarray;
   shots : shotarray;
   walls : wallarray;
   Weaps : Weaparray;

ItemProb : probArray;
   iImages : iImageType;
   WeapIncrease : array[Weaptype] of byte;

itemcount,
   iteminterval : longint;

item : ItemrecType;
   isitem : boolean;

colors : colortype;

cosk,
   sink : trigtype; {store trig to speed processing}

big,

Screen : vidtype;  {video config info}

visual,               {variables for page flipping}
   active,
   dummy : integer;

r,    {row pos of text cursor}
   c,     {columns}

t,    {global Tank control variable}
   p,    {for <p>owerful Weapons}
   s,    {same for shots}
   w,    {same for walls}
   i,
   j,
   o    {i, j, and o might be useful}
   : integer;

TotShots : longint;
   numWeaps : integer;

fillpattern : fillpatternType;
   fillstyle : word;

numwalls : integer;

shotspec : SpecType;


shotedge : shotedgetype;
   shotwall : shotwalltype;



(*******************************************************)

PROCEDURE updateTankstats( var tank : tanktype );
FORWARD;

   PROCEDURE Tankright( var tank : tanktype );
   FORWARD;

      PROCEDURE cleanupshots;
      FORWARD;

         PROCEDURE cleanupWeaps;
         FORWARD;

         (**********************************************************)

         (*  UTILITY PROCEDURES ************************************)

         (**********************************************************)

            FUNCTION incoords( xy1, xy2 : CoordType;
                              size1, size2 : SpecType;
                              oldxy : CoordType ) : hittype;
            {checks whether objects represented by xy1, size1, xy2, and size2
            have collided and returns whether from top/bottom or the side or
            nohit}


            begin
               incoords:=nohit;

               {if distance between center makes them overlap}
               if ( abs( xy2.x - xy1.x ) <= size1.x + size2.x ) and
                  ( abs( xy2.y - xy1.y ) <= size1.y + size2.y ) then

                  {if used to be to one side of it, therefore it hit a
                  side}
               begin
                  if abs( oldxy.x - xy2.x ) > size1.x + size2.x
                     then incoords := side
                  else if abs( oldxy.y - xy2.y ) > size1.y + size2.y
                     then incoords := top
                  else incoords := inwall;

               end;


            end;

         (*====================================================*)

            FUNCTION sign( blah : integer ): integer;
            {gets the sign of an integer}

            begin

               if blah < 0
                  then sign:= -1
               else sign:= 1;

            end;

         (*====================================================*)

            PROCEDURE putclose( var hyp : coordtype;
                                   loc, hitloc : coordtype;
                                   size, hitsize : spectype;
                                   whack : hittype );
            {places two objects represented by loc, size, hitloc, and hitsize
            as close as possible either
            vertically or horizontally according to whack}

            begin
               case whack of
                 side : if loc.x < hitloc.x
                           then hyp.x := hitloc.x - size.x - hitsize.x-1
                        else hyp.x := hitloc.x + size.x + hitsize.x+1;

                 top  : if loc.y < hitloc.y
                           then hyp.y := hitloc.y - size.y - hitsize.y-1
                        else hyp.y := hitloc.y + size.y + hitsize.y+1;
               end;

            end;

         (*====================================================*)

            PROCEDURE PutCloseToEdge( var hyp : coordtype;
                                         size : spectype );

            {puts an object as close to the edge as possible if it has hit
            the edge}

            begin
               if (hyp.x + size.x > screen.MaxX)
                  then hyp.x := screen.MaxX - size.x;
               if (hyp.x - size.x < 0)
                  then hyp.x := size.x;
               if (hyp.y + size.y > screen.MaxFightY)
                  then hyp.y := screen.MaxFightY - size.y;
               if (hyp.y - size.y < 0)
                  then hyp.y := size.y;
            end;

         (**********************************************************)

         (* GRAPHICS PROCEDURES ************************************)

         (**********************************************************)

            PROCEDURE NewColor( color : word );
            {changes the color to color}

            begin
               setcolor( color );
               setfillpattern( fillpattern, color );
               {   setfillstyle( , color );}
            end;

         (*=========================================================*)

            PROCEDURE switchpages;
            {switches video pages from active to visual}

            begin

               dummy := visual;
               visual := active;
               setvisualpage( visual );
               active := dummy;
               setactivepage( active );


            end;

         (*=======================================================*)

            PROCEDURE anglerec( x1, y1, x2, y2:integer; width : integer;
                               angle : AngleType );

            {draw a rectangle at angle angle}

            var x,y : integer;
               cosr, sinr : real;

            begin
               cosr := cosk[angle];
               sinr := sink[angle];


               line( x1-round(width*sinr), y1+round(width*cosr),   {front left}
                    x1+round(width*sinr), y1-round(width*cosr) ); {front right}

               line( x1+round(width*sinr), y1-round(width*cosr),   {f-r}
                    x2+round(width*sinr), y2-round(width*cosr) ); {b-r}

               line( x2+round(width*sinr), y2-round(width*cosr),   {b-r}
                    x2-round(width*sinr), y2+round(width*cosr) ); {b-l}

               line( x2-round(width*sinr), y2+round(width*cosr),   {b-l}
                    x1-round(width*sinr), y1+round(width*cosr) ); {f-l}

               {floodfill doesn't work if thing too small}

               {right in between}
               floodfill( (x1+x2) div 2, (y1+y2) div 2, getcolor);

               {one sixteenth of the way from x1}
               floodfill( (15*x1 + x2) div 16,
                         (15*y1 + y2) div 16, getcolor);

               {one sixteenth of the way from x2}
               floodfill( (15*x2 + x1) div 16,
                         (15*y2 + y1) div 16, getcolor);

            end;

         (*=========================================================*)

            PROCEDURE blankbottom;

            begin
               newcolor( BLACK );
               bar( 0, Screen.MaxFightY, Screen.MaxX, Screen.MaxY );
            end;

         (*=======================================================*)

            PROCEDURE blankscreen;

            begin
               newcolor( colors.null );
               bar( 0, 0, screen.MaxX, screen.MaxFightY );
               {   blankbottom;}
            end;

         (*==================================================*

NOTE:     erasing procedures do the checking for whether other
          objects were erased

          *==================================================*)

            PROCEDURE eraseTank( var tank : tanktype );

            begin
               with Tank do
               begin
                  newcolor( colors.null );
                  bar( old.x + smudge.x,
                      old.y + smudge.y,
                      old.x - smudge.x,
                      old.y - smudge.y );

               end;
            end;

         (*===========================================================*)

            PROCEDURE drawtreads(var tank : tanktype);
            var x, y : real;

            begin
               with Tank do
               begin

                  x := cosk[vec.dir] ;
                  y := sink[vec.dir] ;

                  newcolor( treadcolor );

                  anglerec( front.x-round(size.x*y), {front left}
                           front.y+round(size.y*x),
                           back.x- round(size.x*y),  {back left}
                           back.y+ round(size.y*x),
                           treadwidth, vec.dir );

                  anglerec( front.x+round(size.x*y),    {front right}
                           front.y-round(size.y*x),
                           back.x+ round(size.x*y),     {backright}
                           back.y- round(size.y*x),
                           treadwidth, vec.dir )
               end;
            end;

         (*=====================================================*)

            PROCEDURE drawshield(var tank : tanktype);
            {draws shield around tank}

            var x, y : real;

            begin

               newcolor( red );
               circle( tank.loc.x,
                      tank.loc.y,
                      tank.smudge.x );

            end;

         (*=====================================================*)

            PROCEDURE drawGun ( var tank : tanktype);

            var x, y : real;

            begin
               with Tank do
               begin

                  x := cosk[Gun.dir];
                  y := sink[Gun.dir];

                  {draw circle for turret}
                  newcolor( turretcolor );

                  fillellipse( loc.x,
                              loc.y,
                              turretrad, turretrad );

                  {draw the Gun}
                  newcolor( Guncolor );
                  anglerec( loc.x,
                           loc.y,
                           Guntip.x,
                           Guntip.y,
                           2,
                           Gun.dir );

               end;
            end;

         (*=====================================================*)

            PROCEDURE drawTank( var tank : tanktype );

            begin

               with tank do
               begin

                  drawtreads( tank );
                  drawGun( tank );

                  if Tank.count.shield < SHIELDLENGTH
                     then
                     drawshield( tank );

               end;
            end;

         (*================================*)

            PROCEDURE drawshot (xy : CoordType; color : integer);

            begin
               newcolor( color );

               bar( xy.x - shotspec.x,
                   xy.y - shotspec.y,
                   xy.x + shotspec.x,
                   xy.y + shotspec.y );

            end;


         (*=========================================================*)

            PROCEDURE drawmine( xy : CoordType );

            begin

               newcolor( DARKGRAY );            {body}
               fillellipse( xy.x,
                           xy.y,
                           5, 3 );

               newcolor( BLACK );                    {top}
               fillellipse( xy.x,
                           xy.y-2,
                           5, 2 );

            end;

         (*=====================================*)

            PROCEDURE drawbomb( xy : CoordType );

            var i, j : integer;

            begin

               {body of bomb}
               newcolor( BLACK );
               fillellipse( xy.x,
                           xy.y,
                           5, 5 );

               newcolor( DARKGRAY );
               {stem of bomb}
               for i := -2 to 2 do
                  for j := -2 to 2 do
                     putpixel( xy.x + 5 + i,
                              xy.y - 5 + j-i,
                              DARKGRAY);
            end;

         (*========================================================*)

            PROCEDURE drawmissile( xy : CoordType; dir : AngleType );


            var x, y : integer;
               i, j : integer;

            begin

               x := round(cosk[dir] * 7);
               y := round(sink[dir] * 7);

               newcolor( colors.missile );

               anglerec( xy.x - x div 2,
                        xy.y - y div 2,
                        xy.x + x,
                        xy.y + y,
                        3, dir );

               i := random(3);

               case i of
                 1 : i := red;
                 2 : i := yellow;
                 3 : i := lightred;
               end;

               newcolor( i );

               anglerec( xy.x - x div 2,
                        xy.y - y div 2,
                        xy.x - x,
                        xy.y - y,
                        2, dir );

            end;

         (*============================================*)

            PROCEDURE erasemissile( weap : WeapRecType);

            begin
               with weap do
               begin

                  newcolor( colors.null );
                  bar( old.x + smudge.x,
                      old.y + smudge.y,
                      old.x - smudge.x,
                      old.y - smudge.y );

               end;
            end;

         (*==========================================*)

            PROCEDURE eraseshot( shot : shottype );

            begin
               with shot do
               begin
                  drawshot( old, colors.null );


               end;
            end;

         (*==========================================*)

            PROCEDURE eraseheavygun( weap : weapRecType );

            begin
               with weap do
               begin
                  drawshot( old, colors.null );

               end;
            end;

         (*===============================================*)

            PROCEDURE drawwall( wall : walltype );

            begin
               with wall do
               begin
                  if shotblock
                     then newcolor( brown )
                  else newcolor( yellow );

                  case visible of
                    norm : bar( loc.x + size.x,
                               loc.y + size.y,
                               loc.x - size.x,
                               loc.y - size.y );

                    outline : rectangle( loc.x + size.x,
                                        loc.y + size.y,
                                        loc.x - size.x,
                                        loc.y - size.y );

                    cloud :  begin
                                rectangle( loc.x + size.x,
                                          loc.y + size.y,
                                          loc.x - size.x,
                                          loc.y - size.y );
                                newcolor(white);
                                bar( loc.x + size.x-1,
                                    loc.y + size.y-1,
                                    loc.x - size.x+1,
                                    loc.y - size.y+1 );

                             end;
                  end; {case}

               end;
            end;

         (*=========================================================*)

            PROCEDURE updatebottom;

            {updates the info bar}

            var x, y : integer;
               lame : string;
               Weapcount : Weaptype;

            begin
               newcolor( lightmagenta );

               {Tank 2}

               {life}
               lame := 'Purple: 100';  {100 is in there to align text correctly}
               x := Screen.MaxX div 5 - textwidth(lame) div 2;
               y := Screen.MaxFightY + 3;

               lame := 'Purple: ';
               Moveto( x, y );
               outtext( lame );
               str( Tanks[2].count.life, lame );
               outtext( lame );

               {Weapons}
               x := Screen.MaxX div 20;
               y := y + 10;

               newcolor( RED );

               for Weapcount := tripleshot to HeavyGun do
               begin
                  putimage( x + 23 * ord(Weapcount), y,
                           iImages[WeapCount], normalput );

                  str( Tanks[2].Weapons[WeapCount], lame );
                  outtextxy( x + 23 * ord(Weapcount)+3, y+22, lame );

                  if WeapCount = Tanks[2].ActiveWeap
                     then begin
                        newcolor( YELLOW );
                        rectangle( x + 23 * ord(WeapCount)-1, y-1,
                                  x + 23 * ord(WeapCount)+21, y+22+textheight(lame));
                        newcolor( RED );
                     end;
               end;


               {Tank 1}
               {life}
               newcolor( lightmagenta );
               lame := 'Green: 100';
               x := Screen.MaxX * 5 div 6 - textwidth(lame) div 2;
               y := Screen.MaxFightY + 3;

               lame := 'Green: ';
               Moveto( x, y );
               outtext( lame );
               str( Tanks[1].count.life, lame );
               outtext( lame );

               {Weapons}
               x := Screen.MaxX div 20 * 19 - 23 * 8;
               y := y + 10;

               newcolor( RED );

               for Weapcount := tripleshot to HeavyGun do
               begin
                  putimage( x + 23 * ord(Weapcount), y,
                           iImages[WeapCount], normalput );

                  str( Tanks[1].Weapons[WeapCount], lame );
                  outtextxy( x + 23 * ord(Weapcount)+3, y+22, lame );

                  if WeapCount = Tanks[1].ActiveWeap
                     then begin
                        newcolor( YELLOW );
                        rectangle( x + 23 * ord(WeapCount)-1, y-1,
                                  x + 23 * ord(WeapCount)+21, y+22+textheight(lame));
                        newcolor( RED );
                     end;
               end;


            end;

         (*====================================================*)

            PROCEDURE drawexplosion( Weap : WeapRecType );

            begin
               with Weap do
                  if (ex.count > 0) and not removed then
                  begin

                     newcolor( red );
                     circle( loc.x,
                            loc.y,
                            ex.count * exringsize - 2 );

                     newcolor( yellow );
                     circle( loc.x,
                            loc.y,
                            ex.count * exringsize - 4);

                  end;
            end;

         (*============================================================*)

            PROCEDURE eraseexplosion( Weap : WeapRecType );

            var x1, y1, x2, y2 : longint;

            begin
               with Weap do
               begin
                  if ex.count > 0
                     then begin

                        newcolor( colors.null );
                        fillellipse( loc.x,
                                    loc.y,
                                    ex.count * exringsize-1,
                                    ex.count * exringsize-1 );


                     end; {then}
               end; {with weap}
            end;

         (*============================================================*)

            Procedure UpdateScreen;

            {the order of things is very important, if updatebottom is
            put after the shots, it is blank whenever a shot is present.
            If the delay is not right there, things flicker.}

            begin
               {back page update}

               for t := 1 to 2 do
                  if tanks[t].count.invis > invislength
                     then drawTank( tanks[t] );

               blankbottom;
               updatebottom;

               with item do
               begin
                  if isitem
                     then begin
                        putImage( loc.x - size.x,
                                 loc.y - size.y,
                                 iImages[Weap], normalput);

                     end;
                  if removed
                     then begin
                        putImage( old.x - size.x,
                                 old.y - size.y,
                                 iImages[none], normalput);
                     end;
               end;

               for w := 1 to numwalls do
                  if walls[w].visible <> cloud
                     then begin
                        drawwall( walls[w] );
                     end;

               for s := 1 to TotShots do
               begin
                  if not shots[s].reMoved
                     then drawshot( shots[s].loc, colors.shot );
               end;


               for p := 1 to numWeaps do
                  case Weaps[p].kind of
                    missile : drawmissile( Weaps[p].loc, Weaps[p].vec.dir);
                    bomb : begin
                              drawbomb( Weaps[p].loc );
                           end;
                    mine : begin
                              drawmine( Weaps[p].loc );
                           end;
                    HeavyGun : drawshot( Weaps[p].loc, colors.HeavyGun );
                    explosion : drawexplosion( Weaps[p] );
                  end; {case}

               for w := 1 to numwalls do
                  if walls[w].visible = cloud
                     then begin
                        drawwall( walls[w] );
                     end;


               switchpages;
               delay( 30 );

               {make it all pretty back there}

               for p := 1 to numWeaps do
                  case Weaps[p].kind of
                    missile : erasemissile( Weaps[p] );
                    HeavyGun : eraseheavygun( Weaps[p] );
                    explosion : eraseexplosion( Weaps[p] );
                  end; {case}




               for s := 1 to TotShots do
               begin
                  eraseshot( shots[s] );
               end;

               with item do
                  if reMoved
                     then begin
                        putImage( old.x - size.x,
                                 old.y - size.y,
                                 iImages[none], normalput);
                        reMoved := false;
                     end;

               eraseTank( tanks[1] );
               eraseTank( tanks[2] );



            end;



         (**********************************************************)

         (* INITIALIZATION PROCEDURES ******************************)

         (**********************************************************)

            PROCEDURE inittrig;
            {store trig function in arrays for speed}

            begin

               for i := 0 to 359 do
               begin
                  cosk[i] := cos(i * pi / 180);
                  sink[i] := sin(i * pi / 180);
               end;
            end;

         (*========================================================*)

            PROCEDURE setupgraphics( graphdriver, graphmode : integer);
            {sets up the graphics stuff}

            var gmode, gdriver : integer;

            begin
               gmode := graphmode;      {initgraph takes variable parameters}
               gdriver := graphdriver;

               initgraph( gdriver, gmode, '.' );

               case gdriver of
                 grNotDetected   : writeln( 'grNotDetected' );
                 grFileNotFound  : writeln( 'grFileNotFound' );
                 grInvalidDriver : writeln( 'grInvalidDriver' );
                 grNoLoadMem     : writeln( 'grNoLoadMem' );
                 grInvalidMode   : writeln( 'grInvalidMode' );
               end;

            end;

         (*==========================================================*)

            PROCEDURE getvidstats;
            {get msgraph specs into my variables}

            begin

               screen.MaxX := getMaxX;
               screen.MaxY := getMaxY;
               screen.MaxFightY := round(screen.MaxY - 60/480 * screen.MaxY);

            end;

         (*=========================================================*)

            PROCEDURE initTanks;
            {initialize tanks to starting status}

            begin

               {Tank 1 only stuff }
               with Tanks[1] do
               begin
                  loc.x := screen.MaxX * 2 div 3;
                  loc.y := screen.MaxFightY div 2;
                  old := loc;
                  hyp := loc;

                  vec.dir := 180;
                  Gun.dir := 180;

                  Guncolor := RED;       {RED}
                  turretcolor := GREEN;  {GREEN}
                  treadcolor := BLACK;    {BLACK}
               end;

               with Tanks[2] do
               begin
                  loc.x := screen.MaxX div 3;
                  loc.y := screen.MaxFightY div 2;
                  old := loc;
                  hyp := loc;

                  vec.dir := 0;
                  Gun.dir := 0;

                  Guncolor := BLUE;       {RED}
                  turretcolor := MAGENTA;  {GREEN}
                  treadcolor := BLACK;    {BLACK}
               end;
               for t := 1 to 2 do
                  with Tanks[t] do
                  begin


                     Weapons[none]         := 0; { 0}
                     Weapons[tripleshot]   := 3; { 0}
                     Weapons[allshot]      := 3; { 0}
                     Weapons[missile]      := 1; { 0}
                     Weapons[bomb]         := 2; { 0}
                     Weapons[mine]         := 2; { 0}
                     Weapons[proxy]        := 5; { 0}
                     Weapons[teleport]     := 5; { 0}
                     Weapons[HeavyGun]     := 5; { 0}
                     ActiveWeap := tripleshot;

                     vec.mag := 3;

                     MissileFired := false;

                     size.x := round(12/640 * screen.MaxX); {12/640}
                     size.y := round(12/480 * screen.MaxY); {12/480}
                     smudge.x := round(size.x + (10/12 * size.x));
                     smudge.y := round(size.y + (10/12 * size.y));
                     hit.x := size.x;
                     hit.y := size.y;
                     treadwidth := round(1/3 * size.x);
                     num := t;

                     Gun.mag := round( 0.8 * size.x);  {0.8 size.x}
                     turretrad := round( 0.6 * size.x ); {0.6 size.x}

                     updateTankstats(tanks[t]);
                     with count do
                     begin
                        shots := 0;
                        life := 100;
                        shield := shieldlength +1;
                        invis := invislength +1;
                        hit := rotsteps + 1;
                     end;

                     maxshots := 4;
                     maxlife := tanks[1].count.life;
                  end


            end;

         (*================================================*)

            PROCEDURE initsettings;
            {initialize global settings}
            {defaults are commented}


            var i : byte;

            begin

               {these must add to 100 or less, totals less than 100 will make
               items increasingly scarce and with random intervals}

               ItemProb[none]         :=  0; { 0}
               ItemProb[tripleshot]   := 10; {10}
               ItemProb[allshot]      := 10; {10}
               ItemProb[missile]      :=  5; { 5}
               ItemProb[bomb]         := 10; {10}
               ItemProb[mine]         := 10; {10}
               ItemProb[proxy]        :=  5; { 5}
               ItemProb[teleport]     :=  5; {10}
               ItemProb[HeavyGun]     := 10; { 5}
               ItemProb[shield]       :=  5; { 5}
               ItemProb[invisible]    := 10; {10}
               ItemProb[health]       :=  5; { 5}
               ItemProb[shotup]       := 15; {15}

               iteminterval := 200;  {200}
               itemcount := 0;      {0}
               isitem := false;

               WeapIncrease[none]         :=  0; { 0}
               WeapIncrease[tripleshot]   := 10; {15}
               WeapIncrease[allshot]      :=  3; { 5}
               WeapIncrease[missile]      :=  2; { 2}
               WeapIncrease[bomb]         :=  5; { 5}
               WeapIncrease[mine]         :=  5; { 5}
               WeapIncrease[proxy]        :=  5; { 5}
               WeapIncrease[teleport]     :=  5; {10}
               WeapIncrease[HeavyGun]     := 10; {20}

               colors.shot := BLACK;
               colors.HeavyGun := red;
               colors.null := lightgray; {LIGHTGRAY}
               colors.missile := BLACK;

               for i := 1 to 8 do
                  fillpattern[i] := 255; {255}

               shotedge := bounce;   {wrap}
               shotwall := bounce; {bounce}

               visual := 1; {1}
               active := 0; {0}

               TotShots := 0;      {0}
               shotspec.x := 1;    {1}
               shotspec.y := 1;    {1}
            end;

         (*=========================================================*)

            PROCEDURE loadmap{( filename : string )};
            {initialize the battlefield}


            begin
               numwalls := 9;

               with walls[1] do
               begin
                  loc.x := screen.MaxX div 5;
                  loc.y := Screen.MaxFightY div 4;
                  size.x := 20;
                  size.y := 20;
                  visible := norm;
                  shotblock := true;
               end;

               with walls[2] do
               begin
                  loc.x := screen.MaxX div 2 ;
                  loc.y := screen.MaxFightY div 4;
                  size.x := 5;
                  size.y := 20;
                  visible := norm;
                  shotblock := false;
               end;

               with walls[3] do
               begin
                  loc.x := screen.MaxX div 5 * 4;
                  loc.y := screen.MaxFightY div 4;
                  size.x := 20;
                  size.y := 20;
                  visible := norm;
                  shotblock := true;

               end;

               with walls[4] do
               begin
                  loc.x := screen.MaxX div 4;
                  loc.y := screen.MaxFightY div 2;
                  size.x := 20;
                  size.y := 20;
                  visible := outline;
                  shotblock := true;
               end;

               with walls[5] do
               begin
                  loc.x := screen.MaxX div 2;
                  loc.y := screen.MaxFightY div 2;
                  size.x := 40;
                  size.y := 40;
                  visible := cloud;
                  shotblock := false;

               end;

               with walls[6] do
               begin
                  loc.x := screen.MaxX div 4 * 3;
                  loc.y := screen.MaxFightY div 2;
                  size.x := 20;
                  size.y := 20;
                  visible := outline;
                  shotblock := true;

               end;

               with walls[7] do
               begin
                  loc.x := screen.MaxX div 5;
                  loc.y := screen.MaxFightY div 4 * 3;
                  size.x := 20;
                  size.y := 20;
                  visible := norm;
                  shotblock := true;

               end;

               with walls[8] do
               begin
                  loc.x := screen.MaxX div 2;
                  loc.y := screen.MaxFightY div 4 * 3;
                  size.x := 5;
                  size.y := 20;
                  visible := norm;
                  shotblock := false;

               end;

               with walls[9] do
               begin
                  loc.x := screen.MaxX div 5 * 4;
                  loc.y := screen.MaxFightY div 4 * 3;
                  size.x := 20;
                  size.y := 20;
                  visible := norm;
                  shotblock := true;
               end;


               for w := 1 to numwalls do
                  drawwall( walls[w] );

               switchpages;

               for w := 1 to numwalls do
                  drawwall( walls[w] );

               switchpages;
            end;


         (*====================================================*)

            PROCEDURE initiImages;
            {initializes bitmaps for icons representing Items}


            (*-------------------------*)

               PROCEDURE inittripleshot;

               begin
                  newcolor( BLACK );
                  rectangle( 0, 0, 20, 20 );

                  newcolor( YELLOW );
                  floodfill( 10, 10, BLACK );

                  newcolor( RED );
                  for i := 1 to 3 do
                     line( 5, 10, 15, i * 5 );

               end;

            (*------------------------*)

               PROCEDURE initallshot;

               begin
                  newcolor( BLACK );
                  rectangle( 0, 0, 20, 20 );

                  newcolor( RED );
                  floodfill( 10, 10, BLACK );

                  newcolor( YELLOW );

                  for j := 1 to 3 do
                     for i := 1 to 3 do
                        line( 10, 10, j * 5, i * 5);
               end;

            (*--------------------------*)

               PROCEDURE initmissile;

               begin
                  newcolor( BLACK );
                  rectangle( 0, 0, 20, 20 );

                  newcolor( MAGENTA );
                  floodfill( 10, 10, BLACK );

                  newcolor( BLACK );
                  bar( 5, 7, 10, 13 );

                  line( 10, 13, 15, 10 );
                  line( 15, 10, 10, 7 );

                  floodfill( 12, 10, BLACK );
               end;

            (*------------------------*)

               PROCEDURE initbomb;

               var lame : CoordType;

               begin
                  newcolor( BLACK );
                  rectangle( 0, 0, 20, 20 );

                  newcolor( LIGHTRED );
                  floodfill( 10, 10, BLACK );

                  lame.x := 10;
                  lame.y := 10;

                  drawbomb( lame );
               end;

            (*--------------------------*)

               PROCEDURE initmine;

               var coords : CoordType;

               begin
                  coords.x := 10;
                  coords.y := 10;

                  newcolor( BLACK );
                  rectangle( 0, 0, 20, 20 );

                  newcolor( CYAN );
                  floodfill( 10, 10, BLACK );

                  drawmine( coords );

               end;

            (*-------------------------*)

               PROCEDURE initHeavyGun;

               begin
                  newcolor( BLACK );
                  rectangle( 0, 0, 20, 20 );

                  newcolor( LIGHTBLUE );
                  floodfill( 10, 10, BLACK );

                  newcolor( BLACK );
                  line( 12, 8, 5, 15 );
                  line( 12, 8, 15, 5 );
                  line( 12, 8, 12, 5 );
                  line( 12, 5, 10, 5 );
                  line( 12, 8, 15, 8 );
                  line( 15, 8, 15, 10 );

               end;

            (*------------------------*)


               PROCEDURE initproxy;

               begin
                  newcolor( BLACK );
                  rectangle( 0, 0, 20, 20 );

                  newcolor( DARKGRAY );
                  floodfill( 10, 10, BLACK );

                  for i := 1 to 3 do
                  begin
                     newcolor( i + 10 );
                     circle( 10, 10, 5*i div 2 );
                  end; {for}
               end;

            (*----------------------*)

               PROCEDURE initshield;

               begin
                  newcolor( BLACK );
                  rectangle( 0, 0, 20, 20 );

                  newcolor( BROWN );
                  floodfill( 10, 10, BLACK );

                  newcolor( BLUE );
                  bar( 5, 5, 15, 10);

                  line( 5, 10, 10, 15);
                  line( 10, 15, 15, 10 );
                  floodfill( 10, 12, BLUE );

               end;

            (*---------------------*)

               PROCEDURE initinvis;

               begin

                  newcolor( BLACK );
                  rectangle( 0, 0, 20, 20 );

                  newcolor( DARKGRAY );
                  floodfill( 10, 10, BLACK );

                  newcolor( white );
                  rectangle( 5, 5, 15, 7 );
                  rectangle( 5, 13, 15, 15 );

                  circle( 10, 10, 3 );
               end;

            (*----------------------*)

               PROCEDURE initteleport;

               begin
                  newcolor( BLACK );
                  rectangle( 0, 0, 20, 20 );

                  newcolor( LIGHTGRAY );
                  floodfill( 10, 10, BLACK );

                  newcolor( YELLOW );

                  Moveto( 5, 7 );
                  lineto( 7, 5 );
                  lineto( 13, 5 );
                  lineto( 15, 7 );
                  lineto( 10, 10 );
                  lineto( 10, 15 );

                  putpixel( 10, 17, YELLOW );
               end;

            (*-------------------*)

               PROCEDURE inithealth;

               begin
                  newcolor( BLACK );
                  rectangle( 0, 0, 20, 20 );

                  newcolor( LIGHTGREEN );
                  floodfill( 10, 10, BLACK );

                  newcolor( BLACK );
                  rectangle( 5, 5, 15, 15 );  {box}
                  rectangle( 7, 3, 13, 5 );   {handle}

                  newcolor( WHITE );
                  floodfill( 10, 10, BLACK );

                  newcolor( RED );     {red cross}
                  bar( 9, 7, 11, 13 );
                  bar( 7, 9, 13, 11 );

               end;

            (*------------------*)

               PROCEDURE initshotup;

               var s : string;

               begin
                  newcolor( BLACK );
                  rectangle( 0, 0, 20, 20 );

                  newcolor( WHITE );
                  floodfill( 10, 10, BLACK );

                  str( shotIncrease, s );
                  s := '+' + s       ;

                  newcolor( BLACK );
                  outtextxy( 4, 6, s );

               end;

            (*----------------*)

            begin {initIimages}

               blankscreen;

               getimage( 0, 0, 20, 20, iImages[none] );

               inittripleshot;
               getImage( 0, 0, 20, 20, iImages[tripleshot] );

               putImage( 0, 0, iImages[none], normalput );

               initallshot;
               getImage( 0, 0, 20, 20, iImages[allshot] );

               putImage( 0, 0, iImages[none], normalput );

               initmissile;
               getImage( 0, 0, 20, 20, iImages[missile] );

               putImage( 0, 0, iImages[none], normalput );

               initbomb;
               getImage( 0, 0, 20, 20, iImages[bomb] );

               putImage( 0, 0, iImages[none], normalput );

               initmine;
               getImage( 0, 0, 20, 20, iImages[mine] );

               putImage( 0, 0, iImages[none], normalput );

               initHeavyGun;
               getImage( 0, 0, 20, 20, iImages[HeavyGun] );

               putImage( 0, 0, iImages[none], normalput );

               initproxy;
               getImage( 0, 0, 20, 20, iImages[proxy] );

               putImage( 0, 0, iImages[none], normalput );

               initshield;
               getImage( 0, 0, 20, 20, iImages[shield] );

               putImage( 0, 0, iImages[none], normalput );

               initinvis;
               getImage( 0, 0, 20, 20, iImages[invisible] );

               putImage( 0, 0, iImages[none], normalput );

               initteleport;
               getImage( 0, 0, 20, 20, iImages[teleport] );

               putImage( 0, 0, iImages[none], normalput );

               inithealth;
               getImage( 0, 0, 20, 20, iImages[health] );

               putImage( 0, 0, iImages[none], normalput );

               initshotup;
               getImage( 0, 0, 20, 20, iImages[shotup] );

               putImage( 0, 0, iImages[none], normalput );

            end;

         (***************************************************************)

         (* CONTROL PROCEDURES ******************************************)

         (***************************************************************)

            PROCEDURE updateTankstats( var tank : tanktype );
            {used to get useful points of parts of a tank}

            begin

               with Tank do
               begin

                  {front middle of tank}
                  front.x := round(loc.x + cosk[vec.dir] * size.x);
                  front.y := round(loc.y + sink[vec.dir] * size.y);

                  {back middle}
                  back.x := round(loc.x - cosk[vec.dir] * size.x);
                  back.y := round(loc.y - sink[vec.dir] * size.y);

                  Guntip.x := round(loc.x + cosk[Gun.dir] * Gun.mag);
                  Guntip.y := round(loc.y + sink[Gun.dir] * Gun.mag);

                  Move.x := round(cosk[vec.dir] * vec.mag);
                  Move.y := round(sink[vec.dir] * vec.mag);

               end;
            end;



         (******************************************)

            PROCEDURE Tankright ( var tank : tanktype);
            {turn treads to the right}

            var up : byte;

            begin
               with Tank do
               begin

                  up := round(360/rotsteps);

                  If vec.dir + up > 359
                     Then
                     vec.dir := vec.dir + up - 360
                  else
                     vec.dir := vec.dir + up;
                  Moved := true;

                  updateTankstats( tank );

               end;
            end;

         (*=====================================================*)

            PROCEDURE Tankleft ( var tank : tanktype);

            begin
               with Tank do
               begin

                  If vec.dir - rotconst < 0
                     Then
                     vec.dir := vec.dir - rotconst + 360
                  else
                     vec.dir := vec.dir - rotconst;

                  Moved := true;

                  updateTankstats( tank );

               end;
            end;

         (*=======================================================*)

            PROCEDURE Gunleft ( var tank : tanktype );

            begin
               with Tank do
               begin

                  if Gun.dir - rotconst < 0
                     then Gun.dir := Gun.dir - rotconst + 360
                  else Gun.dir := Gun.dir - rotconst;

                  Guntip.x := round(loc.x + cosk[Gun.dir] * Gun.mag);
                  Guntip.y := round(loc.y + sink[Gun.dir] * Gun.mag);

                  Moved := true;

               end;
            end;

         (*=====================================================*)

            PROCEDURE Gunright ( var tank : tanktype );

            begin
               with Tank do
               begin

                  if Gun.dir + rotconst > 359
                     then Gun.dir := Gun.dir + rotconst - 360
                  else Gun.dir := Gun.dir + rotconst;

                  Guntip.x := round(loc.x + cosk[Gun.dir] * Gun.mag);
                  Guntip.y := round(loc.y + sink[Gun.dir] * Gun.mag);

                  Moved := true;

               end;
            end;

         (*=====================================================*)

            PROCEDURE gearup( var tank : tanktype );
            {speed tank up           }

            begin
               with Tank do
               begin
                  vec.mag := vec.mag + 2;
                  if vec.mag = 0 then vec.mag := vec.mag + 1;
                  Move.x := round(cosk[vec.dir] * vec.mag);
                  Move.y := round(sink[vec.dir] * vec.mag);
               end;
            end;

         (*================================================*)

            PROCEDURE geardown( var tank : tanktype );
            {slow down tank}


            begin
               with Tank do
               begin
                  vec.mag := vec.mag - 2;
                  if vec.mag = 0 then vec.mag := vec.mag - 1;
                  Move.x := round(cosk[vec.dir] * vec.mag);
                  Move.y := round(sink[vec.dir] * vec.mag);
               end;
            end;

         (*====================================================*)

            PROCEDURE fireGun( var tank : tanktype );

            begin
               with Tank do
               begin
                  inc( count.shots );
                  inc( TotShots );

                  shots[TotShots].dir := Gun.dir;
                  shots[TotShots].source := num;
                  shots[Totshots].justshot := true;
                  shots[Totshots].multi := false;

                  shots[TotShots].loc.x := Guntip.x;

                  shots[TotShots].loc.y := Guntip.y;

                  shots[TotShots].old.x := loc.x;
                  shots[TotShots].old.y := loc.y;

                  shots[TotShots].wraps := 0;
                  shots[TotShots].bounces := 0;

                  shots[TotShots].Move.x := round(cosk[Gun.dir] * shotmag);
                  shots[TotShots].Move.y := round(sink[Gun.dir] * shotmag);

                  shots[TotShots].reMoved := false;

               end;
            end;

         (*=============================================*)

            PROCEDURE changeWeap( var tank : tanktype );

            begin
               with Tank do
               begin
                  if ActiveWeap < HeavyGun
                     then inc(ActiveWeap)
                  else ActiveWeap := tripleshot;
               end;
            end;

         (*==================================================*)

            PROCEDURE firetripleshot( var tank : tanktype);

            begin

               for i := -1 to 1 do
               begin
                  inc( TotShots );
                  with shots[TotShots] do
                  begin

                     if Tank.Gun.dir + 45 * i > 359
                        then dir := Tank.Gun.dir + 45 * i - 360
                     else if Tank.Gun.dir + 45 * i < 0
                        then dir := Tank.Gun.dir + 45 * i + 360
                     else dir := Tank.Gun.dir + 45 * i;

                     source := tank.num;
                     multi := true;
                     justShot := true;

                     loc.x := Tank.Guntip.x;

                     loc.y := Tank.Guntip.y;


                     wraps := 0;
                     bounces := 0;

                     Move.x := round(cosk[dir] * shotmag);
                     Move.y := round(sink[dir] * shotmag);

                     reMoved := false;
                  end; {with}

               end; {for}

            end;

         (*==================================================*)

            PROCEDURE fireallshot( var tank : tanktype);

            begin

               for i := -4 to 3 do
               begin

                  inc( TotShots );
                  with shots[TotShots] do
                  begin

                     if Tank.Gun.dir + 45 * i > 359
                        then dir := Tank.Gun.dir + 45 * i - 360
                     else if Tank.Gun.dir + 45 * i < 0
                        then dir := Tank.Gun.dir + 45 * i + 360
                     else dir := Tank.Gun.dir + 45 * i;

                     source := tank.num;
                     multi := true;
                     justshot := true;

                     loc.x := Tank.loc.x;

                     loc.y := Tank.loc.y;

                     wraps := 0;
                     bounces := 0;

                     Move.x := round(cosk[dir] * shotmag);
                     Move.y := round(sink[dir] * shotmag);

                     reMoved := false;
                  end; {with}
               end; {for}

            end;


         (*==================================================*)

            PROCEDURE teleportTank( var tank : tanktype);

            begin
               with tank do
               begin
                  teleported := false;
                  randomize;

                  Moved := true;

                  hyp.x := random( SCREEN.MaxX - 2 * size.x) + size.x;

                  hyp.y := random( SCREEN.MaxFightY - 2 * size.y) + size.y;

               end;
            end;

         (*=====================================*)

            PROCEDURE fireHeavyGun( var tank : tanktype );

            begin
               with tank do
               begin

                  inc( numWeaps );
                  p := numWeaps;

                  {explosion info}
                  Weaps[p].ex.count := 0;
                  Weaps[p].ex.dam   := 3;
                  Weaps[p].ex.width := 2;

                  Weaps[p].size := shotspec;

                  Weaps[p].vec.dir := Gun.dir;

                  Weaps[p].loc.x := Guntip.x;

                  Weaps[p].loc.y := Guntip.y;

                  Weaps[p].old := Weaps[p].loc;
                  Weaps[p].justshot := true;
                  Weaps[p].source := num;

                  Weaps[p].vec.mag := shotmag;

                  Weaps[p].Move.x := round(cosk[Gun.dir] * Weaps[p].vec.mag);
                  Weaps[p].Move.y := round(sink[Gun.dir] * Weaps[p].vec.mag);

                  Weaps[p].kind := HeavyGun;

                  Weaps[p].reMoved := false;

               end;
            end;


         (*=============================================*)

            PROCEDURE firemissile( var tank : tanktype );

            begin
               with tank do
               begin
                  MissileFired := true;

                  inc( numWeaps );
                  p := numWeaps;

                  {explosion info}
                  Weaps[p].ex.count := 0;
                  Weaps[p].ex.dam   := 7;
                  Weaps[p].ex.width := 7;

                  Weaps[p].vec.dir := Gun.dir;

                  Weaps[p].size.x := 7;
                  Weaps[p].size.y := 7;

                  Weaps[p].smudge.x := 20;
                  Weaps[p].smudge.y := 20;

                  Weaps[p].loc.x := Guntip.x;

                  Weaps[p].loc.y := Guntip.y;

                  Weaps[p].old := Weaps[p].loc;
                  Weaps[p].justshot := true;
                  Weaps[p].source := num;

                  Weaps[p].count2 := 1;
                  Weaps[p].counter := 1;
                  Weaps[p].vec.mag := 1;

                  Weaps[p].Move.x := round(cosk[Gun.dir] * Weaps[p].vec.mag);
                  Weaps[p].Move.y := round(sink[Gun.dir] * Weaps[p].vec.mag);

                  Weaps[p].kind := missile;

                  Weaps[p].reMoved := false;


               end;
            end;

         (*=============================================*)

            PROCEDURE triggermissile( tanknum : byte );
            {missiles have remote detonation, this does it}

            var i : integer;

            begin

               for i := 1 to numweaps do
                  if (weaps[i].Kind = missile) and (weaps[i].source = tanknum)
                     then weaps[i].kind := explosion;

               tanks[tanknum].MissileFired := false;

            end;

         (*=============================================*)

            PROCEDURE LayBomb( var tank : tanktype );

            begin
               with tank do
               begin

                  inc( numWeaps );
                  p := numWeaps;

                  {explosion info}
                  Weaps[p].ex.count := 0;
                  Weaps[p].ex.dam   := 5;
                  Weaps[p].ex.width := 10;

                  Weaps[p].size.x := 8;
                  Weaps[p].size.y := 8;

                  Weaps[p].vec.dir := Gun.dir;

                  Weaps[p].loc.x := loc.x;
                  Weaps[p].loc.y := loc.y;

                  Weaps[p].old := Weaps[p].loc;
                  Weaps[p].source := num;

                  Weaps[p].vec.mag := 0;

                  Weaps[p].kind := bomb;

                  Weaps[p].counter := 0;

                  Weaps[p].reMoved := false;

               end;
            end;


         (*=============================================*)

            PROCEDURE LayMine( var tank : tanktype );

            begin
               with tank do
               begin

                  inc( numWeaps );
                  p := numWeaps;

                  {explosion info}
                  Weaps[p].ex.count := 0;
                  Weaps[p].ex.dam   := 20;
                  Weaps[p].ex.width := 2;

                  Weaps[p].size.x := 5;
                  Weaps[p].size.y := 5;

                  Weaps[p].vec.dir := Gun.dir;

                  Weaps[p].loc.x := loc.x;
                  Weaps[p].loc.y := loc.y;

                  Weaps[p].old := Weaps[p].loc;
                  Weaps[p].justshot := true;
                  Weaps[p].source := num;

                  Weaps[p].vec.mag := 0;

                  Weaps[p].kind := mine;

                  Weaps[p].counter := 0;

                  Weaps[p].reMoved := false;

               end;
            end;


         (*=============================================*)


            PROCEDURE fireproxy( var tank : tanktype );
            {proxy is small explosion surrounding tank the fires it}

            begin
               with tank do
               begin

                  inc( numWeaps );
                  p := numWeaps;

                  {explosion info}
                  Weaps[p].ex.count := 3;
                  Weaps[p].ex.dam   := 10;
                  Weaps[p].ex.width := 5;

                  Weaps[p].vec.dir := Gun.dir;

                  Weaps[p].loc := loc;

                  Weaps[p].kind := explosion;

                  Weaps[p].reMoved := false;

                  count.hit := rotsteps div 2 + 1;
               end;
            end;


         (*=============================================*)

            PROCEDURE UseWeap( var tank : tanktype );

            begin
               with tank do
               begin
                  if (Activeweap = Missile) and (Missilefired)
                     then triggermissile( num )
                  else if Tank.Weapons[Tank.ActiveWeap] > 0
                     then begin
                        dec( Weapons[ActiveWeap] );
                        case ActiveWeap of
                          tripleshot : firetripleshot( tank );
                          allshot : fireallshot( tank );
                          missile : firemissile( tank );
                          bomb : laybomb( tank );
                          mine : laymine( tank );
                          proxy : if Tank.count.hit > rotsteps
                                     then fireproxy( tank )
                                  else inc( Tanks[t].Weapons[ActiveWeap] );
                          teleport : teleported := true;
                          HeavyGun : fireHeavyGun( tank );
                        end {case}
                     end { then}
               end;
            end;



         (************************************************************)

         (* EVENT PROCEDURES *****************************************)

         (************************************************************)

            PROCEDURE shothitTank( var shot : shottype; var tank : tanktype );

            begin
               with tank do
               begin
                  If count.hit > rotsteps
                     then begin
                        {get rid of the shot}
                        shot.removed := true;

                        {subtract one life point from dude, if vulnerable}
                        if count.shield > shieldlength
                           then begin
                              count.life := count.life - 5;
                              count.hit := 1;
                           end;
                     end;
               end;
            end;

         (*=====================================================*)

            PROCEDURE shotbounce( var shot : shottype; whack : hittype);

            begin
               with shot do
               begin

                  inc(bounces);

                  if bounces > maxbounces
                     then reMoved := true;

                  {hit a side, special method of bouncing}
                  if whack = side
                     then begin
                        Move.x := -Move.x;
                        if dir > 180
                           then
                           dir := 180 + (360 - dir)
                        else
                           dir := 180 - dir
                     end
                     else if whack = top
                        then begin

                           Move.y := -Move.y;
                           dir := 360 - dir;
                        end;

                  {       hyp.x := loc.x + Move.x;
                  hyp.y := loc.y + Move.y;}

               end;
            end;

         (*===================================================*)

            PROCEDURE shotwrap( var shot : shottype; whack : hittype);

            begin
               with shot do
               begin
                  inc( wraps );

                  if wraps > maxwraps
                     then reMoved := true;

                  if whack = side
                     then

                     {wrap around sides}
                     if hyp.x > SCREEN.MaxX
                        then hyp.x := 0
                     else hyp.x := SCREEN.MaxX

                     else if whack = top
                        then

                        {wrap top/bottom}
                        if hyp.y > SCREEN.MaxFightY
                           then hyp.y := 0
                        else hyp.y := SCREEN.MaxFightY;


               end;

            end;

         (*=====================================================*)

            PROCEDURE shothitedge( var shot : shottype; whack : hittype );

            begin

               case shotedge of
                 kill : shots[s].reMoved := true;
                 wrap : shotwrap( shot, whack );
                 bounce : begin
                             PutCloseToEdge( shot.hyp, shotspec );
                             shotbounce( shot, whack );
                          end;
               end; {case}

            end;

         (*=====================================================*)

            PROCEDURE shothitwall( var shot : shottype; var wall : WallType;
                                      whack : hittype );
            begin
               case shotwall of
                 kill : shot.reMoved := true;
                 bounce : begin
                             putclose( shot.hyp,
                                      shot.loc, wall.loc,
                                      shotspec, wall.size,
                                      whack );
                             shotbounce( shot, whack );
                          end;
               end; {case}

            end;

         (*=============================================*)

            PROCEDURE getitem( var tank : tanktype );

            begin
               with Tank do
               begin

                  if item.Weap < shield
                     then if weapons[item.Weap] < MaxWeap - WeapIncrease[item.Weap]
                        then Weapons[item.Weap] := Weapons[item.Weap] + WeapIncrease[item.Weap]
                     else Weapons[item.Weap] := MaxWeap
                     else
                        case item.Weap of
                          shield : count.shield := 1;
                          invisible  : count.invis := 1;
                          health : if count.life + 20 <= maxlife
                                      then count.life := count.life + 20
                                   else count.life := maxlife;

                          shotup : maxshots := maxshots + shotincrease;
                        end; {case}

                  isitem := false;
                  item.old := item.loc;
                  item.Weap := none;
                  item.reMoved := true;

               end;
            end;

         (*=============================================*)



         (**********************************************************)

         (* MOVEMENT PROCEDURES ************************************)

         (**********************************************************)

            PROCEDURE MoveTank( var tank : tanktype);

            var t : integer;
               whack : hittype;
               negx, negy : shortint;

            begin
               with Tank do
                  if count.hit > rotsteps
                     then
                  begin
                     if teleported
                        then teleporttank( tank )
                     else begin
                        {set hypothetical future coords}
                        hyp.x := round(loc.x + Move.x);
                        hyp.y := round(loc.y + Move.y);
                     end;

                     {check if outside screen}
                     if hyp.x <= size.x
                        then hyp.x := size.x

                     else if hyp.x >= SCREEN.MaxX - size.x
                        then hyp.x := Screen.MaxX - size.x;

                     if hyp.y <= size.y
                        then hyp.y := size.y

                     else if hyp.y >= SCREEN.MaxFightY - size.y
                        then
                        hyp.y := Screen.maxFightY - size.y;


                     {check if hitting other Tank}
                     for t := 1 to 2 do
                        if (loc.x <> tanks[t].loc.x) or (loc.y <> tanks[t].loc.y)
                           then begin
                              whack := incoords( hyp, Tanks[t].loc,
                                                size, Tanks[t].size,
                                                loc );

                              {put as close as possible to other Tank}
                              putclose( hyp, loc, tanks[t].loc, size, tanks[t].size, whack );

                           end; {then}

                     {check if hitting walls}
                     for w := 1 to numwalls do
                     begin
                        whack := incoords( hyp, walls[w].loc,
                                          size, walls[w].size,
                                          loc );

                        {put as close to wall as possible}
                        if whack <> nohit
                           then
                           if walls[w].visible <> cloud
                              then putclose( hyp, loc, walls[w].loc, size, walls[w].size, whack )

                     end; {for w}

                     old := loc;
                     loc := hyp;
                     updateTankstats( tank );

                     {check if just got an item}
                     if (incoords( loc, item.loc, size, item.size, loc ) <> nohit)
                        and isitem
                        then getitem( tank );


                  end
                  else begin
                     old := loc;

                     Gunleft( tank );
                     Tankright( tank );
                     inc( count.hit );
                  end;

               if tank.count.invis <= invislength
                  then inc( tank.count.invis );

               if tank.count.shield <= shieldlength
                  then inc( tank.count.shield );

            end;

         (*===========================================================*)

            PROCEDURE Moveshots;

            var whack : hittype;

            begin
               s := 1;

               {cycle through all shots}
               while (s <= TotShots) do
                  with shots[s] do
                  begin

                     {calculate hypothetical new x,y}
                     hyp.x := trunc(loc.x + Move.x);
                     hyp.y := trunc(loc.y + Move.y);

                     {check if off top/bottom of screen}
                     if (hyp.x > screen.MaxX) Or (hyp.x < 0)
                        then shothitedge( shots[s], side );
                     if (hyp.y > screen.MaxFightY) Or (hyp.y < 0)
                        then shothitedge( shots[s], top );

                     {check if hit Tank}
                     for t := 1 to 2 do
                        if incoords( hyp, Tanks[t].loc,
                                    shotspec, Tanks[t].hit,
                                    loc ) <> nohit
                           then if not( justshot and (source = t)) {check if hitting}
                              then shothitTank( shots[s], tanks[t] );    {tank that just shot}




                     for w := 1 to numwalls do
                     begin
                        whack := incoords( hyp, walls[w].loc,
                                          shotspec, walls[w].size,
                                          loc );
                        if whack <> nohit
                           then begin
                              if whack = inwall
                                 then whack := incoords( loc, walls[w].loc,        {checks one step}
                                                        shotspec, walls[w].size,  {further back   }
                                                        old );
                              if walls[w].shotblock
                                 then shothitwall( shots[s], walls[w], whack )
                           end;

                     end;

                     if justshot                                    {once it is not hitting}
                        then if incoords( hyp, Tanks[source].loc,        {tank it can be freed}
                                         shotspec, Tanks[source].size,
                                         loc ) = nohit
                           then justshot := false;

                     old := loc;
                     loc := hyp;
                     inc( s );
                  end; {big while/with}
            end; { Moveshots }

         (*===========================================*)

            PROCEDURE MoveExplosion( var weap : weaprectype );
            {expand explosion one step and check for damage}


            var a, x1, y1, x2, y2 : real;
               angle : angletype; {angle of tank from explosion}

            begin
               with Weap do
               begin

                  inc( ex.count );
                  if ex.count <= ex.width
                     then begin
                        for t := 1 to 2 do
                        begin
                           {use distance formula for explosion radius}
                           x1 := loc.x;
                           y1 := loc.y;
                           x2 := Tanks[t].loc.x;
                           y2 := Tanks[t].loc.y;

                           if (sqr(x2 - x1) +
                               sqr(y2 - y1) <=
                               sqr(ex.count * exringsize + tanks[t].hit.x / 2) )
                              and (Tanks[t].count.hit > rotsteps)
                              and (tanks[t].count.shield > shieldlength )

                              then
                              Tanks[t].count.life := Tanks[t].count.life - ex.dam;
                        end; {for t}

                        {this one is already an explosion, so this loop won't affect it}
                        for o := 1 to numWeaps do
                        begin
                           x1 := loc.x;
                           y1 := loc.y;
                           x2 := Weaps[o].loc.x;
                           y2 := Weaps[o].loc.y;


                           if sqr(x2 - x1) +
                              sqr(y2 - y1) <=
                              sqr(ex.count * exringsize / 2) {weapon must be near center}
                              {of explosion to be triggered}
                              then
                              Weaps[o].kind := explosion;
                        end; {for o}


                     end {then}
                     else removed := true;

               end; {with weaps[p]}
            end; {moveexplosion}


         (*=============================================*)

            PROCEDURE MoveHeavyGun( var weap : weaprectype );

            var whack : hittype;

            begin
               with Weap do
               begin

                  {calculate hypothetical new x,y}
                  hyp.x := loc.x + Move.x;
                  hyp.y := loc.y + Move.y;


                  {check if off top/bottom of screen}
                  if (hyp.x > screen.MaxX) Or (hyp.x < 0)
                     or (hyp.y > screen.MaxFightY) Or (hyp.y < 0)

                     then begin
                        size.x := 0;
                        size.y := 0;

                        PutCloseToEdge( hyp, size );

                        kind := explosion;
                        loc := hyp;
                     end;

                  {check if hit tanks}
                  for t := 1 to 2 do
                  begin
                     whack := incoords( hyp, Tanks[t].loc,
                                       size, Tanks[t].hit,
                                       loc );

                     if not ( justshot and (source = t))
                        and ( whack <> nohit )       {check if hitting}
                        then begin                      {tank that just shot}
                           putclose( hyp, loc, tanks[t].loc,
                                    size, tanks[t].hit, whack);
                           kind := explosion;
                           loc := hyp;
                        end; {then}
                  end; {for t}

                  for w := 1 to numwalls do
                  begin
                     whack :=  incoords( hyp, walls[w].loc,
                                        size, walls[w].size,
                                        loc );
                     if whack <> nohit
                        then begin
                           putclose( hyp, loc, walls[w].loc,
                                    size, walls[w].size, whack);
                           kind := explosion;
                           loc := hyp;
                        end; {then}
                  end; {for w}



                  if justshot                                    {once it is not hitting}
                     then if incoords( hyp, Tanks[source].loc,        {tank it can be freed}
                                      size, Tanks[source].size,
                                      loc ) = nohit
                        then justshot := false;

                  old := loc;
                  loc := hyp;

                  if kind = explosion
                     then MoveExplosion( weap );

               end; {big with}


            end; { MoveHeavyGun }

         (*=========================================*)

            PROCEDURE Movemissile( var weap : weaprectype );

            var whack : hittype;

            begin
               with Weap do
               begin

                  {calculate hypothetical new x,y}
                  hyp.x := loc.x + Move.x;
                  hyp.y := loc.y + Move.y;

                  {check if off top/bottom of screen}
                  if (hyp.x + size.x > screen.MaxX) Or (hyp.x - size.x < 0)
                     or (hyp.y + size.y > screen.MaxFightY) Or (hyp.y - size.y < 0)

                     then begin
                        size.x := 0;
                        size.y := 0;

                        PutCloseToEdge( hyp, size );

                        kind := explosion;
                        loc := hyp;
                        Tanks[source].MissileFired := false;
                     end;

                  {check if hit tanks}
                  for t := 1 to 2 do
                  begin
                     whack := incoords( hyp, Tanks[t].loc,
                                       size, Tanks[t].hit,
                                       loc );

                     if not ( justshot and (source = t))
                        and ( whack <> nohit )  {check if hitting}
                        then begin                      {tank that just shot}
                           size.x :=0;
                           size.x :=0;
                           putclose( hyp, loc, tanks[t].loc,
                                    size, tanks[t].hit, whack);

                           kind := explosion;
                           loc := hyp;
                           Tanks[source].MissileFired := false;
                        end;
                  end; {for t}

                  for w := 1 to numwalls do
                  begin
                     whack :=  incoords( hyp, walls[w].loc,
                                        size, walls[w].size,
                                        loc );
                     if whack <> nohit
                        then begin
                           size.x := 0;
                           size.y := 0;
                           putclose( hyp, loc, walls[w].loc,
                                    size, walls[w].size, whack);
                           kind := explosion;
                           loc := hyp;
                           Tanks[source].MissileFired := false;
                        end;
                  end;

                  if justshot                                    {once it is not hitting}
                     then if incoords( hyp, Tanks[source].loc,        {tank it can be freed}
                                      size, Tanks[source].size,
                                      loc ) = nohit
                        then justshot := false;

                  old := loc;
                  loc := hyp;

                  inc( counter );

                  if counter > 3
                     then begin
                        vec.mag := vec.mag + count2;
                        if count2 < 5
                           then inc( count2 );
                        counter := 1;
                        Move.x := round(cosk[vec.dir] * vec.mag);
                        Move.y := round(sink[vec.dir] * vec.mag);
                     end;

                  if kind = explosion
                     then MoveExplosion( weap );

               end; {big with}

            end; { Movemissile }

         (*==================================================*)

            PROCEDURE tickbomb( var weap : weaprectype );

            begin
               inc( Weap.counter );
               if Weap.counter > fuselength
                  then
                  Weap.kind := explosion;
            end;

         (*=============================================*)

            PROCEDURE checkmine( var weap : weaprectype );

            begin
               with weap do
               begin
                  {check Tanks}
                  for t := 1 to 2 do
                     if incoords( loc, Tanks[t].loc,
                                 size, Tanks[t].hit,
                                 loc ) <> nohit
                        then if not( justshot and (source = t)) {check if hitting}
                           then                             {tank that just shot}
                           kind := explosion;


                  if justshot                                    {once it is not hitting}
                     then if incoords( loc, Tanks[source].loc,        {tank it can be freed}
                                      size, Tanks[source].size,
                                      loc ) = nohit
                        then justshot := false;

               end;
            end;

         (*=============================================*)

            PROCEDURE MoveWeaps;

            begin
               for p := 1 to numWeaps do
                  case Weaps[p].kind of
                    missile : Movemissile( weaps[p] );
                    bomb : tickbomb( weaps[p] );
                    mine : checkmine( weaps[p] );
                    HeavyGun : MoveheavyGun( weaps[p] );
                    explosion : Moveexplosion( weaps[p] );
                  end; {case}
            end;


         (******************************************************)

         (* ETC ************************************************)

         (******************************************************)

            PROCEDURE genitem;
            {generates a new item on the battlefield, and gets rid of old
            item if it exists}

            var
               badloc : boolean;
               kind : itemtype;

            begin
               with item do
               begin
                  if isitem
                     then begin
                        reMoved := true;
                        old := loc;
                     end;

                  randomize;

                  i := random( 99 ) + 1;

                  Weap := none;
                  kind := none;

                  {figure out by percent which item to generate}
                  while (i > 0) and (Weap = none) do
                  begin
                     inc( kind );
                     if ItemProb[kind] >= i
                        then Weap := kind
                     else i := i - ItemProb[kind]

                  end;

                  size.x := 10;
                  size.y := 10;


                  repeat
                     badloc := false;
                     loc.x := random( round(SCREEN.MaxX - 2 * size.x) ) + size.x;
                     loc.y := random( round(SCREEN.MaxFighty - 2 * size.y) ) + size.y;

                     for w := 1 to numwalls do
                        if incoords( loc, walls[w].loc,
                                    size, walls[w].size,
                                    loc )
                           <> nohit
                           then badloc := true;

                     for t := 1 to 2 do
                        if incoords( loc, Tanks[t].loc,
                                    size, Tanks[t].size,
                                    loc ) <> nohit
                           then badloc := true;

                  until not badloc;

                  isitem := true;


               end;
            end;

         (*=============================================*)

            PROCEDURE cleanupshots;
            {takes shots that have been removed out of storage}

            var s : integer;

            begin

               s:= 1;
               while s <= TotShots do
                  with shots[s] do
                  begin
                     if reMoved then
                     begin
                        {decrement appropriate Tank's shot tally}

                        if not multi
                           then dec(Tanks[source].count.shots);

                        {this shot is over written by last shot}
                        shots[s] := shots[TotShots];

                        dec( TotShots )
                     end;
                     inc( s );
                  end;

            end;

         (*==================================================*)

            PROCEDURE cleanupWeaps;
            {takes weaps that have been removed out of storage}

            var p : integer;

            begin

               p:= 1;
               while p <= numWeaps do
                  with Weaps[p] do
                  begin
                     if reMoved then
                     begin
                        {this Weap is over written by last Weap}
                        Weaps[p] := Weaps[numWeaps];

                        dec( numWeaps )
                     end;
                     inc( p );
                  end;

            end;

         (*==================================================*)

            FUNCTION Tankdeath : boolean;
            {tank is dead}

            var i, o : integer;
               s : string;

            begin
               for i := 1 to 50 do
               begin
                  colors.null := random( 16 );
                  blankscreen;
                  switchpages;
                  delay(20);
               end;


               colors.null := lightgray;
               blankscreen;
               blankbottom;

               if tanks[1].count.life > tanks[2].count.life
                  then s := 'Green Wins'
               else if tanks[2].count.life > tanks[1].count.life
                  then s := 'Purple Wins'
               else s := 'Draw';

               newcolor( WHITE );
               outTextXY( 5, screen.MaxFightY + 5, s );


               s := 'Again? (Y/N)';
               outTextXY( 5, screen.MaxFightY + 20, s );

               while keypressed do readkey;
               switchpages;

               tankdeath := upcase( readkey ) = 'Y';

            end;

         (********************************************************)

         (* SIMULATION PROCEDURES ********************************)

         (********************************************************)

            function quitgame( var again : boolean ) : boolean;

            var s : string;
               q : boolean;
            begin
               blankbottom;

               newcolor( WHITE );
               s := 'Are you sure? (Y/N)';
               outTextXY( 5, screen.MaxFightY + 5, s );
               switchpages;
               while keypressed do readkey; {flush keyboard buffer}

               q := upcase( readkey ) = 'Y';
               quitgame := q;

               switchpages;
               while keypressed do readkey; {flush keyboard buffer}

               if q then
               begin
                  s := 'Again? (Y/N)';
                  outTextXY( 5, screen.MaxFightY + 20, s );
                  switchpages;
                  again := upcase( readkey ) = 'Y';
               end;

            end;

         (*==================================================*)

            function processinput( c : char; var again : boolean ) : boolean;

            {boolean value of processinput is the option to quit}

            begin
               processinput := false;
               case c of
                 '-' : if speed < 800 then speed := speed + 100;
                 '=' : if speed > 0 then speed := speed - 100;

                 {Tank 2 (purple)}
                 {esc}
                 'D' : Tankleft( tanks[2] );
                 'G' : Tankright( tanks[2] );
                 'H' : Gunleft( tanks[2] );
                 'K' : Gunright( tanks[2] );
                 'J' : if ( Tanks[2].count.shots < Tanks[2].maxshots )
                    and (TotShots < TotMaxShots)
                    then fireGun( tanks[2] );

                 'F' : if Tanks[2].vec.mag > MinSpeed
                    then geardown( tanks[2] );

                 'R' : if Tanks[2].vec.mag < MaxSpeed
                    then gearup( tanks[2] );
                 ' ' : changeWeap( tanks[2] );

                 'U' : useWeap( tanks[2] );


                 {Tank 1 (green)}
                 chr(0) :

                 case readkey of
                   'H' : if Tanks[1].vec.mag < MaxSpeed {up button}
                      then gearup( tanks[1] );

                   'P' : if Tanks[1].vec.mag > MinSpeed {down button}
                      then geardown( tanks[1] );

                   'K' : Tankleft( tanks[1] );   {left button}
                   'M' : Tankright( tanks[1] );
                 end;

                 '4' : Gunleft( tanks[1] );
                 '6' : Gunright( tanks[1] );
                 '5' : if ( Tanks[1].count.shots < Tanks[1].maxshots )
                    and (TotShots < TotMaxShots)
                    then fireGun( tanks[1] );
                 '0' : changeWeap( tanks[1] );

                 '8' : useWeap( tanks[1] );

                 char( 27 ) : processinput := quitgame( again );
               end;
            end;
         (************************************************)

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
         (************************************************)
            PROCEDURE DukeItOut;

            var again,
               quit : boolean;
               cycles : longint;
               temphunds,
               tempsecs,
               temphours,
               tempmins : word;
               OldTotalHunds,
               TotalHunds : longint;  {hundredths of seconds}

            DifHunds : longint;

            begin
               repeat
                  initsettings;

                  blankscreen;
                  switchpages;
                  blankscreen;
                  loadmap;

                  initTanks;
                  updatescreen;

                  Totalhunds := 0;

                  quit := false;
                  cycles := 1;



                  repeat {quit}
                     gettime( temphours, tempmins, tempsecs, temphunds );

                     oldTotalHunds := Totalhunds;

                     TotalHunds := (((  temphours * 60)
                                    + tempmins * 60)
                                    + tempsecs * 100) +
                     temphunds;     {converts to hundredths of seconds}


                     if totalhunds < oldtotalhunds
                        then DifHunds := (8640000 - oldtotalhunds) + totalhunds
                     else DifHunds := totalhunds - oldtotalhunds;

                     cycles := cycles + DifHunds;

                     if cycles > SPEED
                        then
                     begin
                        cycles := 1;
                        {Move all the stuff }

                        MoveTank( tanks[1] );
                        MoveTank( tanks[2] );
                        Moveshots;
                        MoveWeaps;

                        inc(itemcount);

                        {generate new item if appropriate}
                        if itemcount = iteminterval
                           then begin
                              genitem;
                              itemcount := 0
                           end;

                        updatescreen;

                        cleanupshots;
                        cleanupWeaps;

                        for t := 1 to 2 do
                           if Tanks[t].count.life < 1
                              then begin
                                 quit := true;
                                 again := Tankdeath;
                              end;

                     end; {then}



                     if (keypressed and (not quit))
                        then quit := processinput(upcase(readkey), again);

                  until quit;
               until not(again)

            END;

         (***************************************************
          ****************************************************

          *********    **    ***   *** ***   ***
          *********  ******  ****  *** ***  ***
          *********  ******  ***** *** *** ***
          ***    ***  *** ********* ******
          ***    ***  *** ********* ******
          ***    ******** *** ***** *** ***
          ***    ***  *** ***  **** ***  ***
          ***    ***  *** ***   *** ***   ***

          ***     ***    **    ******     *******
          ***     ***  ******  *******   ********
          ***     ***  ******  ***  ***  **
          *** *** *** ***  *** ***  ***  *******
          *** *** *** ***  *** *******    *******
          *********  ******** *** ***         **
          *********  ***  *** ***  ***  ********
          *** ***   ***  *** ***   *** *******

          ****************************************************
          ****************************************************)

         BEGIN
            ClrScr;
            DemoControls;
            writeln( '<<<Press Any Key To Continue>>>' );
            readkey;

            inittrig;
            initsettings;

            setupgraphics( EGA, EGAHi );
            getvidstats;

            initIimages;

            dukeitout;
            
            closegraph;
            
            while keypressed do readkey;

         END.


      {NOTE: tank wiggles, change so that all stats are based upon current
      position.}
      {ok, too get rid of wiggle, maybe must round middle of tank off, then
decide where edges are...}
