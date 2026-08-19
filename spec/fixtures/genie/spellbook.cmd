var abbrev 0
var targetchest 0
var targethead 0

# Requries
# commonjustice.cmd
# commonbg.cmd
# commonbow.cmd

SBReturn:
goto %spellbookreturn

# Aug and Warding

CommonPrepPF:
if ($pf != 1) then put #var pf 1
# put #class pfspellprep on
put #var pfspellprepped 1
if ($pfspellready != 0) then put #var pfspellready 0
put #class pfspellloss on
put #class pfspellprepared on
goto CommonPrepPF2

CommonPrepPF2:
matchre CommonPrepPF2 ^\.\.\.wait|^Sorry\,
# matchre MagicExit ^But you're already|^You are already preparing|^Invoke what\?$
matchre CheckSpellStatus ^Invoke what\?$
matchre NoCasting ^Something in the area interferes with your spell preparations\.$
matchre CheckSpellStatus ^You begin channeling mana
match RelPFError You are already channeling a spell
match SpellStollen You seem to have forgotten this spell!
match CalmedEffectPFSB Your desire to prepare this offensive spell suddenly slips away.
put #var pfspelltimer #evalmath ($unixtime + 69)
put #var pfpausetime #evalmath ($unixtime + %secpausepf)
if ($longpause != 0) then
{
    put #var pfpausetime #evalmath ($pfpausetime + $longpause)
}
put invoke my cube %abbrev $pfprepm
matchwait

CommonPrep:
if ($pf != 0) then put #var pf 0
if ($spelllost != 0) then put #var spelllost 0
if ($tmspellready != 0) then put #var tmspellready 0
if ($attackspell != 0) then put #var attackspell 0
if ($stattackspell != 0) then put #var stattackspell 0
if ($spellready != 0) then put #var spellready 0
put #class spelllostwatcher on
put #class spellprepared on
goto CommonPrep2

CommonPrep2:
matchre CommonPrep2 ^\.\.\.wait|^Sorry\,
matchre RegsRelError ^But you're already|^You are already preparing|^You have already fully
matchre NoCasting ^Something in the area interferes with your spell preparations\.$
matchre CommonPrepTime ^You trace a geometric sigil in the air
matchre PeaceRoomSB ^As you attempt to prepare the spell, a sense of overwhelming peace washes over you\.$|^Your desire to prepare this offensive spell suddenly slips away\.$
match SpellStollen You seem to have forgotten this spell!
match CalmedEffectSB Your desire to prepare this offensive spell suddenly slips away.
put prep %abbrev $prepm
matchwait

CommonPrepTime:
if ($longpause != 0) then put #var pausetime #evalmath ($pausetime + $longpause)
else put #var pausetime #evalmath ($unixtime + %pausesec)
goto CheckSpellStatus

CommonCastPF:
put #var pf 1
put #class spellcast on
matchre CommonCastPF ^\.\.\.wait|^Sorry\,
matchre CheckSpellStatus ^You gesture|^The mental strain of initiating a cyclic spell
matchre RelPFError ^I do not understand what you mean\.|^You wave your spiritwood cube around\.|^Your spell.*?backfires
match CalmedEffectPFSB You don't feel like casting that kind of spell right now.
put wave my cube
matchwait

CommonCast:
put #var pf 0
put #class spellcast on
matchre CommonCast ^\.\.\.wait|^Sorry\,
matchre RegsCastVars ^You gesture|^The mental strain of initiating a cyclic spell|^You place your hands on your temples\.|^The spell pattern collapses
matchre RegsRelError ^You don't have a spell prepared|^Your spell.*?backfires
match CalmedEffectSB You don't feel like casting that kind of spell right now.
put cast
matchwait

RegsCastVars:
var mainslotchecked 0
goto CheckSpellStatus

CommonCastRT:
put #var pf 0
put #class spellcast on
matchre CommonCastRT ^\.\.\.wait|^Sorry\,
matchre RegsCastVarsRT ^You gesture|^The mental strain of initiating a cyclic spell|^Your spell.*?backfires|^The spell pattern collapses
match RegsRelError You don't have a spell prepared
match CalmedEffectSB You don't feel like casting that kind of spell right now.
put cast
matchwait

RegsCastVarsRT:
var mainslotchecked 0
goto MagicExit

RegsRelError:
var mainslotchecked 0
var commonrel 1
# var relpathway 1
var relreturn CheckSpellStatus
goto RelSpell

SBRelRes:
put .res
exit

RelPFError:
var relpf 1
var relreturn CheckSpellStatus
goto RelSpell

SpellStollen:
var abbrevstring %abbrev spelllosstimer
eval localspellloss replacere("%abbrevstring", "\s", "")
put #var %localspellloss #evalmath ($unixtime + 45)
goto CheckSpellStatus

PeaceRoomSB:
put #var peaceroom 1
var commonrel 1
var relreturn CheckSpellStatus
goto RelSpell

CalmedEffectPFSB:
put #var calmed 1
goto RelPFError

CalmedEffectSB:
put #var calmed 1
goto RegsRelError

MAF:
var abbrev maf
if (%cast = 1) then goto CheckES
if (%pf = 1) then goto MAFManaCheckPF
goto MAFManaCheck

MAFManaCheckPF:
if ($mana > 69) then
{
    # put #var pfpausetime #evalmath ($unixtime + 9)
    var secpausepf 9
    put #var pfprepm 100
    put #var pfharn1 0
    put #var pfharn2 0
    put #var pfharnlimit 0
    var getpfocreturn CommonPrepPF
    goto GetPFoc
}
# put #var pfpausetime #evalmath ($unixtime + 5)
if ($boosttimer > $unixtime) then
{
    var secpausepf 7
}
else
{
    var secpausepf 5
}
put #var pfprepm 34
put #var pfharn1 33
put #var pfharn2 33
put #var pfharnlimit 2
var getpfocreturn CommonPrepPF
goto GetPFoc

MAFManaCheck:
if ($mana > 69) then
{
    # put #var pausetime #evalmath ($unixtime + 9)
    var pausesec 9
    put #var prepm 100
    put #var harn1 0
    put #var harn2 0
    put #var harnlimit 0
    goto CommonPrep
}
# put #var pausetime #evalmath ($unixtime + 5)
if ($boosttimer > $unixtime) then
{
    var pausesec 11
}
else
{
    var pausesec 9
}
put #var prepm 34
put #var harn1 33
put #var harn2 33
put #var harnlimit 2
goto CommonPrep

CheckES:
if ($SpellTimer.EtherealShield.active = 0) then goto CastMAF
matchre CheckES ^\.\.\.wait|^Sorry\,
matchre CastMAF ^The shimmering ethereal shield fades|^Release what\?$
put rel es
matchwait

CastMAF:
if (%pf = 1) then 
{
    put #class mafrefresh on
    var getpfocreturn CheckSpellStance
    put #var autostancedef 1
    put #var autostancedur 0
    put #var autostanceinteg 0
    put #var autostancepot 0
    var spellstancereturn MAFCastPF
    goto CheckSpellStance
}
put #class mafrefresh on
put #var autostancedef 1
put #var autostancedur 0
put #var autostanceinteg 0
put #var autostancepot 0
var spellstancereturn MAFCast
goto CheckSpellStance

MAFCastPF:
put #var pf 1
put #class spellcast on
matchre MAFCastPF ^\.\.\.wait|^Sorry\,
matchre MAFCastVars ^You gesture|^The mental strain of initiating a cyclic spell
matchre RelPFError ^I do not understand what you mean\.|^You wave your spiritwood cube around\.|^Your spell.*?backfires
put wave my cube
matchwait

MAFCast:
put #var pf 0
put #class spellcast on
matchre MAFCast ^\.\.\.wait|^Sorry\,
matchre MAFCastVars ^You gesture
matchre RegsRelError ^You don't have a spell prepared|^Your spell.*?backfires
put cast
matchwait

MAFCastVars:
put #var mafcasttimer #evalmath ($unixtime +5)
if (%pf = 1) then goto CheckSpellStatus
goto RegsCastVars

GI:
var abbrev gi
if (%cast = 1) then
{
    if (%pf = 1) then
    {
        var getpfocreturn CheckSpellStance
        put #var autostancedef 1
        put #var autostancedur 0
        put #var autostanceinteg 0
        put #var autostancepot 0
        var spellstancereturn CommonCastPF
        goto GetPFoc
    }
}
if (%cast = 1) then
{
    put #var autostancedef 1
    put #var autostancedur 0
    put #var autostanceinteg 0
    put #var autostancepot 0
    var spellstancereturn CommonCast
    goto CheckSpellStance
}
if (%pf = 1) then goto GIManaCheckPF
goto GIManaCheck

GIManaCheckPF:
if ($mana > 69) then
{
    # put #var pfpausetime #evalmath ($unixtime + 10)
    var secpausepf 10
    put #var pfprepm 100
    put #var pfharn1 0
    put #var pfharn2 0
    put #var pfharnlimit 0
    var getpfocreturn CommonPrepPF
    goto GetPFoc
}
# put #var pfpausetime #evalmath ($unixtime + 6)
if ($boosttimer > $unixtime) then
{
    var secpausepf 8
}
else
{
    var secpausepf 6
}
put #var pfprepm 34
put #var pfharn1 33
put #var pfharn2 33
put #var pfharnlimit 2
var getpfocreturn CommonPrepPF
goto GetPFoc

GIManaCheck:
if ($mana > 69) then
{
    # put #var pausetime #evalmath ($unixtime + 10)
    var pausesec 10
    put #var prepm 100
    put #var harn1 0
    put #var harn2 0
    put #var harnlimit 0
    goto CommonPrep
}
# put #var pausetime #evalmath ($unixtime + 6)
if ($boosttimer > $unixtime) then
{
    var pausesec 8
}
else
{
    var pausesec 6
}
put #var prepm 34
put #var harn1 33
put #var harn2 33
put #var harnlimit 2
goto CommonPrep

ES:
var abbrev es
if (%cast = 1) then goto CheckMAFSB
if (%pf = 1) then goto ESManaCheckPF
goto ESManaCheck

ESManaCheckPF:
if ($mana > 69) then
{
    # put #var pfpausetime #evalmath ($unixtime + 9)
    var secpausepf 9
    put #var pfprepm 100
    put #var pfharn1 0
    put #var pfharn2 0
    put #var pfharnlimit 0
    var getpfocreturn CommonPrepPF
    goto GetPFoc
}
# put #var pfpausetime #evalmath ($unixtime + 5)
if ($boosttimer > $unixtime) then
{
    var secpausepf 7
}
else
{
    var secpausepf 5
}
put #var pfprepm 34
put #var pfharn1 33
put #var pfharn2 33
put #var pfharnlimit 2
var getpfocreturn CommonPrepPF
goto GetPFoc

ESManaCheck:
if ($mana > 69) then
{
    # put #var pausetime #evalmath ($unixtime + 9)
    var pausesec 9
    put #var prepm 100
    put #var harn1 0
    put #var harn2 0
    put #var harnlimit 0
    goto CommonPrep
}
# put #var pausetime #evalmath ($unixtime + 5)
if ($boosttimer > $unixtime) then
{
    var pausesec 7
}
else
{
    var pausesec 5
}
put #var prepm 34
put #var harn1 33
put #var harn2 33
put #var harnlimit 2
goto CommonPrep

CheckMAFSB:
if ($SpellTimer.ManifestForce.active = 0) then goto CastES
matchre CheckMAFSB ^\.\.\.wait|^Sorry\,
matchre CastES ^The air around you shimmers|^Release what\?
put rel maf
matchwait

CastES:
if (%cast = 1) then
{
    if (%pf = 1) then
    {
        var getpfocreturn CheckSpellStance
        put #var autostancedef 1
        put #var autostancedur 0
        put #var autostanceinteg 0
        put #var autostancepot 0
        var spellstancereturn CommonCastPF
        goto GetPFoc
    }
}
put #var autostancedef 1
put #var autostancedur 0
put #var autostanceinteg 0
put #var autostancepot 0
var spellstancereturn CommonCast
goto CheckSpellStance

Tranq:
var abbrev tranquility
if (%cast = 1) then
{
    put #var autostancedef 1
    put #var autostancedur 0
    put #var autostanceinteg 0
    put #var autostancepot 0
    var spellstancereturn TranqCast
    goto CheckSpellStance
}
# put #var pausetime #evalmath ($unixtime + 14)
if matchre ("$roomname" , "Wyvern Arena") then
{
    var pausesec 16
}
else
{
    var pausesec 14
}
put #var prepm 1
put #var harn1 0
put #var harn2 0
put #var harnlimit 0
goto TranqPrep

TranqPrep:
put #var pf 0
put #var spelllost 0
put #var tmspellready 0
put #var attackspell 0
put #var stattackspell 0
put #var spellready 0
put #class spelllostwatcher on
put #class spellprepared on
goto TranqPrep2

TranqPrep2:
matchre TranqPrep2 ^\.\.\.wait|^Sorry\,
matchre RegsRelError ^But you're already|^You are already preparing|^You have already fully
matchre NoCasting ^Something in the area interferes with your spell preparations\.
matchre CheckSpellStatus ^Closing your eyes, you carefully bend some mana streams
match HeadDamageSB You are in no condition to do that.
put #var pausetime #evalmath ($unixtime + %pausesec)
if ($longpause != 0) then
{
    put #var pausetime #evalmath ($pausetime + $longpause)
}
put invoke my tattoo
matchwait

HeadDamageSB:
put #var headdamage 1
goto RegsRel

TranqCast:
# var shleftreturn TranqFlame
# var shrightreturn TranqFlame
# goto EmptyOneHand

# TranqFlame:
# matchre TranqFlame ^\.\.\.wait|^Sorry\,
# matchre TranqCast2 ^You get|^You pick up|^You are already
# match PFocHandDamaged You can't pick that up with your hand that damaged.
# match TranqCast You need a free hand to pick that up.
# put get my flame
# matchwait

TranqCast2:
put #var pf 0
put #class spellcast on
if ($backstop > 9) then put #var backstop 0
var tranq 0
action var tranq 1 when enhanced awareness of every nerve in your body\.$
goto TranqCast21

TranqCast21:
put #var backstop #evalmath ($backstop + 1)
matchre TranqCast21 ^\.\.\.wait|^Sorry\,
matchre AssessTranq Tranq Backstop $backstop$
put cast
put echo Tranq Backstop $backstop
matchwait

AssessTranq:
action remove enhanced awareness of every nerve in your body\.$
if (%tranq = 1) then goto TranqCast3
goto RegsRelError

TranqCast3:
put #var tranqcasttimer #evalmath ($unixtime + 5)
goto RegsCastVars

# StowFlame:
# matchre StowFlame ^\.\.\.wait|^Sorry\,
# matchre CheckSpellStatus ^You put|What were you 
# put put my flame in my $backpack
# matchwait

SUF:
var abbrev suf
if (%cast != 1) then goto SUF3
if ($sufbufftarget = 0) then goto SUF2
if (%pf = 1) then
{
    var getpfocreturn CheckSpellStance
    put #var autostancedef 0
    put #var autostancedur 0
    put #var autostanceinteg 1
    put #var autostancepot 0
    var spellstancereturn SUFBuffCast
    goto GetPFoc
}
goto SUFBuffCast

SUF2:
if (%pf = 1) then
{
    var getpfocreturn CheckSpellStance
    put #var autostancedef 0
    put #var autostancedur 0
    put #var autostanceinteg 1
    put #var autostancepot 0
    var spellstancereturn CommonCastPF
    goto GetPFoc
}
put #var autostancedef 0
put #var autostancedur 0
put #var autostanceinteg 1
put #var autostancepot 0
var spellstancereturn CommonCast
goto CheckSpellStance

SUF3:
if (%pf = 1) then goto SUFManaCheckPF
goto SUFManaCheck

SUFManaCheckPF:
if ($mana > 69) then
{
    # put #var pfpausetime #evalmath ($unixtime + 9)
    var secpausepf 9
    put #var pfprepm 88
    put #var pfharn1 0
    put #var pfharn2 0
    put #var pfharnlimit 0
    var getpfocreturn CommonPrepPF
    goto GetPFoc
}
put #var pfpausetime #evalmath ($unixtime + 5)
if ($boosttimer > $unixtime) then
{
    var secpausepf 7
}
else
{
    var secpausepf 5
}
put #var pfprepm 29
put #var pfharn1 30
put #var pfharn2 29
put #var pfharnlimit 2
var getpfocreturn CommonPrepPF
goto GetPFoc

SUFManaCheck:
if ($mana > 69) then
{
    # put #var pausetime #evalmath ($unixtime + 9)
    var pausesec 9
    put #var prepm 88
    put #var harn1 0
    put #var harn2 0
    put #var harnlimit 0
    goto CommonPrep
}
# put #var pausetime #evalmath ($unixtime + 5)
if ($boosttimer > $unixtime) then
{
    var pausesec 7
}
else
{
    var pausesec 5
}
put #var prepm 29
put #var harn1 30
put #var harn2 29
put #var harnlimit 2
goto CommonPrep

SUFBuffCast:
if (%pf = 1) then put #var pf 1
if (%pf != 1) then put #var pf 0
put #class spellcast on
matchre SUFBuffCast ^\.\.\.wait|^Sorry\,
matchre SUFBuffCast2 ^You gesture|^Your spell.*?backfires|^The spell pattern collapses
matchre RelPFError ^I do not understand what you mean\.|^You wave your spiritwood cube around\.
match RegsRelError You don't have a spell prepared
if ($pf = 1) then put wave my cube at $sufbufftarget
if ($pf != 1) then put cast $sufbufftarget
matchwait

SUFBuffCast2:
put #var sufbufftarget 0
if (%pf = 1) then goto CheckSpellStatus
goto RegsCastVars

SW:
var abbrev sw
if (%cast != 1) then goto SW3
if ($swbufftarget = 0) then goto SW2
if (%pf = 1) then
{
    var getpfocreturn CheckSpellStance
    put #var autostancedef 0
    put #var autostancedur 0
    put #var autostanceinteg 1
    put #var autostancepot 0
    var spellstancereturn SWBuffCast
    goto GetPFoc
}
goto SWBuffCast

SW2:
if (%pf = 1) then
{
    var getpfocreturn CheckSpellStance
    put #var autostancedef 0
    put #var autostancedur 0
    put #var autostanceinteg 1
    put #var autostancepot 0
    var spellstancereturn SWCastPF
    goto GetPFoc
}
put #var autostancedef 0
put #var autostancedur 0
put #var autostanceinteg 1
put #var autostancepot 0
var spellstancereturn SWCast
goto CheckSpellStance

SW3:
if (%pf = 1) then goto SWManaCheckPF
goto SWManaCheck

SWManaCheckPF:
if ($mana > 69) then
{
    # put #var pfpausetime #evalmath ($unixtime + 9)
    var secpausepf 9
    put #var pfprepm 88
    put #var pfharn1 0
    put #var pfharn2 0
    put #var pfharnlimit 0
    var getpfocreturn CommonPrepPF
    goto GetPFoc
}
# put #var pfpausetime #evalmath ($unixtime + 6)
if ($boosttimer > $unixtime) then
{
    var secpausepf 7
}
else
{
    var secpausepf 5
}
put #var pfprepm 29
put #var pfharn1 30
put #var pfharn2 29
put #var pfharnlimit 2
var getpfocreturn CommonPrepPF
goto GetPFoc

SWManaCheck:
if ($mana > 69) then
{
    # put #var pausetime #evalmath ($unixtime + 10)
    var pausesec 9
    put #var prepm 88
    put #var harn1 0
    put #var harn2 0
    put #var harnlimit 0
    goto CommonPrep
}
# put #var pausetime #evalmath ($unixtime + 6)
if ($boosttimer > $unixtime) then
{
    var pausesec 7
}
else
{
    var pausesec 5
}
put #var prepm 29
put #var harn1 30
put #var harn2 29
put #var harnlimit 2
goto CommonPrep

SWBuffCast:
if (%pf = 1) then put #var pf 1
if (%pf != 1) then put #var pf 0
put #class spellcast on
matchre SWBuffCast ^\.\.\.wait|^Sorry\,
matchre SWBuffCast2 ^You harness the currents of air 
matchre RelPFError ^I do not understand what you mean\.|^You wave your spiritwood cube around\.
matchre RegsRelError ^You don't have a spell prepared|^Your spell.*?backfires|^The spell pattern collapses
if ($pf = 1) then put wave my cube at $swbufftarget
if ($pf != 1) then put cast $swbufftarget
matchwait

SWBuffCast2:
# if ($swbufftarget = 0) then
# {
#     put #var swcasttimer #evalmath ($unixtime +5)
# }
put #var swbufftarget 0
if (%pf = 1) then goto CheckSpellStatus
goto RegsCastVars

SWCastPF:
put #var pf 1
put #class spellcast on
matchre SWCastPF ^\.\.\.wait|^Sorry\,
matchre SWCastVars allowing you to dodge more easily\.$
matchre RelPFError ^I do not understand what you mean\.|^You wave your spiritwood cube around\.|^Your spell.*?backfires
put wave my cube
matchwait

SWCast:
put #var pf 0
put #class spellcast on
matchre SWCast ^\.\.\.wait|^Sorry\,
matchre SWCastVars allowing you to dodge more easily\.$
matchre RegsRelError ^You don't have a spell prepared|^Your spell.*?backfires
put cast
matchwait

SWCastVars:
put #var swcasttimer #evalmath ($unixtime + 5)
if (%pf = 1) then goto CheckSpellStatus
goto RegsCastVars

VOI:
var abbrev voi
if (%cast != 1) then goto VOI3
if ($voibufftarget = 0) then goto VOI2
if (%pf = 1) then
{
    var getpfocreturn CheckSpellStance
    put #var autostancedef 1
    put #var autostancedur 0
    put #var autostanceinteg 0
    put #var autostancepot 0
    var spellstancereturn VOIBuffCast
    goto GetPFoc
}
goto VOIBuffCast

VOI2:
if (%pf = 1) then
{
    var getpfocreturn CheckSpellStance
    put #var autostancedef 1
    put #var autostancedur 0
    put #var autostanceinteg 0
    put #var autostancepot 0
    var spellstancereturn VoICastPF
    goto GetPFoc
}
put #var autostancedef 1
put #var autostancedur 0
put #var autostanceinteg 0
put #var autostancepot 0
var spellstancereturn VoICast
goto CheckSpellStance

VOI3:
if (%pf = 1) then goto VOIManaCheckPF
goto VOIManaCheck

VOIManaCheckPF:
if ($mana > 69) then
{
    # put #var pfpausetime #evalmath ($unixtime + 12)
    var secpausepf 12
    put #var pfprepm 100
    put #var pfharn1 0
    put #var pfharn2 0
    put #var pfharnlimit 0
    var getpfocreturn CommonPrepPF
    goto GetPFoc
}
# put #var pfpausetime #evalmath ($unixtime + 8)
if ($boosttimer > $unixtime) then
{
    var secpausepf 10
}
else
{
    var secpausepf 8
}
put #var pfprepm 34
put #var pfharn1 33
put #var pfharn2 33
put #var pfharnlimit 2
var getpfocreturn CommonPrepPF
goto GetPFoc

VOIManaCheck:
if ($mana > 69) then
{
    # put #var pausetime #evalmath ($unixtime + 12)
    var pausesec 12
    put #var prepm 100
    put #var harn1 0
    put #var harn2 0
    put #var harnlimit 0
    goto CommonPrep
}
# put #var pausetime #evalmath ($unixtime + 8)
if ($boosttimer > $unixtime) then
{
    var pausesec 10
}
else
{
    var pausesec 8
}
put #var prepm 34
put #var harn1 33
put #var harn2 33
put #var harnlimit 2
goto CommonPrep

VOIBuffCast:
if (%pf = 1) then put #var pf 1
if (%pf != 1) then put #var pf 0
put #class spellcast on
matchre VOIBuffCast ^\.\.\.wait|^Sorry\,
matchre VOIBuffCast2 ^You gesture|^Your spell.*?backfires|^The spell pattern collapses
matchre RelPFError ^I do not understand what you mean\.|^You wave your spiritwood cube around\.
match RegsRelError You don't have a spell prepared
if ($pf = 1) then put wave my cube at $voibufftarget
if ($pf != 1) then put cast $voibufftarget
matchwait

VOIBuffCast2:
put #var voibufftarget 0
if (%pf = 1) then goto CheckSpellStatus
goto RegsCastVars

VoICastPF:
put #var pf 1
put #class spellcast on
matchre VoICastPF ^\.\.\.wait|^Sorry\,
matchre VoICastSuccess ^You gesture
matchre RelPFError ^I do not understand what you mean\.$|^You wave your spiritwood cube around\.|^Your spell.*?backfires
put wave my cube
matchwait

VoICast:
put #var pf 0
put #class spellcast on
matchre VoICast ^\.\.\.wait|^Sorry\,
matchre VoICastSuccess ^You gesture
matchre RegsRelError ^You don't have a spell prepared|^Your spell.*?backfires
put cast
matchwait

VoICastSuccess:
put #var voicasttimer #evalmath ($unixtime + 5)
if (%pf = 1) then goto CheckSpellStatus
goto RegsCastVars

SUB:
var abbrev sub
if (%cast != 1) then goto SUB3
if ($subbufftarget = 0) then goto SUB2
if (%pf = 1) then
{
    var getpfocreturn CheckSpellStance
    put #var autostancedef 0
    put #var autostancedur 0
    put #var autostanceinteg 1
    put #var autostancepot 0
    var spellstancereturn SUBBuffCast
    goto GetPFoc
}
goto SUBBuffCast

SUB2:
if (%pf = 1) then
{
    var getpfocreturn CheckSpellStance
    put #var autostancedef 0
    put #var autostancedur 0
    put #var autostanceinteg 1
    put #var autostancepot 0
    var spellstancereturn SubCastPF
    goto GetPFoc
}
put #var autostancedef 0
put #var autostancedur 0
put #var autostanceinteg 1
put #var autostancepot 0
var spellstancereturn SubCast
goto CheckSpellStance

