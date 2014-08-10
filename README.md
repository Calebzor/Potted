Potted
======

An addon to remind you if you are missing consumables during raid combat. /potted

##Features
* Moveable
* Icon size can be changed
* There can be a horizontal padding between icons ( space )
* Time threshold: If a buff type has less than this value time remaining (in seconds), then it'll show the icon. Of course it'll be also shown if you don't have it on. It is recommended to have this be longer than the duration of the 2nd buff you get from like reactive boost ( 10 sec ).
* Party member in combat for show: Changing this is the best way to disable the addon for 5 man content. Basically this sets the amount of group members (including yourself) required to be in combat for the displays to even show up.
* Opacity
* Color overlay for time threshold progress
* Font customization options
* Containers can be customized to what you want them to display. If you two to display the same, only the first one in order will show.

##Configuration window slash command:
> /potted

> /Potted

##READ ME!
If you feel like a buff is not being tracked or not being correctly associated to the correct buff type then it is most likely because the buff's spellId is missing from the addon. Even tho I'm a technologist myself and I spent some time looking up the spellIds for the most common raid buffs it is very possible I missed some. So if you found something missing do the following to help improve the addon:
 
	1) Make sure you have the buff on you.
	2) Mouse over the buff on your buff bar and write the buffs name into the input box just below this text (or at least part of the buff's name).
	3) Once you wrote in the buff's name (and hit enter) press the button ("Click me!") next to the input box ( you must still have the buff on you ).
	4) You'll get a debug print in your chat. Write this down and post it on curse as a comment for the addon. ( or e-mail me at: calebzor@gmail.com or tweet at me: @CalebEnsidia)
 
##How to install:
Extract the Potted.zip file into the Wildstar Addon folder ( which can be found at %APPDATA%\Roaming\NCSOFT\WildStar\Addons by default, if you can't find the Addons folder, then create it! )