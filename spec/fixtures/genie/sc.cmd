# Spell Caster
# debug 5
put #script abort all except sc
if ("$magicloop" != ".sc") then put #var magicauraloop .sc
if ($combattriggersloaded != 1) then
{
    put .loadcombattriggers
    exit
}
var notarget 0
if ($challengeover = 1) then goto StopDead
if ($SpellTimer.HuldahsPall.active = 1) then
{
    put #var nomagic 1
    put #class hulprecover on
    put .res
}
if ($unixtime > $hardccrecover) then put #var hardccused 0
var pf 0
var cast 0
var endauramessage 0
var cyclicpreptimer 0
var auraready 0
var parallelfocusoff 0
var mainslotchecked 0
var debiled 0

IncVis:
var targetvisible IncSpellBook
var targetspoteffect IncSpellBook
var targetnotvisible IncSpellBook
include commonvis.cmd

IncSpellBook:
var spellbookreturn IncJustice
include spellbook.cmd

IncJustice:
var justicereturn IncAura
include commonjustice.cmd

IncAura:
var aurareturn IncFOISkip
include commonaura.cmd

IncFOISkip:
var foiskipreturn IncShear
include commonfoiskip.cmd

IncShear:
var shearreturn IncPWDef
include commonshear.cmd

IncPWDef:
var pathwaydefreturn IncRelease
include commonpathwaydef.cmd

IncRelease:
var relreturn RetreatInc
include commonrelease.cmd

RetreatInc:
var retreatreturn IncInvis
include commonretreat.cmd

IncInvis:
var invisreturn IncBG
include commoninvis.cmd

IncBG:
var bgreturn IncDB
include commonbg.cmd

IncDB:
var dbreturn IncDebil
include commondb.cmd

IncDebil:
var debilcheckreturn HandsInc
include commondebilcheck.cmd

HandsInc:
var shleftreturn IncShield
var shrightreturn IncShield
include handscheck.cmd

IncShield:
var shieldreturn IncBow
include commonshield.cmd

IncBow:
var bowreturn InitialCheck
include commonbow.cmd

# Actions
StopDead:
put #script abort all
put #queue clear
put .remdead
exit

PeaceRoom:
put #var peaceroom 1
var commonrel 1
var relreturn CheckSpellStatus
goto RelSpell
# Actions End

InitialCheck:
var perced 0
goto CheckSpellStatus

CheckSpellStatus:
var pf 0
var prep 0
var cast 0
var acdebil 0
var pfslot 0
if ($pf != 0) then put #var pf 0
var cao 1
var tmpfcheck 0
var requiresmainslot 0
var morespells 0
var nextspell 0
var maf 0
var repr 0
if ($combatloop = 0) then 
{
    var cao 0
    # if ($roundtime != 0) then waiteval ($roundtime = 0)
    goto CheckSituationalReleases
}
if ($pvpfull != 0) then put #var pvpfull 0
if ($cax != 0) then put #var cax 0
if ($peaceroom != 0) then put #var peaceroom 0
goto CheckSituationalReleases

CheckSituationalReleases:
if ($nomagic = 1) then
{
    put #echo >Conversation
    put #echo >Conversation #000000 *** No Magic On
    echo
    echo **** No Magic On ****
    put #var magicauraloop 0
    put #var cax 0
    put #var pvpfull 0
    put .relx
    exit
}
var relreturn CheckSpellStatus
if ($spelllost != 0) then goto RegsRel
if ($pfspelllost != 0) then goto PFRel
if ($harn > $harnlimit) then
{
    var relpf 1
    var commonrel 1
    var relpathway 1
    goto RelSpell
}
# if ($kickonly = 1) then
# {
#     if ($pfspellprepped = 1) then goto DamagedPFRel
# }
# if ($handdamaged = 1) then
# {
#     if ($pfspellprepped = 1) then goto DamagedPFRel
# }
if ($pfharn > $pfharnlimit) then
{
    var relpf 1
    var commonrel 1
    goto RelSpell
}
if ($pfoff = 1) then goto PFSlotOFF
if ($handdamaged = 1) then goto PFSlotOFF
if ($kickonly = 1) then goto PFSlotOFF
if ($webbed = 1) then goto PFSlotOFF
goto NoTMRelCheck

PFSlotOFF:
var parallelfocusoff 1
goto NoTMRelCheck

RegsRel:
var relreturn CheckSpellStatus
var commonrel 1
goto RelSpell

PFRel:
var relreturn CheckSpellStatus
var relpf 1
goto RelSpell

NoTMRelCheck:
# Seek and Destory logic for when to cast FOI. 
# This is past the point at which FOI was checked and confirms seek and destory won't cast FOI when it doesn't need to buff, or only needs to reup an attack spell or expired PF FOI.
# put #var sndfoicast 0
if ($notm = 1) then goto NoTMRelCheck2
if ($acon = 1) then
{
    if matchre ("$roomname" , "Ice Fortress") then
    {
        if ($pvptarget = 0) then goto CheckEERel
        var targetvisible NoTMRelCheck1
        var targetspoteffect NoTMRelCheck1
        var targetnotvisible CheckEERel
        goto CheckVisiblity
    }
}
goto NoTMRelCheck1

NoTMRelCheck1:
if ($acon != 1) then goto CheckEERel
if (%cao != 1) then goto CheckEERel
if ($unixtime > $cyclicinitiated) then
{
    if ("$pfspellname" = "Aether Cloak") then goto CheckEERel
}
goto ACTMRelCheck

NoTMRelCheck2:
if ($attackspell = 1) then goto RegsRelAC
if ($stattackspell = 1) then goto RegsRelAC
if ("$rspellname" = "Dragon's Breath") then goto RegsRelAC
if ("$rspellname" = "Blufmor Garaen") then goto RegsRelAC
if ($notm != 1) then goto CheckEERel
if ("$rspellname" = "Magnetic Ballista") then goto RegsRelAC
goto CheckEERel

ACTMRelCheck:
if ($attackspell = 1) then goto RegsRelAC
if ($stattackspell = 1) then goto RegsRelAC
if ("$rspellname" = "Dragon's Breath") then goto RegsRelAC
if ("$rspellname" = "Blufmor Garaen") then goto RegsRelAC
if ($notm != 1) then goto CheckEERel
goto CheckEERel

RegsRelAC:
if ($notm = 1) then
{
    put #echo >Conversation
    put #echo >Conversation #000000 *** TM is Off
    put #echo >Conversation #000000 *** Releasing TM Spell
    echo
    echo **** TM is Off ****
    echo **** Releasing TM Spell ****
    goto RegsRel
}
put #echo >Conversation
put #echo >Conversation #000000 *** AC is On
put #echo >Conversation #000000 *** Releasing TM Spell
echo
echo **** AC is On ****
echo **** Releasing TM Spell ****
goto RegsRel

CheckEERel:
if ($pvptarget = 0) then goto ETremCheck
if ("$rspellname" != "Electrostatic Eddy") then goto ETremCheck
if ($cyclicinitiated >= $unixtime) then goto ETremCheck
if ($groupbattle = 1) then goto ETremCheck
if ($fortdebil = 0) then goto RegsRel
# if ($autoee = 0) then goto RegsRel
goto ETremCheck

ETremCheck:
if ("$rspellname" = "Tremor") then goto ETremRunningRel
# {
#     if ($spelltime > 0) then goto ETremRunningRel
# }
goto TMRelCheck

ETremRunningRel:
if ($unixtime >= $tremtimer) then goto TMRelCheck
put #echo >Conversation
put #echo >Conversation #000000 *** Tremor Running
put #echo >Conversation #000000 *** Releasing Tremor
echo
echo **** Tremor Running
echo **** Releasing Tremor
goto RegsRel

TMRelCheck:
# if ($stattackspell = 1) then
# {
#     # if (%cao = 0) then goto CheckACRel
#     if ($pvptarget = 0) then goto CheckACRel
#     var targetvisible CheckACRel
#     var targetspoteffect CheckACRel
#     var targetnotvisible RegsRel
#     goto CheckVisiblity
# }
if ("$rspellname" = "Fortress of Ice") then goto CheckFOIRel
goto CheckACRel

CheckFOIRel:
var foiskipreturn CheckFOIRel2
goto FoISkipCheck

CheckFOIRel2:
if ("$cscript" = ".seekanddestroy") then goto CheckACRel
if (%foiskip = 1) then goto RegsRel
# {
#     var foiskip 0
#     goto RegsRel
# }
if (%cao = 0) then goto CheckACRel
if ($pvptarget = 0) then goto CheckACRel
var targetvisible RegsRel
var targetspoteffect RegsRel
var targetnotvisible CheckACRel
goto CheckVisiblity

CheckACRel:
if ($acon != 1) then goto PriorityCasting
if ("$pfspellname" != "Aether Cloak") then goto PriorityCasting
if ($autoac != 1) then goto PFRel
if ($autodb != 0) then
{
    if ("$rspellname" = "Dragon's Breath") then goto PriorityCasting
    if ($SpellTimer.DragonsBreath.active = 0) then goto PriorityCasting
}
if ($autobg != 0) then
{
    if ("$rspellname" = "Blufmor Garaen") then goto PriorityCasting
    if ($SpellTimer.BlufmorGaraen.active = 0) then goto PriorityCasting
}
if ($pvptarget = 0) then goto PriorityCasting
var targetvisible PriorityCasting
var targetspoteffect PriorityCasting
var targetnotvisible PFRel
goto CheckVisiblity

# CheckFOIRel:

PriorityCasting:
if ($invisible = 1) then 
{
    if !matchre ("$roomname" , "Ice Fortress") then goto SkipSlotInvisCheck
}
goto PriorityCasting1

SkipSlotInvisCheck:
if ($pvptarget = 0) then goto MainPerc
var targetvisible PriorityCasting1
var targetspoteffect PriorityCasting1
var targetnotvisible MainPerc
goto CheckVisiblity

PriorityCasting1:
if ($harn != 0) then goto Harn
if ($pfharn != 0) then goto PFHarn
if ("$rspellname" = "Fortress of Ice") then goto CheckFoICast
if ("$pfspellname" = "Fortress of Ice") then goto CheckPFFOI
goto PriorityCasting2

CheckFoICast:
if ($pausetime > $unixtime) then goto CheckSpellReady2
goto Harn

CheckPFFOI:
if ($pfpausetime > $unixtime) then goto CheckSpellReady2
if ("$cscript" = ".seekanddestroy") then
{
    if ($sndfoicast != 1) then goto CheckSpellReady2
}
put #var sndfoicast 0
var foiskipreturn CheckPFFOI2
goto FoISkipCheck

CheckPFFOI2:
if (%foiskip = 1) then goto PriorityCasting2
if matchre ("$roomname" , "Ice Fortress") then goto PriorityCasting2
if (%cao = 0) then goto PFHarn
if ($pvptarget = 0) then goto PFHarn
var aurareturn CheckPFFOI3
goto AuraCheck

CheckPFFOI3:
if (%nextspell = 0) then goto PriorityCasting2
var targetvisible PriorityCasting2
var targetspoteffect PriorityCasting2
var targetnotvisible PFHarn
goto CheckVisiblity

PriorityCasting2:
if ("$preparedspell" = "Aegis of Granite") then goto CheckRitualFocus
if ("$preparedspell" = "Mantle of Flame") then goto CheckRitualFocus
if ("$pfspellname" = "Aether Cloak") then
{
    if ($acon != 1) then
    {
        if ($pfpausetime < $unixtime) then goto PFHarn
    }
}
goto CheckSpellReady2

CheckRitualFocus:
if ($focinvoked = 1) then goto CheckSpellReady2
if ($kickonly = 1) then goto CheckSpellReady2
goto RitualPrep

CheckSpellReady2:
if ($combatloop = 0) then goto CheckConcentration
if ($pvptarget = 0) then goto CheckConcentration
var targetvisible CheckMana
var targetspoteffect CheckMana
var targetnotvisible CheckConcentration
goto CheckVisiblity

CheckConcentration:
if ($concentration < 80) then goto RegenMana
goto CheckMana

CheckMana:
if ($mana < 40) then goto RegenMana
goto CheckMainSlot

RegenMana:
if ($pvptarget = 0) then goto RegenManaA
if ($autofoi = 0) then goto RegenManaA
var foiskipreturn RegenFOIAnalysis
goto FoISkipCheck

RegenFOIAnalysis:
if (%foiskip = 1) then goto RegenManaA
if ($rspell = 0) then
{
    if matchre ("$qspell" , "FOI$") then goto QSpell
}
if (%parallelfocusoff != 1) then
{
    if ($pfspell = 0) then
    {
        if matchre ("$qspell" , "FOI$") then goto QSpell

    }
}
if matchre ("$rspell" , "FOI$") then
{
    if ($cax = 0) then
    {
        if ($pvpfull = 0) then goto FOIQuickCast
    }
}
if ("$pfspell" = "FOI$") then
{
    if ($cax = 0) then
    {
        if ($pvpfull = 0) then goto FOIQuickCastPF
    }
}
if ($pvptarget != 0) then
{
    if (%cao = 1) then
    {
        if (%parallelfocusoff != 1) then
        {
            if ($pfspell = 0) then 
            {
                var targetvisible RegenManaA
                var targetspoteffect RegenManaA
                var targetnotvisible PFFoISC
                goto CheckVisiblity
            }
        }
    }
}
if ($pvptarget != 0) then
{
    if (%cao = 1) then
    {
        if ($rspell = 0) then 
        {
            var targetvisible RegenManaA
            var targetspoteffect RegenManaA
            var targetnotvisible FoISC
            goto CheckVisiblity
        }
    }
}
goto RegenManaA

FOIQuickCast:
if ($unixtime > $pausetime) then goto Harn
if (%cao = 0) then
{
    echo
    echo **** Pausing for FOI ****
    echo
    var foipausetime $pausetime
    math foipausetime subtract $unixtime
    if (%foipausetime < 1) then goto Harn
    pause %foipausetime
    goto Harn
}
goto PhysicalExit

FOIQuickCastPF:
if ($unixtime > $pfpausetime) then goto PFHarn
if (%cao = 0) then
{
    echo
    echo **** Pausing for FOI ****
    echo
    var foipausetime $pfpausetime
    math foipausetime subtract $unixtime
    if (%foipausetime < 1) then goto PFHarn
    pause %foipausetime
    goto PFHarn
    # pause
    # goto PFHarn
}
goto PhysicalExit

RegenManaA:
if ($rspell != 0) then goto RegenMana2
if ($pfspell != 0) then goto RegenMana2
if ($qspell != 0) then goto RegenMana2
if (%cao != 0) then goto RegenMana2
if ($cax != 0) then goto RegenMana2
if ($pvpfull != 0) then goto RegenMana2
goto MagicExit

RegenMana2:
var wandreturn RegenMana3
goto WandCheck

RegenMana3:
echo
echo ******** Regenerating Mana *********
echo      Mana - $mana
echo      Concentration - $concentration
echo ************************************
echo
if ($combatloop != 0) then goto PhysicalExit
pause 10
put .res
exit

CheckMainSlot:
# Align to commonspellskip.cmd
if (%mainslotchecked = 0) then
{
    if ($rspell = 0) then goto MainPerc
}
var mainslotchecked 0
if ($rspell = 0) then goto CheckPFSlot
if ($acon = 1) then
{
    if ($stattackspell = 1) then goto ACTMCheck
    if ($attackspell = 1) then goto ACTMCheck
    if ("$rspellname" = "Dragon's Breath") then goto ACTMCheck
    if ("$rspellname" = "Blufmor Garaen") then goto ACTMCheck
}
# if ($stattackspell = 1) then
# {
#     if ($pvptarget = 0) then goto CheckMainSlot1
#     var targetvisible CheckMainSlot1
#     var targetspoteffect CheckMainSlot1
#     var targetnotvisible CheckPFSlot
#     goto CheckVisiblity
# }
goto CheckMainSlot1

ACTMCheck:
if (%cao != 1) then goto CheckMainSlot1
if !matchre ("$roomname" , "Ice Fortress") then goto ACTMCheck2
if ($pvptarget = 0) then goto CheckMainSlot1
var targetvisible ACTMCheck2
var targetspoteffect ACTMCheck2
var targetnotvisible CheckMainSlot1
goto CheckVisiblity

ACTMCheck2:
if ("$pfspellname" != "Aether Cloak") then goto RegsRel
var pfacpreptime $pfpausetime
math pfacpreptime subtract 1
if (%pfacpreptime >= $unixtime) then goto CheckPFSlot
goto CheckMainSlot1

CheckMainSlot1:
if ($tmspellready = 1) then goto SkipSlotCheck
if ($acon = 1) then
{
    if ($debil = 1) then goto ACDebilCheck
}
if ($spellready = 1) then goto SkipSlotCheck
if matchre ("$preparedspell" , "^(Aegis of Granite|Mantle of Flame)") then goto PrepWait
if ("$rspellname" = "Lightning Bolt") then goto QuickLBCheck
if ("$rspellname" = "Frost Scythe") then goto QuickFRSCheck
# Main Perc prevents casting PF spells that would break targeting
if matchre ("$rspellname" , "Stone Strike|Gar Zeng|Fire Shard") then goto MultiHitTMCheck
if matchre ("$rspellname" , "Chain Lightning|Shockwave|Frostbite") then goto AoETMCheck
goto CheckMainSlot2

QuickLBCheck:
if ($spelltime < 3) then goto MainPerc
if ($longpause != 0) then
{
    var lbspelltime $longpause
    math multispelltime add 3
    if ($spelltime < %multispelltime) then goto MainPerc
}
if ($acon = 1) then
{
    if ($wellbalanced != 1) then goto MainPerc
}
goto SkipSlotCheck

QuickFRSCheck:
if ($spelltime < 3) then goto MainPerc
if ($longpause != 0) then
{
    var lbspelltime $longpause
    math multispelltime add 3
    if ($spelltime < %multispelltime) then goto MainPerc
}
if ($wellbalanced != 1) then goto MainPerc
if ($meleelasttime != 1) then goto MainPerc
var debiledreturn SkipSlotCheck
var notdebiledreturn QuickFRSCheck3
goto OpponentDebiledCheck

OpponentDebiledCheck:
if ($pvpdummy != 0) then goto OpponentDebiledCheckDummy
if ($pvppet != 0) then goto OpponentDebiledCheckDummy
if (%debiled = 1) then goto %debiledreturn
if (%debiled = 2) then goto %notdebiledreturn
goto OpponentDebiledCheck2

OpponentDebiledCheckDummy:
# if matchre ("$pvptarget" , "\w+ \w+") then goto OpponentDebiledCheckDummy2
# var newpvpdummy $pvptarget
# goto OpponentDebiledCheckDummy3

# OpponentDebiledCheckDummy2:
# var newpvpdummy $pvptarget
# eval newpvpdummy replacere("%newpvpdummy", ".+ ", "")
# goto OpponentDebiledCheckDummy3

# OpponentDebiledCheckDummy3:
if matchre ("$roomobjs" , "that is lying down|that appears (immobilized|stunned)") then goto OpponentDebiled
goto OpponentNotDebiled

OpponentDebiledCheck2:
if matchre ("$roomplayers" , "(?i)\b$pvptarget\w*(?-i)(?:(?!\band\s+[A-Z])[^,])*?\b(lying down|kneeling|sitting|immobilized)\b") then goto OpponentDebiled
if matchre ("$roomplayers" , "a stunned (?i)\b$pvptarget\w*(?-i)") then goto OpponentDebiled
goto OpponentNotDebiled

OpponentDebiled:
var debiled 1
goto %debiledreturn

OpponentNotDebiled:
var debiled 2
goto %notdebiledreturn

QuickFRSCheck3:
if ($tmfoc != 1) then goto MainPerc
goto SkipSlotCheck

MultiHitTMCheck:
if ($spelltime < 1) then goto MainPerc
# if ($offbalance = 1) then goto MainPerc
if ($longpause != 0) then
{
    var multispelltime $longpause
    math multispelltime add 1
    if ($spelltime < %multispelltime) then goto MainPerc
}
if ($thief = 1) then goto SkipSlotCheck
if ($moonmage = 1) then goto SkipSlotCheck
if ($barb = 1) then
{
    if ($tmfoc != 1) then
    {
        if ($nocharge != 1) then
        {
            if ($tmspellready != 1) then goto MainPerc
        }
    }
}
if ($meleelasttime = 0) then
{
    if ($polerange = 0) then goto MainPerc
}
if ($acon = 1) then
{
    if ($meleelasttime != 1) then goto MainPerc
}
# if ($tmfoc = 0) then goto MainPerc
goto SkipSlotCheck

