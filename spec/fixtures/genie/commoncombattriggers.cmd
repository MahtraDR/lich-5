goto %combattriggerreturn

UntriggerCCT:
put #trigger clear
if ($combattriggersloaded != 0) then put #var combattriggersloaded 0
if ($pvptriggers != 0) then put #var pvptriggers 0
goto %combattriggerreturn

SetTriggersCCT:
put #trigger {^A sleek onyx ballista set with banded silvery mechanisms shudders slightly and makes a noisy thrumming as it launches a large rock} {#var balloaded 0} {ballista}
put #trigger {^You feel ready for more firebreathing\.} {#var dbtimer 0;#class db off} {db}
put #trigger {^The.*?onyx ballista grinds with the sound of stone on stone as a large rock rises up|^The.*?onyx ballista is already loaded|^The.*?onyx ballista grinds with the sound of stone on stone as.*?rock settles into place atop the launching device\.} {#var balloaded 1;#var balloadtimer #evalmath (\\$unixtime + 20)} {ballista}
put #trigger {^Spirals of tightly compressed air gather around your forearms} {#var bgready 1;#var bgshot 0;#class bgend on;#class bgstart off} {bgstart}
put #trigger {^The winds encircling your forearms disperse\.$} {#var bgready 0;#var bgcheckskip #evalmath (\\$unixtime + 5);#class bgshot off;#class bgend off} {bgend}
put #trigger {^Swirls of ash, dust and vapor begin to erupt from the ground as the temperature quickly increases\.} {#var fron 1;#var cyclicinitiated #evalmath (\\$unixtime + 30);#class firerain on;#class firerain2 on;#class firerainstart off} {firerainstart}
put #trigger {^The ceiling interferes with the formation of the rain of fire\.} {#var inside 1;#var fron 0;#var aoecyclic 0;#var cyclicinitiated 0;#class firerain off;#class firerain2 off} {firerain2}
put #trigger {^A blazing flame-like droplet} {#class firerain2 off} {firerain2}
put #trigger {^Your link to the Fire Rain matrix} {#var fron 0;#var aoecyclic 0;#class firerain off} {firerain}
put #trigger {^Tapping into the Elemental Plane of Electricity, you begin charging the air} {#var eeon 1;#var paralysischeck #evalmath (\\$unixtime + 15);#var cyclicinitiated #evalmath (\\$unixtime + 30);#class electrostaticeddy on;#class electrostaticeddystart off} {electrostaticeddystart}
put #trigger {^You release your connection to the Elemental Plane of Electricity, allowing the static electricity to dissipate\.} {#var eeon 0;#var aoecyclic 0;#class electrostaticeddy off} {electrostaticeddy}
put #trigger {^A chilling mist begins seeping slowly from your body\.} {#var rimon 1;#var cyclicinitiated #evalmath (\\$unixtime + 30);#class rimefang on;#class rimefangstart off} {rimefangstart}
put #trigger {^The chilling vapor surrounding you dissipates} {#var rimon 0;#class rimefang off} {rimefang}
put #trigger {^Everything seems to darken, and you feel slightly colder as a cloak of aether folds itself possessively about you\.} {#var acon 1;#var cyclicinitiated #evalmath (\\$unixtime + 30);#class aethercloak on;#class aethercloakstart off} {aethercloakstart}
put #trigger {^The dark mantle of aether surrounding you fades away\.} {#var acon 0;#class aethercloak off} {aethercloak}
put #trigger {^The complementary nature of the spell empowers you\.|^Your Grounding Field thrums with energy, empowering you\.} {#var nocharge 0;#class chargewatcher on;#class nocharge off} {nocharge}
put #trigger {^You lack the necessary charge|^Unable to muster any further energy, the complex web of manipulations collapse|^You lack the elemental charge|^You are unable to muster the energy to do that\.} {#var nocharge 1;#var pathwaydaming 0;#var pathwayacc 0;#var pathwayquick 0;#var pathwaydef 0;#var pathwayprecise 0;#class nocharge on;#class chargewatcher off} {chargewatcher}
put #trigger {^The glow slowly fades away from around you\.} {#var tmfoc 0;#class tmfocstart off;#class tmfocwatcher off} {tmfocwatcher}
put #trigger {^You are ready, and brace yourself\!} {#var rubbal 1} {ballista}
put #trigger {^You close to melee range|closes to melee range on you\!$} {#var meleelasttime 1;#var polerange 1;#class retreatwatcher on;#class polerangewatcher off;#class meleewatcher off} {meleewatcher}
put #trigger {^You close to pole weapon range|closes to pole weapon range on you\!$} {#var polerange 1;#class retreatwatcher on;#class meleewatcher on;#class polerangewatcher off} {polerangewatcher}
put #trigger {^You feel fully prepared to cast your spell\.} {#var spellready 1;#class spellprepared off} {spellprepared}
put #trigger {^Your spiritwood cube vibrates slightly as the spell pattern you were tracing with it completes\.} {#var pfspellready 1;#class pfspellprepared off} {pfspellprepared}
put #trigger {^You gesture|^You reach with your fist toward the ground\.|^You raise your fist toward the sun\.|^A crackling mantle of blazing orange-yellow flames surrounds you|^You press your fist firmly against the ground\.|^Tendrils of flame dart along your|^The flames dancing along your fingertips|^You roll your hands in an elliptical|^Your fingerbones phosphoresce hylomorphic blue|^A storm of blinding white lightning arcs from your|^Steadying your breath, you briefly point|^You raise your.*?toast to Glythtide|^You reach out toward.*?with your.*?hand\.|^As the spell dabs at the spirit realm|^You extend your.*?hand toward.*?tendrils of electricity coiling around your|^Electricity crackles about you as you bend the elements to your will\.|^You sense.*?attempting to absorb the spell in your mind.  You successfully weave|^Your spell loses cohesion|^You place your hands on your temples|^The spell pattern collapses} {#if {(\\$pf = 0)} {#class spellprepared off;#class spelllostwatcher off;#if {(\\$tmspellready != 0)} {#var tmspellready 0};#if {(\\$harn != 0)} {#var harn 0};#if {(\\$attackspell != 0)} {#var attackspell 0};#if {(\\$stattackspell != 0)} {#var stattackspell 0};#if {(\\$debil != 0)} {#var debil 0};#if {(\\$sorcery != 0)} {#var sorcery 0};#if {(\\$spellready != 0)} {#var spellready 0};#var prepm 0;#if {(\\$harn1 != 0)} {#var harn1 0};#if {(\\$harn2 != 0)} {#var harn2 0};#if {(\\$harnlimit != 0)} {#var harnlimit 0};#var rspell 0;#var rspellname 0;#var pausetime 0;#if {(\\$focinvoked != 0)} {#var focinvoked 0};#class spellcast off};#if {(\\$pf = 1)} {#class pfspellloss off;#class pfspellprepared off;#var pfprepm 0;#if {(\\$pfharn1 != 0)} {#var pfharn1 0};#if {(\\$pfharn2 != 0)} {#var pfharn2 0};#if {(\\$pfbufftarget != 0)} {#var pfbufftarget 0};#if {(\\$pfharnlimit != 0)} {#var pfharnlimit 0};#var pfspell 0;#var pfspellname 0;#if {(\\$pfharn != 0)} {#var pfharn 0};#var pfspellprepped 0;#var pfpausetime 0;#var pf 0;#if {(\\$pfsorcery != 0)} {#var pfsorcery 0};#if {(\\$pfspellready != 0)} {#var pfspellready 0};#var pfspelltimer 0;#class spellcast off}} {spellcast}
put #trigger {^You lose focus on maintaining the spell pattern you were tracing with a spiritwood cube with intricate truegold accents\.} {#var pfspelllost 1;#var pfspellready 0;#class pfspellprepared off;#class pfspellloss off} {pfspellloss}
put #trigger {^You tap into the mana} {#if {(\\$pf = 0)} {#var harn #evalmath (\\$harn + 1)};#if {(\\$pf = 1)} {#var pfharn #evalmath (\\$pfharn + 1)};#class harness off} {harness}
put #trigger {^You're unconscious|^Wake me up before you \. \. \. never mind, just wake up first\.|^You are still stunned|^You don't seem to be able to|^You can't do that while entangled in a web|^You must be in full command of your faculties|^That takes conscious effort\!|^You need to gain control of your mental faculties} {#script abort all;#send .uncon;#echo ;#echo #000000 **** Recovering ****} {recovery}
put #trigger {focused only where it is facing\.$} {#var rubbal 0} {ballista}
put #trigger {^Your formation of a targeting pattern|^Your target pattern has finished forming around|^Your target pattern has finished forming, but shows signs of misalignment with your current area\.} {#var tmspellready 1;#class tmfulltarget off} {tmfulltarget}
put #trigger {^Your target pattern dissipates|^Your concentration lapses|^Your pattern dissipates|^Your concentration slips for a moment, and your spell is lost|^The mental strain of initiating a cyclic spell so recently prevents you|^You have lost the spell you were preparing\.|until.*has insidiously stolen away.*spell you were shaping\!$} {#var spelllost 1;#var tmspellready 0;#var spellready 0;#class tmfulltarget off;#class spelllostwatcher off} {spelllostwatcher}
put #trigger {^The air around you shimmers with a blinding yellow luminescence.  The scintillating light writhes and twists, abruptly coalescing into a translucent field before blinking out of sight\.} {#if {(\\$mafhit != 0)} {#var mafhit 0};#class mafrefresh off} {mafrefresh}
put #trigger {^You feel indomitable as Redeemer's Pride takes hold of you, bolstering you with unshakeable confidence\.} {#if {(\\$reprhit != 0)} {#var reprhit 0};#class reprrefresh off} {reprrefresh}
put #trigger {^The air around you solidifies into a blinding yellow luminescence} {#var mafhit #evalmath (\\$mafhit + 1)}
put #trigger {^Your uncanny confidence is weakened slightly beneath the onslaught\.|^Your uncanny confidence crumbles beneath the onslaught\.} {#var reprhit #evalmath (\\$reprhit + 1)}