SUB3:
if (%pf = 1) then goto SUBManaCheckPF
goto SUBManaCheck

SUBManaCheckPF:
if ($mana > 69) then
{
    # put #var pfpausetime #evalmath ($unixtime + 9)
    var secpausepf 9
    put #var pfprepm 88
    put #var pfharn1 0
    put #var pfharn2 0
    put #var pfharnlimit 0
    var getpfocreturn CommonPrepPF
    goto GetPFoc
}
# put #var pfpausetime #evalmath ($unixtime + 5)
if ($boosttimer > $unixtime) then
{
    var secpausepf 7
}
else
{
    var secpausepf 5
}
put #var pfprepm 29
put #var pfharn1 30
put #var pfharn2 29
put #var pfharnlimit 2
var getpfocreturn CommonPrepPF
goto GetPFoc

SUBManaCheck:
if ($mana > 69) then
{
    # put #var pausetime #evalmath ($unixtime + 9)
    var pausesec 9
    put #var prepm 88
    put #var harn1 0
    put #var harn2 0
    put #var harnlimit 0
    goto CommonPrep
}
# put #var pausetime #evalmath ($unixtime + 5)
if ($boosttimer > $unixtime) then
{
    var pausesec 7
}
else
{
    var pausesec 5
}
put #var prepm 29
put #var harn1 30
put #var harn2 29
put #var harnlimit 2
goto CommonPrep

SUBBuffCast:
if (%pf = 1) then put #var pf 1
if (%pf != 1) then put #var pf 0
put #class spellcast on
matchre SUBBuffCast ^\.\.\.wait|^Sorry\,
matchre SUBBuffCast2 ^You gesture|^Your spell.*?backfires|^The spell pattern collapses
matchre RelPFError ^I do not understand what you mean\.|^You wave your spiritwood cube around\.
match RegsRelError You don't have a spell prepared
if ($pf = 1) then put wave my cube at $subbufftarget
if ($pf != 1) then put cast $subbufftarget
matchwait

SUBBuffCast2:
put #var subbufftarget 0
if (%pf = 1) then goto CheckSpellStatus
goto RegsCastVars

SubCastPF:
put #var pf 1
put #class spellcast on
matchre SubCastPF ^\.\.\.wait|^Sorry\,
matchre SubCastVars but you still feel very aware of their position\.$
matchre RelPFError ^I do not understand what you mean\.|^You wave your spiritwood cube around\.|^Your spell.*?backfires
put wave my cube
matchwait

SubCast:
put #var pf 0
put #class spellcast on
matchre SubCast ^\.\.\.wait|^Sorry\,
matchre SubCastVars but you still feel very aware of their position\.$
matchre RegsRelError ^You don't have a spell prepared|^Your spell.*?backfires
put cast
matchwait

SubCastVars:
put #var subcasttimer #evalmath ($unixtime + 5)
if (%pf = 1) then goto CheckSpellStatus
goto RegsCastVars

TW:
var abbrev tw
if (%cast = 1) then
{
    if (%pf = 1) then
    {
        var getpfocreturn CheckSpellStance
        put #var autostancedef 0
        put #var autostancedur 0
        put #var autostanceinteg 1
        put #var autostancepot 0
        var spellstancereturn CommonCastPF
        goto GetPFoc
    }
}
if (%cast = 1) then
{
    put #var autostancedef 0
    put #var autostancedur 0
    put #var autostanceinteg 1
    put #var autostancepot 0
    var spellstancereturn CommonCast
    goto CheckSpellStance
}
if (%pf = 1) then goto TWManaCheckPF
goto TWManaCheck

TWManaCheckPF:
if ($mana > 69) then
{
    # put #var pfpausetime #evalmath ($unixtime + 9)
    var secpausepf 9
    put #var pfprepm 88
    put #var pfharn1 0
    put #var pfharn2 0
    put #var pfharnlimit 0
    var getpfocreturn CommonPrepPF
    goto GetPFoc
}
# put #var pfpausetime #evalmath ($unixtime + 5)
if ($boosttimer > $unixtime) then
{
    var secpausepf 11
}
else
{
    var secpausepf 9
}
put #var pfprepm 29
put #var pfharn1 30
put #var pfharn2 29
put #var pfharnlimit 2
var getpfocreturn CommonPrepPF
goto GetPFoc

TWManaCheck:
if ($mana > 69) then
{
    # put #var pausetime #evalmath ($unixtime + 9)
    var pausesec 9
    put #var prepm 88
    put #var harn1 0
    put #var harn2 0
    put #var harnlimit 0
    goto CommonPrep
}
# put #var pausetime #evalmath ($unixtime + 5)
if ($boosttimer > $unixtime) then
{
    var pausesec 7
}
else
{
    var pausesec 5
}
put #var prepm 29
put #var harn1 30
put #var harn2 29
put #var harnlimit 2
goto CommonPrep

GF:
var abbrev gf
if (%cast = 1) then
{
    if (%pf = 1) then
    {
        var getpfocreturn CheckSpellStance
        put #var autostancedef 0
        put #var autostancedur 0
        put #var autostanceinteg 1
        put #var autostancepot 0
        var spellstancereturn GFCastPF
        goto GetPFoc
    }
}
if (%cast = 1) then
{
    put #var autostancedef 0
    put #var autostancedur 0
    put #var autostanceinteg 1
    put #var autostancepot 0
    var spellstancereturn GFCast
    goto CheckSpellStance
}
if (%pf = 1) then goto GFManaCheckPF
goto GFManaCheck

GFManaCheckPF:
if ($mana > 69) then
{
    # put #var pfpausetime #evalmath ($unixtime + 18)
    var secpausepf 18
    put #var pfprepm 88
    put #var pfharn1 0
    put #var pfharn2 0
    put #var pfharnlimit 0
    var getpfocreturn CommonPrepPF
    goto GetPFoc
}
# put #var pfpausetime #evalmath ($unixtime + 14)
if ($boosttimer > $unixtime) then
{
    var secpausepf 16
}
else
{
    var secpausepf 14
}
put #var pfprepm 29
put #var pfharn1 30
put #var pfharn2 29
put #var pfharnlimit 2
var getpfocreturn CommonPrepPF
goto GetPFoc

GFManaCheck:
if ($mana > 69) then
{
    # put #var pausetime #evalmath ($unixtime + 18)
    var pausesec 18
    put #var prepm 91
    put #var harn1 0
    put #var harn2 0
    put #var harnlimit 0
    goto CommonPrep
}
# put #var pausetime #evalmath ($unixtime + 14)
if ($boosttimer > $unixtime) then
{
    var pausesec 16
}
else
{
    var pausesec 14
}
put #var prepm 30
put #var harn1 31
put #var harn2 30
put #var harnlimit 2
goto CommonPrep

GFCast:
put #var pf 0
put #class spellcast on
matchre GFCast ^\.\.\.wait|^Sorry\,
matchre GFCastSuccess ^Steadying your breath, you briefly point
match GFOff The Grounding Field spell pattern abruptly fizzles in this hybrid reality.
matchre RegsRelError ^You don't have a spell prepared|^Your spell.*?backfires|^The spell pattern collapses
put cast
matchwait

GFOff:
put #var autogf 0
goto RegsRelError

GFCastSuccess:
put #var gfattempttimer #evalmath ($unixtime + 5)
if (%pf = 1) then goto CheckSpellStatus
goto RegsCastVars

GFCastPF:
put #var pf 1
put #class spellcast on
matchre GFCastPF ^\.\.\.wait|^Sorry\,
matchre GFCastSuccess ^Steadying your breath, you briefly point
match GFOffPF The Grounding Field spell pattern abruptly fizzles in this hybrid reality.
matchre RelPFError ^I do not understand what you mean\.$|^You wave your spiritwood cube around\.|^Your spell.*?backfires|^The spell pattern collapses
put wave my cube
matchwait

GFOffPF:
put #var autogf 0
goto RelPFError

AEG:
var abbrev aeg
if (%cast = 1) then
{
    put #var autostancedef 1
    put #var autostancedur 0
    put #var autostanceinteg 0
    put #var autostancepot 0
    var spellstancereturn CheckMoFSB
    goto CheckSpellStance 
}
put #var sorcery 1
# put #var pausetime #evalmath ($unixtime + 32)
var pausesec 32
put #var prepm 800
put #var harn1 0
put #var harn2 0
put #var harnlimit 0
put #var focinvoked 0
goto CommonPrep

CheckMoFSB:
if ($SpellTimer.MantleofFlame.active = 0) then goto AEGCast
matchre CheckMoFSB ^\.\.\.wait|^Sorry\,
matchre AEGCast ^Your body is no longer imbued with Fire\.$|^Release what\?$
put rel mof
matchwait

AEGCast:
put #var pf 0
put #class spellcast on
matchre AEGCast ^\.\.\.wait|^Sorry\,
matchre RegsCastVars ^You reach with your fist toward the ground\.$|^You press your fist firmly against the ground\.$|^Your spell.*?backfires|^The spell pattern collapses
match RegsRelError You don't have a spell prepared
matchre LowMana ^You strain
put cast
matchwait

MoF:
var abbrev mof
if (%cast = 1) then
{
    put #var autostancedef 1
    put #var autostancedur 0
    put #var autostanceinteg 0
    put #var autostancepot 0
    var spellstancereturn CheckAEG
    goto CheckSpellStance 
}
put #var sorcery 1
# put #var pausetime #evalmath ($unixtime + 32)
var pausesec 32
put #var prepm 800
put #var harn1 0
put #var harn2 0
put #var harnlimit 0
goto CommonPrep

CheckAEG:
if ($SpellTimer.AegisofGranite.active = 0) then goto MoFCast
matchre CheckAEG ^\.\.\.wait|^Sorry\,
matchre MoFCast ^The Earth energy flows from your body|^Release what\?$
put rel aeg
matchwait

MoFCast:
put #var pf 0
put #class spellcast on
matchre MoFCast ^\.\.\.wait|^Sorry\,
matchre RegsCastVars ^You raise your fist toward the sun\.|^You press your fist firmly against the ground\.|^A crackling mantle of blazing orange-yellow flames surrounds you
matchre RegsRelError ^You don't have a spell prepared|^Your spell.*?backfires|^The spell pattern collapses
matchre LowMana ^You strain
put cast
matchwait

YS:
var abbrev ys
if (%cast = 1) then
{
    if (%pf = 1) then
    {
        var getpfocreturn CheckSpellStance
        put #var autostancedef 0
        put #var autostancedur 0
        put #var autostanceinteg 1
        put #var autostancepot 0
        var spellstancereturn YSCastPF
        goto GetPFoc
    }
}
if (%cast = 1) then
{
    put #var autostancedef 0
    put #var autostancedur 0
    put #var autostanceinteg 1
    put #var autostancepot 0
    var spellstancereturn YSCast
    goto CheckSpellStance
}
if (%pf = 1) then goto YSManaCheckPF
goto YSManaCheck

YSManaCheckPF:
if ($mana > 69) then
{
    var secpausepf 9
    put #var pfprepm 89
    put #var pfharn1 0
    put #var pfharn2 0
    put #var pfharnlimit 0
    var getpfocreturn CommonPrepPF
    goto GetPFoc
}
if ($boosttimer > $unixtime) then
{
    var secpausepf 11
}
else
{
    var secpausepf 9
}
put #var pfprepm 29
put #var pfharn1 30
put #var pfharn2 30
put #var pfharnlimit 2
var getpfocreturn CommonPrepPF
goto GetPFoc

YSManaCheck:
if ($mana > 69) then
{
    var pausesec 9
    put #var prepm 89
    put #var harn1 0
    put #var harn2 0
    put #var harnlimit 0
    goto CommonPrep
}
if ($boosttimer > $unixtime) then
{
    var pausesec 7
}
else
{
    var pausesec 5
}
put #var prepm 29
put #var harn1 30
put #var harn2 30
put #var harnlimit 2
goto CommonPrep

YSCastPF:
put #var pf 1
put #class spellcast on
matchre YSCastPF ^\.\.\.wait|^Sorry\,
matchre YSCastVars ^You gesture|^The mental strain of initiating a cyclic spell
matchre RelPFError ^I do not understand what you mean\.|^You wave your spiritwood cube around\.|^Your spell.*?backfires
match CalmedEffectPFSB You don't feel like casting that kind of spell right now.
put wave my cube
matchwait

YSCast:
put #var pf 0
put #class spellcast on
matchre YSCast ^\.\.\.wait|^Sorry\,
matchre YSCastVars ^You gesture|^The mental strain of initiating a cyclic spell|^You place your hands on your temples\.|^The spell pattern collapses
matchre RegsRelError ^You don't have a spell prepared|^Your spell.*?backfires
match CalmedEffectSB You don't feel like casting that kind of spell right now.
put cast
matchwait

YSCastVars:
put #var yscasttimer #evalmath ($unixtime + 5)
if (%pf = 1) then goto CheckSpellStatus
goto RegsCastVars


# Utility

Dispel:
var abbrev dispel
if (%cast = 1) then
{
    put #var autostancedef 0
    put #var autostancedur 1
    put #var autostanceinteg 0
    put #var autostancepot 0
    var spellstancereturn CommonCast
    goto CheckSpellStance
}
if ($mana > 69) then
{
    # put #var pausetime #evalmath ($unixtime + 4)
    var pausesec 4
    put #var prepm 89
    put #var harn1 0
    put #var harn2 0
    put #var harnlimit 0
    goto DispelPrep
}
# put #var pausetime $unixtime
if ($boosttimer > $unixtime) then
{
    var pausesec 2
}
else
{
    var pausesec 0
}
put #var prepm 29
put #var harn1 30
put #var harn2 30
put #var harnlimit 2
goto DispelPrep

DispelPrep:
var shleftreturn GetRuneDispel
var shrightreturn GetRuneDispel
if ($handdamaged = 1) then
{
    var clearboth 1
    goto SheathR
}
goto EmptyOneHand

GetRuneDispel:
matchre GetRuneDispel ^\.\.\.wait|^Sorry\,
matchre StopNoRuneDispel ^What were you
matchre InvokeRuneDispel ^You get|^You are already
match HandHurtSB You can't pick that up with your hand that damaged.
put get my basic runestone
matchwait

InvokeRuneDispel:
var revealreturn InvokeRuneDispel2
goto RevealSB

RevealSB:
if ($invisible != 1) then goto %revealreturn
matchre RevealSB ^\.\.\.wait|^Sorry\,
matchre %revealreturn ^You reveal yourself\.|^You aren't
put reveal
matchwait

InvokeRuneDispel2:
if ($pf != 0) then put #var pf 0
if ($spelllost != 0) then put #var spelllost 0
if ($tmspellready != 0) then put #var tmspellready 0
if ($attackspell != 0) then put #var attackspell 0
if ($stattackspell != 0) then put #var stattackspell 0
if ($spellready != 0) then put #var spellready 0
put #class spelllostwatcher on
put #class spellprepared on
goto InvokeRuneDispel3

InvokeRuneDispel3:
matchre InvokeRuneDispel3 ^\.\.\.wait|^Sorry\,
matchre RegsRelError ^But you're already|^You are already preparing
matchre DispelPrep ^You'll have to hold it
matchre NoCasting ^Something in the area interferes with your spell preparations\.$
matchre StowRune ^Closing your eyes, you carefully bend some mana
matchre DropRune ^You harness a moderate amount of energy
match InvokeRuneDispel You cannot use
match HeadDamageSB You are in no condition to do that.
put #var pausetime #evalmath ($unixtime + %pausesec)
put invoke my runestone $prepm
matchwait

StopNoRuneDispel:
put #var norunedispel 1
echo ***** No Rune *****
goto RegsRelError

ETF:
var abbrev etf
if (%cast = 1) then
{
    var nofissure ETF3
    goto CheckFissure
}
var nofissure ETF2
goto CheckFissure

ETF3:
if (%pf = 1) then
{
    var getpfocreturn CheckSpellStance
    put #var autostancedef 0
    put #var autostancedur 0
    put #var autostanceinteg 1
    put #var autostancepot 0
    var spellstancereturn ETFCast
    goto GetPFoc
}
put #var autostancedef 0
put #var autostancedur 0
put #var autostanceinteg 1
put #var autostancepot 0
var spellstancereturn ETFCast
goto CheckSpellStance

CheckFissure:
if matchre ("$roomobjs" , "^You also see .*(fiery|electrical|aqueous|airy|earthen|chaotic) fissure") then goto BigFissure
goto %nofissure


# matchre CheckFissure ^\.\.\.wait|^Sorry\,
# matchre BigFissure ^You take a moment to look for all the items in the area and .*(fiery|electrical|aqueous|airy|earthen|chaotic) fissure.*\.$
# matchre %nofissure ^You take a moment to look for all the items in the area .*\.$|^You look around and notice that there is nothing here\.$
# put look items
# matchwait

BigFissure:
echo
echo **** Fissure Present ****
echo
# if (%cast = 0) then goto NoPrepETF
if (%pf = 1) then goto PFRel
goto RegsRel

# PFETFRel:
# var relpf 1
# var relreturn CheckSpellStatus
# goto RelSpell

# NoPrepETF:
# if (%pf = 1) then goto NoPrepETFPF
# goto RegsRel

# NoPrepETFPF:
# put #var pfspell 0
# put #var pfspellname 0
# goto CheckSpellStatus

ETF2:
if (%pf = 1) then goto ETFManaCheckPF
goto ETFManaCheck

ETFManaCheckPF:
if ($mana > 69) then
{
    # put #var pfpausetime #evalmath ($unixtime + 18)
    var secpausepf 18
    put #var pfprepm 88
    put #var pfharn1 0
    put #var pfharn2 0
    put #var pfharnlimit 0
    var getpfocreturn CommonPrepPF
    goto GetPFoc
}
# put #var pfpausetime #evalmath ($unixtime + 14)
if ($boosttimer > $unixtime) then
{
    var secpausepf 16
}
else
{
    var secpausepf 14
}
put #var pfprepm 29
put #var pfharn1 30
put #var pfharn2 29
put #var pfharnlimit 2
var getpfocreturn CommonPrepPF
goto GetPFoc

ETFManaCheck:
if ($mana > 69) then
{
    # put #var pausetime #evalmath ($unixtime + 18)
    var pausesec 18
    put #var prepm 89
    put #var harn1 0
    put #var harn2 0
    put #var harnlimit 0
    goto CommonPrep
}
# put #var pausetime #evalmath ($unixtime + 14)
if ($boosttimer > $unixtime) then
{
    var pausesec 16
}
else
{
    var pausesec 14
}
put #var prepm 29
put #var harn1 30
put #var harn2 30
put #var harnlimit 2
goto CommonPrep

ETFCast:
if (%pf = 1) then put #var pf 1
if (%pf != 1) then put #var pf 0
put #class spellcast on
var nofissure ETFCast
matchre ETFCast ^\.\.\.wait|^Sorry\,
matchre ETFCastSuccess ^You roll your hands in an elliptical|^Your spell.*?backfires|^The fissure's spell matrix looks too unstable|^The spell pattern collapses
matchre ETFMisCast ^I do not understand what you mean\.$|^You wave your spiritwood cube around\.$
match RegsRelError You don't have a spell prepared
if ($pf = 1) then
{
    if ($element != "Metal") then
    {
        put wave my cube $element
    }
    if ($element = "Metal") then
    {
        put wave my cube fire
    }
}
if ($pf != 1) then
{
    if ($element != "Metal") then
    {
        put cast $element
    }
    if ($element = "Metal") then
    {
        put cast fire
    }
}
matchwait

ETFMisCast:
echo
echo **** ETF Cast Failed on PF ****
echo
var relpf 1
var relreturn CheckSpellStatus
goto RelSpell

ETFCastSuccess:
if (%pf = 1) then goto CheckSpellStatus
goto RegsCastVars

FOI:
var abbrev foi
if (%cast = 1) then
{
    if (%pf = 1) then 
    {
        var getpfocreturn CheckSpellStance
        put #var autostancedef 1
        put #var autostancedur 0
        put #var autostanceinteg 0
        put #var autostancepot 0
        var spellstancereturn FoICastPF
        goto GetPFoc
    }
}
if (%cast = 1) then
{
    put #var autostancedef 1
    put #var autostancedur 0
    put #var autostanceinteg 0
    put #var autostancepot 0
    var spellstancereturn FoICast
    goto CheckSpellStance
}
if (%pf = 1) then
{
    # put #var pfpausetime #evalmath ($unixtime + 5)
    var secpausepf 5
    put #var pfprepm 1
    put #var pfharn1 0
    put #var pfharn2 0
    put #var pfharnlimit 0
    var getpfocreturn FoIPFPrep
    goto GetPFoc
}
# put #var pausetime #evalmath ($unixtime + 5)
var pausesec 5
put #var prepm 1
put #var harn1 0
put #var harn2 0
put #var harnlimit 0
goto FoIPrep

FOIM:
var abbrev foi
if (%cast = 1) then
{
    if (%pf = 1) then 
    {
        var getpfocreturn CheckSpellStance
        put #var autostancedef 1
        put #var autostancedur 0
        put #var autostanceinteg 0
        put #var autostancepot 0
        var spellstancereturn FoICastPF
        goto GetPFoc
    }
}
if (%cast = 1) then
{
    put #var autostancedef 1
    put #var autostancedur 0
    put #var autostanceinteg 0
    put #var autostancepot 0
    var spellstancereturn FoICast
    goto CheckSpellStance
}
if (%pf = 1) then
{
    # put #var pfpausetime #evalmath ($unixtime + 15)
    if ($boosttimer > $unixtime) then
    {
        var secpausepf 17
    }
    else
    {
        var secpausepf 15
    }
    put #var pfprepm 34
    put #var pfharn1 33
    put #var pfharn2 33
    put #var pfharnlimit 2
    var getpfocreturn FoIPFPrep
    goto GetPFoc
}
# put #var pausetime #evalmath ($unixtime + 15)
if ($boosttimer > $unixtime) then
{
    var pausesec 17
}
else
{
    var pausesec 15
}
put #var prepm 34
put #var harn1 33
put #var harn2 33
put #var harnlimit 2
goto FoIPrep


FoIPFPrep:
put #var pf 1
# put #class pfspellprep on
put #var pfspellprepped 1
put #var pfspellready 0
put #class pfspellloss on
put #class pfspellprepared on
goto FoIPFPrep2

FoIPFPrep2:
matchre FoIPFPrep2 ^\.\.\.wait|^Sorry\,
matchre RelPFError ^But you're already|^You are already preparing|^Invoke what\?$
match NoCastRoomFoIPF You sense an instability in the spell pattern that may prevent it from working.
matchre NoCasting ^Something in the area interferes with your spell preparations\.$
matchre CheckSpellStatus ^You begin channeling mana
match RelPFError You are already channeling a spell
put #var pfspelltimer #evalmath ($unixtime + 69)
put #var pfpausetime #evalmath ($unixtime + %secpausepf)
if ($longpause != 0) then
{
    put #var pfpausetime #evalmath ($pfpausetime + $longpause)
}
put invoke my cube %abbrev $pfprepm
matchwait

FoIPrep:
put #var pf 0
put #var spelllost 0
put #var tmspellready 0
put #var attackspell 0
put #var stattackspell 0
put #var spellready 0
put #class spelllostwatcher on
put #class spellprepared on
goto FoIPrep2

FoIPrep2:
matchre FoIPrep2 ^\.\.\.wait|^Sorry\,
matchre RegsRelError ^But you're already|^You are already preparing|^You have already fully
matchre NoCasting ^Something in the area interferes with your spell preparations\.$
match NoCastRoomFoI You sense an instability in the spell pattern that may prevent it from working.
matchre CheckSpellStatus ^You trace a geometric sigil in the air
matchre PeaceRoomSB ^As you attempt to prepare the spell, a sense of overwhelming peace washes over you\.$|^Your desire to prepare this offensive spell suddenly slips away\.$
match SpellStollen You seem to have forgotten this spell!
put #var pausetime #evalmath ($unixtime + %pausesec)
if ($longpause != 0) then
{
    put #var pausetime #evalmath ($pausetime + $longpause)
}
put prep %abbrev $prepm
matchwait

FoICastPF:
put #var pf 1
put #class spellcast on
matchre FoICastPF ^\.\.\.wait|^Sorry\,
# matchre FoICastSuccess ^You are now within the Fortress\!
matchre CheckSpellStatus ^Your spell.*?backfires|^Though you were successful in adding some power|^Currently lacking the skill to complete the pattern, your spell fails completely\.$
match FoICastSuccess You are now within the Fortress!
matchre RelPFError ^I do not understand what you mean\.$|^You wave your spiritwood cube around\.$
match NoCastInsidePF You can't cast that inside!
match NoCastRoomFoIPF Something in the area prevents your spell from working.
put wave my cube
matchwait

FoICastSuccess:
if ($escape != 0) then put #var escape 0
if ($mescape != 0) then put #var mescape 0
if ($pvptarget != 0) then
{
    if ($combatloop != 0) then
    {
        put #var cscript .seekanddestroy
    }
}
goto CheckSpellStatus

FoICast:
if ($pvptarget = 0) then goto FoICast2
if matchre ("$roomname" , "Ice Fortress") then goto ScanFortressPerimeterSB
goto FoICast2

ScanFortressPerimeterSB:
if ($prioritytarget != 0) then matchre FoIFaceCheckPrioritySB ^Also here:.*?(?i)\b$prioritytarget\w*(?-i)
if ($pvptarget != 0) then matchre FoICast3 ^Also here:.*?(?i)\b$pvptarget\w*(?-i)
if ($pvptarget2 != 0) then matchre FoIFaceCheckSB2 ^Also here:.*?(?i)\b$pvptarget2\w*(?-i)
if ($pvptarget3 != 0) then matchre FoIFaceCheckSB3 ^Also here:.*?(?i)\b$pvptarget3\w*(?-i)
if ($pvptarget4 != 0) then matchre FoIFaceCheckSB4 ^Also here:.*?(?i)\b$pvptarget4\w*(?-i)
if ($pvptarget5 != 0) then matchre FoIFaceCheckSB5 ^Also here:.*?(?i)\b$pvptarget5\w*(?-i)
if ($pvptarget6 != 0) then matchre FoIFaceCheckSB6 ^Also here:.*?(?i)\b$pvptarget6\w*(?-i)
matchre CheckPFSlot ^(Obvious|Ship) (paths|exits)
put look wall
matchwait

