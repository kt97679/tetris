#!/usr/bin/perl
use strict;
use 5.010;
use Time::HiRes qw(time);
use POSIX qw(:termios_h strftime);

my ($RED, $GREEN, $YELLOW, $BLUE, $FUCHSIA, $CYAN, $WHITE) = (1, 2, 3, 4, 5, 6, 7);

my $PLAYFIELD_W = 10;
my $PLAYFIELD_H = 20;
my $PLAYFIELD_X = 30;
my $PLAYFIELD_Y = 1;
my $BORDER_COLOR = $YELLOW;

my $HELP_X = 58;
my $HELP_Y = 1;
my $HELP_COLOR = $CYAN;

my $SCORE_X = 1;
my $SCORE_Y = 2;
my $SCORE_COLOR = $GREEN;

my $NEXT_X = 14;
my $NEXT_Y = 11;

my $GAMEOVER_X = 1;
my $GAMEOVER_Y = $PLAYFIELD_H + 3;

my $INITIAL_MOVE_DOWN_DELAY = 1.0;
my $DELAY_FACTOR = 0.8;
my $LEVEL_UP = 20;

my $NEXT_EMPTY_CELL = "  ";
my $PLAYFIELD_EMPTY_CELL = " .";
my $FILLED_CELL = "[]";

my @COLORS = ($RED, $GREEN, $YELLOW, $BLUE, $FUCHSIA, $CYAN, $WHITE);

my $use_color = 1;
my $tetris_delay = $INITIAL_MOVE_DOWN_DELAY;
my $help_visible = 1;
my $next_piece_visible = 1;
my @playfield = 0 x $PLAYFIELD_H;
my %next_piece;
my %current_piece;
my $last_down_time = time();

sub xyprint {
    my ($x, $y, $s) = @_;
    print "\e[${y};${x}H${s}";
}

sub show_cursor {
    print "\e[?25h";
}

sub hide_cursor {
    print "\e[?25l";
}

sub set_fg {
    my ($c) = @_;
    print "\e[3${c}m" if ($use_color);
}

sub set_bg {
    my ($c) = @_;
    print "\e[4${c}m" if ($use_color);
}

sub reset_colors {
    print "\e[0m";
}

sub set_bold {
    print "\e[1m";
}

sub clear_screen {
    print "\e[2J";
}

sub get_random_color {
    return $COLORS[rand @COLORS];
}

sub draw_help {
    my @text = (
        "  Use cursor keys",
        "       or",
        "    s: rotate",
        "a: left,  d: right",
        "    space: drop",
        "      q: quit",
        "  c: toggle color",
        "n: toggle show next",
        "h: toggle this help"
    );
    my $spaces = "                   ";

    if ($help_visible) {
        set_fg($HELP_COLOR);
        set_bold();
    }
    for my $i (0 .. $#text) {
        xyprint($HELP_X, $HELP_Y + $i, $help_visible ? $text[$i] : $spaces);
    }
    if ($help_visible) {
        reset_colors();
    }
}

sub draw_border {
    my $x1 = $PLAYFIELD_X - 2;
    my $x2 = $PLAYFIELD_X + $PLAYFIELD_W * 2;
    my $y = 0;

    set_bold();
    set_fg($BORDER_COLOR);
    for (my $i = 0; $i < $PLAYFIELD_H + 1; $i++) {
        $y = $i + $PLAYFIELD_Y;
        xyprint($x1, $y, "<|");
        xyprint($x2, $y, "|>");
    }

    $y = $PLAYFIELD_Y + $PLAYFIELD_H;
    for (my $i = 0; $i < $PLAYFIELD_W; $i++) {
        $x1 = $i * 2 + $PLAYFIELD_X;
        xyprint($x1, $y, "==");
        xyprint($x1, $y + 1, "\\/");
    }
    reset_colors();
}

sub update_score {
    my ($complete_lines) = @_;
    state $lines_completed = 0;
    state $score = 0;
    state $level = 1;

    $lines_completed += $complete_lines;
    $score += ($complete_lines * $complete_lines);
    if ($score > $LEVEL_UP * $level) {
        $tetris_delay *= $DELAY_FACTOR;
        $level++;
    }
    set_bold();
    set_fg($SCORE_COLOR);
    xyprint($SCORE_X, $SCORE_Y,     "Lines completed: $lines_completed");
    xyprint($SCORE_X, $SCORE_Y + 1, "Level:           $level");
    xyprint($SCORE_X, $SCORE_Y + 2, "Score:           $score");
    reset_colors();
}