AoETMCheck:
if ($pvptarget = 0) then goto CheckMainSlot2
if ($acon = 1) then goto CheckMainSlot2
if matchre ("$rspellname" = "Chain Lightning") then goto QuickCLCheck
if ($spelltime < 6) then goto CheckMainSlot2
if ($longpause != 0) then
{
    var aoetmtime $longpause
    math aoetmtime add 6
    if ($spelltime < %aoetmtime) then goto CheckMainSlot2
}
goto AoETMCheck2

QuickCLCheck:
if ($spelltime < 5) then goto CheckMainSlot2
if ($longpause != 0) then
{
    var aoetmtime $longpause
    math aoetmtime add 5
    if ($spelltime < %aoetmtime) then goto CheckMainSlot2
}
goto AoETMCheck2

AoETMCheck2:
var targetvisible SkipSlotCheck
var targetspoteffect SkipSlotCheck
var targetnotvisible CheckMainSlot2
goto CheckVisiblity

ACDebilCheck:
# Make sure this aligns with commonspellskip
if matchre ("$rspellname" , "Tremor|Electrostatic Eddy") then goto CheckMainSlot2
if ($hardccused < 2) then
{
    if ($autoip != 0) then
    {
        if ($refdebil = 1) then goto CheckMainSlot2
    }
    if ($alsoftcc != 1) then
    {
        if ($fortdebil = 1) then goto CheckMainSlot2
    }
}
if ($tremtimer < $unixtime) then
{
    if ($verhex < $unixtime) then goto CheckMainSlot2
}
if ($offbalance = 1) then goto CheckMainSlot2
if ($polerange = 0) then
{
    if ($meleelasttime = 0) then goto CheckMainSlot2
}
if ($kickonly = 1) then goto CheckMainSlot2
if ($handdamaged = 1) then goto CheckMainSlot2
# If ACMs are available, don't cast.
if ($unixtime > $cleavetime) then goto CheckPFSlot
if ($unixtime > $impaletime) then goto CheckPFSlot 
if ($unixtime > $twirltime) then goto CheckPFSlot
if ($meleelasttime != 1) then goto CheckMainSlot2
if ($unixtime > $doubletime) then goto CheckPFSlot
if ($unixtime > $palmtime) then goto CheckPFSlot
if ($unixtime > $crashtime) then goto CheckPFSlot
goto CheckMainSlot2

CheckMainSlot2:
if ($stattackspell = 1) then goto MainPerc
if ($attackspell = 1) then goto MainPerc
# if ($attackspell = 1) then
# {
#     if ("$cscript" != ".seekanddestroy") then
#     {
#         if ($harn = $harnlimit) then goto MainPerc
#     }
# }
goto CheckMainSlot3

CheckMainSlot3:
# Prioritizes main slot, but casts from PF if main slot isn't being used.

# Checking if main spell is ready and going to cast
if ($unixtime >= $pausetime) then goto SkipSlotCheck
goto CheckPFSlot

SkipSlotCheck:
if ("$cscript" = ".seekanddestroy") then goto SnDCheckSC
if ($shear = 1) then goto CheckShearVis
goto SkipSlotCheck2

CheckShearVis:
var targetvisible SkipShearCheck
var targetspoteffect ShearPoint
var targetnotvisible SkipShearCheck
goto CheckVisiblity

ShearPoint:
var bgreturn SkipShearCheck
goto SkipShearAnalysis

SkipShearCheck:
var shearreturn SkipShearAnalysis
goto CheckShear

SkipShearAnalysis:
if (%shear = 0) then goto SkipSlotCheck2
if ($pvpjustice = 1) then goto SkipSlotCheck2
if ($attackspell = 1) then goto SkipSlotCheck2
if ($debil = 1) then goto SkipShearAnalysis2
if ($stattackspell = 1) then goto RegsRel
goto SkipSlotCheck2
# goto RegsRel

SkipShearAnalysis2:
# if matchre ("$preparedspell" , "Chain Lightning|Shockwave|Tremor|Frostbite|Thunderclap|Electrostatic Eddy") then goto SkipSlotCheck2
if matchre ("$preparedspell" , "Tremor|Frostbite|Thunderclap|Electrostatic Eddy") then goto SkipSlotCheck2
# if ($spelltime > 29) then goto RegsRel
# goto CheckPFSlot
goto RegsRel

SkipSlotCheck2:
if ("$preparedspell" = "Ice Patch") then goto CheckIPPos
if matchre ("$preparedspell" , "Arc Light|Tingle|Anther's Call|Mark of Arhat|Vertigo") then goto STDebilSkip
if matchre ("$preparedspell" , "Chain Lightning|Shockwave|Frostbite|Thunderclap") then goto CheckAoETMSkip
goto Harn

CheckIPPos:
# if ($pvpdummy != 0) then goto CheckIPPosDummy
if ($pvptarget = 0) then goto Harn
var targetvisible CheckIPPos2
var targetspoteffect CheckIPPos2
var targetnotvisible CheckPFSlot
goto CheckVisiblity

CheckIPPos2:
var debiledreturn IPImmobRel
var notdebiledreturn Harn
goto OpponentDebiledCheck

# if ($pvppet != 0) then goto IPPosDummy
# if ($pvpdummy != 0) then goto IPPosDummy
# goto CheckIPPos3

# IPPosDummy:
# if matchre ("$pvptarget" , "\w+ \w+") then goto IPPosDummy2
# var newpvpdummy $pvptarget
# goto IPPosDummy3

# IPPosDummy2:
# var newpvpdummy $pvptarget
# eval newpvpdummy replacere("%newpvpdummy", ".+ ", "")
# goto IPPosDummy3

# IPPosDummy3:
# if matchre ("$roomobjs" , "%newpvpdummy (that is lying down|that appears (immobilized|stunned))") then goto IPImmobRel
# goto Harn

# CheckIPPos3:
# if matchre ("$roomplayers" , "(?i)\b$pvptarget\w*(?-i)(?:(?!\band\s+[A-Z])[^,])*?\b(lying down|kneeling|sitting|immobilized)\b") then goto IPImmobRel
# if matchre ("$roomplayers" , "a stunned (?i)\b$pvptarget\w*(?-i)") then goto IPImmobRel
# goto Harn

IPImmobRel:
if ($autotrem = 1) then
{
    if ($unixtime > $tremtimer) then
    {
        if ($pvpjustice != 1) then
        {
            if ($inside != 1) then goto IPImmobRel2
        }
    }
}
if ($notm = 1) then goto CheckPFSlot
if ($autoac = 1) then
{
    if ("$pfspellname" != "Aether Cloak") then goto CheckPFSlot
}
# if ($wormsmist != 0) then
# {
#     if ($pvpjustice != 0) then goto CheckPFSlot
# }
goto IPImmobRel2

IPImmobRel2:
put #var hardccattempttimer #evalmath ($unixtime + 5)
goto RegsRel

CheckIPPosDummy:
var targetvisible Harn
var targetspoteffect Harn
var targetnotvisible CheckPFSlot
goto CheckVisiblity

STDebilSkip:
if ($pvptarget = 0) then goto Harn
var targetvisible STDebilSkip2
var targetspoteffect STDebilSkip2
var targetnotvisible CheckPFSlot
goto CheckVisiblity

STDebilSkip2:
if ("$rspellname" != "Arc Light") then goto Harn
var debiledreturn CheckALStunnedRel
var notdebiledreturn Harn
goto OpponentDebiledCheck

# if matchre ("$roomplayers" , "a stunned (?i)\b$pvptarget\w*(?-i)") then goto CheckALStunnedRel
# goto Harn

CheckALStunnedRel:
put #var hardccattempttimer #evalmath ($unixtime + 5)
goto RegsRel

SnDCheckSC:
if matchre ("$preparedspell" , "^(Arc Light|Ice Patch|Chain Lightning|Shockwave|Tremor|Frostbite|Vertigo|Tingle)") then goto CheckPFSlot
goto Harn

CheckAoETMSkip:
if ($pvptarget = 0) then goto Harn
var targetvisible Harn
var targetspoteffect Harn
var targetnotvisible CheckAoETMSkip2
goto CheckVisiblity

CheckAoETMSkip2:
if ($mana < 70) then goto CheckPFSlot
if ($concentration < 80) then goto CheckPFSlot
goto Harn

Harn:
# if ($sorcery = 1) then
# {
#     if ($spellready = 0) then
#     {
#         if ($tmspellready = 0) then
#         {
#             if ($harn != 0) then goto PrepWait
#             goto CheckPFSlot
#         }
#     }
    
# }
var mainslotchecked 0
var ipwandexit HarnOneOne
goto AutoWandCheck

HarnOneOne:
if ($pf != 0) then put #var pf 0
if ($harn1 = 0) then goto RSpellCast
if ($harnlimit != 0) then
{
    if ($harn = $harnlimit) then goto RSpellCast
}
if ($harn > 2) then
{
    var commonrel 1
    var relreturn CheckSpellStatus
    goto RelSpell
}
# if ($sorcery = 0) then
# {
#     if ($unixtime > $pausetime) then goto RSpellCast
# }
var shieldreturn HarnOne
goto ShieldCheck

HarnOne:
if ($harn = 1) then goto Harn2
matchre Harn ^\.\.\.wait|^Sorry\,
match MagicExit You tap into the mana
put #class harness on
put harn $harn1
matchwait

Harn2:
if ($pf != 0) then put #var pf 0
if ($harn2 = 0) then goto RSpellCast
if ($harnlimit != 0) then
{
    if ($harn = $harnlimit) then goto RSpellCast
}
if ($harn > 2) then
{
    var commonrel 1
    var relreturn CheckSpellStatus
    goto RelSpell
}
matchre Harn2 ^\.\.\.wait|^Sorry\,
match MagicExit You tap into the mana
put #class harness on
put harn $harn2
matchwait

RSpellCast:
if ($sorcery = 1) then
{
    if ($spellready = 1) then goto RSpellCast2
    if ($tmspellready = 1) then goto RSpellCast2
    goto SorceryWait
}
goto RSpellCast2

RSpellCast2:
if ($rspell = 0) then goto RegsRel
var cast 1
goto $rspell

SorceryWait:
echo
echo **** Sorcery
echo **** Waiting for Full Prep
echo
pause .1
put .res
exit

CheckPFSlot:

# How to handle PF spell ready, when I could be prepping another main slot spell - except TM, which couldn't start targeting till after the pf cast.

# Option 1: if targeting, skip, then cast pf before adding a new main slot spell.

# Option 2: always load main slot, except if script wants to target tm. This would probably require logic in spellbook to check if a pfspell ready to go on all targeted preps.

if ($pfspell = 0) then goto MainPerc
if ($unixtime > $pfpausetime) then goto PFHarnSkipCheck
goto MainPerc

PFHarnSkipCheck:
# Casting from PF breaks targeting
if ("$pfspellname" = "Aether Cloak") then goto ACCheckPF
goto PFHarnSkipCheck2

ACCheckPF:
if ($acon = 1) then goto ACCheckPF2
goto PFHarnSkipCheck2

ACCheckPF2:
if ($autodb != 0) then
{
    if ("$rspellname" = "Dragon's Breath") then goto MainPerc
    if ($SpellTimer.DragonsBreath.active = 0) then goto MainPerc
}
if ($autobg != 0) then
{
    if ("$rspellname" = "Blufmor Garaen") then goto MainPerc
    if ($SpellTimer.BlufmorGaraen.active = 0) then goto MainPerc
}
if ($pvptarget = 0) then goto PFRel
var targetvisible MainPerc
var targetspoteffect MainPerc
var targetnotvisible PFRel
goto CheckVisiblity

PFHarnSkipCheck2:
if ($stattackspell = 1) then goto MainPerc
if ("$pfspellname" = "Fortress of Ice") then goto FoICheckPF
if ($webbed = 1) then goto MainPerc
if ($attackspell = 1) then goto PFAttackSpellVisCheck
# {
#     # if ("$cscript" = ".seekanddestroy") then goto PFHarn
#     goto PFAttackSpellVisCheck
# }
goto PFHarn

FoICheckPF:
var foiskipreturn FoICheckPF2
goto FoISkipCheck

FoICheckPF2:
if (%foiskip = 1) then goto MainPerc
if matchre ("$roomname" , "Ice Fortress") then goto MainPerc
if ($pvptarget = 0) then goto PFHarn
var targetvisible MainPerc
var targetspoteffect MainPerc
var targetnotvisible PFHarn
goto CheckVisiblity

PFAttackSpellVisCheck:
if ($pvptarget = 0) then goto MainPerc
var targetvisible MainPerc
var targetspoteffect MainPerc
var targetnotvisible PFHarn
goto CheckVisiblity

PFHarn:
var mainslotchecked 0
var ipwandexit PFHarnOneOne
goto AutoWandCheck

PFHarnOneOne:
put #var pf 1
if ($pfharn1 = 0) then goto PFCast
if ($pfharnlimit != 0) then
{
    if ($pfharn = $pfharnlimit) then goto PFCast
}
if ($pfharn > 2) then
{
    var relpf 1
    var relmana 1
    var relreturn CheckSpellStatus
    goto RelSpell
}
var shieldreturn PFHarnOne
goto ShieldCheck

PFHarnOne:
if ($pfharn = 1) then goto PFHarn2
matchre PFHarn ^\.\.\.wait|^Sorry\,
match MagicExit You tap into the mana
put #class harness on
put harn $pfharn1
matchwait

PFCast:
if ($pfspell = 0) then goto PFRel
var pf 1
var cast 1
if ($attackspell = 1) then put #var spelllost 1
if ($stattackspell = 1) then put #var spelllost 1
if ("$lefthand" = "spiritwood cube") then goto $pfspell
if ("$righthand" = "spiritwood cube") then goto $pfspell
if ("$lefthandnoun" = "") then
{
    var getpfocreturn $pfspell
    goto GetPFoc
}
if ("$righthandnoun" = "") then 
{
    var getpfocreturn $pfspell
    goto GetPFoc
}
var getpfocreturn $pfspell
var shleftreturn GetPFoc
var shrightreturn GetPFoc
goto EmptyOneHand

MainPerc:
# Logic for when casting from a fully prepped PF just before reloading TM.
# See TMPFCheckSB in spellbook.cmd
if ($rspell != 0) then
{
    if ("$preparedspell" = "None") then 
    {
        if (%loadmainslot = 1) then
        {
            var loadmainslot 0
            goto CheckSpellStatus
        }
        echo
        echo **** rspell = $rspell ****
        echo **** prepared spell = $preparedspell
        echo
        goto RegsRel
    }
}
if ($pfspell != 0) then
{
    if ($pfspellprepped = 0) then goto PFRel
}
goto MainPercOne

MainPercOne:
if ("$pfspellname" = "Fortress of Ice") then goto FOISlotAvailableCheck
goto ACSlotAvailableCheck

FOISlotAvailableCheck:
var skipfoi 0
var foiskipreturn FOISlotAvailableCheck2
goto FoISkipCheck

FOISlotAvailableCheck2:
if (%foiskip = 1) then goto FOISlotConfirmed
if (%cao = 0) then goto ACSlotAvailableCheck
if ($pvptarget = 0) then goto ACSlotAvailableCheck
var targetvisible FOISlotConfirmed
var targetspoteffect FOISlotConfirmed
var targetnotvisible ACSlotAvailableCheck
goto CheckVisiblity

FOISlotConfirmed:
var skipfoi 1
goto MainPercSlotCheck

ACSlotAvailableCheck:
if ("$pfspellname" != "Aether Cloak") then goto MainPerc1
if ($acon != 1) then goto MainPerc1
if ($pvptarget = 0) then goto MainPerc1
var targetvisible MainPerc1
var targetspoteffect MainPerc1
var targetnotvisible ACSlotAvailableCheck2
goto CheckVisiblity

ACSlotAvailableCheck2:
if ($autodb != 0) then
{
    if ("$rspellname" = "Dragon's Breath") then goto MainPerc1
    if ($SpellTimer.DragonsBreath.active = 0) then goto MainPerc1
}
if ($autobg != 0) then
{
    if ("$rspellname" = "Blufmor Garaen") then goto MainPerc1
    if ($SpellTimer.BlufmorGaraen.active = 0) then goto MainPerc1
}
var relpf 1
var relreturn MainPerc1
goto RelSpell

MainPerc1:
if ($pfspell != 0) then goto PFSlotChecked
# Remove if anything breaks!
if (%parallelfocusoff = 1) then goto PFSlotChecked
goto MainPercSlotCheck

PFSlotChecked:
var pfslot 1
goto MainPercSlotCheck

MainPercSlotCheck:
if ($rspell = 0) then goto SlotAvailable
# Restore if anything breaks!
# if (%parallelfocusoff = 1) then goto PrepWait
if (%pfslot = 0) then goto SlotAvailable
goto PrepWait

SlotAvailable:
if ($qspell != 0) then goto QSpell
goto MainPerc3

QSpell:
if ($qspellpfcompat = 1) then goto CheckPFQ
goto CheckQ

CheckPFQ:
if ("$pfspellname" = "Fortress of Ice") then goto PFRel
if ($pfoff = 1) then goto CheckQ
if ($kickonly = 1) then goto CheckQ
if ($handdamaged = 1) then goto CheckQ
if ($pfspell != 0) then goto CheckMainQ
if ("$pfspellname" = "$qspellname") then
{
    put #var qspell 0
    put #var qspellname 0
    put #var qspellpfcompat 0
    goto MainPerc3
}
if ("$rspellname" = "$qspellname") then
{
    put #var qspell 0
    put #var qspellname 0
    put #var qspellpfcompat 0
    goto MainPerc3
}
put #var pfspell $qspell
put #var pfspellname $qspellname
put #var qspell 0
put #var qspellname 0
put #var qspellpfcompat 0
var pf 1
var prep 1
goto $pfspell

CheckMainQ:
if (%cao = 0) then goto CheckQ
goto MainPerc3

CheckQ:
if ("$pfspellname" = "$qspellname") then
{
    put #var qspell 0
    put #var qspellname 0
    put #var qspellpfcompat 0
    goto MainPerc3
}
if ("$rspellname" = "$qspellname") then
{
    put #var qspell 0
    put #var qspellname 0
    put #var qspellpfcompat 0
    goto MainPerc3
}
if ($rspell != 0) then goto MainPerc3
put #var rspell $qspell
put #var rspellname $qspellname
put #var qspell 0
put #var qspellname 0
put #var qspellpfcompat 0
var prep 1
goto $rspell

MainPerc3:
var percreturn PrioritySpellCheck
if ($backstop > 9) then put #var backstop 0
if ($cax = 1) then goto PercCheck
if ($pvpfull = 1) then goto PercCheck
if (%cao = 1) then goto PercCheck
if ($rspell != 0) then goto PrepWait
if ($pfspell != 0) then goto PrepWait
goto MagicExit

PercCheck:
goto PercExit
# if (%perced = 1) then goto PercExit
# if ($nopercself = 1) then goto PercCheck2
# if ($webbed = 1) then goto PercCheck2
# # if matchre ("$roomname" , "Ice Fortress") then goto PercCheck3
# goto PercCheckA

# PercCheckA:
# put #var backstop #evalmath ($backstop + 1)
# matchre PercCheckA ^\.\.\.wait|^Sorry\,
# # matchre PercExit ^You sense|^You don't sense|^Something in the area is interfering|which should last so long as you remain in \w+ group\.$|^You are preparing
# match PercInterference You reach out with your senses, but there is only interference.
# matchre PercExit Perced $backstop$
# # put #gag {^You sense|^You remember a way|^You are still too fatigued from your previous efforts|^You feel a supreme manifestation|^You are preparing}
# put perc self
# put echo Perced $backstop
# matchwait

# PercInterference:
# put #var nopercself 1
# goto PercCheck2

# PercCheck2:
# put /spelltimer
# goto PercExit

# PercCheck3:
# if ($pvptarget = 0) then goto %percreturn
# var targetvisible %percreturn
# var targetspoteffect %percreturn
# var targetnotvisible PercCheckFOI
# goto CheckVisiblity

# PercCheckFOI:
# put /spelltimer
# pause
# goto PercExit

PercExit:
# pause .1
# put #ungag {^You sense|^You remember a way|^You are still too fatigued from your previous efforts|^You feel a supreme manifestation|^You are preparing}
if ($bgcheckskip >= $unixtime) then goto %percreturn
if ($SpellTimer.BlufmorGaraen.active = 0) then
{
    if ($bgready != 0) then put #var bgready 0;put #class bgstart off;put #class bgend off
}
if ($SpellTimer.BlufmorGaraen.active = 1) then
{
    if ($bgready != 1) then put #var bgready 1;put #class bgstart off;put #class bgend on
}
var perced 1
goto %percreturn

PrioritySpellCheck:
# Checks the queue for parallel focus compatability
if ($autofoi != 1) then goto ACCheck
if (%foiskip = 1) then goto ACCheck
if ($pvptarget = 0) then goto ACCheck
if (%cao != 1) then goto ACCheck
var targetvisible ACCheck
var targetspoteffect ACCheck
var targetnotvisible FoICheck
goto CheckVisiblity

