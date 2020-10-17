if you want add new language;

  Create `<language_you_added.sh>` file, at that dir.

It name will be such as english.sh

and run **tetris.sh** as:
```text
./tetris.sh -l english
```
Tetris script will automatically identify the local variables you added.


EXAMPLE `language_you_added.sh` file:
```bash
local_LinesCompleted="Lines completed: ";
local_Level="Level:           ";
local_Score="Score:           ";
local_UseCursorKeys="  Use cursor keys";
local_Or="       or";
local_Rotate="    s: rotate";
local_LeftRight="a: left,  d: right";
local_Drop="    space: drop";
local_Quit="      q: quit";
local_ToggleColor="  c: toggle color";
local_ToggleShowNext="n: toggle show next";
local_ToggleThisHelp="h: toggle this help";
local_GameOver="Game over!";
```