my ($term, $oterm, $echo, $noecho, $fd_stdin);

$fd_stdin = fileno(STDIN);
$term     = POSIX::Termios->new();
$term->getattr($fd_stdin);
$oterm     = $term->getlflag();

$echo     = ECHO | ECHOK | ICANON;
$noecho   = $oterm & ~$echo;

sub cbreak {
    $term->setlflag($noecho);
    $term->setcc(VTIME, 1);
    $term->setattr($fd_stdin, TCSANOW);
}

sub cooked {
    $term->setlflag($oterm);
    $term->setcc(VTIME, 0);
    $term->setattr($fd_stdin, TCSANOW);
}

sub readkey {
    my ($delay) = @_;
    my $key = '';
    cbreak();
    my $rin = '';
    my $rout;
    vec($rin, fileno(STDIN), 1) = 1;
    $delay = 0 if $delay < 0;
    my $nfound = select($rout=$rin, undef, undef, $delay);
    sysread(STDIN, $key, 1) if ($nfound);
    cooked();
    return $key;
}

sub toggle_help {
    $help_visible ^= 1;
    draw_help();
}

sub toggle_color {
    $use_color ^= 1;
    redraw_screen();
}

sub toggle_next {
    $next_piece_visible ^= 1;
    $next_piece{"visible"} = $next_piece_visible;
    draw_piece(%next_piece);
}

sub cmd_quit {
    xyprint($GAMEOVER_X, $GAMEOVER_Y, "Game over!");
    xyprint($GAMEOVER_X, $GAMEOVER_Y + 1, "");
    show_cursor();
    exit();
}

sub position_ok {
    my ($new_position_ref) = @_;

    for my $c (get_cells(\%current_piece, $new_position_ref)) {
        my ($x, $y) = @$c;
        if ($y < 0 || $y >= $PLAYFIELD_H || $x < 0 || $x >= $PLAYFIELD_W || ((@playfield[$y] >> ($x * 3)) & 7) != 0) {
            return 0;
        }
    }
    return 1;
}

sub move {
    my ($dx, $dy, $dz) = @_;
    my %new_position = (
        "x" => $current_piece{"x"} + $dx,
        "y" => $current_piece{"y"} + $dy,
        "z" => ($current_piece{"z"} + $dz) % $current_piece{"symmetry"}
    );

    if (position_ok(\%new_position)) {
        $current_piece{"visible"} = 0;
        draw_piece(%current_piece);
        $current_piece{"x"} = $new_position{"x"};
        $current_piece{"y"} = $new_position{"y"};
        $current_piece{"z"} = $new_position{"z"};
        $current_piece{"visible"} = 1;
        draw_piece(%current_piece);
        return 1;
    }
    return ($dy == 0);
}

sub cmd_left {
    move(-1, 0, 0);
}

sub cmd_right {
    move(1, 0, 0);
}

sub cmd_rotate {
    move(0, 0, 1);
}

sub line_complete {
    my ($line) = @_;

    for (my $i = 0; $i < $PLAYFIELD_W; $i++) {
        if ((($line >> ($i * 3)) & 7) == 0) {
            return 0;
        }
    }
    return 1;
}

sub process_complete_lines {
    my $complete_lines = 0;

    for (my $i = 0; $i < $PLAYFIELD_H; $i++) {
        if (line_complete($playfield[$i])) {
            for (my $j = $i; $j > 0; $j--) {
                $playfield[$j] = $playfield[$j - 1];
            }
            $playfield[0] = 0;
            $complete_lines++;
        }
    }
    return $complete_lines;
}

sub flatten_piece {
    my $color = $current_piece{"color"};

    for my $c (get_cells(\%current_piece)) {
        my ($x, $y) = @$c;
        $playfield[$y] |= ($color << ($x * 3));
    }
}

sub process_fallen_piece {
    flatten_piece();
    my $complete_lines = process_complete_lines();
    if ($complete_lines > 0) {
        update_score($complete_lines);
        draw_playfield();
    }
}

sub cmd_down {
    $last_down_time = time();
    if (move(0, 1, 0) == 1) {
        return 1;
    }
    process_fallen_piece();
    get_current_piece();
    return 0;
}

sub cmd_drop {
    while (cmd_down()) {
    }
}

