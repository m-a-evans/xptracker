**Xpt**

Xpt generates a small, chat based report that displays when loading into the world (the common use case is entering/leaving instances).

This addon provides an extremely simple and basic tracker for things like:
* experience points
* reputation
* money

This report covers what has been gained (or lost) over the current session, as well as offering estimated times for achieving the next rank or level. A sessions begins when the player logs in, and lasts until logout, ui ```/reload```, or the reset command is issued.

The following commands are available for xpt:
* ```/xpt``` - generates the report on demand.
* ```/xpt setrep <id>``` - sets the currently tracked reputation to be displayed with the report, where ```<id>``` is the id of the faction to track. This tracked reputation will appear in the ```/xpt``` report, and which reputation is tracked will persist through logouts.
* ```/xpt listrep``` - lists all reputations known by your character along with their corresponding ```<id>```.
* ```/xpt rep``` - lists all reputation data tracked in the current session.
* ```/xpt reset``` - resets the current session.
* ```/xpt mute``` - toggles a mute for the report, in case you don't want to hear about it just now.