FoICheck:
if matchre ("$roomname" , "Ice Fortress|Wyvern Arena") then goto ACCheck
if matchre ("$roomexits" , "^Obvious exits") then goto ACCheck
if ($autofoi = 0) then goto ACCheck
if ("$rspellname" = "Fortress of Ice") then goto ACCheck
if ("$pfspellname" = "Fortress of Ice") then goto ACCheck
if ($inside = 1) then goto ACCheck
if ($pvptarget = 0) then goto ACCheck
if matchre ("$roomobjs" , "Ice Fortress") then goto ACCheck
var aurareturn FoICheck2
goto AuraCheck

FoICheck2:
if (%morespells != 1) then goto ACCheck
if ("$cscript" = ".seekanddestroy") then goto ACCheck
if (%pfslot != 1) then goto PFFoISC
if ("$pfspellname" = "Aether Cloak") then
{
    if ($acon = 1) then
    {
        var relreturn FoICheck
        var relpf 1
        goto RelSpell
    }
}
if ($rspell = 0) then goto FoISC
# if ($rspell = 0) then
# {
#     var relreturn FoICheck
#     var commonrel 1
#     goto RelSpell
# }
goto ACCheck

PFFoISC:
put #var pfspell FOI
put #var pfspellname Fortress of Ice
var pf 1
var prep 1
goto $pfspell

FoISC:
put #var rspell FOI
put #var rspellname Fortress of Ice
var prep 1
goto $rspell

ACCheck:
if ($autoac = 0) then goto CheckMAF
if ($dbtimer >= $unixtime) then goto CheckMAF
if ($acon != 0) then goto CheckMAF
if ($cyclicinitiated >= $unixtime) then goto CheckMAF
if ("$rspellname" = "Aether Cloak") then goto CheckMAF
if ("$pfspellname" = "Aether Cloak") then goto CheckMAF
if (%cao != 1) then goto CheckMAF
# if (%cao = 0) then
# {
#     if ($pvpfull = 1) then goto CheckMAF
#     if ($cax = 1) then goto CheckMAF
# }
if matchre ("$roomname" , "Ice Fortress") then
{
    if ($pvptarget = 0) then goto CheckMAF
    var targetvisible ACCheck1
    var targetspoteffect ACCheck1
    var targetnotvisible CheckMAF
    goto CheckVisiblity
}
goto ACCheck1

ACCheck1:
if ("$pfspellname" = "Fortress of Ice") then
{
    if (%skipfoi = 1) then
    {
        var relreturn ACCheck2
        var relpf 1
        goto RelSpell
    }
}
goto ACCheck2

ACCheck2:
if (%pfslot != 1) then goto ACPF
goto ACSC

ACPF:
put #var pfspell AC
put #var pfspellname Aether Cloak
var pf 1
var prep 1
if matchre ("$rspellname" , "Electrostatic Eddy|Fire Rain|Rimefang") then put #var spelllost 1
goto $pfspell

ACSC:
put #var rspell AC
put #var rspellname Aether Cloak
var prep 1
goto $rspell

CheckMAF:
if ($es = 1) then goto GICheck
if ($mafcasttimer >= $unixtime) then goto GICheck
if ($cax = 1) then goto CheckMAFFull
if ($pvpfull = 1) then goto CheckMAFFull
if ($SpellTimer.ManifestForce.duration >= 6) then goto GICheck
goto CheckMAF2

CheckMAFFull:
if ($SpellTimer.ManifestForce.duration >= 20) then goto GICheck
goto CheckMAF2

CheckMAF2:
if ("$rspellname" = "Manifest Force") then goto GICheck
if ("$pfspellname" = "Manifest Force") then goto GICheck
if ($mafspelllosstimer >= $unixtime) then goto GICheck
if ("$pfspellname" = "Fortress of Ice") then
{
    if (%skipfoi = 1) then
    {
        var relreturn CheckMAF3
        var relpf 1
        goto RelSpell
    }
}
goto CheckMAF3

CheckMAF3:
if (%pfslot != 1) then goto MAFPF
goto MAFSC

MAFPF:
put #var pfspell MAF
put #var pfspellname Manifest Force
var pf 1
var prep 1
goto $pfspell

MAFSC:
put #var rspell MAF
put #var rspellname Manifest Force
var prep 1
goto $rspell

GICheck:
if ($cax = 1) then goto CheckGIFull
if ($pvpfull = 1) then goto CheckGIFull
if ($SpellTimer.GamIrnan.duration >= 6) then goto CheckESSC
goto GICheck2

CheckGIFull:
if ($SpellTimer.GamIrnan.duration >= 20) then goto CheckESSC
goto GICheck2

GICheck2:
if ("$rspellname" = "Gam Irnan") then goto CheckESSC
if ("$pfspellname" = "Gam Irnan") then goto CheckESSC
if ($gispelllosstimer >= $unixtime) then goto CheckESSC
if ("$pfspellname" = "Fortress of Ice") then
{
    if (%skipfoi = 1) then
    {
        var relreturn GICheck3
        var relpf 1
        goto RelSpell
    }
}
goto GICheck3

GICheck3:
if (%pfslot != 1) then goto GIPF
goto GISC

GIPF:
put #var pfspell GI
put #var pfspellname Gam Irnan
var pf 1
var prep 1
goto $pfspell

GISC:
put #var rspell GI
put #var rspellname Gam Irnan
var prep 1
goto $rspell

CheckESSC:
if ($es = 0) then goto CheckSUF
if ($cax = 1) then goto CheckESFull
if ($pvpfull = 1) then goto CheckESFull
if ($SpellTimer.EtherealShield.duration >= 6) then goto CheckSUF
goto CheckESSC2

CheckESFull:
if ($SpellTimer.EtherealShield.duration >= 20) then goto CheckSUF
goto CheckESSC2

CheckESSC2:
if ("$rspellname" = "Ethereal Shield") then goto CheckSUF
if ("$pfspellname" = "Ethereal Shield") then goto CheckSUF
if ($esspelllosstimer >= $unixtime) then goto CheckSUF
if ("$pfspellname" = "Fortress of Ice") then
{
    if (%skipfoi = 1) then
    {
        var relreturn CheckESSC3
        var relpf 1
        goto RelSpell
    }
}
goto CheckESSC3

CheckESSC3:
if (%pfslot != 1) then goto ESPF
goto ESSC

ESPF:
put #var pfspell ES
put #var pfspellname Ethereal Shield
var pf 1
var prep 1
goto $pfspell

ESSC:
put #var rspell ES
put #var rspellname Ethereal Shield
var prep 1
goto $rspell

CheckSUF:
if ($cax = 1) then goto CheckSUFFull
if ($pvpfull = 1) then goto CheckSUFFull
if ($SpellTimer.SureFooting.duration >= 6) then goto CheckSW
goto CheckSUF2

CheckSUFFull:
if ($SpellTimer.SureFooting.duration >= 20) then goto CheckSW
goto CheckSUF2

CheckSUF2:
if ("$rspellname" = "Sure Footing") then goto CheckSW
if ("$pfspellname" = "Sure Footing") then goto CheckSW
if ($sufspelllosstimer >= $unixtime) then goto CheckSW
if ("$pfspellname" = "Fortress of Ice") then
{
    if (%skipfoi = 1) then
    {
        var relreturn CheckSUF3
        var relpf 1
        goto RelSpell
    }
}
goto CheckSUF3

CheckSUF3:
if (%pfslot != 1) then goto SUFPF
goto SUFSC

SUFPF:
put #var pfspell SUF
put #var pfspellname Sure Footing
var pf 1
var prep 1
goto $pfspell

SUFSC:
put #var rspell SUF
put #var rspellname Sure Footing
var prep 1
goto $rspell

CheckSW:
if ("$rspellname" = "Swirling Winds") then goto CheckAwaken
if ("$pfspellname" = "Swirling Winds") then goto CheckAwaken
if ($swcasttimer >= $unixtime) then goto CheckAwaken
if ($cax = 1) then goto CheckSWFull
if ($pvpfull = 1) then goto CheckSWFull
if ($SpellTimer.SwirlingWinds.duration >= 6) then goto CheckAwaken
goto CheckSW2

CheckSWFull:
if ($SpellTimer.SwirlingWinds.duration >= 20) then goto CheckAwaken
goto CheckSW2

CheckSW2:
if ($autosw = 0) then goto CheckAwaken
if ($swspelllosstimer >= $unixtime) then goto CheckAwaken
if ("$pfspellname" = "Fortress of Ice") then
{
    if (%skipfoi = 1) then
    {
        var relreturn CheckSW3
        var relpf 1
        goto RelSpell
    }
}
goto CheckSW3

CheckSW3:
if (%pfslot != 1) then goto SWPF
goto SWSC

SWPF:
put #var pfspell SW
put #var pfspellname Swirling Winds
var pf 1
var prep 1
goto $pfspell

SWSC:
put #var rspell SW
put #var rspellname Swirling Winds
var prep 1
goto $rspell

CheckAwaken:
if (%cao = 0) then goto CheckREPR
if ($pvp != 1) then goto CheckREPR
if ($awakencasttimer >= $unixtime) then goto CheckREPR
if ("$cscript" = ".seekanddestroy") then goto CheckAwakenSnD
goto CheckAwakenCAO

CheckAwakenSnD:
if ($SpellTimer.Awaken.duration >= 5) then goto CheckREPR
goto CheckAwaken2

CheckAwakenFull:
if ($SpellTimer.Awaken.duration >= 7) then goto CheckREPR
goto CheckAwaken2

CheckAwakenCAO:
if ($SpellTimer.Awaken.duration >= 2) then goto CheckREPR
goto CheckAwaken2

CheckAwaken2:
if ("$rspellname" = "Awaken") then goto CheckREPR
if ("$pfspellname" = "Awaken") then goto CheckREPR
if ($noscrollawaken = 1) then goto CheckREPR
if ($nosorcery != 0) then goto CheckREPR
if ($awakenspelllosstimer >= $unixtime) then goto CheckREPR
if ("$pfspellname" = "Fortress of Ice") then
{
    if (%skipfoi = 1) then
    {
        var relreturn CheckAwaken3
        var relpf 1
        goto RelSpell
    }
}
goto CheckAwaken3

CheckAwaken3:
if (%pfslot != 1) then goto AwakenPF
goto AwakenSC

AwakenPF:
put #var pfspell AWAKEN
put #var pfspellname Awaken
var pf 1
var prep 1
goto $pfspell

AwakenSC:
put #var rspell AWAKEN
put #var rspellname Awaken
var prep 1
goto $rspell

CheckREPR:
if ($noscrollrepr = 1) then goto CheckGG
if ($cax = 1) then goto CheckREPRFull
if ($pvpfull = 1) then goto CheckREPRFull
if ($SpellTimer.RedeemersPride.duration >= 6) then goto CheckGG
goto CheckREPR2

CheckREPRFull:
if ($SpellTimer.RedeemersPride.duration >= 20) then goto CheckGG
goto CheckREPR2

CheckREPR2:
if ("$rspellname" = "Redeemer's Pride") then goto CheckGG
if ("$pfspellname" = "Redeemer's Pride") then goto CheckGG
if ($reprspelllosstimer >= $unixtime) then goto CheckGG
if ("$pfspellname" = "Fortress of Ice") then
{
    if (%skipfoi = 1) then
    {
        var relreturn CheckREPR3
        var relpf 1
        goto RelSpell
    }
}
goto CheckREPR3

CheckREPR3:
if (%pfslot != 1) then goto REPRPF
goto REPRSC

REPRPF:
put #var pfspell REPR
put #var pfspellname Redeemer's Pride
var pf 1
var prep 1
goto $pfspell

REPRSC:
put #var rspell REPR
put #var rspellname Redeemer's Pride
var prep 1
goto $rspell

CheckGG:
if ($rspell != 0) then goto CheckSUB
if (%cao = 0) then goto CheckSUB
if ($pvp = 0) then goto CheckSUB
if ($ggcasttimer >= $unixtime) then goto CheckSUB
if ($SpellTimer.GlythtidesGift.duration >= 6) then goto CheckSUB
if ($norunegg = 1) then goto CheckSUB
if ($invisible = 1) then goto CheckSUB
if ($nosorcery != 0) then goto CheckSUB
if ($handdamaged = 1) then
{
    if ($tmfoc = 1) then goto CheckSUB
}
if ($kickonly = 1) then goto CheckSUB
if ($headdamage = 1) then goto CheckSUB
goto GGSC

GGSC:
put #var rspell GG
put #var rspellname Glythtide's Gift
var prep 1
goto $rspell

CheckSUB:
if ($subcasttimer >= $unixtime) then goto CheckDB
if ($cax = 1) then goto CheckSUBFull
if ($pvpfull = 1) then goto CheckSUBFull
if ($SpellTimer.Substratum.duration >= 6) then goto CheckDB
goto CheckSUB2

CheckSUBFull:
if ($SpellTimer.Substratum.duration >= 20) then goto CheckDB
goto CheckSUB2

CheckSUB2:
if ("$rspellname" = "Substratum") then goto CheckDB
if ("$pfspellname" = "Substratum") then goto CheckDB
if ($notm = 1) then
{
    if (%cao = 1) then goto CheckDB
}
if ($subspelllosstimer >= $unixtime) then goto CheckDB
if ("$pfspellname" = "Fortress of Ice") then
{
    if (%skipfoi = 1) then
    {
        var relreturn CheckSUB3
        var relpf 1
        goto RelSpell
    }
}
goto CheckSUB3

CheckSUB3:
if (%pfslot != 1) then goto SUBPF
goto SUBSC

SUBPF:
put #var pfspell SUB
put #var pfspellname Substratum
var pf 1
var prep 1
goto $pfspell

SUBSC:
put #var rspell SUB
put #var rspellname Substratum
var prep 1
goto $rspell

CheckDB:
if ($rspell != 0) then goto AttackMagicCheck
if ($acon = 1) then
{
    if (%cao != 0) then
    {
        if ("$pfspellname" != "Aether Cloak") then goto AttackMagicCheck
    }
}
if ($calmed = 1) then goto AttackMagicCheck
# if ("$pfspell" = "AC") then goto AttackMagicCheck
if ($peaceroom = 1) then goto AttackMagicCheck
if ($notm = 1) then goto AttackMagicCheck
if ($dbcasttimer >= $unixtime) then goto AttackMagicCheck
if ($autodb = 0) then goto AttackMagicCheck
if ($fireoff = 1) then goto AttackMagicCheck
if ($cax = 1) then goto CheckDBFull
if ($pvpfull = 1) then goto CheckDBFull
if ($SpellTimer.DragonsBreath.duration >= 6) then goto AttackMagicCheck
goto CheckDB2

CheckDBFull:
if ($SpellTimer.DragonsBreath.duration >= 20) then goto AttackMagicCheck
goto CheckDB2

CheckDB2:
goto DBSC

DBSC:
put #var rspell DB
put #var rspellname Dragon's Breath
var prep 1
goto $rspell

AttackMagicCheck:

# Four possible routes:
# 1. PvP Target Visible - Attack Magic
# 2. PvP Target Not Visible, not in ice fortress - Use Invis Attack Spells, or buff if PF off
# 3. PvP Target Not Visible, in ice fortress - Full buff
# 4. Not in PvP - Full buff

if (%cao = 0) then goto CheckTW
if ($bo = 1) then goto CheckTW
if ($calmed = 1) then goto CheckTW
if ($pvptarget = 0) then goto CheckTW
if ($rspell != 0) then goto CheckTW
var targetvisible PvPAttackSpells
var targetspoteffect PvPAttackSpells
var targetnotvisible PriorityInvisTrem
goto CheckVisiblity

PriorityInvisTrem:
if ("$cscript" = ".seekanddestroy") then goto CheckTW
if ($pvpjustice = 1) then goto CheckTW
if ($inside = 1) then goto CheckTW
if ($refdebil = 0) then goto CheckTW
if ($autotrem = 0) then goto CheckTW
if ($tremtimer > $unixtime) then goto CheckTW
if ($tremspelllosstimer >= $unixtime) then goto CheckTW
goto Tremor

CheckTW:
if ($cax = 1) then goto CheckTWFull
if ($pvpfull = 1) then goto CheckTWFull
if ($SpellTimer.Tailwind.duration >= 6) then goto CheckGF
goto CheckTW2

CheckTWFull:
if ($SpellTimer.Tailwind.duration >= 20) then goto CheckGF
goto CheckTW2

CheckTW2:
if ("$rspellname" = "Tailwind") then goto CheckGF
if ("$pfspellname" = "Tailwind") then goto CheckGF
if ($autotw = 0) then goto CheckGF
if ($tmfoc = 1) then
{
    # if (%cao = 1) then goto CheckGF
    if ($autofoc = 1) then goto CheckGF
}
if ($twspelllosstimer >= $unixtime) then goto CheckGF
if ("$pfspellname" = "Fortress of Ice") then
{
    if (%skipfoi = 1) then
    {
        var relreturn CheckTW3
        var relpf 1
        goto RelSpell
    }
}
goto CheckTW3

CheckTW3:
if (%pfslot != 1) then goto TWPF
goto TWSC

TWPF:
put #var pfspell TW
put #var pfspellname Tailwind
var pf 1
var prep 1
goto $pfspell

TWSC:
put #var rspell TW
put #var rspellname Tailwind
var prep 1
goto $rspell

CheckGF:
if ($autogf = 0) then goto CheckMAFHit
if ($gfattempttimer >= $unixtime) then goto CheckMAFHit
if ("$rspellname" = "Grounding Field") then goto CheckMAFHit
if ("$pfspellname" = "Grounding Field") then goto CheckMAFHit
if ($cax = 1) then goto CheckGFFull
if ($pvpfull = 1) then goto CheckGFFull
if ($SpellTimer.GroundingField.duration >= 6) then goto CheckMAFHit
goto CheckGF2

CheckGFFull:
if ($SpellTimer.GroundingField.duration >= 20) then goto CheckMAFHit
goto CheckGF2

CheckGF2:
if ("$pfspellname" = "Fortress of Ice") then
{
    if (%skipfoi = 1) then
    {
        var relreturn CheckGF3
        var relpf 1
        goto RelSpell
    }
}
goto CheckGF3

CheckGF3:
if (%pfslot != 1) then goto GFPF
goto GFSC

GFPF:
put #var pfspell GF
put #var pfspellname Grounding Field
var pf 1
var prep 1
goto $pfspell

GFSC:
put #var rspell GF
put #var rspellname Grounding Field
var prep 1
goto $rspell

CheckMAFHit:
if ($mafhit < 3) then
{
    if ("$cscript" != ".seekanddestroy") then goto CheckREPRHit
}
if ($mafhit = 0) then goto CheckREPRHit
if ($mafcasttimer >= $unixtime) then goto CheckREPRHit
if ("$rspellname" = "Manifest Force") then goto CheckREPRHit
if ("$pfspellname" = "Manifest Force") then goto CheckREPRHit
if ($mafspelllosstimer >= $unixtime) then goto CheckREPRHit
if ("$pfspellname" = "Fortress of Ice") then
{
    if (%skipfoi = 1) then
    {
        var relreturn CheckMAFHit2
        var relpf 1
        goto RelSpell
    }
}
goto CheckMAFHit2

CheckMAFHit2:
if (%pfslot != 1) then goto MAFPF
goto MAFSC

CheckREPRHit:
if ($reprhit = 0) then goto CheckAEGSC
if ($noscrollrepr = 1) then goto CheckAEGSC
if ("$rspellname" = "Redeemer's Pride") then goto CheckAEGSC
if ("$pfspellname" = "Redeemer's Pride") then goto CheckAEGSC
if ($reprspelllosstimer >= $unixtime) then goto CheckAEGSC
if ("$pfspellname" = "Fortress of Ice") then
{
    if (%skipfoi = 1) then
    {
        var relreturn CheckREPRHit2
        var relpf 1
        goto RelSpell
    }
}
goto CheckREPRHit2

CheckREPRHit2:
if (%pfslot != 1) then goto REPRPF
goto REPRSC

CheckAEGSC:
if ($automof != 0) then goto CheckMOF
if ($rspell != 0) then goto CheckCV
if ($cax = 1) then goto CheckAEGSCFull
if ($pvpfull = 1) then goto CheckAEGSCFull
if ($SpellTimer.AegisofGranite.duration >= 6) then goto CheckCV
goto CheckAEGSC2

CheckAEGSCFull:
if ($SpellTimer.AegisofGranite.duration >= 20) then goto CheckCV
goto CheckAEGSC2

CheckAEGSC2:
if ($tmfoc = 1) then goto CheckCV
if ($kickonly = 1) then goto CheckCV
if ($headdamage = 1) then goto CheckCV
if ($pvptarget = 0) then goto AEGSC
if (%cao != 0) then
{
    if matchre ("$roomname" , "Ice Fortress") then
    {
        var targetvisible CheckCV
        var targetspoteffect CheckCV
        var targetnotvisible AEGSC
        goto CheckVisiblity
    }
    goto CheckCV
}
goto AEGSC

