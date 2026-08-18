echo ==========================================================
echo   GENIE ENGINE, LIVE ON LICH  --  showcase (%scriptname)
echo   run started at @time@
echo ==========================================================
timer start
echo
echo -- variables and eval() string functions --
setvariable target You have 42 silver coins
echo   target      : %target
eval loud toupper("%target")
echo   toupper     : %loud
eval size len("%target")
echo   length      : %size
eval hascoins contains("%target", "silver")
echo   has 'silver': %hascoins
echo
echo -- regex capture with matchre() --
eval matched matchre("%target", "(\d+) silver")
echo   matched?    : %matched   (captured number = $1)
echo
echo -- arrays --
setvariable spells fire|ice|lightning|earth
echo   %spells.length spells; spell #2 is %spells(2)
echo
echo -- math verb and evalmath() (note: ^ is left-assoc) --
var gold 100
math gold add 55
echo   math: 100 + 55 = %gold
evalmath hyp sqrt(3^2 + 4^2)
echo   evalmath: sqrt(3^2 + 4^2) = %hyp
echo
echo -- fibonacci loop (labels + counter + evalmath) --
setvariable a 0
setvariable b 1
counter set 0
fib:
counter add 1
echo   fib(%c) = %a
evalmath next %a + %b
setvariable a %b
setvariable b %next
if %c >= 10 then goto fibdone
goto fib
fibdone:
echo
echo -- block if / else --
random 1 6
echo   rolled %r on a d6
if %r >= 4 then
{
  echo     high roll (>= 4)
}
else
{
  echo     low roll (< 4)
}
echo
echo -- subroutine with an argument --
gosub greet Elanthia
echo   (returned from subroutine)
echo
echo -- global variable + front-end hook --
put #var mode showcase
echo   global variable mode is now '$mode'
put #highlight cyan Genie
echo   (emitted a genieHook to highlight 'Genie' for hook-aware front-ends)
echo
echo -- async action (register + remove) --
action var sensed 1 when you feel a strange sensation
echo   registered an action (fires on 'you feel a strange sensation')
action remove you feel a strange sensation
echo   removed the action
echo
echo -- live round-trip: put + match / matchre + matchwait --
put look
match roomseen Obvious
matchre roomseen2 (?i)obvious
matchwait 3
echo   (no room line within 3s -- fine for this demo)
goto donelook
roomseen:
echo   room matched via match!
goto donelook
roomseen2:
echo   room matched via matchre!
donelook:
echo
echo -- reserved game-state globals (live from the game) --
echo   unix time : $unixtime
echo   health    : $health
echo   room      : $roomname
echo
echo -- include: a helper .cmd loaded at compile time, called via gosub --
gosub libgreet Traveler
echo   libloaded flag is now %libloaded
echo
echo -- timing --
pause 1
echo   after a 1s pause, the script timer reads @timer@ s
echo ==========================================================
echo   showcase complete -- every verb these scripts use, live in Lich
echo ==========================================================
exit
greet:
echo   Hello, $1! Welcome to the Genie engine.
return
include genie-showcase-lib.cmd