FoIFaceCheckPrioritySB:
put .ks $prioritytarget
exit

FoIFaceCheckSB2:
put .ks $pvptarget2
exit

FoIFaceCheckSB3:
put .ks $pvptarget3
exit

FoIFaceCheckSB4:
put .ks $pvptarget4
exit

FoIFaceCheckSB5:
put .ks $pvptarget5
exit

FoIFaceCheckSB6:
put .ks $pvptarget6
exit

NoFoITarget:
pause
goto CheckPFSlot

FoICast2:
put #var pf 0
put #class spellcast on
matchre FoICast2 ^\.\.\.wait|^Sorry\,
matchre FoICastSuccess ^You are now within the Fortress\!
matchre RegsCastVars ^Your spell.*?backfires|^Though you were successful in adding some power|^Currently lacking the skill to complete the pattern, your spell fails completely\.$|^The spell pattern collapses
match NoCastInside You can't cast that inside!
match TargetInFoi is now within the Fortress!
match NoTargetFOI I could not find what you are referring to.
match RegsRelErrorFoI You don't have a spell prepared
match NoCastRoomFoI Something in the area prevents your spell from working.
if ($foibufftarget != 0) then put cast $foibufftarget
if ($foibufftarget = 0) then put cast
matchwait

FoICast3:
put #var pf 0
put #class spellcast on
matchre FoICast3 ^\.\.\.wait|^Sorry\,
matchre RegsCastVars ^Your spell.*?backfires|^Though you were successful in adding some power|^You are now within the Fortress\!|^Currently lacking the skill to complete the pattern, your spell fails completely\.$|^The spell pattern collapses
match NoCastInside You can't cast that inside!
match TargetInFoi is now within the Fortress!
match NoTargetFOI I could not find what you are referring to.
match RegsRelErrorFoI You don't have a spell prepared
match NoCastRoomFoI Something in the area prevents your spell from working.
if ($pvptarget != 0) then put cast $pvptarget
if ($pvptarget = 0) then put cast
matchwait

RegsRelErrorFoI:
put #var foibufftarget 0
# put #var foitrap 0
goto RegsRelError

NoCastInsidePF:
put #echo >Conversation
put #echo >Conversation #000000 *** Inside
put #echo >Conversation #000000 *** No Fortress
echo
echo **** Inside
echo **** No Fortress of Ice
echo
put #var inside 1
put #var autofoi 0
var relpf 1
var relreturn CheckSpellStatus
goto RelSpell

NoCastInside:
put #echo >Conversation
put #echo >Conversation #000000 *** Inside
put #echo >Conversation #000000 *** No Fortress
echo
echo **** Inside
echo **** No Fortress of Ice
echo
put #var inside 1
put #var autofoi 0
var commonrel 1
var relreturn CheckSpellStatus
goto RelSpell

NoCastRoomFoIPF:
put #echo >Conversation
put #echo >Conversation #000000 *** Special Room
put #echo >Conversation #000000 *** No Fortress
echo
echo **** Special Room
echo **** No Fortress of Ice
echo
put #var autofoi 0
var relpf 1
var relreturn CheckSpellStatus
goto RelSpell

NoCastRoomFoI:
put #echo >Conversation
put #echo >Conversation #000000 *** Special Room
put #echo >Conversation #000000 *** No Fortress
echo
echo **** Special Room
echo **** No Fortress of Ice
echo
put #var autofoi 0
var commonrel 1
var relreturn CheckSpellStatus
goto RelSpell

TargetInFoi:
var tempfoitarget $foibufftarget
put #var foibufftarget 0
# put #var foitrap 0
put .ks %tempfoitarget
exit

NoTargetFOI:
put #echo >Conversation
put #echo >Conversation #000000 *** Couldn't find FoI Target
echo
echo **** Couldn't Find FoI Target
echo
var commonrel 1
var relreturn CheckSpellStatus
put #var foibufftarget 0
# put #var foitrap 0
put #var targetinvis 1
goto RelSpell

DB:
var abbrev db
if (%cast = 1) then
{
    put #var autostancedef 1
    put #var autostancedur 0
    put #var autostanceinteg 0
    put #var autostancepot 0
    var spellstancereturn DBCast
    goto CheckSpellStance
}
if ($mana > 69) then
{
    put #var prepm 100
    put #var harn1 0
    put #var harn2 0
    put #var harnlimit 0
    # put #var pausetime #evalmath ($unixtime + 3)
    var pausesec 3  
}
# put #var pausetime $unixtime
if ($boosttimer > $unixtime) then
{
    var pausesec 2
}
else
{
    var pausesec 0
}
put #var prepm 34
put #var harn1 33
put #var harn2 33
put #var harnlimit 2
goto CommonPrep

DBCast:
if ($acon = 1) then
{
    var acrelreturn DBCast2
    goto ACRel
}
goto DBCast2

DBCast2:
put #var pf 0
put #class spellcast on
matchre DBCast ^\.\.\.wait|^Sorry\,
matchre DBCastVars ^A halo of fire flickers into being and hovers around your neck and mouth
matchre RegsRelError ^You don't have a spell prepared|^Your spell.*?backfires
# match CalmedEffectSB You don't feel like casting that kind of spell right now.
put cast
matchwait

DBCastVars:
put #var dbcasttimer #evalmath ($unixtime + 5)
goto RegsCastVars

IG:
if ("$rspellname" = "Ignite") then
{
    if ($tmfoc = 1) then goto RegsRel
}
if ($SpellTimer.Ignite.active = 1) then goto RelIG
goto IG2

RelIG:
matchre RelIG ^\.\.\.wait|^Sorry\,
matchre IG2 ^The warm feeling in your hand goes away\.|^Release what\?
put rel ignite
matchwait

IG2:
put #var pf 0
var abbrev ig
if (%cast = 1) then
{
    put #var autostancedef 0
    put #var autostancedur 0
    put #var autostanceinteg 1
    put #var autostancepot 0
    var spellstancereturn IGCastCheck
    goto CheckSpellStance
}
if ($mana > 69) then
{
    # put #var pausetime #evalmath ($unixtime + 18)
    var pausesec 9
    put #var prepm 88
    put #var harn1 0
    put #var harn2 0
    put #var harnlimit 0
    goto CommonPrep
}
# put #var pausetime #evalmath ($unixtime + 14)
if ($boosttimer > $unixtime) then
{
    var pausesec 7
}
else
{
    var pausesec 5
}
put #var prepm 29
put #var harn1 30
put #var harn2 29
put #var harnlimit 2
goto CommonPrep

IGCastCheck:
put #var pf 0
put #class spellcast on
# if ($pvp = 1) then goto IGPrepMachete
# if ($pvpfull = 1) then goto IGPrepMachete
# goto IGPrepMachete
goto IGPrepGS

IGPrepGS:
if ("$righthand" = "greatsword") then goto IGCastGS
if ("$lefthand" = "greatsword") then goto IGCastGS
var shleftreturn WieldIGGS
var shrightreturn WieldIGGS
goto EmptyOneHand

IGPrepMachete:
if ("$righthandnoun" = "machete") then goto IGCastMachete
if ("$lefthand" = "machete") then goto IGCastMachete
var shleftreturn WieldMachete
var shrightreturn WieldMachete
goto EmptyOneHand

WieldIGGS:
matchre WieldIGGS ^\.\.\.wait|^Sorry\,
matchre IGCastGS ^You draw out|^You're already
match LiftGS You find it difficult to wield
matchre HandDamageSevereSC ^Your.*?hand is too injured to draw
put wield my greatsword
matchwait

LiftGS:
matchre LiftGS ^\.\.\.wait|^Sorry\,
matchre IGCastGS ^You pick up|^You fade in
put lift greatsword
matchwait

WieldMachete:
matchre WieldMachete ^\.\.\.wait|^Sorry\,
matchre IGCastMachete ^You draw out|^You're already
match LiftMachete You find it difficult to wield
matchre HandDamageSevereSC ^Your.*?hand is too injured to draw
put wield my machete
matchwait

LiftMachete:
matchre LiftMachete ^\.\.\.wait|^Sorry\,
matchre IGCastMachete ^You pick up|^You fade in
put lift machete
matchwait

IGCastGS:
matchre IGCastGS ^\.\.\.wait|^Sorry\,
matchre IGCastGSVars ^Tendrils of flame dart along your|^The flames dancing along your
matchre RegsRelError ^You don't have a spell prepared|^Your spell.*?backfires
put cast my greatsword
matchwait

IGCastGSVars:
put #var ignitegs 1
goto IGSheathCheck

IGCastMachete:
matchre IGCastMachete ^\.\.\.wait|^Sorry\,
matchre IGCastMacheteVars ^Tendrils of flame dart along your|^The flames dancing along your
matchre RegsRelError ^You don't have a spell prepared|^Your spell.*?backfires
put cast my machete
matchwait

IGCastMacheteVars:
put #var ignitegs 0
goto IGSheathCheck

IGSheathCheck:
if ($combatloop != 0) then goto RegsCastVars
var shrightreturn RegsCastVars
var shleftreturn RegsCastVars
if ("$righthandnoun" = "greatsword") then goto SheathR
if ("$lefthandnoun" = "greatsword") then goto SheathL
if ("$righthandnoun" = "machete") then goto SheathR
if ("$lefthandnoun" = "machete") then goto SheathL
goto RegsCastVars

BG:
var abbrev bg
if (%cast = 1) then
{
    put #var autostancedef 1
    put #var autostancedur 0
    put #var autostanceinteg 0
    put #var autostancepot 0
    put #class bgstart on
    var spellstancereturn BGCast
    goto CheckSpellStance
}
if ($mana > 69) then
{
    put #var prepm 100
    put #var harn1 0
    put #var harn2 0
    put #var harnlimit 0
    # put #var pausetime #evalmath ($unixtime + 4)
    var pausesec 4
    goto CommonPrep
}
if ($boosttimer > $unixtime) then
{
    var pausesec 2
}
else
{
    var pausesec 0
}
put #var prepm 34
put #var harn1 33
put #var harn2 33
put #var harnlimit 2
# put #var pausetime $unixtime
goto CommonPrep

BGCast:
if ($acon = 1) then
{
    var acrelreturn BGCast2
    goto ACRel
}
goto BGCast2

BGCast2:
put #var pf 0
put #class spellcast on
matchre BGCast ^\.\.\.wait|^Sorry\,
matchre BGReady ^Spirals of tightly compressed air gather around your forearms
# matchre CheckSpellStatus ^Your spell.*?backfires|^The targeting pattern of your
matchre RegsRelError ^You don't have a spell prepared|^Your spell.*?backfires
match CalmedEffectSB You don't feel like casting that kind of spell right now.
put cast
matchwait

BGReady:
put #var bgattempttimer #evalmath ($unixtime + 5)
put #var bgready 1
put #var bgattacks 0
goto RegsCastVars

RIM:
var abbrev rim
if (%cast = 1) then
{
    put #var autostancedef 1
    put #var autostancedur 0
    put #var autostanceinteg 0
    put #var autostancepot 0
    var spellstancereturn RIMCastCheck
    goto CheckSpellStance
}
# put #var pausetime #evalmath ($unixtime + 5)
var pausesec 7
put #var prepm 31
put #var harn1 0
put #var harn2 0
put #var harnlimit 0
goto CommonPrep

RIMCastCheck:
if ($eeon = 1) then goto RIMCastRel
if ($acon = 1) then goto RIMCastRel
if ($fron = 1) then goto RIMCastRel
if ($rimon = 1) then goto RIMCastRel
goto RIMCast

RIMCastRel:
var relcyclic 1
var relreturn RIMCast
goto RelSpell

RIMCast:
put #var pf 0
put #class spellcast on
put #class rimefangstart on
matchre RIMCast ^\.\.\.wait|^Sorry\,
matchre RIMCastFail ^You don't have a spell prepared|^The mental strain of initiating a cyclic spell|^Your spell.*?backfires|^The spell pattern collapses
matchre RegsCastVarsRT ^You gesture
match CalmedEffectSB You don't feel like casting that kind of spell right now.
put cast
matchwait

RIMCastFail:
put #class rimefangstart off
put #var cyclicinitiated 0
goto RegsRel

GG:
var abbrev gg
if (%cast = 1) then
{
    put #var autostancedef 0
    put #var autostancedur 0
    put #var autostanceinteg 1
    put #var autostancepot 0
    var spellstancereturn GGCast
    goto CheckSpellStance
}
if ($boosttimer > $unixtime) then
{
    var pausesec 18
}
else
{
    var pausesec 16
}
put #var prepm 1
put #var harn1 67
put #var harn2 67
put #var harnlimit 2
# put #var pausetime #evalmath ($unixtime + 16)
put #var sorcery 1
goto GGPrep

GGPrep:
var shleftreturn GetRuneGG
var shrightreturn GetRuneGG
if ($handdamaged = 1) then
{
    var clearboth 1
    goto SheathR
}
goto EmptyOneHand

GetRuneGG:
matchre GetRuneGG ^\.\.\.wait|^Sorry\,
matchre StopNoRuneGG ^What were you
matchre InvokeRuneGG ^You get|^You are already
matchre HandHurtSB ^You can't pick that up with your hand that damaged\.|^You are missing
put get my axinite runestone from my runestone pouch
matchwait

HandHurtSB:
put #var handdamaged 1
goto RegsRelError

InvokeRuneGG:
put #var pf 0
put #var spelllost 0
put #var tmspellready 0
put #var attackspell 0
put #var stattackspell 0
put #var spellready 0
put #class spelllostwatcher on
put #class spellprepared on
goto InvokeRuneGG2

InvokeRuneGG2:
matchre InvokeRuneGG2 ^\.\.\.wait|^Sorry\,
matchre RegsRelError ^But you're already|^You are already preparing|^You have already fully
matchre GGPrep ^You'll have to hold it
matchre NoCasting ^Something in the area interferes with your spell preparations\.$
matchre StowRune ^Closing your eyes, you carefully bend some mana
matchre DropRune ^You harness a moderate amount of energy
match HeadDamageSB You are in no condition to do that.
put #var pausetime #evalmath ($unixtime + %pausesec)
# if ($longpause != 0) then
# {
#     put #var pausetime #evalmath ($pausetime + $longpause)
# }
put invoke my runestone
matchwait

StowRune:
matchre StowRune ^\.\.\.wait|^Sorry\,
matchre CheckSpellStatus ^You put|^What were you referring
put put my runestone in my runestone pouch
matchwait

DropRune:
if ($pvpjustice = 1) then goto StowSpentRune
matchre DropRune ^\.\.\.wait|^Sorry\,
matchre RegsRel ^You drop
put drop my runestone
matchwait

StowSpentRune:
matchre DropRune ^\.\.\.wait|^Sorry\,
matchre RegsRel ^You put
put put my runestone in my water bag
matchwait

StopNoRuneGG:
put #var norunegg 1
put #var save
echo ***** No Rune *****
goto RegsRel

GGCast:
var shleftreturn GGCastFlame
var shrightreturn GGCastFlame
goto EmptyOneHand

GGCastFlame:
var stowflamereturn GGCast2
goto RemoveFlameSB

GGCast2:
put #var pf 0
put #class spellcast on
if ($backstop > 9) then put #var backstop 0
var ggon 0
action var ggon 1 when nourishes your mind once again\.$|^As the spell dabs at the spirit realm|you feel wiser than before\.$
goto GGCast3

GGCast3:
put #var backstop #evalmath ($backstop + 1)
matchre GGCast3 ^\.\.\.wait|^Sorry\,
# matchre GGCastComplete ^You raise your hand in an imaginary toast to Glythtide|^As the spell dabs at the spirit realm|^You raise your.*?in a toast to Glythtide\.
# matchre GGCastComplete nourishes your mind once again\.$|^As the spell dabs at the spirit realm|you feel wiser than before\.$
# matchre RegsRelError ^Your spell.*?backfires|^You don't have a spell prepared
matchre AssessGG GG Backstop $backstop$
put cast
put rel mana
put echo GG Backstop $backstop
matchwait

AssessGG:
action remove nourishes your mind once again\.$|^As the spell dabs at the spirit realm|you feel wiser than before\.$
if (%ggon = 1) then goto GGCastComplete
goto RegsRelError

GGCastComplete:
put #var ggcasttimer #evalmath ($unixtime + 5)
var stowflamereturn RegsCastVars
goto GetFlameSB

CV:
var abbrev cv
if (%cast = 1) then
{
    put #var autostancedef 0
    put #var autostancedur 0
    put #var autostanceinteg 1
    put #var autostancepot 0
    var spellstancereturn CVCast
    goto CheckSpellStance
}
if ($boosttimer > $unixtime) then
{
    var pausesec 18
}
else
{
    var pausesec 16
}
put #var prepm 1
put #var harn1 89
put #var harn2 88
put #var harnlimit 2
# put #var pausetime #evalmath ($unixtime + 16)
put #var sorcery 1
goto CVPrep

CVPrep:
var shleftreturn GetRuneCV
var shrightreturn GetRuneCV
if ($handdamaged = 1) then
{
    var clearboth 1
    goto SheathR
}
goto EmptyOneHand

GetRuneCV:
matchre GetRuneCV ^\.\.\.wait|^Sorry\,
matchre StopNoRuneCV ^What were you
matchre InvokeRuneCV ^You get|^You are already
match HandHurtSB You can't pick that up with your hand that damaged.
put get my avaes runestone from my runestone pouch
matchwait

InvokeRuneCV:
put #var pf 0
put #var spelllost 0
put #var tmspellready 0
put #var attackspell 0
put #var stattackspell 0
put #var spellready 0
put #class spelllostwatcher on
put #class spellprepared on
goto InvokeRuneCV2

InvokeRuneCV2:
matchre InvokeRuneCV2 ^\.\.\.wait|^Sorry\,
matchre RegsRelError ^But you're already|^You are already preparing|^You have already fully
matchre CVPrep ^You'll have to hold it
matchre NoCasting ^Something in the area interferes with your spell preparations\.$
matchre StowRune ^Closing your eyes, you carefully bend some mana
matchre DropRune ^You harness a moderate amount of energy
match HeadDamageSB You are in no condition to do that.
put #var pausetime #evalmath ($unixtime + %pausesec)
# if ($longpause != 0) then
# {
#     put #var pausetime #evalmath ($pausetime + $longpause)
# }
put invoke my runestone
matchwait

StopNoRuneCV:
put #var norunecv 1
put #var save
echo ***** No Rune *****
goto RegsRel

CVCast:
var shleftreturn CVCastFlame
var shrightreturn CVCastFlame
goto EmptyOneHand

CVCastFlame:
var stowflamereturn CVCast2
goto RemoveFlameSB

RemoveFlameSB:
goto %stowflamereturn
if ($combatloop != 0) then goto %stowflamereturn
if ($pvpjustice != 0) then goto %stowflamereturn
matchre CVCast ^\.\.\.wait|^Sorry\,
matchre StowFlame ^You remove|^You aren't wearing
matchre %stowflamereturn ^Remove what\?
put remove my flame
matchwait

StowFlame:
matchre StowFlame ^\.\.\.wait|^Sorry\,
matchre %stowflamereturn ^You put your|^What were you referring to\?
match LiftFlameSB Perhaps you should
put put my flame in my $backpack
matchwait

LiftFlameSB:
matchre LiftFlameSB ^\.\.\.wait|^Sorry\,
matchre StowFlame ^What did you want to try and lift\?|^You pick up|^You fade in
put lift flame
matchwait

CVCast2:
put #var pf 0
put #class spellcast on
if ($backstop > 9) then put #var backstop 0
var cvcast 0
action var cvcast 1 when ^You feel more aware|^You briefly feel less aware
goto CVCast3

CVCast3:
put #var backstop #evalmath ($backstop + 1)
matchre CVCast3 ^\.\.\.wait|^Sorry\,
# matchre CVCastComplete ^You gesture|^The mental strain of initiating a cyclic spell|^Your spell.*?backfires|^You place your hands on your temples\.|^You don't have a spell prepared
matchre AssessCV CV Backstop $backstop$
put cast
put rel mana
put echo CV Backstop $backstop
matchwait

AssessCV:
action remove ^You feel more aware|^You briefly feel less aware
if (%cvcast = 1) then goto CVCastComplete
goto RegsRelError

CVCastComplete:
put #var cvcastattempt #evalmath ($unixtime + 5)
var stowflamereturn RegsCastVars
goto GetFlameSB

GetFlameSB:
if ($combatloop != 0) then goto %stowflamereturn
if ($pvpdummy != 0) then goto %stowflamereturn
if ($flameoff = 1) then goto %stowflamereturn
matchre GetFlameSB ^\.\.\.wait|^Sorry\,
matchre WearFlameSB ^You get|^You are already|^You pick up
match %stowflamereturn But that is already
put get my flame
matchwait

WearFlameSB:
matchre WearFlameSB ^\.\.\.wait|^Sorry\,
matchre %stowflamereturn ^You attach|^You are already|^Wear what\?
put wear my flame
matchwait

Shadows:
var abbrev shadows
if (%cast = 1) then goto CommonCast
put #var prepm 1
put #var harn1 100
put #var harn2 100
put #var harnlimit 2
# put #var pausetime #evalmath ($unixtime + 16)
if ($boosttimer > $unixtime) then
{
    var pausesec 18
}
else
{
    var pausesec 16
}
put #var sorcery 1
goto ShadowsPrep

ShadowsPrep:
var shleftreturn GetRuneShadows
var shrightreturn GetRuneShadows
if ($handdamaged = 1) then
{
    var clearboth 1
    goto SheathR
}
goto EmptyOneHand

GetRuneShadows:
matchre GetRuneShadows ^\.\.\.wait|^Sorry\,
matchre StopNoRuneShadows ^What were you
matchre InvokeRuneShadows ^You get|^You are already
match HandHurtSB You can't pick that up with your hand that damaged.
put get my azurite runestone from my runestone pouch
matchwait

InvokeRuneShadows:
put #var pf 0
put #var spelllost 0
put #var tmspellready 0
put #var attackspell 0
put #var stattackspell 0
put #var spellready 0
put #class spelllostwatcher on
put #class spellprepared on
goto InvokeRuneShadows2

InvokeRuneShadows2:
matchre InvokeRuneShadows2 ^\.\.\.wait|^Sorry\,
matchre RegsRelError ^But you're already|^You are already preparing|^You have already fully
matchre ShadowsPrep ^You'll have to hold it
matchre NoCasting ^Something in the area interferes with your spell preparations\.$
matchre StowRune ^Closing your eyes, you carefully bend some mana
matchre DropRune ^You harness a moderate amount of energy
match HeadDamageSB You are in no condition to do that.
put #var pausetime #evalmath ($unixtime + %pausesec)
# if ($longpause != 0) then
# {
#     put #var pausetime #evalmath ($pausetime + $longpause)
# }
put invoke my runestone
matchwait

StopNoRuneShadows:
put #var noruneshadows 1
put #var save
echo ***** No Rune *****
goto RegsRel


Bless:
var abbrev bless
var blessmessage 0
if (%cast = 1) then
{
    put #var autostancedef 1
    put #var autostancedur 0
    put #var autostanceinteg 0
    put #var autostancepot 0
    var spellstancereturn BlessCast
    goto CheckSpellStance
}
put #var prepm 1
put #var harn1 70
put #var harn2 70
put #var harnlimit 2
# put #var pausetime #evalmath ($unixtime + 16)
if ($boosttimer > $unixtime) then
{
    var pausesec 18
}
else
{
    var pausesec 16
}
put #var sorcery 1
goto BlessPrep

BlessPrep:
var shleftreturn GetRuneBless
var shrightreturn GetRuneBless
if ($handdamaged = 1) then
{
    var clearboth 1
    goto SheathR
}
goto EmptyOneHand

GetRuneBless:
matchre GetRuneBless ^\.\.\.wait|^Sorry\,
matchre StopNoRuneBless ^What were you
matchre InvokeRuneBless ^You get|^You are already
match HandHurtSB You can't pick that up with your hand that damaged.
put get my elbaite runestone from my runestone pouch
matchwait

InvokeRuneBless:
put #var pf 0
put #var spelllost 0
put #var tmspellready 0
put #var attackspell 0
put #var stattackspell 0
put #var spellready 0
put #class spelllostwatcher on
put #class spellprepared on
goto InvokeRuneBless2

InvokeRuneBless2:
matchre InvokeRuneBless2 ^\.\.\.wait|^Sorry\,
matchre RegsRelError ^But you're already|^You are already preparing|^You have already fully
matchre BlessPrep ^You'll have to hold it
matchre NoCasting ^Something in the area interferes with your spell preparations\.$
matchre StowRune ^Closing your eyes, you carefully bend some mana
matchre DropRune ^You harness a moderate amount of energy
match HeadDamageSB You are in no condition to do that.
put #var pausetime #evalmath ($unixtime + %pausesec)
# if ($longpause != 0) then
# {
#     put #var pausetime #evalmath ($pausetime + $longpause)
# }
put invoke my runestone
matchwait

StopNoRuneBless:
echo ***** No Rune *****
goto CheckSpellStatus

BlessCast:
put #var pf 0
if ("$blesstarget" = "great") then put #var blesstarget greatsword
if ($blesstarget = 0) then goto CommonCast
if (%blessmessage = 1) then goto NounToBless
var blessmessage 1
echo
echo **** Bless Target = $blesstarget ****
echo
goto NounToBless