AEGSC:
put #var rspell AEG
put #var rspellname Aegis of Granite
var prep 1
goto $rspell

CheckMOF:
if ($rspell != 0) then goto CheckCV
if ($cax = 1) then goto CheckMOFFull
if ($pvpfull = 1) then goto CheckMOFFull
if ($SpellTimer.MantleofFlame.duration >= 6) then goto CheckCV
goto CheckMOF2

CheckMOFFull:
if ($SpellTimer.MantleofFlame.duration >= 20) then goto CheckCV
goto CheckMOF2

CheckMOF2:
if ($tmfoc = 1) then goto CheckCV
if ($kickonly = 1) then goto CheckCV
if ($headdamage = 1) then goto CheckCV
if ($pvptarget = 0) then goto MOFSC
if (%cao = 1) then
{
    if matchre ("$roomname" , "Ice Fortress") then
    {
        var targetvisible CheckCV
        var targetspoteffect CheckCV
        var targetnotvisible MOFSC
        goto CheckVisiblity
    }
    goto CheckCV
}
goto MOFSC

MOFSC:
put #var rspell MoF
put #var rspellname Mantle of Flame
var prep 1
goto $rspell

CheckCV:
if ($rspell != 0) then goto CheckVoI
# if ($cax = 1) then goto CheckCVFull
if ($pvpfull = 1) then goto CheckCVFull
if ($pvp = 0) then goto CheckVoI
if ($SpellTimer.ClearVision.duration >= 6) then goto CheckVoI
goto CheckCV2

CheckCVFull:
if ($SpellTimer.ClearVision.duration >= 20) then goto CheckVoI
goto CheckCV2

CheckCV2:
if ($norunecv = 1) then goto CheckVoI
if ($invisible = 1) then goto CheckVoI
if ($cvcastattempt >= $unixtime) then goto CheckVoI
if ($nosorcery != 0) then goto CheckVoI
if ($handdamaged = 1) then
{
    if ($tmfoc = 1) then goto CheckVoI
} 
if ($kickonly = 1) then goto CheckVoI
if ($headdamage = 1) then goto CheckVoI
if (%cao = 0) then goto CVSC
if ($pvptarget = 0) then goto CheckVoI
var targetvisible CheckVoI
var targetspoteffect CheckVoI
var targetnotvisible CVSC
goto CheckVisiblity

CVSC:
put #var rspell CV
put #var rspellname Clear Vision
var prep 1
goto $rspell

CheckVoI:
if ($autovoi = 0) then goto CheckYS
if ($acon = 1) then goto CheckYS
if ("$rspellname" = "Veil of Ice") then goto CheckYS
if ("$pfspellname" = "Veil of Ice") then goto CheckYS
if ($voicasttimer >= $unixtime) then goto CheckYS
if ($cax = 1) then goto CheckVoIFull
if ($pvpfull = 1) then goto CheckVoIFull
if ($SpellTimer.VeilofIce.duration >= 6) then goto CheckYS
goto CheckVoI2

CheckVoIFull:
if ($SpellTimer.VeilofIce.duration >= 20) then goto CheckYS
goto CheckVoI2

CheckVoI2:
if ($pvp = 0) then
{
    if ($pvpfull != 1) then goto CheckYS
}
if ($voispelllosstimer >= $unixtime) then goto CheckYS
if ("$pfspellname" = "Fortress of Ice") then
{
    if (%skipfoi = 1) then
    {
        var relreturn CheckVoI3
        var relpf 1
        goto RelSpell
    }
}
goto CheckVoI3

CheckVoI3:
if (%pfslot != 1) then goto VOIPF
goto VOISC

VOIPF:
put #var pfspell VOI
put #var pfspellname Veil of Ice
var pf 1
var prep 1
goto $pfspell

VOISC:
put #var rspell VOI
put #var rspellname Veil of Ice
var prep 1
goto $rspell

CheckYS:
if ($autoys = 0) then goto CheckGG2
if ("$rspellname" = "Y'ntrel Sechra") then goto CheckGG2
if ("$pfspellname" = "Y'ntrel Sechra") then goto CheckGG2
if ($yscasttimer >= $unixtime) then goto CheckGG2
if ($cax = 1) then goto CheckYSFull
if ($pvpfull = 1) then goto CheckYSFull
if ($SpellTimer.YntrelSechra.duration >= 6) then goto CheckGG2
goto CheckYS2

CheckYSFull:
if ($SpellTimer.YntrelSechra.duration >= 20) then goto CheckGG2
goto CheckYS2

CheckYS2:
if ($pvp = 0) then
{
    if ($pvpfull != 1) then goto CheckGG2
}
if ($ysspelllosstimer >= $unixtime) then goto CheckGG2
if ("$pfspellname" = "Fortress of Ice") then
{
    if (%skipfoi = 1) then
    {
        var relreturn CheckYS3
        var relpf 1
        goto RelSpell
    }
}
goto CheckYS3

CheckYS3:
if (%pfslot != 1) then goto YSPF
goto YSSC

YSPF:
put #var pfspell YS
put #var pfspellname Y'ntrel Sechra
var pf 1
var prep 1
goto $pfspell

YSSC:
put #var rspell YS
put #var rspellname Y'ntrel Sechra
var prep 1
goto $rspell

CheckGG2:
if ($rspell != 0) then goto CheckTranq
if ($pvp = 0) then
{
    if ($pvpfull = 0) then goto CheckTranq
}
if ($ggcasttimer >= $unixtime) then goto CheckTranq
if ($pvpfull = 1) then goto CheckGG2Full
if ($cax = 1) then goto CheckGG2Full
if ($SpellTimer.GlythtidesGift.duration >= 6) then goto CheckTranq
goto CheckGG22

CheckGG2Full:
if ($SpellTimer.GlythtidesGift.duration >= 20) then goto CheckTranq
goto CheckGG22

CheckGG22:
if ($norunegg = 1) then goto CheckTranq
if ($invisible = 1) then goto CheckTranq
if ($nosorcery != 0) then goto CheckTranq
if ($handdamaged = 1) then goto CheckTranq
{
    if ($tmfoc = 1) then goto CheckTranq
}
if ($kickonly = 1) then goto CheckTranq
if ($headdamage = 1) then goto CheckTranq
goto GGSC

CheckTranq:
# goto CheckIG
if ($rspell != 0) then goto CheckIG
if ($tranqcasttimer >= $unixtime) then goto CheckIG
if ($pvpfull = 1) then goto CheckTranqFull
if ($pvp = 0) then goto CheckIG
if ($cax = 1) then goto CheckTranqFull
if ($SpellTimer.Tranquility.duration >= 6) then goto CheckIG
goto CheckTranq2

CheckTranqFull:
if ($SpellTimer.Tranquility.duration >= 20) then goto CheckIG
goto CheckTranq2

CheckTranq2:
if ($invisible = 1) then goto CheckIG
if ($nosorcery != 0) then goto CheckIG
if ($handdamaged = 1) then
{
    if ($tmfoc = 1) then goto CheckIG
}
if ($kickonly = 1) then goto CheckIG
if ($headdamage = 1) then goto CheckIG
if ($pvptarget = 0) then goto TranqSC
if (%cao = 0) then goto TranqSC
var targetvisible CheckIG
var targetspoteffect CheckIG
var targetnotvisible CheckTranq3
goto CheckVisiblity

CheckTranq3:
if matchre ("$roomname" , "Ice Fortress") then goto TranqSC
if ($mana >= 90) then goto TranqSC
goto CheckIG

TranqSC:
put #var rspell Tranq
put #var rspellname Tranquility
var prep 1
goto $rspell

CheckIG:
if ($rspell != 0) then goto CheckBG
if ($tmfoc = 1) then goto CheckBG
if ($autofoc = 1) then goto CheckBG
if ($autoig = 0) then goto CheckBG
if ($pvptarget != 0) then
{
    if (%cao = 1) then goto CheckIgVis
}
goto CheckIG1

CheckIgVis:
var targetvisible CheckBG
var targetspoteffect CheckBG
var targetnotvisible CheckIG1
goto CheckVisiblity

CheckIG1:
if ($cax = 1) then goto CheckIGFull
if ($pvpfull = 1) then goto CheckIGFull
if ($SpellTimer.Ignite.active = 1) then goto CheckBG
goto CheckIG2

CheckIGFull:
if ($SpellTimer.Ignite.duration >= 10) then goto CheckBG
goto CheckIG2

CheckIgniteWeapon:
# if ($boosttimer > $unixtime) then
# {
#     if ($ignitegs = 1) then goto CheckBG
# }
# if ($pvp = 0) then
# {
#     if ($pvpfull = 0) then
#     {
#         if ($ignitegs = 1) then goto CheckBG
#     }
# }
# if ($pvp = 1) then
# {
#     if ($ignitegs = 0) then goto CheckBG
# }
# if ($pvpfull = 1) then
# {
#     if ($ignitegs = 0) then goto CheckBG
# }
goto CheckIG2

CheckIG2:
if ($kickonly = 1) then goto CheckBG
if ($igspelllosstimer >= $unixtime) then goto CheckBG
if ($fireoff = 1) then goto CheckBG
if ($pvptarget = 0) then goto IGSC
if (%cao = 0) then goto IGSC
var targetvisible CheckBG
var targetspoteffect CheckBG
var targetnotvisible IGSC
goto CheckVisiblity

IGSC:
put #var rspell IG
put #var rspellname Ignite
var prep 1
goto $rspell

CheckBG:
if ($rspell != 0) then goto CheckRIM
if ($calmed = 1) then goto CheckRIM
if ($acon != 0) then
{
    if (%cao != 0) then goto CheckRIM
}
if matchre ("$roomname" , "Ice Fortress") then
{
    if ($pvptarget = 0) then goto CheckBG3
    var targetvisible CheckBG2
    var targetspoteffect CheckBG2
    var targetnotvisible CheckBG3
    goto CheckVisiblity
}
goto CheckBG2

CheckBG2:
if ("$pfspell" = "AC") then goto CheckRIM
goto CheckBG3

CheckBG3:
if ($peaceroom = 1) then goto CheckRIM
if ($notm = 1) then goto CheckRIM
if ($iceoff = 1) then goto CheckRIM
if ($autobg = 0) then goto CheckRIM
if ($bgattempttimer > $unixtime) then goto CheckRIM
if ($cax = 1) then goto CheckBGFull
if ($pvpfull = 1) then goto CheckBGFull
if ("$cscript" = ".seekanddestroy") then goto CheckBGFull
# if ($SpellTimer.BlufmorGaraen.active = 1) then goto CheckRIM
if ($SpellTimer.BlufmorGaraen.active = 1) then
{
    if (%cao = 1) then goto CheckRIM
    if ($bgattacks = 0) then goto CheckRIM
}
goto BGSC

CheckBGFull:
# if ($SpellTimer.BlufmorGaraen.duration >= 5) then goto CheckRIM
if ($SpellTimer.BlufmorGaraen.duration >= 5) then
{
    if ($bgattacks = 0) then goto CheckRIM 
}
goto BGSC

BGSC:
put #var rspell BG
put #var rspellname Blufmor Garaen
var prep 1
goto $rspell

CheckRIM:
if ($autoac = 1) then goto CheckSecondAC
if ($rspell != 0) then goto CheckSecondAC
# If in combat skip rim for main cyclic if not RIME.
if ($combatloop != 0) then
{
    if ($autorim = 0) then goto CheckSecondAC   
}
if ($cyclicoff = 1) then goto CheckSecondAC
if ($cyclicinitiated >= $unixtime) then goto CheckSecondAC
if ($autoee = 1) then
{
    if ($eeon = 1) then goto CheckSecondAC
}
if ($autoac = 1) then
{
    if ($acon = 1) then goto CheckSecondAC
}
if ($autofr = 1) then
{
    if ($fron = 1) then goto CheckSecondAC
}
if ($rimon = 1) then goto CheckSecondAC
if ($calmed = 1) then goto CheckSecondAC
if ($peaceroom = 1) then goto CheckSecondAC
if ($autorim = 0) then goto RIMTemp
goto RIMSC

RIMSC:
put #var autoee 0
put #var autorim 1
put #var autofr 0
put #var autoac 0
put #var rspell RIM
put #var rspellname Rimefang
var prep 1
goto $rspell

RIMTemp:
put #var rspell RIM
put #var rspellname Rimefang
var prep 1
goto $rspell

CheckSecondAC:
# Logic for skipping AC until BG and DB are up when building auras
if (%cao != 0) then goto CheckSecondAC1
if ($notm != 0) then goto CheckSecondAC1
if ($peaceroom != 1) then goto CheckSecondAC1
if ($autodb != 1) then goto CheckACBG
if ($cax != 1) then
{
    if ($pvpfull != 1) then
    {
        if ($SpellTimer.DragonsBreath.active != 1) then goto CheckWill
    }
     goto CheckACBG
}
if ($SpellTimer.DragonsBreath.duration < 20) then goto CheckWill
goto CheckACBG

CheckACBG:
if ($autobg != 1) then goto CheckSecondAC1
if ($cax != 1) then
{
    if ($pvpfull != 1) then
    {
        if ($bgready != 0) then goto CheckWill
    }
    goto CheckSecondAC1
}
if ($SpellTimer.BlufmorGaraen.duration < 5) then goto CheckWill
if ($bgattacks != 0) then goto CheckWill
goto CheckSecondAC1

CheckSecondAC1:
# if ($acon = 1) then goto CheckWill
if ($dbtimer >= $unixtime) then goto CheckWill
if ($autoac = 0) then goto CheckWill
if ($acon != 0) then
{
    if ($notm = 1) then goto CheckWill
}
if matchre ("$rspellname" , "Aether Cloak|Dragon's Breath|Blufmor Garaen") then goto CheckWill
if ("$pfspellname" = "Aether Cloak") then goto CheckWill
if ($cyclicinitiated >= $unixtime) then goto CheckWill
goto CheckSecondAC2

CheckSecondAC2:
if (%cao = 0) then goto CheckSecondAC3
if ($pvptarget = 0) then goto CheckSecondAC3
var targetvisible CheckSecondAC3
var targetspoteffect CheckSecondAC3
var targetnotvisible InvisSecondAC
goto CheckVisiblity

InvisSecondAC:
if ($autofoi != 0) then goto CheckWill
if ($autodb != 0) then
{
    if ("$rspellname" = "Dragon's Breath") then goto CheckSecondAC3
    if ($SpellTimer.DragonsBreath.active = 0) then goto CheckSecondAC3
}
if ($autobg != 0) then
{
    if ("$rspellname" = "Blufmor Garaen") then goto CheckSecondAC3
    if ($SpellTimer.BlufmorGaraen.active = 0) then goto CheckSecondAC3
}
goto CheckWill

CheckSecondAC3:
if ("$pfspellname" = "Fortress of Ice") then
{
    if (%skipfoi = 1) then
    {
        var relreturn ACPF
        var relpf 1
        goto RelSpell
    }
}
if (%pfslot != 1) then goto ACPF
if ($acon != 0) then goto CheckWill
goto ACSC

CheckWill:
if ($pvptarget = 0) then goto CheckAwakenLate
if ($autowill = 0) then goto CheckAwakenLate
if ($invisible = 1) then goto CheckAwakenLate
if ($unixtime <= $willtimer) then goto CheckAwakenLate
if ($SpellTimer.WillofWinter.active = 1) then goto CheckAwakenLate
if ($wandsoff = 1) then goto CheckAwakenLate
if ($handdamaged = 1) then
{
    if ($tmfoc = 1) then goto CheckAwakenLate
}
if ($kickonly = 1) then goto CheckAwakenLate
if ($headdamage = 1) then goto CheckAwakenLate
put .willw
exit

CheckAwakenLate:
if (%cao = 1) then goto CheckDispel
if ($awakencasttimer >= $unixtime) then goto CheckDispel
if ($pvpfull = 0) then goto CheckDispel
var aurareturn LateAwakenAnalysis
goto AuraCheck

LateAwakenAnalysis:
if ("%nextspell" != "Awaken") then goto CheckDispel
if ($SpellTimer.Awaken.duration >= 7) then goto CheckDispel
if ("$rspellname" = "Awaken") then goto CheckDispel
if ("$pfspellname" = "Awaken") then goto CheckDispel
if ($noscrollawaken = 1) then goto CheckDispel
if ($nosorcery != 0) then goto CheckDispel
if ($awakenspelllosstimer >= $unixtime) then goto CheckDispel
if ("$pfspellname" = "Fortress of Ice") then
{
    if (%skipfoi = 1) then
    {
        var relreturn CheckAwakenFull3
        var relpf 1
        goto RelSpell
    }
}
goto CheckAwakenFull3

CheckAwakenFull3:
if (%pfslot != 1) then goto AwakenPF
goto AwakenSC

CheckDispel:
if ($rspell != 0) then goto CheckFOI
if ($autodispel = 0) then goto CheckFOI
# if ($dispelspelllosstimer >= $unixtime) then goto CheckFOI
if ($kickonly = 1) then goto CheckFOI
if ($norunedispel = 1) then goto CheckFOI
if ($headdamage = 1) then goto CheckFOI
if ($SpellTimer.Beshrew.active = 1) then goto DispelSC
if ($SpellTimer.Compel.active = 1) then goto DispelSC
if ($SpellTimer.Calm.active = 1) then goto DispelSC
if ($SpellTimer.CurseoftheWilds.active = 1) then goto DispelSC
if ($SpellTimer.Devolve.active = 1) then goto DispelSC
if ($SpellTimer.HarawepsBonds.active = 1) then goto DispelSC
if ($SpellTimer.HeightenPain.active = 1) then goto DispelSC
if ($SpellTimer.Lethargy.active = 1) then goto DispelSC
if ($SpellTimer.Malediction.active = 1) then goto DispelSC
if ($SpellTimer.Shatter.active = 1) then goto DispelSC
if ($SpellTimer.SidhlotsFlaying.active = 1) then goto DispelSC
if ($SpellTimer.SoulBonding.active = 1) then goto DispelSC
if ($SpellTimer.Vertigo.active = 1) then goto DispelSC
if ($SpellTimer.VisionsofDarkness.active = 1) then goto DispelSC
if ($SpellTimer.Vertigo.active = 1) then goto DispelSC
if ($SpellTimer.Tingle.active = 1) then goto DispelSC
if ($SpellTimer.CurseofZachriedek.active = 1) then goto DispelSC
if ($SpellTimer.DamarisLullaby.active = 1) then goto DispelSC
if ($SpellTimer.AetherWolves.active = 1) then goto DispelSC
if ($SpellTimer.Frostbite.active = 1) then goto DispelSC
goto CheckFOI

DispelSC:
put #var rspell Dispel
put #var rspellname Dispel
var prep 1
goto $rspell

CheckFOI:
if (%cao = 0) then
{
    if ($pvpfull = 0) then goto AuraCombatCheck
}
if (%cao = 0) then goto CheckFOILastSpell
goto CombatFOICheck

CombatFOICheck:
if ($pvptarget = 0) then goto AuraCombatCheck
goto CheckFOILastSpell

CheckFOILastSpell:
if (%cao = 0) then 
{
    if ($rspell != 0) then goto AuraCombatCheck
}
if (%pfslot = 1) then goto AuraCombatCheck
if (%parallelfocusoff = 1) then goto AuraCombatCheck
if ($autofoi = 0) then goto AuraCombatCheck
if ("$pfspellname" = "Fortress of Ice") then goto AuraCombatCheck
if ($inside = 1) then goto AuraCombatCheck
if ($peaceroom = 1) then goto AuraCombatCheck
if matchre ("$roomname" , "^Wyvern Arena") then goto AuraCombatCheck
if matchre ("$roomexits" , "^Obvious exits") then goto AuraCombatCheck
if ("$rspellname" = "Fortress of Ice") then goto AuraCombatCheck
if matchre ("$roomname" , "Ice Fortress") then
{
    if ("$cscript" != ".seekanddestroy") then goto AuraCombatCheck
}
# if (%cao = 1) then goto PFFoISC
# Reset AuraCheckVars since we're casting spells back to back
# var requiresmainslot 0
# var morespells 0
# var nextspell 0
# var maf 0
# var repr 0
# if ($pfoff = 1) then var requiresmainslot 1
# if ($handdamaged = 1) then var requiresmainslot 1
# if ($kickonly = 1) then var requiresmainslot 1
# if ($webbed = 1) then var requiresmainslot 1
var aurareturn FOIAuraAnalysis
goto AuraCheck

FOIAuraAnalysis:
if ("%nextspell" != "Fortress of Ice") then goto AuraCombatCheck
goto PFFoISC