sub draw_piece {
    my (%piece) = @_;

    if ($piece{"visible"}) {
        set_fg($piece{"color"});
        set_bg($piece{"color"});
    }
    for my $c (get_cells(\%piece)) {
        my ($x, $y) = @$c;
        xyprint($x * 2 + $piece{"origin_x"}, $y + $piece{"origin_y"}, $piece{"visible"} ? $FILLED_CELL : $piece{"empty_cell"});
    }
    if ($piece{"visible"}) {
        reset_colors();
    }
}

sub get_cells {
    my ($piece_ref, $new_position_ref) = @_;
    my %piece = %$piece_ref;
    my %new_position = ();
    %new_position = %$new_position_ref if $new_position_ref;
    my @cells = ();
    my $x = $new_position{"x"} || $piece{"x"};
    my $y = $new_position{"y"} || $piece{"y"};
    my $z = $new_position{"z"} || $piece{"z"};
    my $data = $piece{"data"}[$z];

    for (my $i = 0; $i < 4; $i++) {
        push @cells, [$x + (($data >> (4 * $i)) & 3), $y + (($data >> (4 * $i + 2)) & 3)];
    }
    return @cells;
}

sub get_next_piece {
    my @piece_data = (
        [ 0x1256 ],
        [ 0x159d, 0x4567 ],
        [ 0x4512, 0x0459 ],
        [ 0x0156, 0x1548 ],
        [ 0x159a, 0x8456, 0x0159, 0x2654 ],
        [ 0x1598, 0x0456, 0x2159, 0xa654 ],
        [ 0x1456, 0x1596, 0x4569, 0x4159 ]
    );
    my @data = @{$piece_data[rand @piece_data]};
    my $symmetry = scalar @data;
    %next_piece = (
        "data" => \@data,
        "origin_x" => $NEXT_X,
        "origin_y" => $NEXT_Y,
        "x" => 0,
        "y" => 0,
        "color" => get_random_color(),
        "symmetry" => $symmetry,
        "z" => rand $symmetry,
        "empty_cell" => $NEXT_EMPTY_CELL,
        "visible" => $next_piece_visible
    );
    draw_piece(%next_piece);
}

sub draw_playfield {
    for (my $y = 0; $y < $PLAYFIELD_H; $y++) {
        xyprint($PLAYFIELD_X, $PLAYFIELD_Y + $y, "");
        for (my $x = 0; $x < $PLAYFIELD_W; $x++) {
            my $color = (($playfield[$y]) >> ($x * 3)) & 7;
            if ($color != 0) {
                set_bg($color);
                set_fg($color);
                printf($FILLED_CELL);
                reset_colors();
            } else {
                printf($PLAYFIELD_EMPTY_CELL);
            }
        }
    }
}

sub redraw_screen {
    clear_screen();
    update_score(0);
    draw_help();
    draw_border();
    draw_playfield();
    draw_piece(%next_piece);
    draw_piece(%current_piece);
}

sub get_current_piece {
    %current_piece = %next_piece;
    $current_piece{"x"} = ($PLAYFIELD_W - 4) / 2;
    $current_piece{"y"} = 0;
    $current_piece{"origin_x"} = $PLAYFIELD_X;
    $current_piece{"origin_y"} = $PLAYFIELD_Y;
    $current_piece{"empty_cell"} = $PLAYFIELD_EMPTY_CELL;
    $current_piece{"visible"} = 1;
    if (!position_ok()) {
        cmd_quit();
    }
    $next_piece{"visible"} = 0;
    draw_piece(%next_piece);
    draw_piece(%current_piece);
    get_next_piece();
}

select STDOUT;
$| = 1;

my @key = (0, 0, 0);

my %commands = (
    "" => \&cmd_down,
    "q" => \&cmd_quit,
    "C" => \&cmd_right,
    "d" => \&cmd_right,
    "D" => \&cmd_left,
    "a" => \&cmd_left,
    "A" => \&cmd_rotate,
    "s" => \&cmd_rotate,
    " " => \&cmd_drop,
    "h" => \&toggle_help,
    "n" => \&toggle_next,
    "c" => \&toggle_color
);

get_next_piece();
get_current_piece();
redraw_screen();
hide_cursor();

while(1) {
    shift @key;
    push @key, readkey($last_down_time + $tetris_delay - time());
    unless ($key[0] == "\e" && $key[1] == "[") {
        $key[2] = lc $key[2];
    }
    my $cmd = $commands{$key[2]};
    $cmd->() if $cmd;
}