put #trigger {^You raise the.*?up, and.*?glow surrounds it\.} {#var tmfoc 1;#class tmfocwatcher on;#class tmfocstart off} {tmfocstart}

put #trigger {^With a sharp overhand motion, you send a focused blast of air} {#var bgshot #evalmath (\\$bgshot + 1);#class bgshot off} {bgshot}

put #trigger {^\[You're.*?(incredibly|adeptly|nimbly)\sbalanced} {#if {(\\$wellbalanced != 1)} {#var wellbalanced 1};#if {(\\$neutralbalance != 0)} {#var neutralbalance 0};#if {(\\$offbalance != 0)} {#var offbalance 0}}
put #trigger {^\[You're.*?(solidly\sbalanced|slightly\soff\sbalance)} {#if {(\\$wellbalanced != 0)} {#var wellbalanced 0};#if {(\\$neutralbalance != 1)} {#var neutralbalance 1};#if {(\\$offbalance != 0)} {#var offbalance 0}}
put #trigger {^\[You're.*?(off balance|somewhat off balance|badly balanced|very badly balanced|extremely imbalanced|hopelessly unbalanced|completely imbalanced)} {#if {(\\$wellbalanced != 0)} {#var wellbalanced 0};#if {(\\$neutralbalance != 0)} {#var neutralbalance 0};#if {(\\$offbalance != 1)} {#var offbalance 1}}