AuraCombatCheck:
if (%cao = 1) then
{
    if ($pvptarget = 0) then
    {
        if ($rspell = 0) then goto PvECyclicCheck
        goto PhysicalExit
    }
}
if (%cao = 1) then 
{
    if (%mainslotchecked = 1) then goto FullyBuffedVisCheck
    # {
    #     if ("$cscript" = ".seekanddestroy") then goto FullyBuffedVisCheck
    #     goto FullyBuffedVisCheck
    # }
    var mainslotchecked 1
    goto CheckPFSlot
}
if (%cao != 1) then
{
    if (%mainslotchecked = 1) then goto EndAuraSpellWait
}
var mainslotchecked 1
goto CheckPFSlot

FullyBuffedVisCheck:
# All buffs are applied.
# PvP Attack spells for visible opponents are applied.
# If not PvP, spam attack spells
# If PvP, spam invis spells
if ($rspell != 0) then goto PrepWait
if ("$cscript" = ".seekanddestroy") then goto SnDPFCheck
goto FullyBuffedVisCheck2

SnDPFCheck:
if ("$pfspellname" = "Fortress of Ice") then goto FullyBuffedVisCheck2
if ($acon = 1) then
{
    if ("$pfspellname" = "Aether Cloak") then goto FullyBuffedVisCheck2
}
if (%parallelfocusoff = 1) then goto FullyBuffedVisCheck2
if ($pfspell != 0) then goto PrepWait
goto FullyBuffedVisCheck2

FullyBuffedVisCheck2:
if ($pvptarget = 0) then goto PvECyclicCheck
var targetvisible PhysicalExit
var targetspoteffect PhysicalExit
var targetnotvisible PvPInvisMagic
goto CheckVisiblity

PvECyclicCheck:
if ($cyclicoff = 1) then goto CheckTM
if ($cyclicinitiated >= $unixtime) then goto CheckTM
if ("$pfspell" = "AC") then goto CheckTM
if ($autoee = 1) then goto EECheckFortCheck
goto PvECyclicCheck2

EECheckFortCheck:
if ($pvptarget = 0) then goto PvECyclicCheck2
if ($fortdebil = 1) then goto PvECyclicCheck2
if ($groupbattle = 1) then goto PvECyclicCheck2
put #var autoee 0
goto PvECyclicCheck2

PvECyclicCheck2:
if ($autoee = 1) then
{
    if ($eeon = 1) then goto CheckTM
}
if ($autoac = 1) then
{
    if ($acon = 1) then goto CheckTM
}
if ($autofr = 1) then
{
    if ($fron = 1) then goto CheckTM
}
if ($autorim = 1) then
{
    if ($rimon = 1) then goto CheckTM
}
var cyclicreturn CheckTM
goto SelectCyclic

EndAuraSpellWait:
if ($pvpfull = 1) then goto AuraTMFocCheck
goto EndAuraSpellWait2

AuraTMFocCheck:
if ($tmfoc = 1) then goto EndAuraSpellWait2
if ($autoac = 1) then goto EndAuraSpellWait2
if ($acon = 1) then goto EndAuraSpellWait2
if ($nomagic = 1) then goto EndAuraSpellWait2
if ($notm = 1) then goto EndAuraSpellWait2
if ($pvptarget = 0) then goto EndAuraSpellWait2
if ($autofoc = 2) then goto EndAuraSpellWait2
put .foca m
exit

EndAuraSpellWait2:
if ($rspell != 0) then goto PrepWait
if ($pvpfull = 1) then goto CheckLastFoI
if ($cax = 1) then goto CheckLastFoI
goto AuraAnalysis2

CheckLastFoI:
var requiresmainslot 0
var morespells 0
var nextspell 0
# var maf 0
# var repr 0
if ($pfoff = 1) then var requiresmainslot 1
if ($handdamaged = 1) then var requiresmainslot 1
if ($kickonly = 1) then var requiresmainslot 1
if ($webbed = 1) then var requiresmainslot 1
var wandreturn CheckLastAura
goto WandCheck

CheckLastAura:
var aurareturn AuraAnalysis
goto AuraCheck

AuraAnalysis:
if (%nextspell = 0) then goto EndAura
echo
echo **** Next Spell = %nextspell
goto AuraAnalysis2

AuraAnalysis2:
# if ($rspell != 0) then goto PrepWait
# if ("$pfspellname" != "Fortress of Ice") then
# {
#     if ($pfspell != 0) then goto PrepWait
# }
# if ("%nextspell" = "Fortress of Ice") then
# {
#     if ("$pfspellname" = "Fortress of Ice") then goto EndAura
# }
# echo
# echo **** Error at AuraAnalysis2
# echo **** Next Spell = %nextspell
# if (%cao = 0) then
# {
#     pause 5
#     goto CheckSpellStatus
# }
# exit
if (%nextspell = 0) then goto EndAura
# if (%nextspell != "Fortress of Ice") then
# {
#     if ($rspell = 0) then
#     {
#         if ($pfspell = 0) then goto CheckSpellStatus
#     }
# }
goto PrepWait

EndAura:
var auraready 1
if ($peaceroom != 0) then put #var peaceroom 0
var endauramessage 1
goto MagicExit

# ---------------------------------------------

WandCheck:
# Don't check wands if we have already, if we're only casting single spells.
if (%cao = 0) then
{
    if ($cax = 0) then
    {
        if ($pvpfull = 0) then goto %wandreturn
    }
}
if ($wandsoff = 1) then goto %wandreturn
if ($wandtimer > $unixtime) then goto %wandreturn
if ($invisible = 1) then goto %wandreturn
if ($headdamage = 1) then goto %wandreturn
if ($SpellTimer.MentalFocus.duration < 3) then
{
    if ($unixtime > $bothmeftimer) then
    {
        put .mef
        exit
    }
}
if ($unixtime > $bothragetimer) then
{
    if ($SpellTimer.RageoftheClans.duration < 3) then
    {
        put .rage
        exit
    }
}
if ($unixtime > $bothfintimer) then
{
    if ($SpellTimer.Finesse.duration < 3) then
    {
        put .fin
        exit
    }
}
if ($unixtime > $bothrwtimer) then
{
    if ($SpellTimer.RighteousWrath.duration < 3) then
    {
        put .rwt
        exit
    }
}
put #var wandtimer #evalmath ($unixtime + 120)
goto %wandreturn

CheckTMFoc:
if ($pvptarget = 0) then goto CheckPvPFoIPrep
if ($acon = 1) then goto CheckPvPFoIPrep
if ($autoac = 1) then goto CheckPvPFoIPrep
if ($pvpfull = 0) then goto CheckPvPFoIPrep
if ($tmfoc = 1) then goto CheckPvPFoIPrep
if ($notm = 1) then goto CheckPvPFoIPrep
if ($autofoc = 2) then goto CheckPvPFoIPrep
put .foca m
exit

PvPInvisMagic:
if ($bo = 1) then goto PhysicalExit
if ($calmed = 1) then goto PhysicalExit
if ($cyclicoff = 1) then goto InvisBGCheck2
if ($invisible = 1) then
{
    if !matchre ("$roomname" , "Ice Fortress") then goto InvisIPCheck
}
if ($cyclicinitiated >= $unixtime) then goto InvisBGCheck2
if ($autoee = 1) then
{
    if ($eeon = 1) then goto CheckAoECyclic
}
if ($autoac = 1) then
{
    if ($acon = 1) then goto InvisBGCheck2
}
if ($autoac = 1) then
{
    # if ($dbtimer >= $unixtime) then
    # {
        if ($eeon = 1) then goto InvisBGCheck2
        if ($rimon = 1) then goto InvisBGCheck2
        if ($fron = 1) then goto InvisBGCheck2
    # }
}

if ($autofr = 1) then
{
    if ($fron = 1) then goto CheckAoECyclic
}
if ($autorim = 1) then
{
    if ($rimon = 1) then goto InvisBGCheck2
}
if ($autofr = 1) then goto InvisFRAnalysis
var cyclicreturn InvisBGCheck2
goto SelectCyclic

CheckAoECyclic:
if ($pvpdummy != 0) then goto InvisBGCheck2
if ($aoearea = 1) then
{
    if ($aoecyclic = 1) then goto InvisBGCheck2
}
if ($aoearea = 0) then
{
    if ($aoecyclic = 0) then goto InvisBGCheck2
}
var cyclicreturn InvisBGCheck2
goto SelectCyclic

InvisFRAnalysis:
if ($rimon = 1) then goto InvisBGCheck2
if ($eeon = 1) then goto InvisBGCheck2
if ($cyclicinitiated >= $unixtime) then goto InvisBGCheck2
if ($pvpjustice = 1) then goto InvisFRAnalysis2
if ($elecoff = 1) then goto InvisFRAnalysis2
if ($fortdebil = 0) then goto InvisFRAnalysis2
goto EECyclicTemp

InvisFRAnalysis2:
if ($notm = 1) then goto InvisBGCheck2
if ($iceoff = 1) then goto InvisBGCheck2
goto RIMCyclicTemp

EECyclicTemp:
put #var rspell EE
put #var rspellname Electrostatic Eddy
var prep 1
goto $rspell

RIMCyclicTemp:
put #var rspell RIM
put #var rspellname Rimefang
var prep 1
goto $rspell

InvisBGCheck2:
if ("$cscript" != ".seekanddestroy") then
{
    if ($magicdefense != 1) then goto InvisTremCheck
}
if ($autobg != 1) then goto InvisTremCheck
# if ($SpellTimer.BlufmorGaraen.duration > 4) then goto InvisTremCheck
if ($SpellTimer.BlufmorGaraen.duration > 4) then
{
    if ($bgattacks < 3) then goto InvisTremCheck
}
if ($bgattempttimer > $unixtime) then goto InvisTremCheck
# if ($acon = 1) then goto InvisTremCheck
if !matchre ("$roomname" , "Ice Fortress") then
{
    if ($acon = 1) then
    {
        if ("$pfspell" != "AC") then goto InvisTremCheck
    }
}
# if ("$pfspell" = "AC") then goto InvisTremCheck
if ($notm = 1) then goto InvisTremCheck
goto BGSC

InvisTremCheck:
# After cyclic, use Tremor and setup MAB, then prep hard CC.
# Separates hunt from ambush. If I'm hunting, go to hard cc or TM; otherwise check Trem and Mab.
if ("$cscript" = ".seekanddestroy") then goto InvisBGCheck3
if ($pvpjustice = 1) then goto InvisBGCheck3
if ($inside = 1) then goto InvisBGCheck3
if ($refdebil = 0) then goto InvisBGCheck3
if ($autotrem = 0) then goto InvisBGCheck3
if ($tremtimer > $unixtime) then goto InvisBGCheck3
if ($tremspelllosstimer >= $unixtime) then goto InvisBGCheck3
goto Tremor

InvisBGCheck3:
if ("$cscript" = ".seekanddestroy") then goto InvisHardCCorTM
if ($autobg != 1) then goto InvisHardCCorTM
# if ($SpellTimer.BlufmorGaraen.duration > 4) then goto InvisHardCCorTM
if ($SpellTimer.BlufmorGaraen.duration > 4) then
{
    if ($bgattacks < 3) then goto InvisHardCCorTM
}
if ($bgattempttimer > $unixtime) then goto InvisHardCCorTM
# if ($acon = 1) then goto InvisHardCCorTM
if !matchre ("$roomname" , "Ice Fortress") then
{
    if ($acon = 1) then
    {
        if ("$pfspell" != "AC") then goto InvisHardCCorTM
    }
}
# if ("$pfspell" = "AC") then goto InvisHardCCorTM
if ($notm = 1) then goto InvisHardCCorTM
goto BGSC

InvisHardCCorTM:
if matchre ("$roomname" , "Ice Fortress") then
{
    if ("$cscript" != ".seekanddestroy") then goto FoISC
}
if ($wormsmist = 1) then goto InvisLPTremCheck
if ($shear = 1) then goto InvisLPTremCheck
if ($unixtime < $hardccattempttimer) then goto InvisLPTremCheck
if ($unixtime < $hardccduration) then goto InvisLPTremCheck
if ($hardccused > 1) then goto InvisLPTremCheck
# if ("$cscript" != ".seekanddestroy") then
# {
#     if ($hardccused > 1) then
#     {
#         if ($tmfoc = 1) then goto InvisLPTremCheck
#     }
# }
goto InvisIPCheck

InvisIPCheck:
if ($refdebil = 0) then goto InvisALCheck
# if ($thief = 1) then goto InvisBarbShockwave
if ($autoip = 0) then goto InvisALCheck
# if ($iceoff = 1) then goto MainALCheck
if ($ipspelllosstimer >= $unixtime) then goto InvisALCheck
goto IPHCC

InvisALCheck:
if ($fortdebil = 0) then goto InvisLPTremCheck
if ($alsoftcc = 1) then goto InvisLPTremCheck
if ($autoal != 1) then goto InvisLPTremCheck
if ($alspelllosstimer >= $unixtime) then goto InvisLPTremCheck
goto ALHCC

# InvisMabCheck:
# if ("$cscript" = ".seekanddestroy") then goto InvisVertigoCheck
# # Skip for guilds that using pulsing invis.
# if ($thief = 1) then goto InvisVertigoCheck
# if ($ranger = 1) then goto InvisVertigoCheck
# # if ($necro = 1) then goto InvisVertigoCheck
# if ($redeemed = 1) then goto InvisVertigoCheck
# if ($moonmage = 1) then goto InvisVertigoCheck
# if ($invisible = 1) then goto InvisVertigoCheck
# if ($ballista != 0) then
# {
#     if !matchre ("$roomobjs" , "sleek onyx ballista set with banded silvery mechanisms|stuff\.$") then
#     {
#         put #var ballista 0
#         put #class ballista off
#     }
# }
# if ($ballista = 1) then goto InvisVertigoCheck
# if ($automab = 0) then goto InvisVertigoCheck
# if ($notm = 1) then goto InvisVertigoCheck
# goto MABSC

InvisLPTremCheck:
if ($refdebil = 0) then goto InvisBarbShockwave
if ($inside = 1) then goto InvisBarbShockwave
if ($pvpjustice = 1) then goto InvisBarbShockwave
if ($autotrem = 0) then goto InvisBarbShockwave
if ($tremtimer > $unixtime) then goto InvisBarbShockwave
if ($tremspelllosstimer >= $unixtime) then goto InvisBarbShockwave
goto Tremor

InvisBarbShockwave:
if ($barb != 1) then goto InvisTingleCheck
if ($tmfoc != 1) then goto InvisTingleCheck
if ($pvpjustice = 1) then goto InvisTingleCheck
if ($notm = 1) then goto InvisTingleCheck
if ("$pfspell" = "AC") then goto InvisTingleCheck
if ($acon = 1) then goto InvisTingleCheck
if ($shockwavespelllosstimer < $unixtime) then
{
    if ($autoshw = 1) then goto ShockwaveSC
    if ($aoeshockwave = 1) then goto ShockwaveSC
    if ($elecoff = 1) then goto ShockwaveSC
}
goto InvisTingleCheck

InvisTingleCheck:
if ($fortdebil != 1) then goto InvisVertigoCheck
if ($tinglehex >= $unixtime) then goto InvisVertigoCheck
if ($autotingle = 0) then goto InvisVertigoCheck
if ($tinglespelllosstimer >= $unixtime) then goto InvisVertigoCheck
if ($shear = 1) then
{
    if ($pvpjustice != 1) then goto InvisVertigoCheck
}
if ($wormsmist = 1) then
{
    if ($pvpjustice != 1) then goto InvisVertigoCheck
}
goto TingleSC

InvisVertigoCheck:
if ($minddebil = 0) then goto InvisALCheck2
if ($verhex > $unixtime) then goto InvisALCheck2
if ($shear = 1) then
{
    if ($pvpjustice != 1) then goto InvisALCheck2
}
if ($wormsmist = 1) then
{
    if ($pvpjustice != 1) then goto InvisALCheck2
}
if ($autovertigo = 0) then goto InvisALCheck2
if ($vertigospelllosstimer >= $unixtime) then goto InvisALCheck2
goto Vertigo

InvisALCheck2:
if ($fortdebil = 0) then goto InvisAttackCheck
if ($refdebil != 0) then goto InvisAttackCheck
if ($wormsmist = 1) then goto InvisAttackCheck
if ($shear = 1) then goto InvisAttackCheck
if ($unixtime < $hardccattempttimer) then goto InvisAttackCheck
if ($unixtime < $hardccduration) then goto InvisAttackCheck
if ("$cscript" != ".seekanddestroy") then
{
    if ($hardccused > 1) then
    {
        if ($tmfoc = 1) then goto InvisAttackCheck
    }
}
if ($alspelllosstimer >= $unixtime) then goto InvisAttackCheck
goto ALHCC

InvisAttackCheck:
if ($pvpjustice = 1) then goto InvisFrbCheck
if ($notm = 1) then goto InvisFrbCheck
if ("$pfspell" = "AC") then goto InvisFrbCheck
if ($acon = 1) then goto InvisFrbCheck
if ($shockwavespelllosstimer < $unixtime) then
{
    if ($autoshw = 1) then goto ShockwaveSC
    if ($aoeshockwave = 1) then goto ShockwaveSC
    if ($elecoff = 1) then goto ShockwaveSC
}
put #var rspell CL
put #var rspellname Chain Lightning
var prep 1
goto $rspell

ShockwaveSC:
put #var rspell SHW
put #var rspellname Shockwave
var prep 1
goto $rspell

InvisFrbCheck:
if ($fortdebil = 0) then goto InvisFinalHardCC
if ($pvpjustice = 1) then goto InvisFinalHardCC
if ($iceoff = 1) then goto InvisFinalHardCC
if ($frostbitespelllosstimer >= $unixtime) then goto InvisFinalHardCC
goto FrostBiteSC

InvisFinalHardCC:
if ($refdebil = 0) then goto InvisFinalALCheck
if ($autoip = 0) then goto InvisFinalALCheck
if ($ipspelllosstimer >= $unixtime) then goto InvisFinalALCheck
goto IPHCC

InvisFinalALCheck:
if ($autoal != 1) then goto InvisSpellBackstop
if ($shear = 1) then goto InvisSpellBackstop
if ($wormsmist = 1) then goto InvisSpellBackstop
if ($alspelllosstimer >= $unixtime) then goto InvisSpellBackstop
goto ALHCC
# if ($fortdebil = 1) then
# {
#     if ($elecoff != 1) then
#     {
#         if ($alspelllosstimer < $unixtime) then goto ALHCC
#     }
# }
# if ($minddebil = 1) then
# {
#     if ($verhex < $unixtime) then
#     {
#         if ($vertigospelllosstimer < $unixtime) then goto Vertigo
#     }
# }
InvisSpellBackstop:
echo
echo **** Many Spells Stolen! ****
goto PhysicalExit

# Prioritizes Hard CC, starting with assessing whether it's necessary to use BG to break magic wards.

PvPAttackSpells:

# Check BG for magic resistance
if ($calmed = 1) then goto AttackSpellBackstop
if ($bo = 1) then goto AttackSpellBackstop
if ($magicdefense != 1) then
{
    if ($elision != 1) then goto HardCCCheck
}
if ($bgready = 1) then goto HardCCCheck
if ($acon = 1) then
{
    if ("$pfspellname" != "Aether Cloak") then goto HardCCCheck
}
if ($notm = 1) then goto HardCCCheck
if ($autobg != 1) then goto HardCCCheck
if ($bgattempttimer > $unixtime) then goto HardCCCheck
goto BGSC

HardCCCheck:
if ($unixtime < $hardccattempttimer) then goto HPTremCheck
if ($pvpdummy != 0) then 
{
    if ($hardccduration >= $unixtime) then goto HPTremCheck
}
var debiledreturn HPTremCheck
var notdebiledreturn HardCCCheck12
goto OpponentDebiledCheck

# if ($pvpdummy != 0) then goto HardCCDummyPos
# goto HardCCCheck1

# HardCCDummyPos:
# if matchre ("$pvptarget" , "\w+ \w+") then goto HardCCDummyPos2
# var newpvpdummy $pvptarget
# goto HardCCDummyPos3

# HardCCDummyPos2:
# var newpvpdummy $pvptarget
# eval newpvpdummy replacere("%newpvpdummy", ".+ ", "")
# goto HardCCDummyPos3

# HardCCDummyPos3:
# if matchre ("$roomobjs" , "%newpvpdummy (that is lying down|that appears (immobilized|stunned))") then goto FRCyclicCheck
# goto HardCCCheck12

# HardCCCheck1:
# if matchre ("$roomplayers" , "(?i)\b$pvptarget\w*(?-i)(?:(?!\band\s+[A-Z])[^,])*?\b(lying down|kneeling|sitting|immobilized)\b") then goto HPTremCheck
# if matchre ("$roomplayers" , "a stunned (?i)\b$pvptarget\w*(?-i)") then goto HPTremCheck
# goto HardCCCheck12