NounToBless:
# $blesstarget allows for adjectives, which are used for Wield logic. The adjective is removed here in order to make casting syntax consistantly "cast my <noun>."
var blessnoun $blesstarget
eval blessnoun replacere("%blessnoun", "\w+ ", "")
goto HandCheckBless

HandCheckBless:
if ("$righthandnoun" != "") then
{
    if matchre ("%blessnoun" , "$righthandnoun.*") then goto CastBlessRight
    if matchre ("$righthandnoun" , "%blessnoun.*") then goto CastBlessRight
}
if ("$lefthandnoun" != "") then
{
    if matchre ("%blessnoun" , "$lefthandnoun.*") then goto CastBlessLeft
    if matchre ("$lefthandnoun" , "%blessnoun.*") then goto CastBlessLeft
}
if ("$lefthandnoun" = "") then goto GetBlessItem
var shrightreturn GetBlessItem
var shleftreturn GetBlessItem
var clearboth 1
goto SheathR

CastBlessRight:
put #class spellcast on
matchre CastBlessRight ^\.\.\.wait|^Sorry\,
matchre BlessExit ^You gesture
matchre RegsRelError ^You don't have a spell prepared|^Your spell.*?backfires
put cast my $righthandnoun
put rel mana
matchwait

CastBlessLeft:
put #class spellcast on
matchre CastBlessLeft ^\.\.\.wait|^Sorry\,
matchre BlessExit ^You gesture
matchre RegsRelError ^You don't have a spell prepared|^Your spell.*?backfires
put cast my $lefthandnoun
put rel mana
matchwait

GetBlessItem:
matchre GetBlessItem ^\.\.\.wait|^Sorry\,
matchre HandCheckBless ^You draw out|^You are already
match LiftBlessItem You find it difficult to wield
match NothingtoBless I could not find
matchre HandDamageSevereSC ^Your .*hand is too injured to draw .*\!$
put wield my $blesstarget
put rel mana
matchwait

LiftBlessItem:
matchre LiftBlessItem ^\.\.\.wait|^Sorry\,
matchre HandCheckBless ^You pick up|^You fade in
match NothingtoBless I could not find
put lift %blessnoun
matchwait

NothingtoBless:
put #echo >Conversation
put #echo >Conversation #000000 *** Could Not Find Bless Target
echo
echo **** Could Not Find Bless Target ****
put #var blesstarget 0
goto RegsRelError

BlessExit:
put #var blesstarget 0
# if ($combatloop = 0) then
# {
#     var shleftreturn MagicExit
#     goto SheathR
# }
goto CheckSpellStatus

LW:
var abbrev lw
if (%cast = 1) then
{
    if (%pf = 1) then 
    {
        var getpfocreturn CommonCastPF
        goto GetPFoc
    }
}
if (%cast = 1) then goto CommonCast
if (%pf = 1) then
{
    # put #var pfpausetime #evalmath ($unixtime + 5)
    if ($boosttimer > $unixtime) then
    {
        var secpausepf 7
    }
    else
    {
        var secpausepf 5
    }
    put #var pfprepm 34
    put #var pfharn1 33
    put #var pfharn2 33
    put #var pfharnlimit 2
    var getpfocreturn CommonPrepPF
    goto GetPFoc
}
# put #var pausetime #evalmath ($unixtime + 5)
if ($boosttimer > $unixtime) then
{
    var pausesec 7
}
else
{
    var pausesec 5
}
put #var prepm 34
put #var harn1 33
put #var harn2 33
put #var harnlimit 2
goto CommonPrep

AC:
var abbrev ac
# if (%cast != 1) then goto AC2
# put #class firerainstart off
# put #class firerain off
# put #class electrostaticeddystart off
# put #class electrostaticeddy off
# put #class aethercloakstart on
# put #class aethercloak on
# put #class rimefangstart off
# put #class rimefang off
# goto AC2

# AC2:
if (%cast = 1) then
{
    if (%pf = 1) then 
    {
        var getpfocreturn CheckSpellStance
        put #var autostancedef 1
        put #var autostancedur 0
        put #var autostanceinteg 0
        put #var autostancepot 0
        var spellstancereturn ACCastPF
        goto GetPFoc
    }
}
if (%cast = 1) then
{
    put #var autostancedef 1
    put #var autostancedur 0
    put #var autostanceinteg 0
    put #var autostancepot 0
    var spellstancereturn ACCast
    goto CheckSpellStance
}
if (%pf = 1) then goto ACPF2
goto AC3

ACPF2:
var secpausepf 5
# put #var dbtimer #evalmath ($unixtime + 35)
put #var pfprepm 25
put #var pfharn1 0
put #var pfharn2 0
put #var pfharnlimit 0
var getpfocreturn CommonPrepPF
goto GetPFoc

AC3:
var pausesec 5
# put #var dbtimer #evalmath ($unixtime + 35)
put #var prepm 25
put #var harn1 0
put #var harn2 0
put #var harnlimit 0
goto CommonPrep

ACCastPF:
if ($eeon = 1) then goto ACCastRelPF
if ($fron = 1) then goto ACCastRelPF
if ($rimon = 1) then goto ACCastRelPF
# if ($acon = 1) then goto ACCastRelPF
goto ACCastPF2

ACCastRelPF:
var relcyclic 1
var relreturn ACCastPF2
goto RelSpell

ACCastPF2:
put #var pf 1
put #class spellcast on
put #class aethercloakstart on
put #var invisattack 0
matchre ACCastPF2 ^\.\.\.wait|^Sorry\,
matchre ACCastErrorPF ^I do not understand what you mean\.$|^You wave your spiritwood cube around\.$|^The mental strain of initiating a cyclic spell|^Your spell.*?backfires
matchre CheckSpellStatus ^Everything seems to darken, and you feel slightly colder as a cloak of aether folds itself possessively about you\.
matchre ACFLRPF ^Residual energy from Fire Lion Reborn is interfering with the flows of dark aether\.
put wave my cube
matchwait

ACCastErrorPF:
put #class aethercloakstart off
put #var cyclicinitiated 0
goto PFRel

ACFLRPF:
put #class aethercloakstart off
# if ($dbtimer <= $unixtime) then put #var dbtimer #evalmath ($unixtime + 35)
put #class db on
put #var dbtimer #evalmath ($unixtime + 85)
put #var cyclicinitiated 0
goto PFRel

ACCast:
if ($eeon = 1) then goto ACCastRel
if ($rimon = 1) then goto ACCastRel
if ($fron = 1) then goto ACCastRel
if ($acon = 1) then goto ACCastRel
goto ACCast2

ACCastRel:
var relcyclic 1
var relreturn ACCast2
goto RelSpell

ACCast2:
put #var pf 0
put #class spellcast on
put #class aethercloakstart on
put #var invisattack 0
matchre ACCast2 ^\.\.\.wait|^Sorry\,
matchre ACCastError ^You don't have a spell prepared|^The mental strain of initiating a cyclic spell|^Your spell.*?backfires
matchre RegsCastVars ^Everything seems to darken, and you feel slightly colder as a cloak of aether folds itself possessively about you\.
matchre ACFLR ^Residual energy from Fire Lion Reborn is interfering with the flows of dark aether\.
put cast
matchwait

ACCastError:
put #class aethercloakstart off
put #var cyclicinitiated 0
goto RegsRel

ACFLR:
put #class aethercloakstart off
# if ($dbtimer <= $unixtime) then put #var dbtimer #evalmath ($unixtime + 35)
put #class db on
put #var dbtimer #evalmath ($unixtime + 85)
put #var cyclicinitiated 0
goto RegsRel

REPR:
var abbrev repr
if (%cast = 1) then
{
    if (%pf = 1) then 
    {
        put #class reprrefresh on
        var getpfocreturn CheckSpellStance
        put #var autostancedef 0
        put #var autostancedur 0
        put #var autostanceinteg 1
        put #var autostancepot 0
        var spellstancereturn CommonCastPF
        goto GetPFoc
    }
}
if (%cast = 1) then 
{
    put #class reprrefresh on
    put #var autostancedef 0
    put #var autostancedur 0
    put #var autostanceinteg 1
    put #var autostancepot 0
    var spellstancereturn CommonCast
    goto CheckSpellStance
}
if (%pf = 1) then goto REPRManaCheckPF
goto REPRManaCheck

REPRManaCheckPF:
if ($mana > 69) then
{
    # put #var pfpausetime #evalmath ($unixtime + 9)
    var secpausepf 9
    put #var pfprepm 88
    put #var pfharn1 0
    put #var pfharn2 0
    put #var pfharnlimit 0
    var getpfocreturn PrepREPRPF
    goto GetPFoc
}
# put #var pfpausetime #evalmath ($unixtime + 5)
if ($boosttimer > $unixtime) then
{
    var secpausepf 7
}
else
{
    var secpausepf 5
}
put #var pfprepm 29
put #var pfharn1 30
put #var pfharn2 29
put #var pfharnlimit 2
var getpfocreturn PrepREPRPF
goto GetPFoc

REPRManaCheck:
if ($mana > 69) then
{
    # put #var pausetime #evalmath ($unixtime + 9)
    var pausesec 9
    put #var prepm 88
    put #var harn1 0
    put #var harn2 0
    put #var harnlimit 0
    goto PrepREPR
}
# put #var pausetime #evalmath ($unixtime + 5)
if ($boosttimer > $unixtime) then
{
    var pausesec 7
}
else
{
    var pausesec 5
}
put #var prepm 29
put #var harn1 30
put #var harn2 29
put #var harnlimit 2
goto PrepREPR

PrepREPR:
put #var pf 0
put #var spelllost 0
put #var tmspellready 0
put #var attackspell 0
put #var stattackspell 0
put #var spellready 0
put #class spelllostwatcher on
put #class spellprepared on
goto PrepREPR2

PrepREPR2:
matchre PrepREPR2 ^\.\.\.wait|^Sorry\,
matchre RegsRelError ^But you're already|^You are already preparing|^You have already fully
matchre NoCasting ^Something in the area interferes with your spell preparations\.$
match NoREPRSc You have no idea how to cast that spell.
matchre CheckSpellStatus ^You trace a geometric sigil in the air
match SpellStollen You seem to have forgotten this spell!
put #var pausetime #evalmath ($unixtime + %pausesec)
if ($longpause != 0) then
{
    put #var pausetime #evalmath ($pausetime + $longpause)
}
put prep %abbrev $prepm
matchwait

PrepREPRPF:
put #var pf 1
# put #class pfspellprep on
put #var pfspellprepped 1
put #var pfspellready 0
put #class pfspellloss on
put #class pfspellprepared on
goto PrepREPRPF2

PrepREPRPF2:
matchre PrepREPRPF2 ^\.\.\.wait|^Sorry\,
matchre RelPFError ^But you're already|^You are already preparing|^Invoke what\?$
matchre NoCasting ^Something in the area interferes with your spell preparations\.$
match NoREPRSc You have no idea how to cast that spell.
matchre CheckSpellStatus ^You begin channeling mana
match SpellStollen You seem to have forgotten this spell!
put #var pfspelltimer #evalmath ($unixtime + 69)
put #var pfpausetime #evalmath ($unixtime + %secpausepf)
if ($longpause != 0) then
{
    put #var pfpausetime #evalmath ($pfpausetime + $longpause)
}
put invoke my cube %abbrev $pfprepm
matchwait

NoREPRSc:
put #var noscrollrepr 1
var relreturn CheckSpellStatus
if ($pf = 1) then
{
    var relpf 1
    goto RelSpell
}
var commonrel 1
goto RelSpell

AWAKEN:
var abbrev awaken
if (%cast = 1) then
{
    if (%pf = 1) then 
    {
        var getpfocreturn CheckSpellStance
        put #var autostancedef 0
        put #var autostancedur 0
        put #var autostanceinteg 1
        put #var autostancepot 0
        var spellstancereturn AwakenCastPF
        goto GetPFoc
    }
}
if (%cast = 1) then
{
    put #var autostancedef 0
    put #var autostancedur 0
    put #var autostanceinteg 1
    put #var autostancepot 0
    var spellstancereturn AwakenCast
    goto CheckSpellStance
}
if (%pf = 1) then goto AWAManaCheckPF
goto AWAManaCheck

AWAManaCheckPF:
# if ($mana > 69) then
# {
#     # put #var pfpausetime #evalmath ($unixtime + 8)
#     var secpausepf 8
#     put #var pfprepm 56
#     put #var pfharn1 57
#     put #var pfharn2 0
#     put #var pfharnlimit 1
#     put #var pfsorcery 1
#     var getpfocreturn PrepAwakenPF
#     goto GetPFoc
# }
# put #var pfpausetime #evalmath ($unixtime + 6)
var secpausepf 8
put #var pfprepm 89
put #var pfharn1 0
put #var pfharn2 0
put #var pfharnlimit 0
put #var pfsorcery 1
var getpfocreturn PrepAwakenPF
goto GetPFoc

AWAManaCheck:
# if ($mana > 69) then
# {
#     # put #var pausetime #evalmath ($unixtime + 10)
#     var pausesec 8
#     put #var prepm 56
#     put #var harn1 56
#     put #var harn2 0
#     put #var harnlimit 1
#     put #var sorcery 1
#     goto PrepAwaken
# }
# # put #var pausetime #evalmath ($unixtime + 6)
var pausesec 8
put #var prepm 89
put #var harn1 0
put #var harn2 0
put #var harnlimit 0
put #var sorcery 1
goto PrepAwaken

PrepAwaken:
put #var pf 0
put #var spelllost 0
put #var tmspellready 0
put #var attackspell 0
put #var stattackspell 0
put #var spellready 0
put #class spelllostwatcher on
put #class spellprepared on
goto PrepAwaken2

PrepAwaken2:
matchre PrepAwaken2 ^\.\.\.wait|^Sorry\,
matchre RegsRelError ^But you're already|^You are already preparing|^You have already fully
matchre NoCasting ^Something in the area interferes with your spell preparations\.$
match NoAwakenSc You have no idea how to cast that spell.
matchre CheckSpellStatus ^You trace a geometric sigil in the air
match SpellStollen You seem to have forgotten this spell!
put #var pausetime #evalmath ($unixtime + %pausesec)
if ($longpause != 0) then
{
    put #var pausetime #evalmath ($pausetime + $longpause)
}
put prep %abbrev $prepm
matchwait

PrepAwakenPF:
put #var pf 1
# put #class pfspellprep on
put #var pfspellprepped 1
put #var pfspellready 0
put #class pfspellloss on
put #class pfspellprepared on
goto PrepAwakenPF2

PrepAwakenPF2:
matchre PrepAwakenPF2 ^\.\.\.wait|^Sorry\,
matchre RelPFError ^But you're already|^You are already preparing|^Invoke what\?$
matchre NoCasting ^Something in the area interferes with your spell preparations\.$
match NoAwakenSc You have no idea how to cast that spell.
matchre CheckSpellStatus ^You begin channeling mana
match SpellStollen You seem to have forgotten this spell!
put #var pfspelltimer #evalmath ($unixtime + 69)
put #var pfpausetime #evalmath ($unixtime + %secpausepf)
if ($longpause != 0) then
{
    put #var pfpausetime #evalmath ($pfpausetime + $longpause)
}
put invoke my cube %abbrev $pfprepm
matchwait

NoAwakenSc:
put #var noscrollawaken 1
var relreturn CheckSpellStatus
if ($pf = 1) then
{
    var relpf 1
    goto RelSpell
}
var commonrel 1
goto RelSpell

AwakenCastPF:
put #var pf 1
put #class spellcast on
if ($backstop > 9) then put #var backstop 0
var awakencast 0
action var awakencast 1 when you are pervaded by a feeling of sobered vigilance\.$
goto AwakenCastPF2

AwakenCastPF2:
put #var backstop #evalmath ($backstop + 1)
matchre AwakenCastPF2 ^\.\.\.wait|^Sorry\,
# matchre AwakenCastVars you are pervaded by a feeling of sobered vigilance\.$
# matchre RelPFError ^I do not understand what you mean\.|^You wave your spiritwood cube around\.|^Your spell.*?backfires
matchre AssessPFAwaken Awaken Backstop $backstop$
put wave my cube
put rel mana
put echo Awaken Backstop $backstop
matchwait

AssessPFAwaken:
action remove you are pervaded by a feeling of sobered vigilance\.$
if (%awakencast = 1) then goto AwakenCastVars
goto RelPFError

AwakenCast:
put #var pf 0
put #class spellcast on
if ($backstop > 9) then put #var backstop 0
var awakencast 0
action var awakencast 1 when you are pervaded by a feeling of sobered vigilance\.$
goto AwakenCast2

AwakenCast2:
put #var backstop #evalmath ($backstop + 1)
matchre AwakenCast2 ^\.\.\.wait|^Sorry\,
# matchre AwakenCastVars you are pervaded by a feeling of sobered vigilance\.$
# matchre RegsRelError ^You don't have a spell prepared|^Your spell.*?backfires
matchre AssessAwaken Awaken Backstop $backstop$
put cast
put rel mana
put echo Awaken Backstop $backstop
matchwait

AssessAwaken:
action remove you are pervaded by a feeling of sobered vigilance\.$
if (%awakencast = 1) then goto AwakenCastVars
goto RegsRelError

AwakenCastVars:
put #var awakencasttimer #evalmath ($unixtime + 5)
if (%pf = 1) then goto CheckSpellStatus
goto RegsCastVars

# TM

AoETMPrep:
put #var pf 0
put #var spelllost 0
put #var tmspellready 0
put #var stattackspell 0
put #var attackspell 1
put #var spellready 0
put #class spelllostwatcher on
put #class tmfulltarget on
if ($aoearea = 0) then goto AoETMPrep2
if ($pvptarget = 0) then goto AoETMPrep2
# if ("$roomplayers" != "") then goto AoETMPrep2
if ($pvpdummy != 0) then goto AoETMPrep2
goto AoETargetArea

AoETMPrep2:
matchre AoETMPrep2 ^\.\.\.wait|^Sorry\,
matchre RegsRelError ^But you're already|^You are already preparing|^You have already fully
matchre NoCasting ^Something in the area interferes with your spell preparations\.$
matchre CheckSpellStatus ^You begin to weave mana lines
match SpellStollen You seem to have forgotten this spell!
matchre PeaceRoomSB ^As you attempt to prepare the spell, a sense of overwhelming peace washes over you\.
match CalmedEffectSB Your desire to prepare this offensive spell suddenly slips away.
put #var pausetime #evalmath ($unixtime + %pausesec)
put target %abbrev $prepm
matchwait

AoETargetArea:
matchre AoETargetArea ^\.\.\.wait|^Sorry\,
matchre RegsRelError ^But you're already|^You are already preparing|^You have already fully
matchre NoCasting ^Something in the area interferes with your spell preparations\.$
matchre CheckSpellStatus ^You begin to weave mana lines
match SpellStollen You seem to have forgotten this spell!
matchre PeaceRoomSB ^As you attempt to prepare the spell, a sense of overwhelming peace washes over you\.
match CalmedEffectSB Your desire to prepare this offensive spell suddenly slips away.
put #var pausetime #evalmath ($unixtime + %pausesec)
put target %abbrev $prepm at nongroup
matchwait

FacingCheckSB:
if ($pvptarget = 0) then goto %facereturn
if ($targetfaced = 1) then goto %facereturn
if ($meleelasttime = 1) then goto %facereturn
if ($charmed = 1) then goto %facereturn
var targetvisible FacingCheckSB2
var targetspoteffect FacingEngageSB
var targetnotvisible %facereturn
goto CheckVisiblity

FacingCheckSB2:
if ($backstop > 9) then put #var backstop 0
goto FacingCheckSB3

FacingCheckSB3:
put #var backstop #evalmath ($backstop + 1)
matchre FacingCheckSB3 ^\.\.\.wait|^Sorry\,
matchre FacingSBVars ^You turn to face|^You are already
matchre CharmedSB ^Abruptly, you lose all track of why you were intending to engage
matchre %facereturn CheckFacing Backup $backstop$
put face $pvptarget
put echo CheckFacing Backup $backstop
matchwait

FacingEngageSB:
if ($backstop > 9) then put #var backstop 0
goto FacingEngageSB2

FacingEngageSB2:
put #var backstop #evalmath ($backstop + 1)
matchre FacingEngageSB2 ^\.\.\.wait|^Sorry\,
matchre SBEngageRet ^You will have to retreat
matchre FacingSBVars ^You spin around to|^You begin to|^You begin to stealthily|^You are already advancing
matchre AtMeleeSB ^You are already at melee
matchre CharmedSB ^Abruptly, you lose all track of why you were intending to engage
matchre %facereturn FacingEngage Backup $backstop$
put engage $pvptarget
put echo FacingEngage Backup $backstop
matchwait

FacingSBVars:
put #var targetfaced 1
if ($meleelasttime != 0) then put #var meleelasttime 0
goto %facereturn

SBEngageRet:
var retreatreturn FacingEngageSB
var warstompreturn %facereturn
var grapplereturn %facereturn
goto Retreat

AtMeleeSB:
if ($targetfaced != 1) then put #var targetfaced 1
put #var meleelasttime 1
put #class retreatwatcher on
goto %facereturn

CharmedSB:
put #var charmed 1
put .res
exit

FacingOpSB:
put #var targetfaced 1
goto %facereturn

AoETMCast:
if ($acon = 1) then
{
    var acrelreturn AoETMCast1
    goto ACRel
}
goto AoETMCast1

AoETMCast1:
put #var pf 0
put #class spellcast on
goto AoETMCast2

AoETMCast2:
matchre AoETMCast2 ^\.\.\.wait|^Sorry\,
matchre PathRelCheck ^You gesture|^The mental strain of initiating a cyclic spell|^Your spell.*?backfires|^The spell pattern collapses
match RegsRelError You don't have a spell prepared
match CalmedEffectSB You don't feel like casting that kind of spell right now.
put cast
matchwait

STTMPrep:
put #var pf 0
put #var spelllost 0
put #var tmspellready 0
put #var stattackspell 1
put #var attackspell 0
put #var spellready 0
put #class spelllostwatcher on
put #class tmfulltarget on
if (%targethead = 1) then goto STTMHead
if (%targetchest = 1) then goto STTMChest
goto STTMPrep2

STTMPrep2:
# put #class sttmprep on
matchre STTMPrep2 ^\.\.\.wait|^Sorry\,
matchre RegsRelError ^But you're already|^You are already preparing|^You have already fully
matchre NoCasting ^Something in the area interferes with your spell preparations\.$
matchre STTMTargeting ^You begin to weave mana lines
matchre RelSpellNoEnemies ^There is nothing else to face\!$|^I could not find what you were referring to\.$|^You can't cast|^Face what\?$
match SpellStollen You seem to have forgotten this spell!
matchre PeaceRoomSB ^As you attempt to prepare the spell, a sense of overwhelming peace washes over you\.
match CalmedEffectSB Your desire to prepare this offensive spell suddenly slips away.
put #var pausetime #evalmath ($unixtime + %pausesec)
# if ($longpause != 0) then
# {
#     put #var pausetime #evalmath ($pausetime + $longpause)
# }
if ($pvptarget = 0) then put target %abbrev $prepm
if ($pvptarget != 0) then put target %abbrev $prepm at $pvptarget
matchwait

STTMTargeting:
if matchre ("$rspellname" , "Gar Zeng|Stone Strike") then goto SpellEngage
goto CheckSpellStatus

SpellEngage:
if ($meleelasttime != 0) then
{
    if ($targetfaced != 0) then goto CheckSpellStatus
}
if ($backstop > 9) then put #var backstop 0
goto SpellEngage2

SpellEngage2:
put #var backstop #evalmath ($backstop + 1)
matchre SpellEngage2 ^\.\.\.wait|^Sorry\,
matchre SpellEngageRet ^You will have to retreat
matchre SpellEngageSuccess ^You spin around to|^You begin to|^You begin to stealthily|^You are already advancing
matchre SpellEnageAtMelee ^You are already at melee
matchre CheckSpellStatus SpellEngage Backup $backstop$
put engage $pvptarget
put echo SpellEngage Backup $backstop
matchwait

SpellEngageSuccess:
if ($targetfaced != 1) then put #var targetfaced 1
if ($meleelasttime != 0) then put #var meleelasttime 0
goto CheckSpellStatus

SpellEngageRet:
var retreatreturn SpellEngage
var warstompreturn CheckSpellStatus
var grapplereturn CheckSpellStatus
goto Retreat

SpellEnageAtMelee:
put #class retreatwatcher on
if ($targetfaced != 1) then put #var targetfaced 1
put #var meleelasttime 1
goto CheckSpellStatus

STTMChest:
var targetchest 0
matchre STTMChest ^\.\.\.wait|^Sorry\,
matchre RegsRelError ^But you're already|^You are already preparing|^You have already fully|^You must be preparing
matchre NoCasting ^Something in the area interferes with your spell preparations\.$
matchre CheckSpellStatus ^You begin to weave mana lines
matchre RelSpellNoEnemies ^There is nothing else to face\!$|^I could not find what you were referring to\.$|^You can't cast|^Face what\?$
match SpellStollen You seem to have forgotten this spell!
# matchre PeaceRoomSB ^As you attempt to prepare the spell, a sense of overwhelming peace washes over you\.$|^Your desire to prepare this offensive spell suddenly slips away\.$
matchre PeaceRoomSB ^As you attempt to prepare the spell, a sense of overwhelming peace washes over you\.
match CalmedEffectSB Your desire to prepare this offensive spell suddenly slips away.
put #var pausetime #evalmath ($unixtime + %pausesec)
# if ($longpause != 0) then
# {
#     put #var pausetime #evalmath ($pausetime + $longpause)
# }
put prep %abbrev $prepm
if ($pvptarget != 0) then put target $pvptarget chest
if ($pvptarget = 0) then put target chest
matchwait

