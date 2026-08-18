echo ==========================================================
echo   GENIE ENGINE, LIVE ON LICH  --  showcase (%scriptname)
echo   run started at @time@
echo ==========================================================
timer start
echo
echo -- string variables and eval() functions --
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
echo   I know %spells.length spells; spell #2 is %spells(2)
echo
echo -- arithmetic via evalmath() (note: ^ is left-assoc) --
evalmath hyp sqrt(3^2 + 4^2)
echo   sqrt(3^2 + 4^2) = %hyp
evalmath biggest max(7, 42, 19)
echo   max(7,42,19)    = %biggest
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
echo -- conditionals + random --
random 1 6
echo   rolled %r on a d6
if %r >= 5 then echo     high roll!
if %r <= 2 then echo     low roll!
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
echo -- timing --
pause 1
echo   after a 1s pause, the script timer reads @timer@ s
echo ==========================================================
echo   showcase complete -- Genie scripts run natively in Lich
echo ==========================================================
exit
greet:
echo   Hello, $1! Welcome to the Genie engine.
return