HardCCCheck12:
if ($hardccused > 1) then goto HPTremCheck
if ($pvpjustice = 1) then goto HardCCCheck11
if ($wormsmist = 1) then goto HPTremCheck
if ($shear = 1) then
{
    var shearreturn HardCCShearAnalysis
    goto CheckShear
}
goto HardCCCheck11

HardCCShearAnalysis:
if (%shear = 1) then goto HPTremCheck
goto HardCCCheck11

HardCCCheck11:
var targetvisible HardCCCheck2
var targetspoteffect MainIPCheck
var targetnotvisible MainIPCheck
goto CheckVisiblity

HardCCCheck2:
if ($invisible != 0) then goto MainIPCheck
if ($refdebil != 1) then goto MainIPCheck
if ($hardccused > 0) then
{
    if ($offbalance != 1) then goto MainIPCheck

}
if ($autoip != 1) then goto MainIPCheck
if ($kickonly != 0) then goto MainIPCheck
if ($autoipwand != 1) then goto MainIPCheck
if ($ipwandtimer1 >= $unixtime) then
{
    if ($ipwandtimer2 >= $unixtime) then goto MainIPCheck
}
if ($headdamage != 0) then goto MainIPCheck
goto HPTremCheck

MainIPCheck:
if ($refdebil = 0) then goto MainALCheck
if ($thief = 1) then goto MainALCheck
if ($autoip = 0) then goto MainALCheck
if ($ipspelllosstimer >= $unixtime) then goto MainALCheck
goto IPHCC

MainALCheck:
if ($fortshield != 0) then
{
    if ($autoee != 0) then
    {
        if ($eeon != 1) then goto HPTremCheck
    }
}
if ($fortdebil = 0) then goto HPTremCheck
if ($alsoftcc = 1) then goto HPTremCheck
if ($autoal != 1) then goto HPTremCheck
if ($ipwandtest != 0) then
{
    if ($unixtime > $ipwandtimer1) then
    {
        if ($unixtime > $ipwandtimer2) then goto HPTremCheck
    }
}
if ($alspelllosstimer >= $unixtime) then goto HPTremCheck
goto ALHCC

IPHCC:
put #var rspell IP
put #var rspellname Ice Patch
var prep 1
goto $rspell

ALHCC:
put #var rspell AL
put #var rspellname Arc Light
var prep 1
goto $rspell

HPTremCheck:
if ($grappled = 1) then
{
    if ($tmfoc = 1) then goto GrappleAttackSpells
    if ($health < 100) then
    {
        if ($wellbalanced = 1) then goto HPTremCheck2
        if ($neutralbalance = 1) then goto GrappleAttackSpells
        if ($offbalance = 1) then goto GrappleAttackSpells
    }
}
goto HPTremCheck2

HPTremCheck2:
if ($hptrem != 1) then goto DebilCheck
if ($pvpjustice = 1) then goto DebilCheck
if ($inside = 1) then goto DebilCheck
if ($tremtimer > $unixtime) then goto DebilCheck
if ($tremspelllosstimer >= $unixtime) then goto DebilCheck
goto Tremor

GrappleAttackSpells:
if ($pvpjustice = 1) then goto PWGrappleCheck
if ($inside = 1) then goto PWGrappleCheck
if ($tremtimer > $unixtime) then goto PWGrappleCheck
if ($refdebil = 0) then goto PWGrappleCheck
if ($tremspelllosstimer >= $unixtime) then goto PWGrappleCheck
goto Tremor

PWGrappleCheck:
if ($autoac = 1) then
{
    if ("$pfspellname" != "Aether Cloak") then goto DebilCheck
}
if ($notm = 1) then goto DebilCheck
if ($pwspelllosstimer >= $unixtime) then goto DebilCheck
goto PWrathSC

DebilCheck:
# if ($pvpdummy != 0) then
# {
#     if ($hardccduration >= $unixtime) then goto CyclicCheck
# }
# if ($pvppet = 1) then goto CyclicCheck
var debiledreturn CyclicCheck
var notdebiledreturn StealthTingle
goto OpponentDebiledCheck

# if ($pvppet != 0) then goto DebilCheckDummy
# if ($pvpdummy != 0) then goto DebilCheckDummy
# goto DebilCheck2

# DebilCheckDummy:
# if matchre ("$pvptarget" , "\w+ \w+") then goto DebilCheckDummy2
# var newpvpdummy $pvptarget
# goto DebilCheckDummy3

# DebilCheckDummy2:
# var newpvpdummy $pvptarget
# eval newpvpdummy replacere("%newpvpdummy", ".+ ", "")
# goto DebilCheckDummy3

# DebilCheckDummy3:
# if matchre ("$roomobjs" , "%newpvpdummy (that is lying down|that appears (immobilized|stunned))") then goto CyclicCheck
# goto StealthTingle

# DebilCheck2:
# if matchre ("$roomplayers" , "(?i)\b$pvptarget\w*(?-i)(?:(?!\band\s+[A-Z])[^,])*?\b(lying down|kneeling|sitting|immobilized)\b") then goto CyclicCheck
# if matchre ("$roomplayers" , "a stunned (?i)\b$pvptarget\w*(?-i)") then goto CyclicCheck
# goto StealthTingle

StealthTingle:
if ($fortdebil != 1) then goto TremorOverEverything
if ($autoee != 0) then
{
    if ($eeon != 1) then goto TremorOverEverything
}
if ($tinglehex >= $unixtime) then goto TremorOverEverything
if ($autotingle = 0) then goto TremorOverEverything
if ($tinglespelllosstimer >= $unixtime) then goto TremorOverEverything
if ($wormsmist = 1) then goto TremorOverEverything
# Logic for waiting for IP wands if available
# If both IP wands are useable, skip Tingle since it's a semi-hardd cc effect.
if ($hardccused > 1) then goto StealthTingle2
if ($refdebil != 1) then goto StealthTingle2
if ($autoip != 1) then goto StealthTingle2
if ($autoipwand != 1) then goto StealthTingle2
if ($ipwandtest != 0) then
{
    if ($ipwandtimer1 > $unixtime) then
    {
        if ($ipwandtimer2 > $unixtime) then goto StealthTingle2
    }
}
goto TremorOverEverything

StealthTingle2:
if ($shear = 1) then
{
    var shearreturn TingleShearAnalysis
    goto CheckShear
}

goto TingleSC

TingleShearAnalysis:
if (%shear = 1) then goto TremorOverEverything
goto TingleSC

# goto TingleSC

TremorOverEverything:
if ($tremtimer > $unixtime) then goto VertigoCheck
if ($refdebil = 0) then goto VertigoCheck
if ($pvpjustice = 1) then goto VertigoCheck
if ($inside = 1) then goto VertigoCheck
if ($novistrem = 1) then goto VertigoCheck
if ($softccattempttimer >= $unixtime) then goto VertigoCheck
if ($autotrem = 0) then goto VertigoCheck
if ($tremspelllosstimer >= $unixtime) then goto VertigoCheck
goto Tremor

VertigoCheck:
if ($minddebil = 0) then goto CyclicCheck
# Skip if either Trem or IP are options.
if ($refdebil = 1) then
{
    if ($autoip = 1) then goto CyclicCheck
    goto VertigoTremCheck
}
if ($autoee != 0) then
{
    if ($eeon != 1) then goto CyclicCheck
}
if ($wormsmist = 1) then goto CyclicCheck
goto VertigoCheck2

VertigoTremCheck:
if ($autotrem = 0) then goto VertigoCheck2
if ($inside = 1) then goto VertigoCheck2
if ($pvpjustice = 1) then goto VertigoCheck2
goto CyclicCheck

VertigoCheck2:
if ($verhex > $unixtime) then goto CyclicCheck
if ($pvpjustice = 1) then goto VertigoCheck21
if ($wormsmist = 1) then goto CyclicCheck
if ($shear = 1) then
{
    var shearreturn VertigoShearAnalysis
    goto CheckShear
}
goto VertigoCheck21

VertigoShearAnalysis:
if (%shear = 1) then goto CyclicCheck
goto VertigoCheck21

VertigoCheck21:
if ($softccattempttimer >= $unixtime) then goto CyclicCheck
if ($autovertigo = 0) then goto CyclicCheck
if ($vertigospelllosstimer >= $unixtime) then goto CyclicCheck
goto Vertigo

CyclicCheck:
if ($cyclicoff = 1) then goto FRCyclicCheck
if ($cyclicinitiated >= $unixtime) then goto FRCyclicCheck
if ("$pfspell" = "AC") then goto FRCyclicCheck
if ($autoee = 1) then
{
    if ($eeon = 1) then goto CheckAoECyclic2
}
if ($autoac = 1) then
{
    if ($acon = 1) then goto FRCyclicCheck
}
if ($autoac = 1) then
{
    # if ($dbtimer >= $unixtime) then
    # {
        if ($eeon = 1) then goto FRCyclicCheck
        if ($rimon = 1) then goto FRCyclicCheck
        if ($fron = 1) then goto FRCyclicCheck
    # }
}
if ($autofr = 1) then
{
    if ($fron = 1) then goto CheckAoECyclic2
}
if ($autorim = 1) then
{
    if ($rimon = 1) then goto FRCyclicCheck
}
if ($autofr = 1) then goto FRCyclicCheck
var cyclicreturn FRCyclicCheck
goto SelectCyclic

CheckAoECyclic2:
if ($pvpdummy != 0) then goto FRCyclicCheck
if ($aoearea = 1) then
{
    if ($aoecyclic = 1) then goto FRCyclicCheck
}
if ($aoearea = 0) then
{
    if ($aoecyclic = 0) then goto FRCyclicCheck
}
var cyclicreturn FRCyclicCheck
goto SelectCyclic

SelectCyclic:
if ($autoac = 1) then
{
    if ($dbtimer < $unixtime) then goto ACCyclic
}
if ($autoee = 1) then goto EECheck
if ($autorim = 1) then goto RIMCheck
if ($autofr = 1) then goto FRCheck
goto AdaptiveCyclic

EECheck:
if ($pvpjustice = 1) then goto AdaptiveCyclic
if ($elecoff = 1) then goto AdaptiveCyclic
# Don't use EE if not going to win vs Fort
# Exclude pets, since we're actually trying to force the main target into the open.
if ($fortdebil = 0) then
{
    if ($pvppet != 1) then
    {
        if ($barb != 1) then goto AdaptiveCyclic
    }
}
goto EECyclic

RIMCheck:
if ($notm = 1) then goto AdaptiveCyclic
if ($iceoff = 1) then goto AdaptiveCyclic
goto RIMCyclic

FRCheck:
if ($notm = 1) then goto AdaptiveCyclic
if ($pvpjustice = 1) then goto AdaptiveCyclic
if ($fireoff = 1) then goto AdaptiveCyclic
if ($inside = 1) then goto AdaptiveCyclic
if ("$cscript" = ".seekanddestroy") then goto AdaptiveCyclic
goto FRCyclic

AdaptiveCyclic:
# Starts with EE
if ($pvpjustice = 1) then goto AdaptiveRIM
if ($fortdebil = 0) then
{
    if ($pvppet != 1) then goto AdaptiveFR
    # {
    #     if ($barb != 1) then goto AdaptiveFR
    # }
}
if ($elecoff = 1) then goto AdaptiveFR
goto EECyclic

AdaptiveFR:
if ($notm = 1) then goto AdaptiveAC
if ($pvpjustice = 1) then goto AdaptiveRIM
if ($fireoff = 1) then goto AdaptiveRIM
if ($inside = 1) then goto AdaptiveRIM
if ("$cscript" = ".seekanddestroy") then
{
    put #var autoee 0
    put #var autorim 0
    put #var autofr 1
    put #var autoac 0
    goto %cyclicreturn
}
goto FRCyclic

AdaptiveRIM:
if ($notm = 1) then goto AdaptiveAC
if ($iceoff = 1) then goto AdaptiveAC
# Checks whether we should wait to use FR while seeking and destroying in PvP
if ($pvptarget != 0) then
{
    if ($fireoff != 1) then
    {
        if ($inside != 1) then
        {
            if ($pvpjustice != 1) then goto AdaptiveAC
        }
    }
}
goto RIMCyclic

AdaptiveAC:
# if ($notm != 1) then goto FRCyclicCheck
goto %cyclicreturn

FRCyclic:
if ($autoac = 1) then
{
    if ($dbtimer >= $unixtime) then goto FLRFR
}
put #var autoee 0
put #var autorim 0
put #var autofr 1
put #var autoac 0
put #var rspell FR
put #var rspellname Fire Rain
var prep 1
goto $rspell

FLRFR:
put #var rspellname Fire Rain
var prep 1
goto $rspell

EECyclic:
if ($autoac = 1) then
{
    if ($dbtimer >= $unixtime) then goto EEFR
}
put #var autoee 1
put #var autorim 0
put #var autofr 0
put #var autoac 0
put #var rspell EE
put #var rspellname Electrostatic Eddy
var prep 1
goto $rspell

EEFR:
put #var rspell EE
put #var rspellname Electrostatic Eddy
var prep 1
goto $rspell

RIMCyclic:
if ($autoac = 1) then
{
    if ($dbtimer >= $unixtime) then goto RimeFR
}
put #var autoee 0
put #var autorim 1
put #var autofr 0
put #var autoac 0
put #var rspell RIM
put #var rspellname Rimefang
var prep 1
goto $rspell

RimeFR:
put #var rspell RIM
put #var rspellname Rimefang
var prep 1
goto $rspell

ACCyclic:
put #var autoee 0
put #var autorim 0
put #var autofr 0
put #var autoac 1
put #var rspell AC
put #var rspellname Aether Cloak
var prep 1
goto $rspell

FRCyclicCheck:
if ($autofr = 0) then goto ALCheck2
if ($fron = 1) then
{
    if ($aoearea = 1) then
    {
        if ($aoecyclic = 1) then goto ALCheck2
    }
}
if ($fron = 1) then
{
    if ($aoearea = 0) then
    {
        if ($aoecyclic = 0) then goto ALCheck2
    }
}
if ($cyclicinitiated >= $unixtime) then goto ALCheck2
# if ($thief = 1) then goto ALCheck2
# if ($moonmage = 1) then goto ALCheck2
# if ($ranger = 1) then goto ALCheck2
# if ($necro = 1) then goto ALCheck2
# if ($redeemed = 1) then goto ALCheck2
# if ($nonaphtha = 1) then goto ALCheck2
goto FRCheck

ALCheck2:
if ($tmfoc = 1) then goto CheckTM
if ($fortdebil = 0) then goto CheckTM
if ($refdebil != 0) then goto CheckTM
if ($verhex > $unixtime) then goto CheckTM
if ($wormsmist = 1) then goto CheckTM
if ($shear = 1) then goto CheckTM
if ($unixtime < $hardccattempttimer) then goto CheckTM
if ($unixtime < $hardccduration) then goto CheckTM
if ($alspelllosstimer >= $unixtime) then goto CheckTM
var debiledreturn CheckTM
var notdebiledreturn ALHCC
goto OpponentDebiledCheck

CheckTM:
if ($notm = 1) then goto SoftCCAttack
if ($acon = 1) then
{
    if ("$pfspellname" != "Aether Cloak") then goto SoftCCAttack
}
# if ("$pfspell" = "AC") then goto SoftCCAttack
goto TMAttacks

TMAttacks:
# TM Spells for PvP and PVE
if ($pvp = 0) then goto PvEMaBCheck
if ($wormsmist != 0) then goto TMWormAttacks
if ($shear = 1) then
{
    var shearreturn TMShearAnalysis
    goto CheckShear
}
goto TMAttacks2

TMWormAttacks:
if ($pvpjustice != 0) then goto TMAttacks2
if ($autoshw != 0) then goto ShearShockwave
if ($aoeshockwave != 0) then goto ShearShockwave
goto ShearCL

TMShearAnalysis:
if (%shear = 1) then goto TMShearAttacks
goto TMAttacks2

TMShearAttacks:
if ($pvpjustice = 1) then goto SoftCCAttack
if ($necro = 1) then goto ShearShockwave
if ($autoshw = 1) then goto ShearShockwave
goto ShearCL

ShearShockwave:
if ($shockwavespelllosstimer > $unixtime) then goto ShearCL
if ($iceoff = 1) then goto ShearCL
goto ShockwaveSC

ShearCL:
if ($elecoff = 1) then goto SoftCCAttack
if ($fireoff = 1) then goto SoftCCAttack
goto ChainLitSC

TMAttacks2:
if ($targethead = 1) then
{
    if ($tmfoc != 1) then goto CloseRangeMultiStikeCheck
}
if ($autopw = 0) then goto CloseRangeMultiStikeCheck
# if ($autopw > $unixtime) then goto CloseRangeMultiStikeCheck
if ($nonaphtha = 1) then goto CloseRangeMultiStikeCheck
# if ($shear = 1) then goto CloseRangeMultiStikeCheck
# if ($thief = 1) then goto CloseRangeMultiStikeCheck
# if ($moonmage = 1) then goto CloseRangeMultiStikeCheck
# if ($ranger = 1) then goto CloseRangeMultiStikeCheck
# if ($necro = 1) then goto CloseRangeMultiStikeCheck
# if ($redeemed = 1) then goto CloseRangeMultiStikeCheck
if ($pwspelllosstimer >= $unixtime) then goto CloseRangeMultiStikeCheck
goto PWrathSC

# HoTCheck:
# if ($pvp = 0) then goto OpHotCheck
# if ($pvpdummy != 0) then goto OpHotCheck
# if ($nosorcery != 0) then goto OpHotCheck
# if ($autohot = 0) then goto OpHotCheck
# if ($fireoff = 1) then goto OpHotCheck
# goto HoTSC

# OpHotCheck:
# if ($pvp = 0) then goto LBCheck
# if ($pvpdummy != 0) then goto LBCheck
# if ($nosorcery != 0) then goto LBCheck
# if ($ophot = 0) then goto LBCheck
# if ($fireoff = 1) then goto LBCheck
# # if matchre ("$roomplayers" , "(?i)\b$pvptarget\w*(?-i) who is (lying down|kneeling|sitting)") then
# # {
# #     if ($hardccduration > $unixtime) then goto HoTSC
# # }
# # if matchre ("$roomplayers" , "a stunned (?i)\b$pvptarget\w*(?-i)") then
# # {
# #     if ($hardccduration > $unixtime) then goto HoTSC
# # }
# # if matchre ("$roomplayers" , "(?i)\b$pvptarget\w*(?-i) who is (lying down|kneeling|sitting)") then
# # {
# #     if ($tremtimer > $unixtime) then goto HoTSC
# # }
# if matchre ("$roomplayers" , "(?i)\b$pvptarget\w*(?-i)(?:(?!\band\s+[A-Z])[^,])*?\b(lying down|kneeling|sitting|immobilized)\b") then goto HoTSC
# if matchre ("$roomplayers" , "a stunned (?i)\b$pvptarget\w*(?-i)") then goto HoTSC
# goto LBCheck

PvEMaBCheck:
if ($automab != 1) then goto LBCheck
if ($ballista != 0) then
{
    if !matchre ("$roomobjs" , "sleek onyx ballista set with banded silvery mechanisms|stuff\.$") then
    {
        put #var ballista 0
        put #class ballista off
    }
}
if ($ballista = 1) then goto LBCheck
if ($tmfoc != 1) then goto LBCheck
put #var rspell MAB
put #var rspellname Magnetic Ballista
var prep 1
goto $rspell

CloseRangeMultiStikeCheck:
if ($closerangemulti != 1) then goto LBCheck
if ($polerange = 0) then
{
    if ($meleelasttime = 0) then goto LBCheck
}
if ($elecoff = 1) then goto CloseRangeMultiStikeCheck2
if ($gzspelllosstimer > $unixtime) then goto CloseRangeMultiStikeCheck2
goto GZSC

CloseRangeMultiStikeCheck2:
if ($autosts = 0) then goto LBCheck
if ($stsspelllosstimer > $unixtime) then goto LBCheck
goto STSSC

LBCheck:
if ($autolb = 0) then goto FrostScytheCheck
if ($inside = 1) then goto AdaptiveTM
if ($elecoff = 1) then goto FrostScytheCheck
if ($fireoff = 1) then goto FrostScytheCheck
if ($lbspelllosstimer > $unixtime) then goto FrostScytheCheck
goto LBSC

FrostScytheCheck:
if ($autofrs = 0) then goto FireShardCheck
if ($iceoff = 1) then goto FireShardCheck
if ($frsspelllosstimer > $unixtime) then goto FireShardCheck
goto FRSSC

FireShardCheck:
if ($autofs = 0) then goto STSCheck
if ($fireoff = 1) then goto STSCheck
if ($fsspelllosstimer > $unixtime) then goto STSCheck
goto FSSC