STTMHead:
var targethead 0
matchre STTMHead ^\.\.\.wait|^Sorry\,
matchre RegsRelError ^But you're already|^You are already preparing|^You have already fully|^You must be preparing
matchre NoCasting ^Something in the area interferes with your spell preparations\.$
matchre CheckSpellStatus ^You begin to weave mana lines
matchre RelSpellNoEnemies ^There is nothing else to face\!$|^I could not find what you were referring to\.$|^You can't cast|^Face what\?$
match SpellStollen You seem to have forgotten this spell!
# matchre PeaceRoomSB ^As you attempt to prepare the spell, a sense of overwhelming peace washes over you\.$|^Your desire to prepare this offensive spell suddenly slips away\.$
matchre PeaceRoomSB ^As you attempt to prepare the spell, a sense of overwhelming peace washes over you\.
match CalmedEffectSB Your desire to prepare this offensive spell suddenly slips away.
put #var pausetime #evalmath ($unixtime + %pausesec)
put prep %abbrev $prepm
if ($pvptarget != 0) then put target $pvptarget head
if ($pvptarget = 0) then put target head
matchwait

ACRel:
matchre ACRel ^\.\.\.wait|^Sorry\,
matchre %acrelreturn ^Release what\?|^The dark mantle of aether surrounding you
put rel ac
matchwait

STTMCast:
var spellbookdbreturn BarrageCheck
var barragereturn STTMCast2
goto SpellBookDBCheck

SpellBookDBCheck:
if ($pvptarget = 0) then goto DragonsBreathCheck3
# DragonsBreathCheck2:
if ($autoac != 1) then goto DragonsBreathCheck21
var debilcheckreturn DragonsBreathCheck2
goto CheckDebil

DragonsBreathCheck2:
if (%debil = 1) then goto DragonsBreathCheck3
goto %spellbookdbreturn

DragonsBreathCheck21:
# if ($refdebil != 0) then goto %spellbookdbreturn
# if ($spiritdebil != 0) then goto %spellbookdbreturn
if ($wellbalanced != 1) then goto %spellbookdbreturn
goto DragonsBreathCheck3

DragonsBreathCheck3:
if ($SpellTimer.DragonsBreath.active = 0) then goto %spellbookdbreturn
if ($dbtimer > $unixtime) then goto %spellbookdbreturn
if ($autodb = 0) then goto %spellbookdbreturn
if matchre ("$rspellname" , "Aethrolysis|Paeldryth's Wrath") then goto %spellbookdbreturn
if ($nomagic = 1) then goto %spellbookdbreturn
if ($notm = 1) then goto %spellbookdbreturn
if ($fireoff = 1) then goto %spellbookdbreturn
if ($bo = 1) then goto %spellbookdbreturn
if ($pvptarget = 0) then goto DragonsBreathCheck5
var targetvisible DragonsBreathCheck5
var targetspoteffect DragonsBreathCheck4
var targetnotvisible DragonsBreathCheck4
goto CheckVisiblity

DragonsBreathCheck4:
if ($acon = 1) then goto %spellbookdbreturn
if ($invisible = 1) then goto %spellbookdbreturn
if ($hidden = 1) then goto %spellbookdbreturn
goto DBPoint

DBPoint:
matchre DBPoint ^\.\.\.wait|^Sorry\,
matchre DragonsBreathCheck5 You point at.*hiding place\.$|^You point|^With a casual flick of your wrists
matchre %spellbookdbreturn ^I could not find what|^That wouldn't be very useful since you're invisible\.
put point $pvptarget
matchwait

DragonsBreathCheck5:
var bgreturn DragonsBreathCheck6
goto SlapPvPTarget

DragonsBreathCheck6:
var relac 1
var dbreturn %spellbookdbreturn
goto Exhale

BarrageCheck:
if ($tmspellready != 1) then goto %barragereturn
if ($nocharge = 1) then goto %barragereturn
if ($stattackspell != 1) then goto %barragereturn
if ($tmfoc = 1) then goto %barragereturn
if matchre ("$rspellname" , "Aethrolysis|Paeldryth's Wrath") then goto %barragereturn
if ($meleelasttime != 1) then
{
    if ($polerange != 1) then goto %barragereturn
}
if ($kickonly = 1) then goto %barragereturn
if ("$lefthandnoun" != "") then
{
    var shleftreturn BarrageCheck2
    goto SheathL
}
goto BarrageCheck2

BarrageCheck2:
if matchre ("$righthand" , "marauder blade|greatsword") then goto BarrageSlice
if matchre ("$righthand" , "lance") then goto BarrageThrust
goto BarrageSliceCheck

BarrageSliceCheck:
var bowreturn BarrageSliceCheck2
goto PowerShot

BarrageSliceCheck2:
if ("$eweap" = "marauder blade") then
{
    if ($eweaptimer > $unixtime) then goto DrawCleaver
}
if matchre ("$eweap" , "lance") then
{
    if ($eweaptimer > $unixtime) then goto DrawImp
}
goto WieldBarrageGS

DrawCleaver:
matchre DrawCleaver ^\.\.\.wait|^Sorry\,
match WieldBarrageGS Wield what?
matchre BarrageSlice ^You draw out|^You're already holding
matchre BarrageCheck ^You need to have a free hand
matchre HandDamageSevereSB ^Your .*hand is too injured to draw .*\!|^You are missing
matchre LiftMarauderBladeSB ^You find it difficult to wield
put wield my marauder blade
matchwait

LiftMarauderBladeSB:
matchre LiftMarauderBladeSB ^\.\.\.wait|^Sorry\,
matchre BarrageSlice ^You pick up|^You fade in
put lift blade
matchwait

DrawImp:
if matchre ("$eweap" , "lightning") then goto DrawElecImp
goto DrawIceImp

DrawIceImp:
matchre DrawIceImp ^\.\.\.wait|^Sorry\,
match WieldBarrageGS Wield what?
matchre BarrageThrust ^You draw out|^You're already holding
matchre BarrageCheck ^You need to have a free hand
matchre HandDamageSevereSB ^Your .*hand is too injured to draw .*\!|^You are missing
matchre LiftLanceSB ^You find it difficult to wield
put wield my water lance
matchwait

DrawElecImp:
matchre DrawElecImp ^\.\.\.wait|^Sorry\,
match WieldBarrageGS Wield what?
matchre BarrageThrust ^You draw out|^You're already holding
matchre BarrageCheck ^You need to have a free hand
matchre HandDamageSevereSB ^Your .*hand is too injured to draw .*\!|^You are missing
matchre LiftLanceSB ^You find it difficult to wield
put wield my lightning lance
matchwait

LiftLanceSB:
matchre LiftLanceSB ^\.\.\.wait|^Sorry\,
matchre BarrageThrust ^You pick up|^You fade in
put lift lance
matchwait

WieldBarrageGS:
# if ($lefthandnoun != "") then
# {
#     var shleftreturn WieldBarrageGS2
#     goto SheathL
# }
if ("$righthandnoun" = "greatsword") then goto BarrageSlice
var shleftreturn WieldBarrageGS2
var shrightreturn WieldBarrageGS2
var clearboth 1
goto SheathR

WieldBarrageGS2:
matchre WieldBarrageGS2 ^\.\.\.wait|^Sorry\,
matchre BarrageSlice balancing with your left\.$|^You're already holding
matchre LiftGSSB ^You find it difficult to wield
matchre HandDamageSevereSB ^Your .*hand is too injured to draw .*\!|^You are missing
put wield my greatsword
matchwait

HandDamageSevereSB:
put #var handdamaged 1
put #var kickonly 1
goto STTMCast2

LiftGSSB:
matchre LiftGSSB ^\.\.\.wait|^Sorry\,
matchre BarrageSlice ^You pick up|^You fade in
put lift greatsword
matchwait

BarrageSlice:
if ($acon = 1) then
{
    var acrelreturn BarrageSlice1
    goto ACRel
}
goto BarrageSlice1

BarrageSlice1:
var calmed 0
var nocharge 0
var outofrange 0
put #var pf 0
put #class spellcast on
if ($backstop > 9) then put #var backstop 0
action var calmed 1 when ^You don't feel like casting that kind of spell right now.|^Strangely, you don't feel like fighting
action var outofrange 1 when ^You aren't close enough to attack|^It's flying out of reach\!
action var nocharge 1 when ^You are unable to muster the energy to do that\.
goto BarrageSlice2

BarrageSlice2:
put #var backstop #evalmath ($backstop + 1)
matchre BarrageSlice2 ^\.\.\.wait|^Sorry\,
# matchre PathRelCheck ^You gesture|^Your spell.*?backfires|^Your fingerbones phosphoresce hylomorphic|^You reach out toward|^You extend your|^The spell pattern collapses
# match RegsRelError You don't have a spell prepared
# matchre RelSpellNoEnemies ^Your target pattern dissipates|^You can't cast
# match CalmedEffectSB You don't feel like casting that kind of spell right now.
matchre AssessBarrage Barrage Backup $backstop$
put barrage slice
put echo Barrage Backup $backstop
matchwait

BarrageThrust:
if ($acon = 1) then
{
    var acrelreturn BarrageThrust1
    goto ACRel
}
goto BarrageThrust1

BarrageThrust1:
var calmed 0
var nocharge 0
var outofrange 0
put #var pf 0
put #class spellcast on
if ($backstop > 9) then put #var backstop 0
action var calmed 1 when ^You don't feel like casting that kind of spell right now.|^Strangely, you don't feel like fighting
action var outofrange 1 when ^You aren't close enough to attack|^It's flying out of reach\!
action var nocharge 1 when ^You are unable to muster the energy to do that\.
goto BarrageThrust2

BarrageThrust2:
put #var backstop #evalmath ($backstop + 1)
matchre BarrageThrust2 ^\.\.\.wait|^Sorry\,
# matchre PathRelCheck ^You gesture|^Your spell.*?backfires|^Your fingerbones phosphoresce hylomorphic|^You reach out toward|^You extend your|^The spell pattern collapses
# match RegsRelError You don't have a spell prepared
# matchre RelSpellNoEnemies ^Your target pattern dissipates|^You can't cast
# match CalmedEffectSB You don't feel like casting that kind of spell right now.
matchre AssessBarrage Barrage Backup $backstop$
put barrage thrust
put echo Barrage Backup $backstop
matchwait

AssessBarrage:
put #class spellcast off
action remove ^You don't feel like casting that kind of spell right now.|^Strangely, you don't feel like fighting
action remove ^You aren't close enough to attack|^It's flying out of reach\!
action remove ^You are unable to muster the energy to do that\.
if (%outofrange = 1) then goto STTMCast2
if (%nocharge = 1) then goto STTMCast2
if (%calmed = 1) then goto CalmedEffectSB
put .res
exit

STTMCast2:
if ($acon = 1) then
{
    var acrelreturn STTMCast21
    goto ACRel
}
goto STTMCast21

STTMCast21:
put #var pf 0
put #class spellcast on
matchre STTMCast2 ^\.\.\.wait|^Sorry\,
matchre PathRelCheck ^You gesture|^Your spell.*?backfires|^Your fingerbones phosphoresce hylomorphic|^You reach out toward|^You extend your|^The spell pattern collapses
match RegsRelError You don't have a spell prepared
matchre RelSpellNoEnemies ^Your target pattern dissipates|^You can't cast
match CalmedEffectSB You don't feel like casting that kind of spell right now.
put cast
matchwait

PathRelCheck:
put #var tmtimer #evalmath ($unixtime + 5)
goto RegsCastVarsRT

PathwayCheck:
if ($nocharge = 1) then goto %pathwayreturn
if !matchre ("$rspellname" , "Lightning Bolt|Frost Scythe|Gar Zeng|Stone Strike|Aethrolysis|Chain Lightning|Shockwave|Paeldryth's Wrath") then goto %pathwayreturn
# if ($stattackspell = 0) then
# {
#     if ($attackspell = 0) then goto %pathwayreturn
# }
if (%prep != 1) then goto PathwayPreciseCheck
if ($pathwayquick != 0) then goto PathwayPreciseCheck
# {
#     # if ("$rspell" = "LB") then
#     # {
#     #     if ($acon != 1) then goto %pathwayreturn
#     # }
#     # if ($pathwaydef = 1) then goto %pathwayreturn
#     if ($pathwayquickon = 1) then
#     {
#         if ($pathwayquick != 1) then goto PathwayQuickCheck
#     }
# }
# goto PathwayPreciseCheck

# PathwayQuickCheck:
if ($pathwayprecise = 1) then goto QuickPWStop
if ($pathwayacc = 1) then goto QuickPWStop
if ($pathwaydaming = 1) then goto QuickPWStop
if ($pathwaydef = 1) then goto QuickPWStop
goto PathwayQuick

QuickPWStop:
var relreturn PathwayQuick
var relpathway 1
goto RelSpell

PathwayPreciseCheck:
if (%cast != 1) then goto %pathwayreturn
if ($targethead = 0) then
{
    if ($targetchest = 0) then goto PathwayAccCheck
}
if !matchre ("$preparedspell" , "Paeldryth's Wrath|Lightning Bolt") then goto PathwayAccCheck
if ("$preparedspell" = "Paeldryth's Wrath") then
{
    if ($tmfoc != 1) then goto PathwayAccCheck
    if ($grappled = 1) then goto PathwayAccCheck
}
if ($pathwayprecise = 1) then goto %pathwayreturn
if ($pathwayquick = 1) then goto PrecisePWStop
if ($pathwayacc = 1) then goto PrecisePWStop
if ($pathwaydaming = 1) then goto PrecisePWStop
if ($pathwaydef = 1) then goto PrecisePWStop
goto PathwayPrecise

PrecisePWStop:
var relreturn PathwayPrecise
var relpathway 1
goto RelSpell

PathwayAccCheck:
# if ($pathwayaccon != 1) then goto PathwayDamCheck
if ($tmspellready = 1) then
{
    if ("$preparedspell" = "Lightning Bolt") then goto PathwayDamCheck
    if ($meleelasttime = 1) then
    {
        if matchre ("$preparedspell" , "Gar Zeng|Stone Strike") then goto PathwayDamCheck
    }
}
if ($pathwayacc = 1) then goto %pathwayreturn
if ($pathwayquick = 1) then goto AccPWStop
if ($pathwayprecise = 1) then goto AccPWStop
if ($pathwaydaming = 1) then goto AccPWStop
if ($pathwaydef = 1) then goto AccPWStop
goto PathwayAcc

AccPWStop:
var relreturn PathwayAcc
var relpathway 1
goto RelSpell

PathwayDamCheck:
# if ($pathwaydam = 0) then goto %pathwayreturn
if ($pathwaydaming = 1) then goto %pathwayreturn 
goto PathwayDam

SwitchToFB:
if ($elecoff = 1) then goto SwitchtoSTS
if ($fireoff = 1) then goto SwitchtoSTS
put #echo >Conversation
put #echo >Conversation #000000 *** Justice On
put #echo >Conversation #000000 *** Switching to GZ
echo
echo **** Justice On ****
echo **** Switching to GZ ****
put #var autolb 0
put #var autofb 0
put #var autoshw 0
put #var autofs 0
put #var autosts 0
put #var autogz 1
put #var autohot 0
put #var autofrs 0
put #var autoaeth 0
put #var chainlit 0
if (%cast = 1) then
{
    var relreturn CheckSpellStatus
    var commonrel 1
    goto RelSpell
}
goto GZ

SwitchtoSTS:
put #echo >Conversation
put #echo >Conversation #000000 *** Justice On
put #echo >Conversation #000000 *** Switching to STS
echo
echo **** Justice On ****
echo **** Switching to STS ****
put #var autolb 0
put #var autofb 0
put #var autoshw 0
put #var autofs 0
put #var autosts 1
put #var autogz 0
put #var autohot 0
put #var autofrs 0
put #var autoaeth 0
put #var chainlit 0
if (%cast = 1) then
{
    var relreturn CheckSpellStatus
    var commonrel 1
    goto RelSpell
}
goto STS

SwitchToRIM:
put #echo >Conversation
put #echo >Conversation #000000 *** Justice On
put #echo >Conversation #000000 *** Switching to RIM
echo
echo **** Justice On ****
echo **** Switching to RIM ****
if (%cast = 1) then
{
    var relreturn CheckSpellStatus
    var commonrel 1
    goto RelSpell
}
goto RIM

TMPFCheckSB:
if ($pfpausetime = 0) then goto %tmplfocusreturn
if ($unixtime > $pfpausetime) then goto TMPFCheckSkipSB
goto %tmplfocusreturn

TMPFCheckSkipSB:
if ("$pfspellname" = "Aether Cloak") then
{
    if ($acon = 1) then goto %tmplfocusreturn
}
if ("$pfspellname" = "Fortress of Ice") then goto FoISkipCheckSB
goto TMPFHarnReturn

FoISkipCheckSB:
if ("$cscript" = ".seekanddestroy") then goto %tmplfocusreturn
if matchre ("$roomname" , ".*Ice Fortress|^Wyvern Arena") then goto %tmplfocusreturn
if matchre ("$roomexits" , "^Obvious exits") then goto %tmplfocusreturn
if matchre ("$roomobjs" , "^You also see.* an Ice Fortress") then goto %tmplfocusreturn
if (%cao = 0) then goto TMPFHarnReturn
if ($pvptarget = 0) then goto TMPFHarnReturn
var targetvisible %tmplfocusreturn
var targetspoteffect %tmplfocusreturn
var targetnotvisible TMPFHarnReturn
goto CheckVisiblity

TMPFHarnReturn:
var loadmainslot 1
put #var rspell 0
put #var rspellname 0
goto PFHarn

CL:
var abbrev cl
if (%cast = 1) then goto CLCastCheck
goto CL2

CLCastCheck:
if ($pvptarget != 0) then
{
    put #var autostancedef 0
    put #var autostancedur 1
    put #var autostanceinteg 0
    put #var autostancepot 0
    var spellstancereturn PathwayCheck
    var pathwayreturn SlapPvPTarget
    var facereturn CLCast2
    var bgreturn FacingCheckSB
    goto CheckSpellStance
}
var justicereturn PathwayCheck
var switchspellreturn SwitchToFB
var pathwayreturn CLCast2
goto Justice

CL2:
var tmplfocusreturn CL3
goto TMPFCheckSB

CL3:
if ($pvptarget = 0) then goto CL31
put #var prepm 89
put #var harn1 0
put #var harn2 0
put #var harnlimit 0
# put #var pausetime #evalmath ($unixtime + 13)
var pausesec 13
# var justicereturn PathwayCheck
# var switchspellreturn SwitchToFB
var pathwayreturn AoETMPrep
goto PathwayCheck

CL31:
if ($mana > 69) then
{
    put #var prepm 89
    put #var harn1 0
    put #var harn2 0
    put #var harnlimit 0
    # put #var pausetime #evalmath ($unixtime + 13)
    var pausesec 13
    # var justicereturn PathwayCheck
    # var switchspellreturn SwitchToFB
    # var pathwayreturn AoETMPrep
    # goto Justice
    goto CLJusticeCheck
}
put #var prepm 29
put #var harn1 30
put #var harn2 30
put #var harnlimit 2
# put #var pausetime #evalmath ($unixtime + 9)
if ($boosttimer > $unixtime) then
{
    var pausesec 11
}
else
{
    var pausesec 9
}
goto CLJusticeCheck

CLJusticeCheck:
if ($pvptarget != 0) then goto CLJusticeCheck2
var justicereturn PathwayCheck
var switchspellreturn SwitchToFB
var pathwayreturn AoETMPrep
goto Justice

CLJusticeCheck2:
var pathwayreturn AoETMPrep
goto PathwayCheck

CLCast2:
if ($acon = 1) then
{
    var acrelreturn CLCast21
    goto ACRel
}
goto CLCast21

CLCast21:
put #var pf 0
put #class spellcast on
if ($backstop > 9) then put #var backstop 0
var notarget 0
var clcast 0
var relerror 0
var calmed 0
var worm 0
var actualcalm 0
action var notarget 1 when ^\.\.\.But ultimately doesn't accomplish anything useful\.
action var clcast 1 when ^A storm of blinding white lightning arcs from your|^Electricity crackles about you as you bend the elements to your will\.$|^Your spell.*?backfires
action var relerror 1 when ^You don't have a spell prepared
# action var targetinvis 1 when ^You can't cast that at yourself\!
action var calmed 1 when ^You don't feel like casting that kind of spell right now\.
if ($necro = 1) then action var worm 1 when ^Your spell loses cohesion when it attempts to pass through the unholy miasma\.
action var actualcalm 1 when ^You don't feel like casting that kind of spell right now\.
# action var notarget 1;goto CLMiss when ^\.\.\.But ultimately doesn't accomplish anything useful\.
goto CLCast3

CLCast3:
put #var backstop #evalmath ($backstop + 1)
matchre CLCast3 ^\.\.\.wait|^Sorry\,
# matchre CLCastSuccess ^A storm of blinding white lightning arcs from your|^Electricity crackles about you as you bend the elements to your will\.$|^Your spell.*?backfires|^The spell pattern collapses
# match ClError You don't have a spell prepared
matchre AssessCL CL Backstop $backstop$
put cast
put echo CL Backstop $backstop
matchwait

AssessCL:
action remove ^\.\.\.But ultimately doesn't accomplish anything useful\.
action remove ^A storm of blinding white lightning arcs from your|^Electricity crackles about you as you bend the elements to your will\.$|^Your spell.*?backfires
action remove ^You don't have a spell prepared
# action var targetinvis 1 when ^You can't cast that at yourself\!
action remove ^You don't feel like casting that kind of spell right now\.
if ($necro = 1) then action remove ^Your spell loses cohesion when it attempts to pass through the unholy miasma\.
action remove ^You don't feel like casting that kind of spell right now\.
if (%notarget = 1) then goto RelSpellNoEnemies
if (%worm = 1) then goto WormTMSB
if (%clcast = 1) then goto PathRelCheck
if (%relerror = 1) then goto RegsRelError
if (%calmed = 1) then goto CalmedSB
if (%actualcalm = 1) then goto CalmedEffectSB
goto RegsRelError

WormTMSB:
put #var wormsmist 1
goto PathRelCheck

FB:
var abbrev fb
if (%cast = 1) then
{
    var pathwayreturn SlapPvPTarget
    var bgreturn STTMCast
    goto PathwayCheck
}
var tmplfocusreturn FB2
goto TMPFCheckSB

FB2:
if ($targetchest = 1) then var targetchest 1
if ($mana > 69) then
{
    put #var prepm 100
    put #var harn1 0
    put #var harn2 0
    put #var harnlimit 0
    # put #var pausetime #evalmath ($unixtime + 8)
    var pausesec 8
    var pathwayreturn STTMPrep
    goto PathwayCheck
}
if ($mana > 59) then
{
    put #var prepm 34
    put #var harn1 33
    put #var harn2 33
    put #var harnlimit 2
    # put #var pausetime #evalmath ($unixtime + 4)
    if ($boosttimer > $unixtime) then
    {
        var pausesec 6
    }
    else
    {
        var pausesec 4
    }
    var pathwayreturn STTMPrep
    goto PathwayCheck
}
put #var prepm 17
put #var harn1 17
put #var harn2 16
put #var harnlimit 2
# put #var pausetime #evalmath ($unixtime + 4)
if ($boosttimer > $unixtime) then
{
    var pausesec 6
}
else
{
    var pausesec 4
}
var pathwayreturn STTMPrep
goto PathwayCheck

Aeth:
var abbrev aethrolysis
if (%cast = 1) then
{
    put #var autostancedef 0
    put #var autostancedur 1
    put #var autostanceinteg 0
    put #var autostancepot 0
    var spellstancereturn PathwayCheck
    var pathwayreturn STTMCast
    goto CheckSpellStance
}
var tmplfocusreturn Aeth2
goto TMPFCheckSB

Aeth2:
if ($mana > 59) then
{
    put #var prepm 44
    put #var harn1 0
    put #var harn2 0
    put #var harnlimit 0
    # put #var pausetime #evalmath ($unixtime + 8)
    var pausesec 8
    goto STTMPrep
}
put #var prepm 14
put #var harn1 15
put #var harn2 15
put #var harnlimit 2
# put #var pausetime #evalmath ($unixtime + 4)
if ($boosttimer > $unixtime) then
{
    var pausesec 7
}
else
{
    var pausesec 5
}
var justicereturn PathwayCheck
var switchspellreturn SwitchToFB
var pathwayreturn STTMPrep
goto Justice

FR:
var abbrev fr
if (%cast = 1) then
{
    put #var autostancedef 1
    put #var autostancedur 0
    put #var autostanceinteg 0
    put #var autostancepot 0
    var spellstancereturn FRCastCheck
    goto CheckSpellStance
}
goto FR2

FR2:
if ($pvptarget != 0) then goto FROne
var justicereturn FROne
var switchspellreturn SwitchToRIM
goto Justice

# if ($cyclicinitiated >= $unixtime) then
# {
#     var cyclicadd $cyclicinitiated

    # Creates the cyclicadd number which is the amount of seconds to wait until casting another cyclic.

#     math cyclicadd subtract $unixtime
#     if (%cyclicadd >= $pausetime) then goto FRPauseCalc
# }
# goto FROne

# FRPauseCalc:
# put #var pausetime #evalmath ($unixtime + %cyclicadd)
# goto FROne

FROne:
# put #var pausetime #evalmath ($unixtime + 6)
var pausesec 6
put #var prepm 37
put #var harn1 0
put #var harn2 0
put #var harnlimit 0
goto CommonPrep

FRCastCheck:
if ($pvptarget != 0) then
{
    var shieldreturn FRCastCheck2
    goto ShieldCheck
}
var justicereturn FRCastCheck2
var switchspellreturn SwitchToRIM
goto Justice

FRCastCheck2:
if ($eeon = 1) then goto FRCastRel
if ($acon = 1) then goto FRCastRel
if ($rimon = 1) then goto FRCastRel
if ($fron = 1) then goto FRCastRel
var facereturn FRCast
goto FacingCheckSB

FRCastRel:
var relcyclic 1
var relreturn FacingCheckSB
var facereturn FRCast
goto RelSpell

