#!/bin/bash
#
# cool-retro-term support for tetris.sh
# Author: Rojen Zaman <rojen@riseup.net>
# License: WTFPL

stdout="/dev/null"                                                                      # default stdout, optional verbose mode is /dev/stdout
script_dir=$(dirname $(readlink -f $0))                                                 # script dir, it is required for cool-retro-term
pl=${VARIABLE:-bash}                                                                    # if pl not specified return bash
hl=${VARIABLE:-english}                                                                 # default language for bash
available_languages=$(ls -I README.md $script_dir/lang/ 2>/dev/null | cut -d. -f1)      # https://github.com/rojen/tetris/blob/master/lang/README.md

# usage
usage() {
    printf "%s\n" \
        "" \
        "usage : $0 [-h] [-v] [-s PL]" \
        "" \
        " -h     help" \
        " -v     verbose" \
        "" \
        " -s     select programming language of tetris" \
        "    c" \
        "    java" \
        "    javascript" \
        "    perl" \
        "    python" \
        "    ruby" \
        "" \
        "    bash [-l language]  select human language of tetris (only work with bash):" \
        "" \
        "english" \
        "$available_languages"
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
check_pl() {
    [[ "$pl" =~ ^(bash|c|java|javascript|perl|python|ruby)$ ]] || {                     # check pl       
        echo "$pl is not supported yet, aborting."
        exit 1                                                                          # stop if wrong pl given
    }
}

check_hl() {
    [ "$pl" != "bash" ] && {                                                            # default language is english, see 10th line
        echo "only bash support internationalization, aborting."
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

# scripts for execute tetris.(*)                                                        # cool-retro-term does not support multiple commands or arguments
load_exec() {
    exec_bash() {
        echo "$script_dir/tetris.sh -l $hl" >>$script_dir/retro_term_command.sh
    }
    exec_c() {
        echo "gcc $script_dir/tetris.c -o /tmp/tetris && /tmp/tetris" >>$script_dir/retro_term_command.sh
    }
    exec_java() {
        echo "javac -d /tmp/ $script_dir/Tetris.java && java -classpath /tmp Tetris" >>$script_dir/retro_term_command.sh
    }
    exec_javascript() {
        echo "node $script_dir/tetris.js" >>$script_dir/retro_term_command.sh
    }
    exec_perl() {
        echo "perl $script_dir/tetris.pl" >>$script_dir/retro_term_command.sh
    }
    exec_python() {
        echo "python $script_dir/tetris.py" >>$script_dir/retro_term_command.sh
    }
    exec_ruby() {
        echo "ruby $script_dir/tetris.rb " >>$script_dir/retro_term_command.sh
    }
}

# main script
main() {
    echo "#!/bin/bash" > $script_dir/retro_term_command.sh                              # because cool-retro-term should be able to see that the file is a bash script
    load_exec && chmod 775 $script_dir/retro_term_command.sh                            # load PL's functions, given 5 to other users because for the cool-retro-term can execute it
    exec_$pl                                                                            # execute the specified pl
    echo "read -rsn1 -p 'Press any key to exit'" >> $script_dir/retro_term_command.sh   # press any key to exit  / if there is a execute error it shows the reason
    echo "tetris theme is loading.."                                                    # music message
    run_music &                                                                         # run music loop at background
    sleep 1                                                                             # sleep 1 for script run after playing the music.
    cool-retro-term \
    --fullscreen \
    --profile "Monochrome Green" \
    -e "$script_dir/retro_term_command.sh" &>$stdout                                    # cool-retro-term deos not support multiple arguments or commands
    echo "exit from cool-retro-term"                                                    # ext retro message
    kill $! &>$stdout                                                                   # kill music loop
    fuser -k -TERM $script_dir/media/tetris-theme.ogg &>$stdout                         # fuse music after program stopped
    echo "music stopped.."
}

while getopts ":hvs:l:" opt; do                                                         # check script
  case ${opt} in
    h ) usage ;;
    v ) stdout="/dev/tty" ;;                                                            # verbose mode
    s ) pl=${OPTARG} ;;
    l ) hl=${OPTARG} ;;
    : ) echo -e "Missing option argument for -$OPTARG\n"; usage; exit 1 ;;
  esac
done


check_commands                                                                          # check commands before run script
set -u                                                                                  # return error if string null
check_hl                                                                                # check hl specifion
check_pl                                                                                # check pl specifion
main                                                                                    # program start here
rm $script_dir/retro_term_command.sh &>$stdout                                          # delete trash file