STSCheck:
if ($autosts = 0) then goto GZCheck
if ($stsspelllosstimer > $unixtime) then goto GZCheck
goto STSSC

GZCheck:
if ($autogz = 0) then goto ShockwaveCheck
if ($elecoff = 1) then goto ShockwaveCheck
if ($gzspelllosstimer > $unixtime) then goto ShockwaveCheck
goto GZSC

ShockwaveCheck:
if ($autoshw = 0) then goto ChainLCheck
if ($pvpjustice = 1) then goto ChainLCheck
if ($shockwavespelllosstimer > $unixtime) then goto ChainLCheck
if ($iceoff = 1) then goto ChainLCheck
goto ShockwaveSC

# FireBallCheck:
# if ($autofb = 0) then goto ChainLCheck
# if ($fireoff = 1) then goto ChainLCheck
# if ($fbspelllosstimer > $unixtime) then goto ChainLCheck
# goto FBSC

ChainLCheck:
if ($chainlit = 0) then goto AethCheck
if ($pvpjustice = 1) then goto AethCheck
if ($elecoff = 1) then goto AethCheck
if ($fireoff = 1) then goto AethCheck
goto ChainLitSC

AethCheck:
if ($autoaeth = 0) then goto AdaptiveTM
if ($pvpjustice = 1) then goto AdaptiveTM
if ($nosor = 1) then goto AdaptiveTM
goto AethSC

AdaptiveTM:
if ($pvp = 1) then goto AdaptiveLB
if ($elecoff = 1) then goto AdaptiveLB
if ($fireoff = 1) then goto AdaptiveLB
if ($pvpjustice = 1) then goto AdaptiveLB
goto ChainLitSC

# AdaptiveFB:
# if ($fireoff = 1) then goto AdapativeFRS
# if ($fbspelllosstimer > $unixtime) then goto AdapativeFRS
# goto FBSC

AdaptiveLB:
if ($elecoff = 1) then goto AdaptiveGZ
if ($inside = 1) then goto AdaptiveGZ
if ($fireoff = 1) then goto AdaptiveGZ
if ($lbspelllosstimer > $unixtime) then goto AdaptiveGZ
goto LBSC

AdaptiveGZ:
if ($barb != 0) then goto AdapativeFRS
if ($paladin != 0) then goto AdapativeFRS
if ($elecoff = 1) then goto AdaptiveSTS
if ($fireoff = 1) then goto AdaptiveSTS
if ($gzspelllosstimer > $unixtime) then goto AdaptiveSTS
goto GZSC

AdaptiveSTS:
if ($stsspelllosstimer > $unixtime) then goto AdapativeFRS
goto STSSC

AdapativeFRS:
# HoT is the last unstealable option if absolutely necessary.
if ($iceoff = 1) then goto AdaptiveTMEnd
if ($frsspelllosstimer > $unixtime) then goto AdaptiveTMEnd
goto FRSSC

AdaptiveTMEnd:
put #echo >Conversation
put #echo >Conversation #000000 *** Manualy Select TM
echo
echo **** Manualy Select TM ****
goto SoftCCAttack

LBSC:
put #var rspell LB
put #var rspellname Lightning Bolt
var prep 1
goto $rspell

FSSC:
put #var rspell FS
put #var rspellname Fire Shards
var prep 1
goto $rspell

STSSC:
put #var rspell STS
put #var rspellname Stone Strike
var prep 1
goto $rspell

GZSC:
put #var rspell GZ
put #var rspellname Gar Zeng
var prep 1
goto $rspell

FRSSC:
put #var rspell FRS
put #var rspellname Frost Scythe
var prep 1
goto $rspell

PWrathSC:
put #var rspell PW
put #var rspellname Paeldryth's Wrath
var prep 1
goto $rspell

HoTSC:
put #var rspell HoT
put #var rspellname Hand of Tenemlor
var prep 1
goto $rspell

FBSC:
put #var rspell FB
put #var rspellname Fire Ball
var prep 1
goto $rspell

ChainLitSC:
put #var rspell CL
put #var rspellname Chain Lightning
var prep 1
goto $rspell

AethSC:
put #var rspell Aeth
put #var rspellname Aethrolysis
var prep 1
goto $rspell

SoftCCAttack:

# Already checked Hard CC
# Options Tremor, Tingle, ANC, Vertigo, Frostbite, MoA
if ($pvptarget = 0) then goto PvETCCheck
if ($tremtimer > $unixtime) then goto CheckVertigoSCC
if ($refdebil = 0) then goto CheckVertigoSCC
if ($pvpjustice = 1) then goto CheckVertigoSCC
if ($inside = 1) then goto CheckVertigoSCC
if ($autotrem = 0) then goto CheckVertigoSCC
if ($novistrem = 1) then goto CheckVertigoSCC
if ($tremspelllosstimer >= $unixtime) then goto CheckVertigoSCC
goto Tremor

CheckVertigoSCC:
if ($pvpjustice = 1) then goto VertigoCheckSCC3
if ($wormsmist = 1) then goto MABCheckSC
if ($shear = 1) then
{
    var shearreturn VertigoShearAnalysisSCC
    goto CheckShear
}
goto VertigoCheckSCC3

VertigoShearAnalysisSCC:
if (%shear = 1) then goto MABCheckSC
goto VertigoCheckSCC3

VertigoCheckSCC3:
if ($minddebil = 0) then goto ANCorTingle
# Skip if either Trem or IP are options.
if ($refdebil = 1) then
{
    if ($autoip = 1) then goto ANCorTingle
    goto VertigoTremCheckSCC
}
goto VertigoCheckSCC2

VertigoTremCheckSCC:
if ($autotrem = 0) then goto VertigoCheckSCC2
if ($inside = 1) then goto VertigoCheckSCC2
if ($pvpjustice = 1) then goto VertigoCheckSCC2
goto ANCorTingle

VertigoCheckSCC2:
if ($verhex > $unixtime) then goto ANCorTingle
# if ($shear = 1) then goto ANCorTingle
if ($autovertigo = 0) then goto ANCorTingle
if ($vertigospelllosstimer >= $unixtime) then goto ANCorTingle
goto Vertigo

ANCorTingle:
var tinglefirst 0
if ($refdebil = 1) then goto ANCCheck
var tinglefirst 1
goto CheckTingle

ANCCheck:
if ($fortdebil = 0) then goto ANCPass
if ($paladin != 0) then goto ANCPass
if ($anchex > $unixtime) then goto ANCPass
if ($autoanc = 0) then goto ANCPass
if ($ancspelllosstimer >= $unixtime) then goto ANCPass
goto Anthers

ANCPass:
if (%tinglefirst = 1) then goto MABCheckSC
goto CheckTingle

CheckTingle:
if ($fortdebil = 0) then goto TinglePass
if ($tinglehex > $unixtime) then goto TinglePass
if ($autotingle = 0) then goto TinglePass
if ($elecoff = 1) then goto TinglePass
if ($tinglespelllosstimer >= $unixtime) then goto TinglePass
goto TingleSC

TinglePass:
if (%tinglefirst = 1) then goto ANCCheck
goto MABCheckSC

# MoACheck:
# if ($spiritdebil = 0) then goto MABCheckSC
# if ($autosts = 1) then
# {
#     if ($nocharge = 1) then goto MABCheckSC
#     if ($regsweapons = 1) then goto MABCheckSC
# }
# if ($acon = 1) then
# {
#     if ($regsweapons = 1) then goto MABCheckSC
# }
# if ($moahex > $unixtime) then goto MABCheckSC
# if ($moaspelllosstimer >= $unixtime) then goto MABCheckSC
# goto MoASC

MABCheckSC:
if ($notm = 1) then goto WORMFrost
if ($automab != 1) then goto WORMFrost
# if ($acon != 1) then goto LateVertigoCheck
# Currently only using MAB w/ AC
if ($moonmage = 1) then goto LateVertigoCheck
if ($necro = 1) then
{
    if !matchre ("$roomobjs" , "\bzombie|\bconstruct") then goto LateVertigoCheck
}
if ($thief = 1) then goto LateVertigoCheck
if ($ranger = 1) then goto LateVertigoCheck
if ($redeemed = 1) then goto LateVertigoCheck
if ($ballista != 0) then
{
    if !matchre ("$roomobjs" , "sleek onyx ballista set with banded silvery mechanisms|stuff\.$") then
    {
        put #var ballista 0
        put #class ballista off
    }
}
if ($ballista = 1) then goto WORMFrost
goto MABSC

MABSC:
put #var rspell MAB
put #var rspellname Magnetic Ballista
var prep 1
goto $rspell

WORMFrost:
if ($wormsmist = 0) then goto LateVertigoCheck
if ($pvpjustice = 1) then goto LateVertigoCheck
if ($frostbitespelllosstimer >= $unixtime) then goto LateVertigoCheck
goto FrostBiteSC

LateVertigoCheck:
if ($minddebil = 0) then goto IPCheck
if ($verhex > $unixtime) then goto IPCheck
if ($wormsmist = 1) then goto IPCheck
if (%shear = 1) then goto IPCheck
if ($autovertigo = 0) then goto IPCheck
if ($vertigospelllosstimer >= $unixtime) then goto IPCheck
goto Vertigo

IPCheck:
# Second IP Check used after hard cc. Goal is to reduce enemy balance.
# Skip if trader to avoid cc amplification, or if not worth the RT because of trem.
if ($trader = 1) then goto AttackSpellBackstop
if ($tremtimer > $unixtime) then
{
    if ($wellbalanced = 1) then goto AttackSpellBackstop
}
if ($wormsmist = 1) then goto FrostbiteCheck
if ($shear = 1) then
{
    var shearreturn IPShearAnalysis
    goto CheckShear
}
goto IPCheck2

IPShearAnalysis:
if (%shear = 1) then goto FrostbiteCheck
goto IPCheck2

IPCheck2:
if ($refdebil = 0) then goto ALCheck
if ($autoip = 0) then goto ALCheck
if ($fortdebil != 0) then
{
    if ($bard = 1) then goto ALCheck
    # if ($tremtimer >= $unixtime) then then goto ALCheck
}
# if ($iceoff = 1) then goto ALCheck
if ($ipspelllosstimer >= $unixtime) then goto ALCheck
goto IPHCC

ALCheck:
# if ($fortdebil = 0) then goto AttackSpellBackstop
if ($alspelllosstimer >= $unixtime) then goto FrostbiteCheck
goto ALHCC

FrostbiteCheck:
if ($pvpjustice != 0) then goto IPCheck3
if ($frostbitespelllosstimer >= $unixtime) then goto TCCheck
goto FrostBiteSC

TCCheck:
if ($tcspelllosstimer >= $unixtime) then goto AttackSpellBackstop
goto TCSC

IPCheck3:
if ($refdebil = 0) then goto AttackSpellBackstop
if ($autoip = 0) then goto AttackSpellBackstop
if ($ipspelllosstimer >= $unixtime) then goto AttackSpellBackstop
goto IPHCC


PvETCCheck:
if ($bo = 1) then goto AttackSpellBackstop
if ($calmed = 1) then goto AttackSpellBackstop
if ($pvpjustice = 1) then goto PvEIP
if ($autotc = 0) then goto PvETremorCheck
if ($tctimer >= $unixtime) then
{
    if ($pith = 1) then goto AttackSpellBackstop
}
if ($tcspelllosstimer >= $unixtime) then goto PvETremorCheck
goto TCSC

PvETremorCheck:
if ($tremtimer > $unixtime) then goto PvEFrostbite
if ($inside = 1) then goto PvEFrostbite
if ($refdebil = 0) then goto PvEFrostbite
if ($autotrem = 0) then goto PvEFrostbite
if ($tremspelllosstimer >= $unixtime) then goto PvEFrostbite
goto Tremor

PvEFrostbite:
if ($autofrostbite = 0) then goto PvEIP
if ($iceoff = 1) then goto PvEAL
if ($frostbitespelllosstimer >= $unixtime) then goto PvEIP
goto FrostBiteSC

PvEIP:
if ($iceoff = 1) then goto PvEAL
if ($autoip = 0) then goto PvEAL
if ($ipspelllosstimer >= $unixtime) then goto PvEAL
goto IPHCC

PvEAL:
if ($alspelllosstimer >= $unixtime) then goto AttackSpellBackstop
goto ALHCC

AttackSpellBackstop:
# All attack spells checked. End of the line for PvE. Cycle back to check about casting from PF/loading PF, and goto to phyical exit if good to go.
# For PVP, go through buffs.
if ($pvptarget = 0) then
{
    if (%mainslotchecked = 1) then
    {
        goto PhysicalExit
    }
    var mainslotchecked 1
    goto CheckPFSlot
}
goto CheckTW

TingleSC:
put #var rspell TIN
put #var rspellname Tingle
var prep 1
goto $rspell

Anthers:
put #var rspell ANC
put #var rspellname Anther's Call
var prep 1
goto $rspell

Tremor:
put #var rspell TREM
put #var rspellname Tremor
var prep 1
goto $rspell

WBSoft:
put #var rspell WB
put #var rspellname Ward Break
var prep 1
goto $rspell

Vertigo:
put #var rspell VER
put #var rspellname Vertigo
var prep 1
goto $rspell

MoASC:
put #var rspell MoA
put #var rspellname Mark of Arhat
var prep 1
goto $rspell

FrostBiteSC:
put #var rspell FRB
put #var rspellname Frostbite
var prep 1
goto $rspell

TCSC:
put #var rspell TC
put #var rspellname Thunderclap
var prep 1
goto $rspell

BOCombatCheck:
var percreturn WandCheck
var wandreturn BOCombatCheck2
goto PercCheck

BOCombatCheck2:
if ($combatloop != 0) then
{
    put .ksnomagic
    exit
}
goto PrepWait

InvisPFCheck:
# Checks if a PF spell that's been prepped is castable
if ("$pfspellname" = "Fortress of Ice") then goto InvisFoICheck
if ("$pfspellname" = "Aether Cloak") then
{
    if ($acon = 1) then goto %invispfreturn
    if ($dbtimer >= $unixtime) then goto %invispfreturn
}
goto InvisPFCheck2

InvisFoICheck:
if matchre ("$roomobjs" , "Ice Fortress") then goto %invispfreturn
if matchre ("$roomname" , "Ice Fortress") then goto %invispfreturn
if matchre ("$roomexits" , "^Obvious exits") then goto %invispfreturn
if ($inside = 1) then goto %invispfreturn
if ("$cscript" = ".seekanddestroy") then goto %invispfreturn
# if ($mafhit != 0) then goto InvisPFCheck2
# if ($reprhit != 0) then goto InvisPFCheck2
# if ($health < 100) then goto InvisPFCheck2
# if ($concentration < 90) then goto InvisPFCheck2
# goto %invispfreturn
goto InvisPFCheck2

InvisPFCheck2:
if ($pfspell = 0) then goto %invispfreturn
if ($pfharn != 0) then
{
    if ($pfharn = $pfharnlimit) then
    {
        var pf 1
        var cast 1
        goto $pfspell
    }
}
if ($pfharn = 1) then goto PFHarn2
if ($pfpausetime != 0) then
{
    if ($unixtime > $pfpausetime) then
    {
        if ($invisible != 1) then goto PFHarn
    }
}
goto %invispfreturn

HardCCInvisCheck:
# Logic for having a prepped hard cc spell while target's invis.
# Waits 3 seconds before releasing just in case the target returns.
# Checks buffs and AoE options. Waits if no need to release.
if ($pvp != 1) then goto RegsRel
if ($combatloop = 0) then goto RegsRel
if matchre ("$roomname" , "Ice Fortress") then goto HardCCInvisCheckAura
if ($debilcasttimer = 0) then
{
    put #var debilcasttimer #evalmath ($unixtime + 3)
}
# if ($debilcasttimer > $unixtime) then goto PhysicalExit
if ($debilcasttimer > $unixtime) then goto PhysicalExit
goto HardCCInvisCheckAura

HardCCInvisCheckAura:
var aurareturn HardCCInvisCheckAura2
goto AuraCheck

HardCCInvisCheckAura2:
if (%requiresmainslot = 1) then
{
    echo
    echo **** Next Spell - %nextspell ****
    echo
    goto RegsRel
}
if (%morespells = 1) then
{
    echo
    echo **** Next Spell - %nextspell ****
    echo
    goto RegsRel
}
if (%nextspell != 0) then
{
    if ($pfspell = 0) then
    {
        var mainslotchecked 1
        goto CheckPFSlot
    }
}
goto PhysicalExit

SoftCCInvisCheck:
# Logic for having a prepped single target soft cc spell while target's invis.
# Waits 3 seconds before releasing just in case the target returns.
# Checks buffs, hard cc and AoE options. Waits if no need to release.
# if ($hardccrecover < $unixtime) then put #var hardccused 0
if ($pvp != 1) then goto RegsRel
if ($debilcasttimer = 0) then
{
    put #var debilcasttimer #evalmath ($unixtime + 3)
}
if ($debilcasttimer > $unixtime) then goto PhysicalExit
if ($fortdebil = 1) then
{
    if ($alsoftcc = 1) then goto SoftCCInvisTrem
}
if ($hardccused < 2) then
{
    if ($hardccduration < $unixtime) then goto RegsRel
}
goto SoftCCInvisTrem

SoftCCInvisTrem:
if ($pvpjustice = 1) then goto SoftCCInvisCheckFrb
if ($inside = 1) then goto SoftCCInvisCheckFrb
if ($autotrem = 0) then goto SoftCCInvisCheckFrb
if ($tremtimer > $unixtime) then goto SoftCCInvisCheckFrb
if ($refdebil = 0) then goto SoftCCInvisCheckFrb
if ($tremspelllosstimer >= $unixtime) then goto SoftCCInvisCheckFrb
goto RegsRel