FRCast:
put #var pf 0
put #class spellcast on
put #class firerainstart on
if ($backstop > 9) then put #var backstop 0
var fron 0
var cyclictimer 0
var actualcalm 0
var frceiling 0
action var fron 1 when ^Swirls of ash, dust and vapor begin
action var frceiling 1 when ^The ceiling interferes with the formation
action var cyclictimer 1 when ^The mental strain of initiating a cyclic spell
action var actualcalm 1 when ^You don't feel like casting that kind of spell right now\.
if ($pvptarget = 0) then goto FRCast2
if ($aoearea = 0) then goto FRCast2
if ($pvpdummy != 0) then goto FRCast2
goto FRCastArea

FRCast2:
put #var backstop #evalmath ($backstop + 1)
matchre FRCast2 ^\.\.\.wait|^Sorry\,
# matchre FRCastFail ^You don't have a spell prepared|^The mental strain of initiating a cyclic spell|^Your spell.*?backfires|^The spell pattern collapses
# matchre MagicExit ^You gesture
matchre AssessFR FR Backstop $backstop$
put cast
put echo FR Backstop $backstop
matchwait

FRCastArea:
put #var backstop #evalmath ($backstop + 1)
matchre FRCastArea ^\.\.\.wait|^Sorry\,
# matchre FRCastFail ^You don't have a spell prepared|^The mental strain of initiating a cyclic spell|^Your spell.*?backfires|^The spell pattern collapses
# matchre MagicExit ^You gesture
matchre AssessFRArea FR Backstop $backstop$
put cast nongroup
put echo FR Backstop $backstop
matchwait

AssessFR:
action remove ^Swirls of ash, dust and vapor begin
action remove ^The ceiling interferes with the formation
action remove ^The mental strain of initiating a cyclic spell
action remove ^You don't feel like casting that kind of spell right now\.
if (%frceiling = 1) then goto FRCeiling
if (%fron = 1) then goto FRCastSuccess
if (%cyclictimer = 1) then goto CyclicTimerFailFR
if (%actualcalm = 1) then goto CalmedEffectSB
goto FRCastFail

AssessFRArea:
action remove ^Swirls of ash, dust and vapor begin
action remove ^The ceiling interferes with the formation
action remove ^The mental strain of initiating a cyclic spell
action remove ^You don't feel like casting that kind of spell right now\.
if (%frceiling = 1) then goto FRCeiling
if (%fron = 1) then goto FRCastSuccessArea
if (%cyclictimer = 1) then goto CyclicTimerFailFR
if (%actualcalm = 1) then goto CalmedEffectSB
goto FRCastFail

FRCastSuccess:
put #var aoecyclic 0
goto RegsCastVarsRT

FRCastSuccessArea:
put #var aoecyclic 1
goto RegsCastVarsRT

CyclicTimerFailFR:
put #class firerainstart off
put #var cyclicinitiated #evalmath ($unixtime + 30)
goto RegsRelError

FRCastFail:
put #class firerainstart off
put #var cyclicinitiated 0
goto RegsRelError

FRCeiling:
put #var inside 1
goto RegsRelError

MAB:
var abbrev mab
if (%cast = 1) then
{
    put #var autostancedef 1
    put #var autostancedur 0
    put #var autostanceinteg 0
    put #var autostancepot 0
    var spellstancereturn MABCast
    goto CheckSpellStance
}
if ($mana > 69) then
{
    put #var prepm 100
    put #var harn1 0
    put #var harn2 0
    put #var harnlimit 0
    # put #var pausetime #evalmath ($unixtime + 8)
    var pausesec 8
    goto CommonPrep
}
put #var prepm 34
put #var harn1 33
put #var harn2 33
put #var harnlimit 2
# put #var pausetime #evalmath ($unixtime + 4)
if ($boosttimer > $unixtime) then
{
    var pausesec 6
}
else
{
    var pausesec 4
}
goto CommonPrep

MABCast:
put #var pf 0
put #class spellcast on
matchre MABCast ^\.\.\.wait|^Sorry\,
matchre MABCheck ^You gesture
matchre RegsRelError ^You don't have a spell prepared|^Your spell.*?backfires
match CalmedEffectSB You don't feel like casting that kind of spell right now.
put cast
matchwait

MABCheck:
put #class ballista on
put #var ballista 1
put #var balloaded 1
if ($pvptarget != 0) then 
{
    put #var rubbal 1
    goto RegsCastVarsRT
}
var shleftreturn Ref
var shrightreturn Ref
goto EmptyOneHand

Ref:
matchre Ref ^\.\.\.wait|^Sorry\,
matchre Ges ^You are now prepared|^You already have a 
put prep cantrip reinforce stone
matchwait

Ges:
matchre Ges ^\.\.\.wait|^Sorry\,
matchre RubBal ^You gesture at|^Something in the area
matchre RegsCastVarsRT ^You'll need to gesture at
put gesture ballista
matchwait 

RubBal:
matchre RubBal ^\.\.\.wait|^Sorry\,|^Deftly, you rub your hands across the onyx ballista, reshaping it subtly so the magnetic pulse it generates flares up with every single shot\.$
matchre Rubbed ^Deftly, you rub your .+ across the onyx ballista, reshaping it subtly so the magnetic pulse it generates is focused only where it is facing\.$
put rub ballista
matchwait

Rubbed:
put #var rubbal 0
goto RegsCastVarsRT

LB:
var abbrev lb
if (%cast = 1) then
{
    put #var autostancedef 0
    put #var autostancedur 1
    put #var autostanceinteg 0
    put #var autostancepot 0
    var spellstancereturn PathwayCheck
    var pathwayreturn SlapPvPTarget
    var bgreturn STTMCast
    goto CheckSpellStance
}
var tmplfocusreturn LB2
goto TMPFCheckSB

LB2:
if ($targethead = 1) then
{
    var targethead 1
    goto LB3
}
if ($targetchest = 1) then var targetchest 1
goto LB3

LB3:
put #var prepm 45
put #var harn1 0
put #var harn2 0
put #var harnlimit 0
var pausesec 3
goto LB4

LB4:
var pathwayreturn STTMPrep
goto PathwayCheck

FRS:
var abbrev frs
if (%cast = 1) then
{
    put #var autostancedef 0
    put #var autostancedur 1
    put #var autostanceinteg 0
    put #var autostancepot 0
    var spellstancereturn PathwayCheck
    var pathwayreturn SlapPvPTarget
    var bgreturn STTMCast
    goto CheckSpellStance
}
var tmplfocusreturn FRS2
goto TMPFCheckSB

FRS2:
if ($targetchest = 1) then var targetchest 1
put #var prepm 45
put #var harn1 0
put #var harn2 0
put #var harnlimit 0
# put #var pausetime #evalmath ($unixtime + 8)
var pausesec 8
var pathwayreturn STTMPrep
goto PathwayCheck

HoT:
var abbrev hot
if (%cast = 1) then
{
    put #var autostancedef 1
    put #var autostancedur 0
    put #var autostanceinteg 0
    put #var autostancepot 0
    var spellstancereturn PathwayCheck
    var pathwayreturn SlapPvPTarget
    var bgreturn STTMCast
    goto CheckSpellStance
}
var tmplfocusreturn HoT2
goto TMPFCheckSB

HoT2:
put #var prepm 1
put #var harn1 0
put #var harn2 0
put #var harnlimit 0
# put #var pausetime #evalmath ($unixtime + 8)
var pausesec 8
var pathwayreturn HoTPrep
goto PathwayCheck

HoTPrep:
put #var pf 0
put #var spelllost 0
put #var tmspellready 0
put #var stattackspell 1
put #var attackspell 0
put #var spellready 0
put #class spelllostwatcher on
put #class tmfulltarget on
goto HoTPrep2

HoTPrep2:
matchre HoTPrep2 ^\.\.\.wait|^Sorry\,
matchre RegsRelError ^But you're already|^You are already preparing|^You have already fully|^You must be preparing
matchre NoCasting ^Something in the area interferes with your spell preparations\.$
matchre CheckSpellStatus ^You begin to weave mana lines
matchre RelSpellNoEnemies ^There is nothing else to face\!$|^I could not find what you were referring to\.$|^You can't cast|^Face what\?$
matchre PeaceRoomSB ^As you attempt to prepare the spell, a sense of overwhelming peace washes over you\.
match CalmedEffectSB Your desire to prepare this offensive spell suddenly slips away.
match HeadDamageSB You are in no condition to do that.
put #var pausetime #evalmath ($unixtime + %pausesec)
# if ($longpause != 0) then
# {
#     put #var pausetime #evalmath ($pausetime + $longpause)
# }
put invoke my tattoo
if ($pvptarget = 0) then
{
    if ($targetchest != 1) then put target
}
if ($pvptarget = 0) then
{
    if ($targetchest = 1) then put target chest
}
if ($pvptarget != 0) then put target $pvptarget
matchwait

FS:
var abbrev fs
if (%cast = 1) then
{
    put #var autostancedef 0
    put #var autostancedur 1
    put #var autostanceinteg 0
    put #var autostancepot 0
    var spellstancereturn PathwayCheck
    var pathwayreturn SlapPvPTarget
    var bgreturn STTMCast
    goto CheckSpellStance
}
var tmplfocusreturn FS2
goto TMPFCheckSB

FS2:
put #var prepm 44
put #var harn1 0
put #var harn2 0
put #var harnlimit 0
# put #var pausetime #evalmath ($unixtime + 13)
var pausesec 13
var pathwayreturn STTMPrep
goto PathwayCheck

GZ:
var abbrev gz
if (%cast = 1) then
{
    put #var autostancedef 0
    put #var autostancedur 1
    put #var autostanceinteg 0
    put #var autostancepot 0
    var spellstancereturn PathwayCheck
    var pathwayreturn SlapPvPTarget
    var bgreturn STTMCast
    goto CheckSpellStance
}
var tmplfocusreturn GZ2
goto TMPFCheckSB

GZ2:
put #var prepm 44
put #var harn1 0
put #var harn2 0
put #var harnlimit 0
# if ($mana > 59) then
# {
#     put #var pausetime #evalmath ($unixtime + 1)
#     goto GZ3
# }
# put #var pausetime #evalmath ($unixtime + 13)
var pausesec 13
goto GZ3

GZ3:
var pathwayreturn STTMPrep
goto PathwayCheck

STS:
var abbrev sts
if (%cast = 1) then
{
    put #var autostancedef 0
    put #var autostancedur 1
    put #var autostanceinteg 0
    put #var autostancepot 0
    var spellstancereturn PathwayCheck
    var pathwayreturn SlapPvPTarget
    var bgreturn STTMCast
    goto CheckSpellStance
}
var tmplfocusreturn STS2
goto TMPFCheckSB

STS2:
# To Do - Set full targeting time, and have special logic for casting early with tm foc and melee or if fighting a thief.
put #var prepm 44
put #var harn1 0
put #var harn2 0
put #var harnlimit 0
# if ($mana > 59) then
# {
#     put #var pausetime #evalmath ($unixtime + 1)
#     goto STS3
# }
# put #var pausetime #evalmath ($unixtime + 13)
var pausesec 13
goto STS3

STS3:
var pathwayreturn STTMPrep
goto PathwayCheck

SHW:
var abbrev shockwave
if (%cast = 1) then goto SHWCastCheck
goto SHW2

SHWCastCheck:
if ($pvptarget != 0) then
{
    put #var autostancedef 0
    put #var autostancedur 1
    put #var autostanceinteg 0
    put #var autostancepot 0
    var spellstancereturn PathwayCheck
    var pathwayreturn SlapPvPTarget
    var bgreturn FacingCheckSB
    var facereturn AoETMCast
    goto CheckSpellStance
}
var justicereturn PathwayCheck
var switchspellreturn SwitchToFB
var pathwayreturn FacingCheckSB
var facereturn AoETMCast
goto Justice

SHW2:
var tmplfocusreturn SHW3
goto TMPFCheckSB

SHW3:
if ($pvptarget = 0) then goto SHW31
put #var prepm 91
put #var harn1 0
put #var harn2 0
put #var harnlimit 0
# put #var pausetime #evalmath ($unixtime + 13)
var pausesec 13
# var justicereturn PathwayCheck
# var switchspellreturn SwitchToFB
var pathwayreturn AoETMPrep
goto PathwayCheck

SHW31:
if ($mana > 59) then
{
    put #var prepm 91
    put #var harn1 0
    put #var harn2 0
    put #var harnlimit 0
    # put #var pausetime #evalmath ($unixtime + 13)
    var pausesec 13
    goto SHWJusticeCheck
    # var justicereturn PathwayCheck
    # var switchspellreturn SwitchToFB
    # var pathwayreturn AoETMPrep
    # goto Justice
}
put #var prepm 30
put #var harn1 31
put #var harn2 30
put #var harnlimit 2
# put #var pausetime #evalmath ($unixtime + 9)
if ($boosttimer > $unixtime) then
{
    var pausesec 11
}
else
{
    var pausesec 9
}
goto SHWJusticeCheck
# var justicereturn PathwayCheck
# var switchspellreturn SwitchToFB
# var pathwayreturn AoETMPrep
# goto Justice

SHWJusticeCheck:
if ($pvptarget != 0) then goto SHWJusticeCheck2
var justicereturn PathwayCheck
var switchspellreturn SwitchToFB
var pathwayreturn AoETMPrep
goto Justice

SHWJusticeCheck2:
var pathwayreturn AoETMPrep
goto PathwayCheck

# ShockwavePrep:
# put #var pf 0
# put #var spelllost 0
# put #var tmspellready 0
# put #var stattackspell 0
# put #var attackspell 1
# put #var spellready 0
# put #class spelllostwatcher on
# put #class tmfulltarget on
# goto ShockwavePrep2

# ShockwavePrep2:
# matchre ShockwavePrep2 ^\.\.\.wait|^Sorry\,
# matchre RegsRelError ^But you're already|^You are already preparing|^You have already fully
# matchre NoCasting ^Something in the area interferes with your spell preparations\.$
# matchre CheckSpellStatus ^You begin to weave mana lines
# match SpellStollen You seem to have forgotten this spell!
# # matchre PeaceRoomSB ^As you attempt to prepare the spell, a sense of overwhelming peace washes over you\.$|^Your desire to prepare this offensive spell suddenly slips away\.$
# matchre PeaceRoomSB ^As you attempt to prepare the spell, a sense of overwhelming peace washes over you\.
# match CalmedEffectSB Your desire to prepare this offensive spell suddenly slips away.
# # put prep fls
# put #var pausetime #evalmath ($unixtime + %pausesec)
# # if ($longpause != 0) then
# # {
# #     put #var pausetime #evalmath ($pausetime + $longpause)
# # }
# put target %abbrev $prepm
# matchwait

PW:
var abbrev pw
if (%cast = 1) then
{
    put #var autostancedef 0
    put #var autostancedur 1
    put #var autostanceinteg 0
    put #var autostancepot 0
    var spellstancereturn PathwayCheck
    var pathwayreturn NaphthaCheck
    goto CheckSpellStance
}
var tmplfocusreturn PW2
goto TMPFCheckSB

PW2:
put #var prepm 45
put #var harn1 0
put #var harn2 0
put #var harnlimit 0
# put #var pausetime #evalmath ($unixtime + 8)
var pausesec 8
# if ($tmfoc != 1) then goto PW3
if ($grappled = 1) then goto PW3
if ($targethead = 1) then
{
    var targethead 1
    goto PW3
}
if ($targetchest = 1) then var targetchest 1
goto PW3

PW3:
var pathwayreturn PWPrep
goto PathwayCheck

PWPrep:
put #var pf 0
put #var spelllost 0
put #var tmspellready 0
put #var stattackspell 1
put #var attackspell 0
put #var spellready 0
put #class spelllostwatcher on
put #class tmfulltarget on
if ($grappled != 0) then goto STTMPrep2
if (%targetchest = 1) then
{
    if ($unixtime > $pwchest) then goto PWTarChest
    goto PWTargeting
}
if ($autopw != 2) then goto STTMPrep2
goto PWTargeting

PWTargeting:
if ($unixtime > $pwchest) then goto PWTarChest
if ($unixtime > $pwback) then goto PWTarBack
if ($unixtime > $pwabdomen) then goto PWTarAb
if ($unixtime > $pwhead) then goto PWTarHead
goto STTMPrep2

PWTarChest:
var targetchest 0
matchre PWTarChest ^\.\.\.wait|^Sorry\,
matchre RegsRelError ^But you're already|^You are already preparing|^You have already fully|^You must be preparing
matchre NoCasting ^Something in the area interferes with your spell preparations\.$
matchre CheckSpellStatus ^You begin to weave mana lines
matchre RelSpellNoEnemies ^There is nothing else to face\!$|^I could not find what you were referring to\.$|^You can't cast|^Face what\?$
match SpellStollen You seem to have forgotten this spell!
# matchre PeaceRoomSB ^As you attempt to prepare the spell, a sense of overwhelming peace washes over you\.$|^Your desire to prepare this offensive spell suddenly slips away\.$
matchre PeaceRoomSB ^As you attempt to prepare the spell, a sense of overwhelming peace washes over you\.
match CalmedEffectSB Your desire to prepare this offensive spell suddenly slips away.
put #var pausetime #evalmath ($unixtime + %pausesec)
# if ($longpause != 0) then
# {
#     put #var pausetime #evalmath ($pausetime + $longpause)
# }
put prep %abbrev $prepm
if ($pvptarget != 0) then put target $pvptarget chest
if ($pvptarget = 0) then put target chest
matchwait

PWTarAb:
var targetchest 0
matchre PWTarAb ^\.\.\.wait|^Sorry\,
matchre RegsRelError ^But you're already|^You are already preparing|^You have already fully|^You must be preparing
matchre NoCasting ^Something in the area interferes with your spell preparations\.$
matchre CheckSpellStatus ^You begin to weave mana lines
matchre RelSpellNoEnemies ^There is nothing else to face\!$|^I could not find what you were referring to\.$|^You can't cast|^Face what\?$
match SpellStollen You seem to have forgotten this spell!
matchre PeaceRoomSB ^As you attempt to prepare the spell, a sense of overwhelming peace washes over you\.
match CalmedEffectSB Your desire to prepare this offensive spell suddenly slips away.
put #var pausetime #evalmath ($unixtime + %pausesec)
# if ($longpause != 0) then
# {
#     put #var pausetime #evalmath ($pausetime + $longpause)
# }
put prep %abbrev $prepm
if ($pvptarget != 0) then put target $pvptarget abdomen
if ($pvptarget = 0) then put target abdomen
matchwait

PWTarBack:
var targetchest 0
matchre PWTarBack ^\.\.\.wait|^Sorry\,
matchre RegsRelError ^But you're already|^You are already preparing|^You have already fully|^You must be preparing
matchre NoCasting ^Something in the area interferes with your spell preparations\.$
matchre CheckSpellStatus ^You begin to weave mana lines
matchre RelSpellNoEnemies ^There is nothing else to face\!$|^I could not find what you were referring to\.$|^You can't cast|^Face what\?$
match SpellStollen You seem to have forgotten this spell!
matchre PeaceRoomSB ^As you attempt to prepare the spell, a sense of overwhelming peace washes over you\.
match CalmedEffectSB Your desire to prepare this offensive spell suddenly slips away.
put #var pausetime #evalmath ($unixtime + %pausesec)
# if ($longpause != 0) then
# {
#     put #var pausetime #evalmath ($pausetime + $longpause)
# }
put prep %abbrev $prepm
if ($pvptarget != 0) then put target $pvptarget back
if ($pvptarget = 0) then put target back
matchwait

PWTarHead:
var targetchest 0
matchre PWTarHead ^\.\.\.wait|^Sorry\,
matchre RegsRelError ^But you're already|^You are already preparing|^You have already fully|^You must be preparing
matchre NoCasting ^Something in the area interferes with your spell preparations\.$
matchre CheckSpellStatus ^You begin to weave mana lines
matchre RelSpellNoEnemies ^There is nothing else to face\!$|^I could not find what you were referring to\.$|^You can't cast|^Face what\?$
match SpellStollen You seem to have forgotten this spell!
matchre PeaceRoomSB ^As you attempt to prepare the spell, a sense of overwhelming peace washes over you\.
match CalmedEffectSB Your desire to prepare this offensive spell suddenly slips away.
put #var pausetime #evalmath ($unixtime + %pausesec)
# if ($longpause != 0) then
# {
#     put #var pausetime #evalmath ($pausetime + $longpause)
# }
put prep %abbrev $prepm
if ($pvptarget != 0) then put target $pvptarget head
if ($pvptarget = 0) then put target head
matchwait

NaphthaCheck:
var shleftreturn NaphthaCheck2
var shrightreturn NaphthaCheck2
if ($nonaphtha = 1) then 
{
    var bgreturn PWCast
    goto SlapPvPTarget
}
if ($kickonly = 1) then
{
    var bgreturn PWCast
    goto SlapPvPTarget
}
if ($autopw = 0) then 
{
    var bgreturn PWCast
    goto SlapPvPTarget
}
if ($tmfoc = 1) then
{
    if ("$righthandnoun" = "naphtha") then goto HoldingNaphtha
    if ("$lefthandnoun" = "naphtha") then goto HoldingNaphtha
    if ($handdamaged = 1) then
    {
        var bgreturn PWCast
        goto SlapPvPTarget
    }
}
if ($tmfoc = 1) then
{
    if ($handdamaged = 1) then
    {
        var bgreturn PWCast
        goto SlapPvPTarget
    }
    if ("$righthandnoun" = "orb") then
    {
        if ("$lefthandnoun" != "") then goto SheathL
    }
    if ("$lefthandnoun" = "orb") then
    {
        if ("$righthandnoun" != "") then goto SheathR
    }
}
if ("$righthandnoun" = "naphtha") then goto HoldingNaphtha
if ("$lefthandnoun" = "naphtha") then goto HoldingNaphtha
goto EmptyOneHand

NaphthaCheck2:
matchre NaphthaCheck2 ^\.\.\.wait|^Sorry\,
matchre NaphthaCheck ^You need a free hand to pick that up\.
matchre HoldingNaphtha ^You get
matchre NoNaphtha ^What were you referring to\?
match HandHurtSB You can't pick that up with your hand that damaged.
put get my naphtha from my haversack
# put get my poision from my holder
matchwait

# NaphthaCheckBackUp:
# matchre NaphthaCheck ^\.\.\.wait|^Sorry\,|^You get|^You need a free hand to pick that up\.$
# matchre NoNaphtha ^What were you referring to\?$
# match HandHurtSB You can't pick that up with your hand that damaged.
# put get my naphtha from my holder
# # put get my poision from my holder
# matchwait

NoNaphtha:
put #var nonaphtha 1
var bgreturn PWCast
goto SlapPvPTarget

HoldingNaphtha:
var bgreturn PWCast
goto SlapPvPTarget

PWCast:
if ($acon = 1) then
{
    var acrelreturn PWCast1
    goto ACRel
}
goto PWCast1

PWCast1:
put #var pf 0
put #class spellcast on
if ($backstop > 9) then put #var backstop 0
var relerror 0
var notarget 0
var worm 0
var actualcalm 0
action put #var pwchest #evalmath ($unixtime + 480) when sticky mixture against.*chest\!$
action put #var pwabdomen #evalmath ($unixtime + 480) when sticky mixture against.*abdomen\!$
action put #var pwback #evalmath ($unixtime + 480) when sticky mixture against.*back\!$
action put #var pwhead #evalmath ($unixtime + 480) when sticky mixture against.*head\!$
action var relerror 1 when ^Your spell.*?backfires|^The spell pattern collapses|^You don't have a spell prepared
action var notarget 1 when ^Your target pattern dissipates|^You can't cast
action var worm 1 when ^Your spell loses cohesion when it attempts to pass through the unholy miasma\.
action var actualcalm 1 when ^You don't feel like casting that kind of spell right now\.
if ($maintaindistance = 1) then goto PWCastAway
if ($grappled = 1) then goto PWCastAway
if ($offbalance != 0) then goto PWCastAway
if ($retreated != 0) then goto PWCastAway
# if ($tmfoc = 1) then
# {
#     if ($autogz = 0) then
#     {
#         if ($autosts = 0) then goto PWCastAway
#     }
# }
goto PWCast2

PWCast2:
var pwpull 1
put #var backstop #evalmath ($backstop + 1)
matchre PWCast2 ^\.\.\.wait|^Sorry\,
# matchre StopClose ^You gesture
# matchre PathRelCheck ^Your spell.*?backfires|^The spell pattern collapses
# match RegsRelError You don't have a spell prepared
# matchre RelSpellNoEnemies ^Your target pattern dissipates|^You can't cast
matchre AssessPW PW Backstop $backstop$
put cast pull
put echo PW Backstop $backstop
matchwait

PWCastAway:
var pwpull 0
put #var backstop #evalmath ($backstop + 1)
matchre PWCastAway ^\.\.\.wait|^Sorry\,
# matchre StopAway ^You gesture
# matchre PathRelCheck ^Your spell.*?backfires|^The spell pattern collapses
# match RegsRelError You don't have a spell prepared
# matchre RelSpellNoEnemies ^Your target pattern dissipates|^You can't cast
matchre AssessPW PW Backstop $backstop$
put cast
put echo PW Backstop $backstop
matchwait

AssessPW:
action remove sticky mixture against.*chest\!$
action remove sticky mixture against.*abdomen\!$
action remove sticky mixture against.*back\!$
action remove sticky mixture against.?head\!$
action remove ^Your spell.*?backfires|^The spell pattern collapses|^You don't have a spell prepared
action remove ^Your target pattern dissipates|^You can't cast
action remove ^Your spell loses cohesion when it attempts to pass through the unholy miasma\.
action remove ^You don't feel like casting that kind of spell right now\.
if (%worm = 1) then goto WormTMSB
if (%notarget = 1) then goto RelSpellNoEnemies
if (%pwpull = 1) then goto StopClose
if (%actualcalm = 1) then goto CalmedEffectSB
goto StopAway

