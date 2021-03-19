# Vigilante City
Fantasy Grounds extension for Index Card RPG supporting Vigilante City.

This extension makes the following changes:
* Adds a Vigilante Point tracker to main tab of the PC sheet
* Adds STUN as another health resource. 
* Replaces the "Effort" button with an "HP" and "SP" button. These buttons are mutually exclusive, and allow treating normal dice as if it were effort of the selected type.
* Adds option to Attempt rolls of Actions (on the Actions tab) to specify whether that actions cost should be deducted from stun or HP
* Adds an option to Effort rolls of Actions (on the Actions tab) to specify whether the effort should be applied to stun or HP.
* NPC actions now read if effort is dealt to HP or stun based on whether an effort type or die roll is followed by the following (ignoring casing):
  * Hit points
  * HP
  * Sun
  * SP
 
 
## Example: NPC Action
The text "1d12 HP damage" will roll as 1d12 HP effort. "1d12 SP" will deal 1d12 stun damage. Dice, by themselves, are treated as stun efort,
so "1d12 damage" will be treated as 1d12 stun damage.

## Stun
Vigilante City adds a secondary health resource for all characters: STUN. A number of changes have been made to support this.
* The combat tracker now displays actor's current wounds and current stun damage. It does not show their maximum HP or stun
* All effort is defaulted to dealing damage to a character's stun.
* The health status displayed for players in chat and the combat tracker refers to an actor's stun damage, not HP damage.
* Damage reduction and damage threshold stats both affect HP and stun equally.
* Actors that take hit points damage also lose 1 stun. This is denoted in chat with the tag '[DRAIN]' (there is a game option to disable this)
* Actors that would normally 0 stun damage due to damage resistance always take a minimum of 1 damage, denoted in chat with the tag '[DRAIN]' (there is a game option to disabl
* If an attempt with a target misses, the system remembers that, and the next effort roll against the same target does 1 stun. This is denote in chat with the tag '[DRAIN]'
* Stun damage cannot be applied to chunks on an NPC
* Creatures whose stun damage equals their max stun have the effet "Fatigued" applied to them
* Creatures whose stun damage exceeds their max stun have the effect "Stunned" applied to them

## Compatibility
This extension is compatibile with all other ICRPG extensions, and is intended to be used in conjuction with the [Mastery](https://github.com/Gtaray/FG_ICRPG_Mastery/releases) extension