SoftCCInvisCheckFrb:
if matchre ("$roomname" , "Ice Fortress) then
{
    if ($autofoi = 1) then goto RegsRel
}
if ($fortdebil = 0) then goto HardCCInvisCheck
if ($iceoff = 1) then goto HardCCInvisCheck
if ($frostbitespelllosstimer >= $unixtime) then goto HardCCInvisCheck
goto RegsRel

PhysicalExit:
var pwshutdownreturn PhysicalExit2
goto ShutDownPathways

PhysicalExit2:
# var percreturn WandCheck
# var wandreturn ExitEECheck
var wandreturn AutoWandCheck
var ipwandexit ExitEECheck
var eecheckreturn KSNoMagicExit
# goto PercCheck
goto WandCheck

ExitEECheck:
if ($autoee != 1) then goto %eecheckreturn
if ($eeon != 1) then goto %eecheckreturn
if ($pvptarget = 0) then goto %eecheckreturn
if ($groupbattle = 1) then goto %eecheckreturn
if ($pvppet = 1) then goto %eecheckreturn
if ($paralysischeck > $unixtime) then goto %eecheckreturn
if ($combatloop = 0) then goto %eecheckreturn
var targetvisible ParalysisCheck
var targetspoteffect %eecheckreturn
var targetnotvisible %eecheckreturn
goto CheckVisiblity

ParalysisCheck:
var paralyzed 0
action var paralyzed 1 when complete paralysis of the entire body\.$
if ($backstop > 9) then put #var backstop 0
goto ParalysisCheck2

ParalysisCheck2:
put #var backstop #evalmath ($backstop + 1)
matchre ParalysisCheck2 ^\.\.\.wait|^Sorry\,
# matchre ParalysisChecked ^You see|^I could not find what you were referring to\.
# match SpellReadyCheck I could not find what you were referring to.
matchre ParalysisChecked Paralysis Backstop $backstop$
put look $pvptarget wounds
put echo Paralysis Backstop $backstop
matchwait

ParalysisChecked:
action remove complete paralysis of the entire body\.$
put #var paralysischeck #evalmath ($unixtime + 15)
if (%paralyzed != 0) then goto Paralized
goto %eecheckreturn

Paralized:
if ($barb = 1) then goto %eecheckreturn
if matchre ("$roomexits" , "^Obvious exits") then goto EEToRIM
if ($inside = 1) then goto EEToRIM
if ($thief = 1) then goto EEToRIM
put #var autoee 0
put #var autorim 0
put #var autofr 1
put #var autoac 0
goto Paralized2

EEToRIM:
put #var autoee 0
put #var autorim 1
put #var autofr 0
put #var autoac 0
goto Paralized2

Paralized2:
# var relreturn %eecheckreturn
# var relcyclic 1
put #echo >Conversation
put #echo >Conversation #000000 *** $pvptarget Paralized
put #echo >Conversation #000000 *** Switching Cyclic
# goto RelSpell
goto %eecheckreturn

KSNoMagicExit:
if ($combatloop != 0) then
{
    put .ksnomagic
    exit
}
goto MagicExit
# echo
# echo **** Error at KSNoMagicExit:
# exit

RitualPrep:
if ("$righthand" = "haralun sword") then
{
    if ("$lefthandnoun" = "") then goto FocRetreat
}
if ("$righthand" = "haralun sword") then
{
    var shleftreturn RitualPrep
    goto SheathL
}
if ("$righthandnoun" = "") then
{
    if ("$lefthandnoun" = "") then goto WieldFoc
}
var shleftreturn RitualPrep
var shrightreturn RitualPrep
var clearboth 1
goto SheathR

WieldFoc:
matchre WieldFoc ^\.\.\.wait|^Sorry\,
matchre FocRetreat ^You draw out|^You are already
match LiftFoc You find it difficult to wield
matchre HandDamageSevereSC ^Your.*?hand is too injured to draw|^You are missing
put wield my haralun sword
matchwait

HandDamageSevereSC:
put #var handdamaged 1
put #var kickonly 1
var commonrel 1
var relreturn CheckSpellStatus
goto RelSpell

LiftFoc:
matchre LiftFoc ^\.\.\.wait|^Sorry\,
matchre RitualPrep ^You pick up|^You fade in
put lift sword
matchwait

FocRetreat:
var retreatreturn InvokeFocus
var warstompreturn InvokeFocus
var grapplereturn InvokeFocus
goto Retreat

InvokeFocus:
matchre InvokeFocus ^\.\.\.wait|^Sorry\,
matchre SheathFocus ^You make sweeping gestures through the air
match HeadDamageFoc You are in no condition to do that.
put #var focinvoked 1
put invoke my haralun sword
matchwait

HeadDamageFoc:
put #var focinvoked 0
goto HeadDamageSB

SheathFocus:
if ($combatloop != 0) then goto CheckSpellStatus
matchre SheathFocus ^\.\.\.wait|^Sorry\,
matchre CheckSpellStatus ^You sheath|^Sheathe what\?$
put sheath my haralun sword in my leather sheath
matchwait

PFPrep:
var getpfocreturn $pfspell
if ("$lefthand" = "spiritwood cube") then goto $pfspell
if ("$righthand" = "spiritwood cube") then goto $pfspell
if ("$lefthandnoun" = "") then goto GetPFoc
if ("$righthandnoun" = "") then goto GetPFoc
var shleftreturn PFPrep
var shrightreturn PFPrep
goto EmptyOneHand

GetPFoc:
if ("$lefthand" = "spiritwood cube") then goto %getpfocreturn
if ("$righthand" = "spiritwood cube") then goto %getpfocreturn
if ("$lefthandnoun" != "") then
{
    if ("$righthandnoun" != "") then goto CheckPFHands
}
matchre GetPFoc ^\.\.\.wait|^Sorry\,
matchre %getpfocreturn ^You get a spiritwood cube|^You are already holding that\.$
matchre PFocHandDamaged ^You can't pick that up with your hand that damaged\.|^You are missing
match SCRes You need a free hand to pick that up.
put get my spiritwood cube
matchwait

SCRes:
put .res
exit

CheckPFHands:
if (%cast = 1) then goto PFCast
goto PFPrep

PFocHandDamaged:
put #var handdamaged 1
put #var pfspellprepped 0
put #var pfprepm 0
put #var pfharn1 0
put #var pfharn2 0
put #var pfharnlimit 0
put #var pfspell 0
put #var pfpausetime 0
put #var pfsorcery 0
put #var pfspelllost 0
if ($pfharn != 0) then
{
    var relmana 1
    var relreturn CheckSpellStatus
    goto RelSpell
}
goto CheckSpellStatus

PFHarn2:
if ($pf != 1) then put #var pf 1
if ($pfharn2 = 0) then goto PFCast
if ($pfharnlimit != 0) then
{
    if ($pfharn = $pfharnlimit) then goto PFCast
}
if ($pfharn > 2) then
{
    var relpf 1
    var relmana 1
    var relreturn CheckSpellStatus
    goto RelSpell
}
matchre PFHarn2 ^\.\.\.wait|^Sorry\,
match MagicExit You tap into the mana
put #class harness on
put harn $pfharn2
matchwait

RelPathway:
var relpathway 1
var relreturn MagicExit
goto RelSpell

PathReleased:
if (%notarget = 1) then
{
    put .wait
    exit
}
goto MagicExit

RelSpellNoEnemies:
var commonrel 1
if ($pathwaydaming = 1) then var relpathway 1
if ($pathwayacc = 1) then var relpathway 1
if ($pathwayquick = 1) then var relpathway 1
var relreturn RelSpellNoEnemies2
goto RelSpell

RelSpellNoEnemies2:
if ($pvptarget != 0) then
{
    if ($meleelasttime != 0) then put #var meleelasttime 0
    if ($polerange != 0) then put #var polerange 0
    put #class meleewatcher on
    put #class polerangewatcher on
    put #class retreatwatcher off
    if ($baltargeted != 0) then put #var baltargeted 0
    if ($grappled != 0) then put #var grappled 0
    if ($pvpdummy != 0) then goto NoTargetDummyVisCheck
    goto MagicExit
}
put .wait
exit

NoTargetDummyVisCheck:
var targetvisible NoTargetDummyVisCheck2
var targetspoteffect NoTargetDummyVisCheck2
var targetnotvisible MagicExit
goto CheckVisiblity

NoTargetDummyVisCheck2:
put .newpvpdummy
exit

LowMana:
echo
echo **** Spell Failed
echo **** Low Mana
goto MagicExit

NoCasting:
put #var magicauraloop 0
put #var cax 0
put #var pvpfull 0
put #var nomagic 1
echo
echo **** No Casting ****
# if ($combatloop != 0) then
# {
#     goto MagicExit
# }
put .relx
exit

# RegenConcentration:
# if ($harn = 1) then goto CheckStatus
# if ($pfharn = 1) then goto CheckStatus
# if ($rspell = 0) then
# {
#     if ($pfspell = 0) then
#     {
#         if (%cao = 0) then
#         {
#             if ($cax = 0) then
#             {
#                 if ($pvpfull = 0) then goto MagicExit
#             }
#         }
#     }
# }
# echo
# echo **** Regenerating Concentration ****
# echo      Current Concentration: $concentration
# echo ************************************
# echo
# if ($combatloop != 0) then goto ExitEECheck
# pause 10
# goto CheckSpellStatus

PrepWait:
var mainslotchecked 1
if ($rspell != 0) then
{
    if ("$preparedspell" = "None") then goto RegsRel
}
if ($pfspell != 0) then
{
    if ($pfspellprepped != 1) then goto PFRel
}
if ($combatloop != 0) then goto PhysicalExit
if ($cscript != 0) then goto PhysicalExit
if ($invisible = 1) then goto Pause5
if matchre ("%nextspell" , "Aether Cloak|Electrostatic Eddy|Fire Rain|Rimefang") then
{
    if ($cyclicinitiated >= $unixtime) then goto Pause5
}
if ($pausetime != 0) then
{
    if ($pfpausetime != 0) then
    {
        if ("$pfspellname" != "Fortress of Ice") then
        {
            var pausetime $pausetime
            math pausetime subtract $unixtime
            var pfpausetime $pfpausetime
            math pfpausetime subtract $unixtime
            if (%pausetime <= %pfpausetime) then
            {
                if (%pausetime >= 5) then goto Pause5
                if (%pausetime < 1) then goto Pause1
                goto PrepWaitTimedPause
            }

            if (%pfpausetime >= 5) then goto Pause5
            if (%pfpausetime < 1) then goto Pause1
            goto PrepWaitTimedPause
        }
    }
}
if ($rspell = 0) then
{
    if ("$pfspellname" = "Fortress of Ice") then
    {
        if (%cao != 0) then
        {
            if ($pvpfull != 0) then goto MagicExit
        }
    }
    if ($pfpausetime = 0) then goto MagicExit
    var pfpausetime $pfpausetime
    math pfpausetime subtract $unixtime
    if (%pfpausetime >= 5) then goto Pause5
    if (%pfpausetime < 1) then goto Pause1
    goto PrepWaitTimedPause
}
var pausetime $pausetime
math pausetime subtract $unixtime
if (%pausetime >= 5) then goto Pause5
if (%pausetime < 1) then goto Pause1
goto PrepWaitTimedPause

PrepWaitTimedPause:
var percreturn WandCheck
var wandreturn PrepWaitTimedPause2
goto PercCheck

PrepWaitTimedPause2:
# if matchre ("$preparedspell" , "^(Aether Cloak|Fire Rain|Electrostatic Eddy|Rimefang)") then
# {
#     if ($cyclicinitiated < $unixtime) then matchre Harn ^You feel fully prepared to cast your spell\.$|^Your spell pattern snaps into shape with little preparation\!$
# }
matchre Harn ^You feel fully prepared to cast your spell\.
if ("$pfspellname" != "Fortress of Ice") then matchre PFHarn ^Your spiritwood cube vibrates slightly as the spell pattern you were tracing with it completes\.
echo
echo **** Waiting for Prep ****
pause %pausetime
# put .res
# exit
goto CheckSpellStatus

Pause1:
# if matchre ("$preparedspell" , "^(Aether Cloak|Fire Rain|Electrostatic Eddy|Rimefang)") then
# {
#     if ($cyclicinitiated < $unixtime) then matchre Harn ^You feel fully prepared to cast your spell\.$|^Your spell pattern snaps into shape with little preparation\!$
# }
matchre Harn ^You feel fully prepared to cast your spell\.
if ("$pfspellname" != "Fortress of Ice") then matchre PFHarn ^Your spiritwood cube vibrates slightly as the spell pattern you were tracing with it completes\.
echo
echo **** Waiting for Prep ****
pause
goto CheckSpellStatus
# put .res
# exit

Pause5:
var percreturn WandCheck
var wandreturn Pause52
goto PercCheck

Pause52:
# if matchre ("$preparedspell" , "^(Aether Cloak|Fire Rain|Electrostatic Eddy|Rimefang)") then
# {
#     if ($cyclicinitiated < $unixtime) then matchre Harn ^You feel fully prepared to cast your spell\.$|^Your spell pattern snaps into shape with little preparation\!$
# }
matchre Harn ^You feel fully prepared to cast your spell\.
if ("$pfspellname" != "Fortress of Ice") then matchre PFHarn ^Your spiritwood cube vibrates slightly as the spell pattern you were tracing with it completes\.$
echo
echo **** Waiting for Prep ****
pause 5
# put .res
# exit
goto CheckSpellStatus

PathwayDam:
if ($webbed = 1) then goto %pathwayreturn
matchre PathwayDam ^\.\.\.wait|^Sorry\,
matchre %pathwayreturn ^You focus on manipulating|^You lack the necessary charge|^You are already manipulating
put #class chargewatcher on
put #class nocharge off
if ($pathwayprecise != 0) then put #var pathwayprecise 0
if ($pathwayacc != 0) then put #var pathwayacc 0
if ($pathwaydaming != 1) then put #var pathwaydaming 1
if ($pathwayquick != 0) then put #var pathwayquick 0
if ($pathwaydef != 0) then put #var pathwaydef 0
put pathway focus damage
matchwait

PathwayAcc:
if ($webbed = 1) then goto %pathwayreturn
matchre PathwayAcc ^\.\.\.wait|^Sorry\,
matchre %pathwayreturn ^You focus on stretching an aethereal pathway|^You lack the necessary charge|^You are already manipulating
put #class chargewatcher on
put #class nocharge off
if ($pathwayprecise != 0) then put #var pathwayprecise 0
if ($pathwayacc != 1) then put #var pathwayacc 1
if ($pathwaydaming != 0) then put #var pathwaydaming 0
if ($pathwayquick != 0) then put #var pathwayquick 0
if ($pathwaydef != 0) then put #var pathwaydef 0
put pathway focus accuracy
matchwait

PathwayPrecise:
if ($webbed = 1) then goto %pathwayreturn
matchre PathwayPrecise ^\.\.\.wait|^Sorry\,
matchre %pathwayreturn ^You focus on extending|^You lack the necessary charge|^You are already manipulating
put #class chargewatcher on
put #class nocharge off
if ($pathwayprecise != 1) then put #var pathwayprecise 1
if ($pathwayacc != 0) then put #var pathwayacc 0
if ($pathwaydaming != 0) then put #var pathwaydaming 0
if ($pathwayquick != 0) then put #var pathwayquick 0
if ($pathwaydef != 0) then put #var pathwaydef 0
put pathway focus precise
matchwait

PathwayQuick:
if ($webbed = 1) then goto %pathwayreturn
matchre PathwayQuick ^\.\.\.wait|^Sorry\,
matchre PathwayQuickVars ^You focus on manipulating|^You are already manipulating
matchre %pathwayreturn ^You lack the necessary charge
put #class chargewatcher on
put #class nocharge off
if ($pathwayprecise != 0) then put #var pathwayprecise 0
if ($pathwayacc != 0) then put #var pathwayacc 0
if ($pathwaydaming != 0) then put #var pathwaydaming 0
if ($pathwayquick != 1) then put #var pathwayquick 1
if ($pathwaydef != 0) then put #var pathwaydef 0
put pathway focus quick
matchwait

PathwayQuickVars:
put #var pausetime #evalmath ($pausetime - 3)
goto %pathwayreturn

AutoWandCheck:
if ($combatloop = 0) then goto %ipwandexit
if ($pvptarget = 0) then goto %ipwandexit
var targetvisible AutoWandCheckPV
var targetspoteffect %ipwandexit
var targetnotvisible %ipwandexit
goto CheckVisiblity

AutoWandCheckPV:
if ($magicdefense = 1) then
{
    if ($bgready = 0) then goto %ipwandexit
}
if ($handdamaged = 1) then goto %ipwandexit
if ($invisible = 1) then goto %ipwandexit
if ($kickonly = 1) then goto %ipwandexit
if ($headdamage = 1) then goto %ipwandexit
if ($calmed = 1) then goto %ipwandexit
if ($pfharn != 0) then goto %ipwandexit
if ($hardccattempttimer > $unixtime) then goto %ipwandexit
if matchre ("$rspellname" , "^(Ice Patch|Arc Light|Thunderclap|Tingle)") then goto %ipwandexit
if ($hardccduration >= $unixtime) then goto %ipwandexit
if ($hardccused > 0) then
{
    if ($offbalance != 1) then goto %ipwandexit

}
if ($wormsmist = 1) then goto %ipwandexit
if ($shear = 1) then
{
    var shearreturn IPWandShearAnalysis
    goto CheckShear
}
goto AutoWandCheckPV2

IPWandShearAnalysis:
if (%shear = 1) then goto %ipwandexit
goto AutoWandCheckPV2

AutoWandCheckPV2:
if ($webbed = 1) then goto %ipwandexit
if ("$preparedspell" = "None") then
{
    if ($mana > 39) then
    {
        if ($nomagic != 1) then goto %ipwandexit
    }
}
if ($pvptarget = 0) then goto %ipwandexit
var debiledreturn %ipwandexit
var notdebiledreturn CheckIPWand
goto OpponentDebiledCheck

# if ($pvppet != 0) then goto AutoWandDummy
# if ($pvpdummy != 0) then goto AutoWandDummy
# goto AutoWandCheckPV3

# AutoWandDummy:
# if matchre ("$pvptarget" , "\w+ \w+") then goto AutoWandDummy2
# var newpvpdummy $pvptarget
# goto AutoWandDummy3

# AutoWandDummy2:
# var newpvpdummy $pvptarget
# eval newpvpdummy replacere("%newpvpdummy", ".+ ", "")
# goto AutoWandDummy3

# AutoWandDummy3:
# if matchre ("$roomobjs" , "%newpvpdummy (that is lying down|that appears (immobilized|stunned))") then goto %ipwandexit
# goto CheckIPWand

# AutoWandCheckPV3:
# if matchre ("$roomplayers" , "(?i)\b$pvptarget\w*(?-i)(?:(?!\band\s+[A-Z])[^,])*?\b(lying down|kneeling|sitting|immobilized)\b") then goto %ipwandexit
# if matchre ("$roomplayers" , "a stunned (?i)\b$pvptarget\w*(?-i)") then goto %ipwandexit
# goto CheckIPWand

CheckIPWand:
if ($autoip = 0) then goto CheckSickWand
if ($refdebil = 0) then goto CheckSickWand
if ($iceoff = 1) then goto CheckSickWand
if ($autoipwand = 0) then goto %ipwandexit
if ($ipwandtimer1 >= $unixtime) then
{
    if ($ipwandtimer2 >= $unixtime) then goto %ipwandexit
}
if ($tremtimer > $unixtime) then
{
    if ($wellbalanced = 1) then goto %ipwandexit
    if ($neutralbalance = 1) then goto %ipwandexit
}
goto WandSlap

WandSlap:
var bgreturn AutoWandAttack
var commonattackreturn AutoWandAttack
goto SlapPvPTarget

AutoWandAttack:
put .ipw
exit

CheckSickWand:
if ($willshield = 1) then goto %ipwandexit
if ($spiritdebil = 0) then goto %ipwandexit
if ($autosickw = 0) then goto %ipwandexit
if ($sickwandtimer1 > $unixtime) then
{
    if ($willshield = 1) then goto %ipwandexit
    if ($sickwandtimer2 > $unixtime) then goto %ipwandexit
}
if ($sickwandtimer2 > $unixtime) then
{
    if ($willshield = 1) then goto %ipwandexit
}
goto SickWandSlap

SickWandSlap:
var bgreturn SickWandAttack
var commonattackreturn SickWandAttack
goto SlapPvPTarget

SickWandAttack:
put .sickw
exit

# Should be the exit for RT actions

MagicExit:
var cast 0
var pwshutdownreturn MagicExit2
goto ShutDownPathways

ShutDownPathways:
var pathwaydefreturn ShutDownPathways2
goto CheckPathwayDef

ShutDownPathways2:
if ($pathwaydef = 1) then goto %pwshutdownreturn
if ($pathwayacc = 1) then goto CheckAccPathway
# {
#     var relpathway 1
#     var relreturn PathwayDefenseCheck
#     goto RelSpell
# }
if ($pathwaydaming = 1) then goto ShutDownPathways3
if ($pathwayquick = 1) then goto ShutDownPathways3
if ($pathwayprecise = 1) then goto ShutDownPathways3
goto %pwshutdownreturn

CheckAccPathway:
if ($fron = 1) then goto %pwshutdownreturn
if ($bgready = 1) then goto %pwshutdownreturn
goto ShutDownPathways3

ShutDownPathways3:
var relpathway 1
var relreturn %pwshutdownreturn
goto RelSpell

MagicExit2:
if (%auraready = 1) then
{
    if ($cax != 0) then put #var cax 0
    if ($pvpfull != 0) then put #var pvpfull 0
    var auraready 2
}
if (%notarget = 1) then
{
    if ($pvp != 1) then
    {
        put .wait
        exit
    }
}
var eecheckreturn MagicExit3
goto ExitEECheck

MagicExit3:
if ($combatloop != 0) then
{
    put $combatloop
    exit
}
if ($premagicscript != 0) then
{
    put $premagicscript
    exit
}
if ($cscript != 0) then
{
    put $cscript
    exit
}
if ($cscriptq != 0) then
{
    put $cscriptq
    exit
}
var perced 0
if ($cax != 0) then goto CheckSpellStatus
if ($pvpfull != 0) then goto CheckSpellStatus
if ("$preparedspell" != "None") then goto CheckSpellStatus
if ("$pfspellname" = "Fortress of Ice") then
    {
        if (%auraready = 2) then goto MagicExit4
    }
if ($pfspell != 0) then goto CheckSpellStatus
goto MagicExit4

MagicExit4:
if ("$righthand" = "spiritwood cube") then  goto StowFoc2
if ("$lefthand" = "spiritwood cube") then goto StowFoc2
goto MagicExitFinal

StowFoc2:
matchre StowFoc2 ^\.\.\.wait|^Sorry\,
matchre MagicExitFinal ^You put|^What were you referring to\?$
put put my cube in my $backpack
matchwait

MagicExitFinal:
put #var magicauraloop 0
if (%endauramessage = 1) then
{
    put #echo >Conversation
    put #echo >Conversation #000000 *** Aura Up
    echo
    echo **** Aura Up ****
}
if ($autofoc = 1) then
{
    if ($notm != 1) then
    {
        if ($autoac != 1) then
        {
            if ($tmfoc != 1) then
            {
                if ($autofoc != 2) then put .foca m
            }
        }
    }
}
# if (%cao != 0) then goto FinalMagicExit
if (%auraready != 2) then goto FinalMagicExit
if ($tmfoc != 0) then goto FinalMagicExit
# if ($autofoc != 0) then goto FinalMagicExit
if ($pvptarget = 0) then goto FinalMagicExit
# if ($pvpfull != 1) then goto FinalMagicExit
if ($autobow != 1) then goto FinalMagicExit
var bowreturn FinalMagicExit
goto WieldBowCheck

FinalMagicExit:
put .chill
exit