StopClose:
# put #var autopw #evalmath ($unixtime + 180)
# if ($paladin != 0) then goto StopCloseFireLocation
# if ($bard != 0) then goto StopCloseFireLocation
if ($autopw != 2) then goto PWDone
if ($unixtime > $pwchest) then goto StopClose2
if ($unixtime > $pwabdomen) then goto StopClose2
if ($unixtime > $pwback) then goto StopClose2
put #var autopw 0
goto StopClose2

PWDone:
put #var autopw 0
goto StopClose2

StopClose2:
put #var meleelasttime 1
# if ($autopw != 0) then put #var autopw #evalmath ($unixtime + 480)
put #class retreatwatcher on
put #class meleewatcher off
goto PathRelCheck

StopAway:
# if ($paladin != 0) then goto StopAwayFireLocation
# if ($bard != 0) then goto StopAwayFireLocation
# put #var autopw 0
# goto StopAway2
if ($autopw != 2) then
{
    put #var autopw 0
    goto StopAway2
}
# goto StopAway2
# goto StopAwayFireLocation

# StopAwayFireLocation:
# if ($autoac != 1) then
# {
#     put #var autopw 0
#     goto StopAway2
# }
if ($unixtime > $pwchest) then goto StopAway2
if ($unixtime > $pwabdomen) then goto StopAway2
if ($unixtime > $pwback) then goto StopAway2
put #var autopw 0
goto StopAway2

StopAway2:
# if ($autopw != 0) then put #var autopw #evalmath ($unixtime + 480)
put #var meleelasttime 0
put #var polerange 0
put #class meleewatcher on
put #class polerangewatcher on
put #class retreatwatcher off
put #var grappled 0
if ($pvp = 1) then put #class grapplewatch on
if ($pvp = 1) then put #class grapplebreakwatch off
goto PathRelCheck

# Debil

ANC:
var abbrev anc
if (%cast = 1) then
{
    put #var autostancedef 1
    put #var autostancedur 0
    put #var autostanceinteg 0
    put #var autostancepot 0
    var spellstancereturn ANCCast
    goto CheckSpellStance
}
put #var prepm 33
put #var harn1 0
put #var harn2 0
put #var harnlimit 0
# put #var pausetime #evalmath ($unixtime + 3)
var pausesec 3
put #var debil 1
put #var debilcasttimer 0
goto CommonPrep

ANCCast:
if ($pvptarget = 0) then goto ANCCast2
var targetvisible ANCSlapCheck
var targetspoteffect ANCCast2
var targetnotvisible HardCCTarInvis
goto CheckVisiblity

ANCSlapCheck:
var bgreturn ANCCast2
goto SlapPvPTarget

ANCCast2:
put #var pf 0
put #class spellcast on
# put #class fortsvsshield on
if ($backstop > 9) then put #var backstop 0
var anchit 0
var fortshield 0
var ancoff 0
var relerror 0
var targetinvis 0
var calmed 0
var worm 0
var actualcalm 0
action var anchit 1 when gripping .*extremities and impairing .*ability to dodge\!$
action var fortshield 1 when unwavering tranquility abates the force of your assault\.$
action var ancoff 1 when but nothing else happens\.$
action var relerror 1 when ^You don't have a spell prepared
action var targetinvis 1 when ^You can't cast that at yourself\!
action var calmed 1 when ^You don't feel like casting that kind of spell right now\.
action var worm 1 when ^Your spell loses cohesion when it attempts to pass through the unholy miasma\.
action var actualcalm 1 when ^You don't feel like casting that kind of spell right now\.
goto ANCCast3

ANCCast3:
put #var backstop #evalmath ($backstop + 1)
matchre ANCCast3 ^\.\.\.wait|^Sorry\,
# matchre ANCCastVars ^You gesture
# matchre ANCHitVars gripping .*extremities and impairing .*ability to dodge\!$
# matchre ANCOff but nothing else happens\.$
# matchre ANCIntegrityBarrier ^Your spell loses cohesion
# match RegsRelError You don't have a spell prepared
# matchre SoftCCTarInvis ^You can't cast that at yourself\!$
matchre AssessANC ANC Backup $backstop$
if ($pvptarget != 0) then put cast $pvptarget
if ($pvptarget = 0) then put cast
put echo ANC Backup $backstop
matchwait

AssessANC:
action remove gripping .*extremities and impairing .*ability to dodge\!$
action remove ^You don't have a spell prepared
action remove ^You can't cast that at yourself\!
action remove unwavering tranquility abates the force of your assault\.$
action remove but nothing else happens\.$
action remove ^You can't cast that at yourself\!
action remove ^You don't feel like casting that kind of spell right now\.
action remove ^Your spell loses cohesion when it attempts to pass through the unholy miasma\.
action remove ^You don't feel like casting that kind of spell right now\.
# Need miss messaging
if (%worm = 1) then goto WormSB
if (%anchit = 1) then goto ANCHitVars
if (%ancoff = 1) then goto ANCOff
if (%relerror = 1) then goto RegsRelError
if (%fortshield = 1) then goto ANCFortShield
if (%targetinvis = 1) then goto SoftCCTarInvis
if (%calmed = 1) then goto CalmedSB
if (%actualcalm = 1) then goto CalmedEffectSB
goto ANCBackstop

WormSB:
put #var wormsmist 1
goto RegsCastVarsRT

ANCHitVars:
if ($pvp != 1) then goto RegsCastVarsRT
put #class fortsvsshield off
# put #var softccattempttimer #evalmath ($unixtime + 5)
# put #var targetinvis 0
put #var anchex #evalmath ($unixtime + 75)
goto RegsCastVarsRT

ANCOff:
put #var autoanc 0
put #echo >Conversation
put #echo >Conversation #000000 *** No ANC Room
echo
echo **** No ANC Room ****
goto RegsRelError

ANCFortShield:
put #var fortshield 1
goto RegsCastVarsRT

CalmedSB:
put #var charmed 1
goto RegsRelError

ANCBackstop:
put #var softccattempttimer #evalmath ($unixtime + 5)
goto RegsRelError

# ANCCastVars:
# # put #class fortsvsshield off
# if ($pvp != 1) then goto MagicExit
# put #var softccattempttimer #evalmath ($unixtime + 5)
# # put #var targetinvis 0
# put #var anchex #evalmath ($unixtime + 75)
# goto MagicExit

# ANCIntegrityBarrier:
# put #class fortsvsshield off
# goto MagicExit

# ANCMissVars:
# put #class fortsvsshield off
# if ($activefortshield = 1) then
# {
#     put #var activefortshield 0
#     goto MagicExit
# }
# put #var fortdebil 0
# goto MagicExit

MoA:
var abbrev moa
if (%cast = 1) then
{
    put #var autostancedef 1
    put #var autostancedur 0
    put #var autostanceinteg 0
    put #var autostancepot 0
    var spellstancereturn MoASlapCheck
    goto CheckSpellStance
}
put #var prepm 33
put #var harn1 0
put #var harn2 0
put #var harnlimit 0
# put #var pausetime #evalmath ($unixtime + 3)
var pausesec 3
put #var debil 1
put #var debilcasttimer 0
goto CommonPrep

# MoACast:
# if ($pvptarget = 0) then goto MoACast2
# var targetvisible MoASlapCheck
# var targetspoteffect MoACast2
# var targetnotvisible HardCCTarInvis
# goto CheckVisiblity

MoASlapCheck:
var bgreturn MoACast2
goto SlapPvPTarget

MoACast2:
put #var pf 0
put #class spellcast on
# put #class willsvsshield on
# put #class moa on
if ($backstop > 9) then put #var backstop 0
var moahit 0
var relerror 0
var targetinvis 0
var willshield 0
var calmed 0
var worm 0
var actualcalm 0
var ambigwillshield 0
action var moahit 1 when leaving a trail of jagged.*lines branded upon.*\!$
# action var willshield 1 when confidence dampens your attack\.$|weakens .+ attack\.$
action var willshield 1 when confidence dampens your attack\.$|bastion of willpower weakens the attack\.$
action math ambigwillshield add 1 when weakens your attack\.$
action var moamiss 1 when ^The lion suddenly yowls and shies away from
action var relerror 1 when ^You don't have a spell prepared
action var targetinvis 1 when ^You can't cast that at yourself\!
action var worm 1 when ^Your spell loses cohesion when it attempts to pass through the unholy miasma\.
action var actualcalm 1 when ^You don't feel like casting that kind of spell right now\.
goto MoACast3

MoACast3:
matchre MoACast3 ^\.\.\.wait|^Sorry\,
put #var backstop #evalmath ($backstop + 1)
# matchre MoACastVars ^You gesture
# matchre MoAHit ^The lion slashes at.* with its blazing claws, leaving a trail of jagged .*lines branded upon .*\!$
# matchre MoAFail ^The lion suddenly yowls and shies away from
# match RegsRelError You don't have a spell prepared
# matchre SoftCCTarInvis ^You can't cast that at yourself\!$
matchre MOAAnalysis MOA Backup $backstop$
if ($pvptarget != 0) then put cast $pvptarget
if ($pvptarget = 0) then put cast
put echo MOA Backup $backstop
matchwait

MOAAnalysis:
action remove leaving a trail of jagged.*lines branded upon.*\!$
action remove confidence dampens your attack\.$|bastion of willpower weakens the attack\.$
action remove weakens your attack\.$
action remove ^The lion suddenly yowls and shies away from
action remove ^You don't have a spell prepared
action remove ^You can't cast that at yourself\!
action remove ^You don't feel like casting that kind of spell right now\.
action remove ^Your spell loses cohesion when it attempts to pass through the unholy miasma\.
action remove ^You don't feel like casting that kind of spell right now\.
if (%worm = 1) then goto WormSB
if (%moahit = 1) then goto MoAHit
if (%willshield = 1) then goto MoAWillShield
if (%ambigwillshield > 1) then goto MoAWillShield
if (%ambigwillshield = 1) then goto MoAMiss
if (%moamiss = 1) then goto MoAMiss
if (%relerror = 1) then goto RegsRelError
if (%targetinvis = 1) then goto SoftCCTarInvis
if (%calmed = 1) then goto CalmedSB
if (%actualcalm = 1) then goto CalmedEffectSB
goto MoABackstop

MoAHit:
# put #var activewillshield 0
put #var willshield 0
put #var moahex #evalmath ($unixtime + 75)
# put #class willsvsshield off
goto RegsCastVarsRT

MoAWillShield:
put #var willshield 1
goto RegsCastVarsRT

MoAMiss:
put #var spiritdebil 0
# put #class willsvsshield off
goto RegsCastVarsRT

MoABackstop:
put #var softccattempttimer #evalmath ($unixtime + 5)
goto RegsRelError

# MoAFail:
# if ($activewillshield = 0) then put #var spiritdebil 0
# put #var activewillshield 0
# put #class willsvsshield off
# goto MagicExit

# MoACastVars:
# if ($pvp != 1) then goto MagicExit
# put #var softccattempttimer #evalmath ($unixtime + 5)
# put #var targetinvis 0
# goto MagicExit

AL:
var abbrev al
if (%cast = 1) then
{
    put #var autostancedef 1
    put #var autostancedur 0
    put #var autostanceinteg 0
    put #var autostancepot 0
    var spellstancereturn ALSlapCheck
    goto CheckSpellStance
}
put #var prepm 33
put #var harn1 0
put #var harn2 0
put #var harnlimit 0
# put #var pausetime #evalmath ($unixtime + 3)
var pausesec 3
put #var debil 1
put #var debilcasttimer 0
goto CommonPrep

# HardCCVis:
# if ($pvptarget = 0) then goto ALCast
# var targetvisible ALSlapCheck
# var targetspoteffect ALCast
# var targetnotvisible HardCCTarInvis
# goto CheckVisiblity

ALSlapCheck:
var bgreturn ALCast
goto SlapPvPTarget

ALCast:
put #var pf 0
put #class spellcast on
put #var backstop #evalmath ($backstop + 1)
var alhit 0
var fortshield 0
var almiss 0
var relerror 0
var targetinvis 0
var calmed 0
var worm 0
var actualcalm 0
action var alhit 1 when ^The bright flash disorients
action var fortshield 1 when unwavering tranquility abates the force of your assault\.$
# action var alunfaze 1 when seems unfazed by the bright flash\.$
action var almiss 1 when quickly looks away, avoiding the bright flash\.$
action var relerror 1 when ^You don't have a spell prepared
action var targetinvis 1 when ^You can't cast that at yourself\!
action var calmed 1 when ^You don't feel like casting that kind of spell right now\.
action var worm 1 when ^Your spell loses cohesion when it attempts to pass through the unholy miasma\.
action var actualcalm 1 when ^You don't feel like casting that kind of spell right now\.
goto ALCast2

ALCast2:
matchre ALCast2 ^\.\.\.wait|^Sorry\,
# matchre HardCCCastVars ^You gesture
# matchre HardCCIntegrityBarrier ^Your spell loses cohesion
# matchre HardCCUnaffected seems unfazed by the bright flash\.$
# matchre ALHit ^The bright flash disorients
matchre ALAnalysis AL Backstop $backstop$
# match RegsRelError You don't have a spell prepared
# matchre HardCCTarInvis ^You can't cast that at yourself\!$
if ($pvptarget != 0) then put cast $pvptarget
if ($pvptarget = 0) then put cast
put echo AL Backstop $backstop
matchwait

ALAnalysis:
action remove ^The bright flash disorients
# action remove seems unfazed by the bright flash\.$
action remove quickly looks away, avoiding the bright flash\.$
action remove ^You don't have a spell prepared
action remove ^You can't cast that at yourself\!
action remove unwavering tranquility abates the force of your assault\.$
action remove ^You don't feel like casting that kind of spell right now\.
action remove ^Your spell loses cohesion when it attempts to pass through the unholy miasma\.
action remove ^You don't feel like casting that kind of spell right now\.
if (%worm = 1) then goto WormSB
if (%alhit = 1) then goto ALHit
if (%fortshield = 1) then goto ANCFortShield
if (%almiss = 1) then goto ALMiss
# if (%alunfaze = 1) then goto ALBackstop
if (%relerror = 1) then goto RegsRelError
if (%targetinvis = 1) then goto HardCCTarInvis
if (%calmed = 1) then goto CalmedSB
if (%actualcalm = 1) then goto CalmedEffectSB
goto ALBackstop

ALHit:
put #var hardccused #evalmath ($hardccused + 1)
put #var hardccattempttimer #evalmath ($unixtime + 10)
put #var fortshield 0
if ($bard = 1) then
{
    if ($refdebil = 1) then put #var alsoftcc 1
}
if ($hardccused < 3) then put #var hardccrecover #evalmath ($unixtime + 61)
if ($hardccused = 1) then put #var hardccduration #evalmath ($unixtime + 10)
if ($hardccused = 2) then put #var hardccduration #evalmath ($unixtime + 10)
if ($hardccused > 2) then put #var hardccduration #evalmath ($unixtime + 2)
goto RegsCastVarsRT

ALMiss:
if ($barb != 0) then
{
    if ($refdebil != 1) then put #var refdebil 1
}
put #var alsoftcc 1
put #var hardccattempttimer #evalmath ($unixtime + 5)
goto RegsCastVarsRT

ALBackstop:
put #var hardccattempttimer #evalmath ($unixtime + 5)
goto RegsCastVarsRT

HardCCTarInvis:
put #class spellcast off
put #class retreatwatcher off
if ($pvp = 1) then put #class grapplebreakwatch off
put #class meleewatcher on
put #class polerangewatcher on
if ($pvp = 1) then put #class grapplewatch on
put #var meleelasttime 0
put #var polerange 0
put #var baltargeted 0
put #var grappled 0
put #var targetfaced 0
# HardCCInvisCheck is located in sc.cmd
var invispfreturn HardCCInvisCheck
goto InvisPFCheck

HardCCCastVars:
# if ($pvp != 1) then goto MagicExit
# put #var targetinvis 0
put #var hardccattempttimer #evalmath ($unixtime + 5)
# if ($autoipwand = 1) then goto MagicExit
# if ($autowand = 1) then put #var autoipwand 1
goto MagicExit

SwitchToIP:
put #echo >Conversation
put #echo >Conversation #000000 *** Justice On
put #echo >Conversation #000000 *** Switching to IP
echo
echo **** Justice On ****
echo **** Switching to IP ****
if (%cast = 1) then
{
    var relreturn CheckSpellStatus
    var commonrel 1
    goto RelSpell
}
goto IP

IP:
var abbrev ip
if (%cast = 1) then
{
    put #var autostancedef 1
    put #var autostancedur 0
    put #var autostanceinteg 0
    put #var autostancepot 0
    var spellstancereturn IPSlapCheck
    goto CheckSpellStance
}
put #var prepm 33
put #var harn1 0
put #var harn2 0
put #var harnlimit 0
# put #var pausetime #evalmath ($unixtime + 3)
var pausesec 3
put #var debil 1
put #var debilcasttimer 0
goto CommonPrep

# IPVisCheck:
# if ($pvptarget = 0) then goto IPCast
# var targetvisible IPVisCheck2
# var targetspoteffect IPVisCheck2
# var targetnotvisible HardCCTarInvis
# goto CheckVisiblity

# IPVisCheck2:
# if ($pvpdummy != 0) then goto IPCastClasses
# if ($pvppet = 1) then goto IPCastClasses
# if ($ippronecheck != 1) then goto IPCastClasses
# if matchre ("$roomplayers" , "(?i)\b$pvptarget\w*(?-i) who is (lying down|kneeling|sitting)") then goto TargetProne
# if matchre ("$roomplayers" , "(?i)\b$pvptarget\w*(?-i)") then goto IPCastClasses
# goto CastIPFull

# CastIPFull:
# matchre TargetProne ^You take a moment to look for everybody in the area and see .*(?i)\b$pvptarget\w*(?-i) who is (lying down|kneeling|sitting).*\.$
# matchre IPCastClasses ^You take a moment to look for everybody in the area and see .*(?i)\b$pvptarget\w*(?-i)|^Short memeory\!\?  You just looked\!$
# matchre HardCCTarInvis ^You take a moment to look for everybody in the area and see|^You look around and notice that you're the only one in the area\.$
# match IPCastClasses Short memeory!?  You just looked!
# put look people
# matchwait

# IPCastClasses:
# # put #class icepatch on
# goto IPSlapCheck

# TargetProne:
# put #class spellcast off
# if ($tmfoc = 1) then goto RegsRel
# if (%cao = 0) then goto RegsRel
# var invispfreturn PhysicalExit
# goto InvisPFCheck

IPSlapCheck:
var bgreturn IPCast
goto SlapPvPTarget

IPCast:
put #var pf 0
put #class spellcast on
if ($backstop > 9) then put #var backstop 0
var iphit 0
var ipmiss 0
var relerror 0
var targetinvis 0
var calmed 0
var worm 0
var spellstollen 0
var actualcalm 0
action var iphit 1 when slips and falls forward, slamming .* on the ice\.$|slips and falls backward, slamming .* on the ice\.$|tries to catch .* with .*, but manages to rock .* chin along the top of the .* as .* crashes to the ice below\.$
action var ipmiss 1 when barely manages to stay on .* feet\.$
action var relerror 1 when ^You don't have a spell prepared
action var targetinvis 1 when ^You can't cast that at yourself\!
action var calmed 1 when ^You don't feel like casting that kind of spell right now\.
if ($pvpdummy != 0) then action var iphit 1 when ^Nothing happens since|^Nothing much else happens since
action var worm 1 when ^Your spell loses cohesion when it attempts to pass through the unholy miasma\.
action var actualcalm 1 when ^You don't feel like casting that kind of spell right now\.
goto IPCast2

IPCast2:
put #var backstop #evalmath ($backstop + 1)
matchre IPCast2 ^\.\.\.wait|^Sorry\,
# matchre HardCCCastVars ^You gesture
matchre AssessIP IP Backstop $backstop$
# matchre IPHit slips and falls forward, slamming .* on the ice\.$|slips and falls backward, slamming .* on the ice\.$|tries to catch .* with .*, but manages to rock .* chin along the top of the .* as .* crashes to the ice below\.$
# if ($pvpdummy != 0) then matchre IPHit ^Nothing happens since|^Nothing much else happens since .*is flying\.
# matchre IPResist barely manages to stay on .* feet\.$
# match RegsRelError You don't have a spell prepared
# matchre HardCCTarInvis ^You can't cast that at yourself\!$
# match IPMiss IP Backstop
if ($pvptarget != 0) then put cast $pvptarget
if ($pvptarget = 0) then put cast
put echo IP Backstop $backstop
matchwait

AssessIP:
action remove slips and falls forward, slamming .* on the ice\.$|slips and falls backward, slamming .* on the ice\.$|tries to catch .* with .*, but manages to rock .* chin along the top of the .* as .* crashes to the ice below\.$
action remove barely manages to stay on .* feet\.$
action remove ^You don't have a spell prepared
action remove ^You can't cast that at yourself\!
action remove ^You don't feel like casting that kind of spell right now\.
if ($pvpdummy != 0) then action remove ^Nothing happens since|^Nothing much else happens since
action remove ^Your spell loses cohesion when it attempts to pass through the unholy miasma\.
action remove ^You seem to have forgotten this spell\!
action remove ^You don't feel like casting that kind of spell right now\.
if (%worm = 1) then goto WormSB
if (%iphit = 1) then goto IPHit
if (%ipmiss = 1) then goto IPMiss
if (%relerror = 1) then goto RegsRelError
if (%targetinvis = 1) then goto HardCCTarInvis
if (%calmed = 1) then goto CalmedSB
if (%actualcalm = 1) then goto CalmedEffectSB
goto IPBackstop

IPHit:
put #var hardccused #evalmath ($hardccused + 1)
if ($hardccused < 2) then
{
    put #var hardccattempttimer #evalmath ($unixtime + 10)
}
if ($hardccused < 3) then put #var hardccrecover #evalmath ($unixtime + 61)
if ($hardccused = 1) then put #var hardccduration #evalmath ($unixtime + 20)
if ($hardccused = 2) then put #var hardccduration #evalmath ($unixtime + 10)
if ($hardccused > 2) then put #var hardccduration #evalmath ($unixtime + 2)
goto RegsCastVarsRT

IPMiss:
put #var refdebil 0
put #var hardccattempttimer #evalmath ($unixtime + 5)
goto RegsCastVarsRT

IPBackstop:
put #var hardccattempttimer #evalmath ($unixtime + 5)
goto RegsRelError

# Soft CC

SoftCCBG:
if ($pvptarget = 0) then goto %softccbgreturn
var targetvisible SoftCCSlap
var targetspoteffect %softccbgreturn
var targetnotvisible SoftCCTarInvis
goto CheckVisiblity

SoftCCSlap:
var bgreturn %softccbgreturn
goto SlapPvPTarget

SoftCCTarInvis:
# put #class spellcast off
# put #class tingle off
# put #class vertigo off
# put #class wardbreak off
# put #class moa off
put #class retreatwatcher off
if ($pvp = 1) then put #class grapplebreakwatch off
put #class meleewatcher on
put #class polerangewatcher on
if ($pvp = 1) then put #class grapplewatch on
put #var meleelasttime 0
put #var polerange 0
put #var baltargeted 0
put #var grappled 0
put #var targetfaced 0
goto HardCCInvisCheck
# var invispfreturn SoftCCInvisCheck
# goto InvisPFCheck

TIN:
var abbrev tingle
if (%cast = 1) then
{
    put #var autostancedef 1
    put #var autostancedur 0
    put #var autostanceinteg 0
    put #var autostancepot 0
    var spellstancereturn TinCast
    goto CheckSpellStance
}
put #var prepm 33
put #var harn1 0
put #var harn2 0
put #var harnlimit 0
# put #var pausetime #evalmath ($unixtime + 3)
var pausesec 4
put #var debil 1
put #var debilcasttimer 0
goto CommonPrep

TinCast:
var softccbgreturn TinCast2
goto SoftCCBG

TinCast2:
put #var pf 0
put #class spellcast on
if ($backstop > 9) then put #var backstop 0
var tinhit 0
var fortshield 0
var tinmiss 0
var relerror 0
var targetinvis 0
var calmed 0
var worm 0
var actualcalm 0
action var tinhit 1 when grimaces\.$|seem to notice this cast\.$|grimaces as .*drops .*fingers\!$|lacking arms, is unaffected\.$
action var fortshield 1 when unwavering tranquility abates the force of your assault\.$
action var tinmiss 1 when manages to resist your spell\.$
action var relerror 1 when ^You don't have a spell prepared
action var targetinvis 1 when ^You can't cast that at yourself\!
action var calmed 1 when ^You don't feel like casting that kind of spell right now\.
action var worm 1 when ^Your spell loses cohesion when it attempts to pass through the unholy miasma\.
action var actualcalm 1 when ^You don't feel like casting that kind of spell right now\.
goto TinCast3

TinCast3:
put #var backstop #evalmath ($backstop + 1)
matchre TinCast3 ^\.\.\.wait|^Sorry\,
# matchre TinCastVars ^You gesture
# matchre TinHit grimaces\.$|seem to notice this cast\.$|grimaces as .*drops .*fingers\!$|lacking arms, is unaffected\.$
# match RegsRelError You don't have a spell prepared
# matchre SoftCCTarInvis ^You can't cast that at yourself\!$
# matchre TinFail manages to resist your spell\.$
matchre AnalyzeTingle Tin Backup $backstop$
if ($pvptarget != 0) then put cast $pvptarget
if ($pvptarget = 0) then put cast
put echo Tin Backup $backstop
matchwait

