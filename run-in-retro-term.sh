#!/bin/bash
#
# cool-retro-term support for tetris.sh
# Author: Rojen Zaman <rojen@riseup.net>
# License: WTFPL

set -u                                                    # return error if string null
stdout="/dev/null"                                        # default stdout, optional verbose mode is /dev/stdout
script_dir=$(cd $(dirname $0) && pwd)                     # script dir, it is require for cool-retro-term

# usage
usage() {
cat <<- EOT    
usage : $0 [-h] [-v]
-h   help
-v   verbose
EOT
exit 0
}

# check cool-retro-term and xdg-open commands
check_commands() {
    if ! command -v xdg-open &>$stdout
    then
        echo -e "xdg-open could not be found, please install it.\naborting."
        echo "if sure you at the gnu operating systems?  :)"
        exit 1
    fi

    if ! command -v cool-retro-term &>$stdout
    then
        echo -e "cool-retro-term could not be found, please install it.\naborting."
        exit 1
    fi
}

# main script
main() {
    run_music() {
        while :
        do                                                      # play music with xdg-open
            xdg-open "$script_dir/media/tetris-theme.ogg" &>$stdout
            sleep 85                                           # sleep 85, 85 is total of music time.
        done
    }
    echo "tetris theme is loading.."                            # music message
    run_music &                                                 # run music loop at background
    sleep 1;                                                    # sleep 1 for script run after playing the music.
    cool-retro-term --fullscreen --profile "Monochrome Green" -e "$script_dir/tetris.sh" &>$stdout
    echo "exit from cool-retro-term"

    kill $! &>$stdout                                           # kill music loop
    fuser -k -TERM $script_dir/media/tetris-theme.ogg &>$stdout # fuse music after program stopped
    echo "music stopped.."
}

while getopts ":hv" opt; do                                     # check script
  case ${opt} in
    h )
        usage
        exit 0
      ;;  
    v )
        stdout="/dev/stdout"                                    # verbose mode
      ;;
  esac
done 

check_commands                                                  # check commands before run script
main                                                            # program start here