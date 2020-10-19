#!/bin/bash
#
# cool-retro-term support for tetris.sh
# Author: Rojen Zaman <rojen@riseup.net>
# License: WTFPL

stdout="/dev/null"                                                                      # default stdout, optional verbose mode is /dev/stdout
script_dir=$(dirname $(readlink -f $0))                                                 # script dir, it is required for cool-retro-term
pl=${VARIABLE:-bash}                                                                    # if pl not specified return bash
hl=${VARIABLE:-english}                                                                 # default language for bash
console_profile=${VARIABLE:-Monochrome Green}                                           # default console profile
available_languages=$(ls -I README.md $script_dir/lang/ 2>/dev/null | cut -d. -f1)      # https://github.com/rojen/tetris/blob/master/lang/README.md

usage_message_0() {
printf "%s\n" \
    "" \
    "usage : $0 [-h] [-v] [-s PL] [-c console]" \
    "" \
    " -h     help" \
    " -v     verbose"
}

usage_message_1() {
printf "%s\n" \
    "" \
    " -s     select programming language of tetris" \
    "    c" \
    "    java" \
    "    javascript" \
    "    perl" \
    "    python" \
    "    ruby" \
    "" \
    "    bash [-l language]  select human language of tetris (only work with bash):"
}

usage_message_2() {
printf "%s\n" \
    "" \
    "english" \
    "$available_languages" \
    ""
}

usage_message_3() {
printf "%s\n" \
    "" \
    " -c    console profile" \
    "    1      Default Amber" \
    "    2      Monochrome Green" \
    "    3      Green Scanlines" \
    "    4      Default Pixelated" \
    "    5      Apple ][" \
    "    6      Vintage" \
    "    7      IBM Dos" \
    "    8      IBM 3278" \
    "    9      Futuristic"
}

# usage
usage() {
    usage_message_0
    usage_message_1
    usage_message_2
    usage_message_3
    exit 0
}

# check cool-retro-term and xdg-open commands
check_commands() {
    local message=()
    command -v xdg-open &>$stdout || message+="xdg-open could not be found, please install it"
    command -v cool-retro-term &>$stdout || message+="cool-retro-term could not be found, please install it"
    [ ${#message} == 0 ] && return 0
    printf "%s\n" "${message[@]}"
    echo "Are you sure you are using GNU operating system ;-)?"
    exit 1
}

# check option arguments
check_hl() {
    [ "$pl" != "bash" ] && {                                                            # default language is english, see 10th line
        echo "only bash support internationalization, aborting."
        usage_message_2
        exit 1
    }
}

check_pl() {
    [[ "$pl" =~ ^(bash|c|java|javascript|perl|python|ruby)$ ]] || {                     # check pl
        echo "$pl is not supported yet, aborting."
        usage_message_1
        usage_message_3
        exit 1                                                                          # stop if wrong pl given
    }
}

check_console_profile() {
    [[ $console_profile =~ ^(1|2|3|4|5|6|7|8|9)$ ]] || {                                # check console profile
        echo "console profile $console_profile not finded."
        usage_message_3
        exit 1
    }
}

# music loop
run_music() {
    while : ; do                                                                        # play music with xdg-open
        xdg-open "$script_dir/media/tetris-theme.ogg" &>$stdout
        sleep 85                                                                        # sleep 85, 85 is total of music time.
    done
}

# functions for execute tetris.(*)                                                      # set exec_tetris for user specification
load_exec() {
    [ "$pl" == "bash" ] && exec_tetris="$script_dir/tetris.sh -l $hl"
    [ "$pl" == "c" ] && exec_tetris="gcc $script_dir/tetris.c -o /tmp/tetris && /tmp/tetris"
    [ "$pl" == "java" ] && exec_tetris="javac -d /tmp/ $script_dir/Tetris.java && java -classpath /tmp Tetris"
    [ "$pl" == "javascript" ] && exec_tetris="node $script_dir/tetris.js"
    [ "$pl" == "perl" ] &&  exec_tetris="perl $script_dir/tetris.pl"
    [ "$pl" == "python" ] &&  exec_tetris="python $script_dir/tetris.py"
    [ "$pl" == "ruby" ] &&  exec_tetris="ruby $script_dir/tetris.rb "
}

# load console profile, defaul is Monochrome Green
load_console_profile() {
    [ "$console_profile" = "1" ] && console_profile="Default Amber"
    [ "$console_profile" = "2" ] && console_profile="Monochrome Green"
    [ "$console_profile" = "3" ] && console_profile="Green Scanlines"
    [ "$console_profile" = "4" ] && console_profile="Default Pixelated"
    [ "$console_profile" = "5" ] && console_profile="Apple ]["
    [ "$console_profile" = "6" ] && console_profile="Vintage"
    [ "$console_profile" = "7" ] && console_profile="IBM Dos"
    [ "$console_profile" = "8" ] && console_profile="IBM 3278"
    [ "$console_profile" = "9" ] && console_profile="Futuristic"
}

# main script
main() {
    echo "tetris theme is loading.."                                                    # music message
    run_music &                                                                         # run music loop at background
    sleep 1                                                                             # sleep 1 for script run after playing the music.
    cool-retro-term \
    --fullscreen \
    --profile "$console_profile" \
    -e bash -c \
    "$exec_tetris;read -rsn1 -p 'Press any key to exit'" &>$stdout                      # execute specified pl - press any key to exit  / if there is a execute error it shows the reason - default console profile
    echo "exit from cool-retro-term / $console_profile"                                 # exit retro message
    kill $! &>$stdout                                                                   # kill music loop
    fuser -k -TERM $script_dir/media/tetris-theme.ogg &>$stdout                         # fuse music after program stopped
    echo "music stopped.."
}

while getopts ":hvs:l:c:" opt; do                                                       # check script
  case ${opt} in
    h ) usage ;;
    v ) stdout="/dev/tty" ;;                                                            # verbose mode
    s ) pl=${OPTARG}; check_pl ;;                                                       # set and check pl specification
    l ) hl=${OPTARG}; check_hl ;;                                                       # set and check hl specification
    c ) console_profile=${OPTARG}; check_console_profile ;;                             # set and check console profile
    : ) echo -e "Missing option argument for -$OPTARG\n"; usage; exit 1 ;;
  esac
done

check_commands                                                                          # check commands before run script
set -u                                                                                  # return error if string null
load_console_profile                                                                    # load console profile
load_exec                                                                               # load PL's functions
main                                                                                    # program start here