AnalyzeTingle:
action remove grimaces\.$|seem to notice this cast\.$|grimaces as .*drops .*fingers\!$|lacking arms, is unaffected\.$
action remove unwavering tranquility abates the force of your assault\.$
action remove manages to resist your spell\.$
action remove ^You don't have a spell prepared
action remove ^You can't cast that at yourself\!
action remove ^You don't feel like casting that kind of spell right now\.
action remove ^Your spell loses cohesion when it attempts to pass through the unholy miasma\.
action remove ^You don't feel like casting that kind of spell right now\.
if (%worm = 1) then goto WormSB
if (%tinhit = 1) then goto TinHit
if (%fortshield = 1) then goto TinFortShield
if (%tinmiss = 1) then goto TinMiss
if (%relerror = 1) then goto RegsRelError
if (%targetinvis = 1) then goto SoftCCTarInvis
if (%calmed = 1) then goto CalmedSB
if (%actualcalm = 1) then goto CalmedEffectSB
goto TinBackstop

TinHit:
put #var tinglehex #evalmath ($unixtime + 75)
if ($tinglehit = 0) then
{
    put #var refdebil 1
    put #var tinglehit 1
}
put #var fortshield 0
# put #var activefortshield 0
# put #class fortsvsshield off
goto RegsCastVarsRT

TinFortShield:
put #var fortshield 1
goto RegsCastVarsRT

TinMiss:
# put #class fortsvsshield off
# if ($activefortshield = 1) then
# {
#     put #var activefortshield 0
#     goto MagicExit
# }
put #var fortdebil 0
goto RegsCastVarsRT

TinBackstop:
put #var softccattempttimer #evalmath ($unixtime + 5)
goto RegsRelError

VER:
var abbrev vertigo
if (%cast = 1) then
{
    put #var autostancedef 1
    put #var autostancedur 0
    put #var autostanceinteg 0
    put #var autostancepot 0
    var spellstancereturn VerCast
    goto CheckSpellStance
}
put #var prepm 33
put #var harn1 0
put #var harn2 0
put #var harnlimit 0
# put #var pausetime #evalmath ($unixtime + 4)
var pausesec 4
put #var debil 1
put #var debilcasttimer 0
goto CommonPrep

VerCast:
var softccbgreturn VerCast2
goto SoftCCBG

VerCast2:
put #var pf 0
put #class spellcast on
if ($backstop > 9) then put #var backstop 0
var vertigohit 0
var willshield 0
var vertigomiss 0
var relerror 0
var targetinvis 0
var calmed 0
var worm 0
var actualcalm 0
var genericshield 0
action var vertigohit 1 when suddenly turns pale and begins to look unsteady\.$|^You are unable to affect the air pressure
action math genericshield add 1 when weakens your attack\.$
action var willshield 1 when confidence dampens your attack\.$|bastion of willpower weakens the attack\.$
action var vertigomiss 1 when pales for a brief moment but fights off your spell\.$
action var relerror 1 when ^You don't have a spell prepared
action var targetinvis 1 when ^You can't cast that at yourself\!
action var calmed 1 when ^You don't feel like casting that kind of spell right now\.
action var worm 1 when ^Your spell loses cohesion when it attempts to pass through the unholy miasma\.
action var actualcalm 1 when ^You don't feel like casting that kind of spell right now\.
goto VerCast3

VerCast3:
put #var backstop #evalmath ($backstop + 1)
matchre VerCast3 ^\.\.\.wait|^Sorry\,
# matchre VerCastVars ^You gesture
# matchre VerHit suddenly turns pale and begins to look unsteady\.$
# matchre VerFail pales for a brief moment but fights off your spell\.$
# match RegsRelError You don't have a spell prepared
# matchre SoftCCTarInvis ^You can't cast that at yourself\!$
matchre VerAnalysis Ver Backup $backstop$
if ($pvptarget != 0) then put cast $pvptarget
if ($pvptarget = 0) then put cast
put echo Ver Backup $backstop
matchwait

VerAnalysis:
action remove suddenly turns pale and begins to look unsteady\.$|^You are unable to affect the air pressure
action remove confidence dampens your attack\.$|bastion of willpower weakens the attack\.$
action remove weakens your attack\.$
action remove pales for a brief moment but fights off your spell\.$
action remove ^You don't have a spell prepared
action remove ^You can't cast that at yourself\!
action remove ^You don't feel like casting that kind of spell right now\.
action remove ^Your spell loses cohesion when it attempts to pass through the unholy miasma\.
action remove ^You don't feel like casting that kind of spell right now\.
if (%worm = 1) then goto WormSB
if (%vertigohit = 1) then goto VerHit
if (%genericshield > 1) then goto VerWillShield
if (%willshield = 1) then goto VerWillShield
if (%genericshield = 1) then goto GenWillShield
if (%vertigomiss = 1) then goto VerMiss
if (%relerror = 1) then goto RegsRelError
if (%targetinvis = 1) then goto SoftCCTarInvis
if (%calmed = 1) then goto CalmedSB
if (%actualcalm = 1) then goto CalmedEffectSB
goto VerBackstop

VerHit:
put #var verhex #evalmath ($unixtime + 41)
if ($willshield != 0) then put #var willshield 0
if ($wbwandattempt != 0) then put #var wbwandattempt 0
# put #var minddebil 1
# put #var activewillshield 0
# put #class willsvsshield off
goto RegsCastVarsRT

VerMiss:
# put #class willsvsshield off
put #var minddebil 0
goto RegsCastVarsRT

VerWillShield:
if ($willshield != 1) then put #var willshield 1
if ($wbwandattempt != 0) then put #var wbwandattempt 0
goto RegsCastVarsRT

GenWillShield:
put #var wbwandattempt #evalmath ($wbwandattempt + 1)
if ($wbwandattempt > 1) then
{
    if ($minddebil != 0) then put #var minddebil 0
}
else
{
    if ($willshield != 1) then put #var willshield 1
    if ($minddebil != 1) then put #var minddebil 1
}
goto RegsCastVarsRT

VerBackstop:
put #var softccattempttimer #evalmath ($unixtime + 5)
goto RegsRelError

# VerCastVars:
# if ($pvp != 1) then goto MagicExit
# put #var softccattempttimer #evalmath ($unixtime + 5)
# put #var targetinvis 0
# goto MagicExit

# VerFail:
# put #class willsvsshield off
# if ($activewillshield = 1) then
# {
#     put #var activewillshield 0
#     goto MagicExit
# }
# put #var minddebil 0
# goto MagicExit

WB:
var abbrev wb
if (%cast = 1) then goto WBCast
put #var prepm 33
put #var harn1 0
put #var harn2 0
put #var harnlimit 0
# put #var pausetime #evalmath ($unixtime + 5)
var pausesec 5
put #var debil 1
put #var debilcasttimer 0
goto CommonPrep

WBCast:
if ($tinvis = 1) then
{
    if ($hidden = 1) then goto SoftCCTarInvis
    # {
    #     var scanreturn SoftCCTarInvis
    #     goto Scan
    # }
}
if ($tinvis = 1) then
{
    if ($invisible = 1) then goto SoftCCTarInvis
    # {
    #     var scanreturn SoftCCTarInvis
    #     goto Scan
    # }
}
goto WBCast2

WBCast2:
put #var pf 0
put #class spellcast on
matchre WBCast2 ^\.\.\.wait|^Sorry\,
matchre WBCastVars ^You gesture|^The spell pattern collapses
match RegsRelError You don't have a spell prepared
matchre SoftCCTarInvis ^You can't cast that at yourself\!$
if ($pvptarget != 0) then put cast $pvptarget
if ($pvptarget = 0) then put cast
matchwait

WBCastVars:
put #var autowb 0
if ($pvp != 1) then goto MagicExit
put #var softccattempttimer #evalmath ($unixtime + 5)
put #var wbtimer #evalmath ($unixtime + 60)
put #var targetinvis 0
goto MagicExit

AoEDebilSlap:
if ($pvptarget = 0) then goto %aoedebilreturn
var targetvisible AoEDebilSlap2
var targetspoteffect %aoedebilreturn
var targetnotvisible %aoedebilreturn
goto CheckVisiblity

AoEDebilSlap2:
var bgreturn %aoedebilreturn
goto SlapPvPTarget

AoEDebilDT:
var bgreturn %aoedebilreturn
goto SlapPvPTarget

EE:
var abbrev ee
if (%cast = 1) then
{
    put #var autostancedef 1
    put #var autostancedur 0
    put #var autostanceinteg 0
    put #var autostancepot 0
    var spellstancereturn EECastCheck
    goto CheckSpellStance
}
goto EETwo

EETwo:
if ($pvptarget != 0) then goto EE2
var justicereturn EE2
var switchspellreturn SwitchToRIM
goto Justice
# if ($cyclicinitiated >= $unixtime) then
# {
#     var cyclicadd $cyclicinitiated

#     # Creates the cyclicadd number which is the amount of seconds to wait until casting another cyclic.

#     math cyclicadd subtract $unixtime
#     if (%cyclicadd >= $pausetime) then goto EEPauseCalc
# }
# goto EE2

# EEPauseCalc:
# put #var pausetime #evalmath ($unixtime + %cyclicadd)
# goto EE2

EE2:
put #var debil 1
put #var prepm 31
put #var harn1 0
put #var harn2 0
put #var harnlimit 0
put #var paralysis 0
# put #var pausetime #evalmath ($unixtime + 6)
var pausesec 6
goto CommonPrep

EECastCheck:
if ($pvptarget != 0) then goto EECastCheck2
var switchspellreturn SwitchToRIM
var justicereturn EECastCheck2
goto Justice

EECastCheck2:
if ($acon = 1) then goto EECastRel
if ($fron = 1) then goto EECastRel
if ($rimon = 1) then goto EECastRel
if ($eeon = 1) then goto EECastRel
var facereturn EECast
goto FacingCheckSB

EECastRel:
var relcyclic 1
var relreturn FacingCheckSB
var facereturn EECast
goto RelSpell

EECast:
put #var pf 0
put #class spellcast on
put #class electrostaticeddystart on
if ($backstop > 9) then put #var backstop 0
var eeon 0
var cyclictimer 0
var actualcalm 0
action var eeon 1 when ^Tapping into the Elemental Plane of Electricity, you begin
action var cyclictimer 1 when ^The mental strain of initiating a cyclic spell
action var actualcalm 1 when ^You don't feel like casting that kind of spell right now\.
if ($aoearea = 0) then goto EECast2
if ($pvptarget = 0) then goto EECast2
# if ("$roomplayers" != "") then goto EECast2
if ($pvpdummy != 0) then goto EECast2
goto EECastArea

EECast2:
put #var backstop #evalmath ($backstop + 1)
matchre EECast2 ^\.\.\.wait|^Sorry\,
# matchre EECastFail ^You don't have a spell prepared|^The mental strain of initiating a cyclic spell|^Your spell.*?backfires|^The spell pattern collapses
# matchre MagicExit ^You gesture
matchre AssessEE EE Backstop $backstop$
put cast
put echo EE Backstop $backstop
matchwait

EECastArea:
put #var backstop #evalmath ($backstop + 1)
matchre EECastArea ^\.\.\.wait|^Sorry\,
# matchre EECastFail ^You don't have a spell prepared|^The mental strain of initiating a cyclic spell|^Your spell.*?backfires|^The spell pattern collapses
# matchre MagicExit ^You gesture
matchre AssessEEArea EE Backstop $backstop$
put cast nongroup
put echo EE Backstop $backstop
matchwait

AssessEE:
action remove ^Tapping into the Elemental Plane of Electricity, you begin
action remove ^The mental strain of initiating a cyclic spell
action remove ^You don't feel like casting that kind of spell right now\.
if (%eeon = 1) then goto EECastSuccess
if (%cyclictimer = 1) then goto CyclicTimerFail
if (%actualcalm = 1) then goto CalmedEffectSB
goto EECastFail

AssessEEArea:
action remove ^Tapping into the Elemental Plane of Electricity, you begin
action remove ^The mental strain of initiating a cyclic spell
action remove ^You don't feel like casting that kind of spell right now\.
if (%eeon = 1) then goto EECastSuccessArea
if (%cyclictimer = 1) then goto CyclicTimerFail
if (%actualcalm = 1) then goto CalmedEffectSB
goto EECastFail

EECastSuccess:
put #var aoecyclic 0
goto RegsCastVarsRT

EECastSuccessArea:
put #var aoecyclic 1
goto RegsCastVarsRT

CyclicTimerFail:
put #class electrostaticeddystart off
put #var cyclicinitiated #evalmath ($unixtime + 30)
goto RegsRelError

EECastFail:
put #class electrostaticeddystart off
put #var cyclicinitiated 0
goto RegsRelError

FRB:
var abbrev frostbite
if (%cast = 1) then
{
    put #var autostancedef 0
    put #var autostancedur 1
    put #var autostanceinteg 0
    put #var autostancepot 0
    var spellstancereturn FrBCast
    goto CheckSpellStance
}
put #var debil 1
if ($mana > 69) then goto FRBMaxMana
if ("$cscript" = ".seekanddestroy") then goto FRBMaxMana
if ($acon = 1) then goto FRBMaxMana
goto FRB2

FRBMaxMana:
put #var prepm 89
put #var harn1 0
put #var harn2 0
put #var harnlimit 0
# put #var pausetime #evalmath ($unixtime + 5)
var pausesec 6
# var justicereturn CommonPrep
# var switchspellreturn SwitchToIP
# goto Justice
goto CommonPrep

FRB2:
put #var prepm 29
put #var harn1 30
put #var harn2 30
put #var harnlimit 2
# put #var pausetime #evalmath ($unixtime + 1)
if ($boosttimer > $unixtime) then
{
    var pausesec 4
}
else
{
    var pausesec 2
}
# var justicereturn CommonPrep
# var switchspellreturn SwitchToIP
# goto Justice
goto CheckFRBJustice

CheckFRBJustice:
if ($pvptarget != 0) then goto CommonPrep
var justicereturn CommonPrep
var switchspellreturn SwitchToIP
goto Justice

FrBCast:
if ($pvptarget != 0) then goto FrBCast1
var switchspellreturn SwitchToIP
var justicereturn FrBCast2
# var shieldreturn FrBCast2
goto Justice

FrBCast1:
# var switchspellreturn SwitchToIP
# var justicereturn ShieldCheck
var shieldreturn FacingCheckSB
var facereturn FrBCast2
goto ShieldCheck

FrBCast2:
put #var pf 0
put #class spellcast on
if ($backstop > 9) then put #var backstop 0
var frbhit 0
var fortshield 0
var frbmiss 0
var relerror 0
var calmed 0
var worm 0
var actualcalm 0
action var frbhit 1 when shivers as a layer of frost covers .+ body\!$|body is completely coated in a layer of frost\!$
action var fortshield 1 when unwavering tranquility abates the force of your assault\.$
action var frbmiss 1 when shakes off the effects of the cold\.$
action var relerror 1 when ^You don't have a spell prepared|^Your spell.*?backfires
action var calmed 1 when ^You don't feel like casting that kind of spell right now\.
if ($necro = 1) then action var worm 1 when ^Your spell loses cohesion when it attempts to pass through the unholy miasma\.
action var actualcalm 1 when ^You don't feel like casting that kind of spell right now\.
if ($pvptarget = 0) then goto FrBCast3
if ($aoearea = 0) then goto FrBCast3
if ($pvpdummy != 0) then goto FrBCast3
goto FrBCastArea

FrBCast3:
put #var backstop #evalmath ($backstop + 1)
matchre FrBCast3 ^\.\.\.wait|^Sorry\,
# matchre FrBCastVars ^You gesture
# match RegsRelError You don't have a spell prepared
matchre AssessFrB FrB Backup $backstop$
put cast
put echo FrB Backup $backstop
matchwait

FrBCastArea:
put #var backstop #evalmath ($backstop + 1)
matchre FrBCastArea ^\.\.\.wait|^Sorry\,
# matchre FrBCastVars ^You gesture
# match RegsRelError You don't have a spell prepared
matchre AssessFrB FrB Backup $backstop$
put cast nongroup
put echo FrB Backup $backstop
matchwait

AssessFrB:
action remove shivers as a layer of frost covers .+ body\!$|body is completely coated in a layer of frost\!$
action remove unwavering tranquility abates the force of your assault\.$
action remove shakes off the effects of the cold\.$
action remove ^You don't have a spell prepared|^Your spell.*?backfires
action remove ^You don't feel like casting that kind of spell right now\.
if ($necro = 1) then action remove ^Your spell loses cohesion when it attempts to pass through the unholy miasma\.
action remove ^You don't feel like casting that kind of spell right now\.
if (%worm = 1) then goto WormSB
if (%frbhit = 1) then goto FrBHit
if (%fortshield = 1) then goto FrBFortShield
if (%tinmiss = 1) then goto FrBMiss
if (%relerror = 1) then goto RegsRelError
if (%calmed = 1) then goto CalmedSB
if (%actualcalm = 1) then goto CalmedEffectSB
goto FrBBackstop

FrBHit:
put #var fortshield 0
put #var frbtimer #evalmath ($unixtime + 75)
goto RegsCastVarsRT

FrBFortShield:
put #var fortshield 1
goto RegsCastVarsRT

FrBMiss:
put #var fortdebil 0
goto RegsCastVarsRT

FrBBackstop:
put #var softccattempttimer #evalmath ($unixtime + 5)
goto RegsCastVarsRT

# FrBCastVars:
# # if ($pvp != 1) then goto MagicExit
# put #var softccattempttimer #evalmath ($unixtime + 5)
# put #var frbtimer #evalmath ($unixtime + 75)
# goto MagicExit

TC:
var abbrev tc
# I don't have messaging for TC hits messaging for hardcc triggers, and I don't use it in a loop, so it goes to commoncast.
if (%cast = 1) then
{
    put #var autostancedef 0
    put #var autostancedur 1
    put #var autostanceinteg 0
    put #var autostancepot 0
    var spellstancereturn TCCastCheck
    goto CheckSpellStance
}
goto TC2

TC2:
put #var debil 1
# if ($mana > 79) then
# {
put #var prepm 66
put #var harn1 0
put #var harn2 0
put #var harnlimit 0
# put #var pausetime #evalmath ($unixtime + 5)
var pausesec 5
goto TCJusticeCheck

TCJusticeCheck:
if ($pvptarget != 0) then goto CommonPrep
var justicereturn CommonPrep
var switchspellreturn SwitchToIP
goto Justice

TCCastCheck:
if ($pvptarget != 0) then goto TCCastCheck2
var switchspellreturn SwitchToIP
var justicereturn TCCast
goto Justice

TCCastCheck2:
# var switchspellreturn SwitchToIP
# var justicereturn AoEDebilSlap
var aoedebilreturn FacingCheckSB
var facereturn TCCast
goto AoEDebilSlap

TCCast:
if ($pvptarget != 0) then
{
    if ($aoearea = 1) then goto TCCastArea
}
put #var pf 0
put #class spellcast on
matchre TCCast ^\.\.\.wait|^Sorry\,
matchre TCCastVars ^You gesture|^The spell pattern collapses
match RegsRelError You don't have a spell prepared
put cast
matchwait

TCCastArea:
put #var pf 0
put #class spellcast on
matchre TCCastArea ^\.\.\.wait|^Sorry\,
matchre TCCastVars ^You gesture|^The spell pattern collapses
match RegsRelError You don't have a spell prepared
put cast nongroup
matchwait

TCCastVars:
# if ($pvp != 1) then goto MagicExit
put #var softccattempttimer #evalmath ($unixtime + 5)
put #var tctimer #evalmath ($unixtime + 8)
goto RegsCastVarsRT

TREM:
var abbrev trem
if (%cast = 1) then
{
    put #var autostancedef 1
    put #var autostancedur 0
    put #var autostanceinteg 0
    put #var autostancepot 0
    var spellstancereturn TremCastCheck
    goto CheckSpellStance
}
goto Trem2

Trem2:
put #var debil 1
put #var prepm 66
put #var harn1 0
put #var harn2 0
put #var harnlimit 0
# put #var pausetime #evalmath ($unixtime + 6)
var pausesec 7
# var justicereturn CommonPrep
# var switchspellreturn SwitchToIP
# goto Justice
goto TremJusticeCheck

TremJusticeCheck:
if ($pvptarget != 0) then goto CommonPrep
var justicereturn CommonPrep
var switchspellreturn SwitchToIP
goto Justice

TremCastCheck:
if ($pvptarget != 0) then goto TremCastCheck2
var switchspellreturn SwitchToIP
var justicereturn TremCast
# var shieldreturn TremCast
goto Justice

TremCastCheck2:
# var switchspellreturn SwitchToIP
# var justicereturn ShieldCheck
var shieldreturn FacingCheckSB
var facereturn TremCast
goto ShieldCheck

# if ($pvptarget != 0) then 
# {
#     var justicereturn ShieldCheck
#     var switchspellreturn SwitchToIP
#     var shieldreturn CheckVisiblity
#     var targetvisible TremCast
#     var targetspoteffect TremCast
#     var targetnotvisible TremCast
#     goto Justice
# }
# var justicereturn TremCast
# var switchspellreturn SwitchToIP
# goto Justice

TremCast:
put #var pf 0
put #class spellcast on
if ($backstop > 9) then put #var backstop 0
var tremhit 0
var tremmiss 0
var relerror 0
var calmed 0
var worm 0
var actualcalm 0
var treminside 0
action var tremhit 1 when but looks a bit wobbly\!$|shakes with the movement of the ground\.$|tumbles away from you\.$|thrown to the ground by the heaving of the earth\!$
action var tremmiss 1 when manages to remain upright\!$
action var treminside 1 when ^As the walls and ceiling shudder, you unravel the spell
action var relerror 1 when ^You don't have a spell prepared|^Your spell.*?backfires
action var calmed 1 when ^You don't feel like casting that kind of spell right now\.
if ($necro = 1) then action var worm 1 when ^Your spell loses cohesion when it attempts to pass through the unholy miasma\.
action var actualcalm 1 when ^You don't feel like casting that kind of spell right now\.
put #class enemytrem off
if ($pvptarget = 0) then goto TremCast2
if ($aoearea = 0) then goto TremCast2
if ($pvpdummy != 0) then goto TremCast2
goto TremCastArea

TremCast2:
put #var backstop #evalmath ($backstop + 1)
matchre TremCast2 ^\.\.\.wait|^Sorry\,
# matchre MagicExit ^You gesture
# match ResetTremVars You don't have a spell prepared
matchre AssessTrem Trem Backup $backstop$
put #var tremtimer #evalmath ($unixtime + 42)
# put #var softccattempttimer #evalmath ($unixtime + 5)
put cast
put echo Trem Backup $backstop
matchwait

TremCastArea:
put #var backstop #evalmath ($backstop + 1)
matchre TremCastArea ^\.\.\.wait|^Sorry\,
# matchre MagicExit ^You gesture
# match ResetTremVars You don't have a spell prepared
matchre AssessTrem Trem Backup $backstop$
put #var tremtimer #evalmath ($unixtime + 42)
# put #var softccattempttimer #evalmath ($unixtime + 5)
put cast nongroup
put echo Trem Backup $backstop
matchwait

AssessTrem:
action remove but looks a bit wobbly\!$|shakes with the movement of the ground\.$|tumbles away from you\.$|thrown to the ground by the heaving of the earth\!$
action remove manages to remain upright\!$
action remove ^As the walls and ceiling shudder, you unravel the spell
action remove ^You don't have a spell prepared|^Your spell.*?backfires
action remove ^You don't feel like casting that kind of spell right now\.
if ($necro = 1) then action remove ^Your spell loses cohesion when it attempts to pass through the unholy miasma\.
action remove ^You don't feel like casting that kind of spell right now\.
put #class enemytrem on
if (%treminside = 1) then goto TremInside
if (%worm = 1) then goto WormSB
if (%tremhit = 1) then goto TremHit
if (%tremmiss = 1) then goto TremMiss
if (%relerror = 1) then goto RegsRelError
if (%calmed = 1) then goto CalmedSB
if (%actualcalm = 1) then goto CalmedEffectSB
goto TremBackstop

TremHit:
put #var refdebil 1
goto RegsCastVarsRT

TremMiss:
put #var refdebil 0
goto RegsCastVarsRT

TremBackstop:
put #var softccattempttimer #evalmath ($unixtime + 5)
goto RegsCastVarsRT

TremInside:
put #var inside 1
goto RegsCastVarsRT

CheckSpellStance:
if ($autostanceinteg = 1) then
{
    if ($spellstanceinteg = 1) then goto %spellstancereturn
    goto StanceInteg
}
if ($autostancedur = 1) then
{
    if ($spellstancedur = 1) then goto %spellstancereturn
    goto StanceDur
}
if ($autostancepot = 1) then
{
    if ($spellstancepot = 1) then goto %spellstancereturn
    goto StancePot
}
if ($autostancedef = 1) then
{
    if ($spellstancedef = 1) then goto %spellstancereturn
}
goto StanceDef

StanceDef:
matchre StanceDef ^\.\.\.wait|^Sorry\,
match StanceDefVars Your spell Integrity is now set
put spells stance 100 100 100
matchwait

StanceDefVars:
put #var spellstanceinteg 0
put #var spellstancedur 0
put #var spellstancedef 1
put #var spellstancepot 0
goto %spellstancereturn

StanceInteg:
matchre StanceInteg ^\.\.\.wait|^Sorry\,
match StanceIntegVars Your spell Integrity is now set
put spells stance 115 115 70
matchwait

StanceIntegVars:
put #var spellstanceinteg 1
put #var spellstancedur 0
put #var spellstancedef 0
put #var spellstancepot 0
goto %spellstancereturn

StanceDur:
matchre StanceDur ^\.\.\.wait|^Sorry\,
match StanceDurVars Your spell Integrity is now set
put spells stance 115 70 115
matchwait

StanceDurVars:
put #var spellstanceinteg 0
put #var spellstancedur 1
put #var spellstancedef 0
put #var spellstancepot 0
goto %spellstancereturn

StancePot:
matchre StancePot ^\.\.\.wait|^Sorry\,
match StancePotVars Your spell Integrity is now set
put spells stance 130 70 100
matchwait

StancePotVars:
put #var spellstanceinteg 0
put #var spellstancedur 0
put #var spellstancedef 0
put #var spellstancepot 1
goto %spellstancereturn