put #var combattriggersloaded 1
put #class recovery on
put #class bgstart off
if ($SpellTimer.BlufmorGaraen.active = 0) then 
{
    put #class bgend off
    if ($bgready != 0) then put #var bgready 0
}
put #class firerainstart off
if ($fron != 1) then put #class firerain off
put #class electrostaticeddystart off
if ($eeon != 1) then put #class electrostaticeddy off
put #class rimefangstart off
if ($rimon != 1) then put #class rimefang off
put #class aethercloakstart off
if ($acon != 1) then put #class aethercloak off
put #class nocharge off
if ($tmfoc != 1) then put #class tmfocwatcher off
if ($pfspellprepped != 1) then put #class pfspellprepared off
put #class retreatwatcher off
if ("$preparedspell" = "None") then put #class spellprepared off
put #class spellcast off
if ("$preparedspell" = "None") then put #class spelllostwatcher off
if ($stattackspell != 1) then
{
    if ($attackspell != 1) then put #class tmfulltarget off
}
if ($dbtimer > $unixtime) then put #class db on
else put #class db off
if ($nocharge = 0) then put #class nocharge off
if ($SpellTimer.ManifestForce.active != 1) then put #class mafrefresh off
if ($SpellTimer.RedeemersPride.active != 1) then put #class reprrefresh off
put #class chargewatcher on
put #class meleewatcher on
put #class polerangewatcher on
put #class tmfocstart off
put #class bgshot off
goto %combattriggerreturn