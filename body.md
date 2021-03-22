[ADDED] A new game option to specify what kind of damage (stun or HP) can affect NPC chunks. The default is all damage effects chunks equally.
[ADDED] A new effect: STUNREGEN. Functions like REGEN, but for STUN.
[ADDED] A new effect: STUNDEGEN. Functions like DEGEN, but for STUN.

[UPDATED] Notifications of damage in chat are now tagged with [STUN] if the damage was to SP.
[UPDATED] Effort rolls tagged with both [STUN] and [HP] will deal both stun and hp damage
[UPDATED] NPCs with 0 maximum stun are now IMPERVIOUS to stun damage
[UPDATED] NPCs with 0 maximum stun no longer suffer DRAIN, and no chat message is sent
[UPDATED] NPC Actions now detect when damage should be dealt to both HP and SP.

[FIXED] Stun field on NPC sheet is now correctly listed after HP
[FIXED] Heal rolls on the PC action sheet now have a select box for STUN or HP healing
[FIXED] The HP and SP modifier buttons now correctly work with actor effort rolls, converting whatever type of damage the roll was to the selected button. i.e. turning STUN  effort into HP effort, or visa versa.
[FIXED] NPC effort rolls are now properly tagged with [STUN] by default
[FIXED] Actor status now displays 'Fatigued' if their current stun damage is equal to maximum stun, and 'Stunned' if current stun is greater than maximum stun