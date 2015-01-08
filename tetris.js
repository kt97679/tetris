#!/usr/bin/env nodejs

var PLAYFIELD_W = 10,
    PLAYFIELD_H = 20,
    PLAYFIELD_X = 30,
    PLAYFIELD_Y = 1,
    BORDER_COLOR = "yellow",

    HELP_X = 58,
    HELP_Y = 1,
    HELP_COLOR = "cyan",

    SCORE_X = 1,
    SCORE_Y = 2,
    SCORE_COLOR = "green",

    NEXT_X = 14,
    NEXT_Y = 11,

    GAMEOVER_X = 1,
    GAMEOVER_Y = PLAYFIELD_H + 3,

    INITIAL_MOVE_DOWN_DELAY = 1000,
    DELAY_FACTOR = 0.8,
    LEVEL_UP = 20,

    NEXT_EMPTY_CELL = "  ",
    PLAYFIELD_EMPTY_CELL = " .",
    FILLED_CELL = "[]";

function TetrisScreen() {
    this.s = "";
    this.use_color = true;
}

TetrisScreen.prototype.toggle_color = function() {
    this.use_color ^= true;
}

TetrisScreen.prototype.print = function(s) {
    this.s += s;
}

TetrisScreen.prototype.flush = function() {
    process.stdout.write(this.s);
    this.s = "";
}

TetrisScreen.prototype.reset_colors = function() {
    this.s += "\u001B[0m"
}

TetrisScreen.prototype.set_bold = function() {
    this.s += "\u001B[1m"
}

TetrisScreen.prototype.clear_screen = function() {
    this.s += "\u001B[2J"
}

TetrisScreen.prototype.show_cursor = function() {
    this.s += "\u001B[?25h"
}

TetrisScreen.prototype.hide_cursor = function () {
    this.s += "\u001B[?25l"
}

TetrisScreen.color = {
    'red'     : 1,
    'green'   : 2,
    'yellow'  : 3,
    'blue'    : 4,
    'fuchsia' : 5,
    'cyan'    : 6,
    'white'   : 7
};

TetrisScreen.prototype.xyprint = function(x, y, s) {
    this.s += ("\u001B[" + y + ";" + x + "H" + s);
}

TetrisScreen.prototype.set_fg = function (c) {
    if (this.use_color) {
        this.s += ("\u001B[3" + TetrisScreen.color[c] + "m");
    }
}

TetrisScreen.prototype.set_bg = function (c) {
    if (this.use_color) {
        this.s += ("\u001B[4" + TetrisScreen.color[c] + "m");
    }
}

TetrisScreen.prototype.get_random_color = function() {
    a = Object.keys(TetrisScreen.color);
    return a[Math.floor(Math.random() * a.length)];
}

function TetrisPlayField(screen) {
    this.screen = screen;
    this.cells = [];
    for (var i = 0; i < PLAYFIELD_H; i++) {
        this.cells[i] = [];
    }
}

TetrisPlayField.prototype.draw_border = function() {
    var blocks = ['==', '\\/'];
    this.screen.set_bold()
    this.screen.set_fg(BORDER_COLOR)
    for (var i = 0; i < PLAYFIELD_H; i++) {
        var y = i + PLAYFIELD_Y;
        this.screen.xyprint(PLAYFIELD_X - 2, y, "<|");
        this.screen.xyprint(PLAYFIELD_X + PLAYFIELD_W * 2, y, "|>");
    }
    for (var i = 0; i < blocks.length; i++) {
        this.screen.xyprint(PLAYFIELD_X, PLAYFIELD_Y + PLAYFIELD_H + i, Array(PLAYFIELD_W + 1).join(blocks[i]));
    }
    this.screen.reset_colors()
}

TetrisPlayField.prototype.show = function() {
    for (var y = 0; y < PLAYFIELD_H; y++) {
        this.screen.xyprint(PLAYFIELD_X, PLAYFIELD_Y + y, "");
        for (var x = 0; x < PLAYFIELD_W; x++) {
            var cell = this.cells[y][x];
            if (cell) {
                this.screen.set_fg(cell);
                this.screen.set_bg(cell);
                this.screen.print(FILLED_CELL);
                this.screen.reset_colors();
            } else {
                this.screen.print(PLAYFIELD_EMPTY_CELL);
            }
        }
    }
}

TetrisPlayField.prototype.position_ok = function(piece, position) {
    return piece.get_cells(position).every(function(cell) {
        var x = cell.x;
        var y = cell.y;
        return (x >= 0 && x < PLAYFIELD_W && y >= 0 && y < PLAYFIELD_H && this.cells[y][x] == undefined);
    }, this);
}

TetrisPlayField.prototype.flatten_piece = function(piece) {
    piece.get_cells().forEach(function(cell) {
        this.cells[cell.y][cell.x] = piece.color;
    }, this);
}

TetrisPlayField.prototype.process_complete_lines = function() {
    var cells = this.cells.filter(function(row) {
        for (var i = 0; i < PLAYFIELD_W; i++) {
            if (row[i] == undefined) {
                return true;
            }
        }
        return false;
    }, this);
    var complete_lines = PLAYFIELD_H - cells.length;
    for (var i = 0; i < complete_lines; i++) {
        cells.unshift([]);
    }
    this.cells = cells;
    return complete_lines;
}

function TetrisScreenItem(screen) {
    this.visible = true;
    this.screen = screen;
}

TetrisScreenItem.prototype.show = function() {
    if (this.visible) {
        this.draw(true);
    }
}

TetrisScreenItem.prototype.hide = function() {
    if (this.visible) {
        this.draw(false);
    }
}

TetrisScreenItem.prototype.toggle = function() {
    this.visible = ! this.visible;
    this.draw(this.visible);
}

TetrisScreenItem.prototype.set_visible = function(value) {
    this.visible = value;
}

TetrisHelp.prototype = new TetrisScreenItem();
TetrisHelp.prototype.constructor = TetrisHelp;

function TetrisHelp(screen) {
    this.screen = screen;
    this.color = HELP_COLOR;
    this.text = [
        "  Use cursor keys",
        "       or",
        "    s: rotate",
        "a: left,  d: right",
        "    space: drop",
        "      q: quit",
        "  c: toggle color",
        "n: toggle show next",
        "h: toggle this help"
    ]   
}

TetrisHelp.prototype.draw = function(visible) {
    this.screen.set_bold();
    this.screen.set_fg(this.color)
    this.text.forEach(function(s, i) {
        this.screen.xyprint(HELP_X, HELP_Y + i, visible ? s : Array(s.length + 1).join(' '))
    }, this);
    this.screen.reset_colors()
}

TetrisScore.prototype = new TetrisScreenItem();
TetrisScore.prototype.constructor = TetrisScore;

function TetrisScore(screen, tetris_input_processor) {
    this.tetris_input_processor = tetris_input_processor;
    this.screen = screen;
    this.score = 0;
    this.level = 1;
    this.lines_completed = 0;
}

TetrisScore.prototype.update = function(complete_lines) {
    this.lines_completed += complete_lines;
    this.score += (complete_lines * complete_lines);
    if (this.score > LEVEL_UP * this.level) {
        this.level += 1;
        this.tetris_input_processor.tick_time *= DELAY_FACTOR;
    }
    this.show();
}

TetrisScore.prototype.show = function() {
    this.screen.set_bold();
    this.screen.set_fg(SCORE_COLOR);
    this.screen.xyprint(SCORE_X, SCORE_Y,     "Lines completed: " + this.lines_completed);
    this.screen.xyprint(SCORE_X, SCORE_Y + 1, "Level:           " + this.level);
    this.screen.xyprint(SCORE_X, SCORE_Y + 2, "Score:           " + this.score);
    this.screen.reset_colors();
}

TetrisPiece.prototype = new TetrisScreenItem();
TetrisPiece.prototype.constructor = TetrisPiece;

function TetrisPiece(screen) {
    // 0123
    // 4567
    // 89ab
    // cdef
    this.piece_data = [
        ["1256"], // square
        ["159d", "4567"], // line
        ["4512", "0459"], // s
        ["0156", "1548"], // z
        ["159a", "8456", "0159", "2654"], // l
        ["1598", "0456", "2159", "a654"], // inverted l
        ["1456", "1596", "4569", "4159"]  // t
    ]

    this.screen = screen;
    this.color = this.screen.get_random_color();
    this.piece_index = Math.floor(Math.random() * this.piece_data.length);
    this.symmetry = this.piece_data[this.piece_index].length;
    this.position = {
        x: 0,
        y: 0,
        z: Math.floor(Math.random() * this.symmetry)
    }
    this.empty_cell = NEXT_EMPTY_CELL;
}

TetrisPiece.prototype.get_cells = function(new_position) {
    var result = [];
    var p = new_position || this.position;
    var data = this.piece_data[this.piece_index][p.z];
    data.split('').forEach(function(c, i) {
        var n = parseInt(c, 16);
        result[i] = {x: p.x + (n & 3), y: p.y + ((n >> 2) & 3)};
    }, this);
    return result;
}

TetrisPiece.prototype.draw = function(visible) {
    if (visible) {
        this.screen.set_fg(this.color);
        this.screen.set_bg(this.color);
    }
    this.get_cells().forEach(function(cell) {
        this.screen.xyprint(this.origin.x + cell.x * 2, this.origin.y + cell.y, visible ? FILLED_CELL : this.empty_cell);
    }, this);
    this.screen.reset_colors();
}

TetrisPiece.prototype.new_position = function(dx, dy, dz) {
    return {
        x: this.position.x + dx,
        y: this.position.y + dy,
        z: (this.position.z + dz) % this.symmetry
    }
}

function TetrisController(tetris_input_processor) {
    this.tetris_input_processor = tetris_input_processor;
    this.screen = new TetrisScreen();
    this.next_piece_visible = true;
    this.playfield = new TetrisPlayField(this.screen);
    this.help = new TetrisHelp(this.screen);
    this.score = new TetrisScore(this.screen, this.tetris_input_processor);
    this.get_next_piece();
    this.get_current_piece();
    this.redraw_screen();
    this.screen.flush();
}

TetrisController.prototype.get_next_piece = function() {
    this.next_piece = new TetrisPiece(this.screen);
    this.next_piece.origin = {x: NEXT_X, y: NEXT_Y};
    this.next_piece.set_visible(this.next_piece_visible);
    this.next_piece.show();
}

TetrisController.prototype.get_current_piece = function() {
    this.next_piece.hide();
    this.current_piece = this.next_piece;
    this.current_piece.position = {x: (PLAYFIELD_W - 4) / 2, y: 0, z: this.current_piece.position.z};
    if (! this.playfield.position_ok(this.current_piece)) {
        this.quit();
    }
    this.current_piece.set_visible(true);
    this.current_piece.empty_cell = PLAYFIELD_EMPTY_CELL;
    this.current_piece.origin = {x: PLAYFIELD_X, y: PLAYFIELD_Y};
    this.current_piece.show();
    this.get_next_piece();
}

TetrisController.prototype.redraw_screen = function() {
    this.screen.clear_screen();
    this.screen.hide_cursor();
    this.playfield.draw_border();
    [this.playfield, this.help, this.score, this.next_piece, this.current_piece].forEach(function(o) {
        o.show();
    });
}

TetrisController.prototype.process_key = function(key) {
    var commands = {
        '\u0003': "quit",
        'q': "quit",
        '\u001b[C': "cmd_right",
        'd': "cmd_right",
        '\u001b[D': "cmd_left",
        'a': "cmd_left",
        '\u001b[A': "cmd_rotate",
        's': "cmd_rotate",
        ' ': "cmd_drop",
        'h': "toggle_help",
        'n': "toggle_next",
        'c': "toggle_color"
    };
    if (commands[key]) {
        this[commands[key]]();
        this.screen.flush();
    }
}

TetrisController.prototype.quit = function() {
    this.screen.xyprint(GAMEOVER_X, GAMEOVER_Y, "Game over!");
    this.screen.xyprint(GAMEOVER_X, GAMEOVER_Y + 1, "");
    this.screen.show_cursor();
    this.screen.flush();
    clearTimeout(this.tetris_input_processor.tick_timeout);
    process.stdin.pause();
    process.exit();
}

TetrisController.prototype.process_fallen_piece = function() {
    this.playfield.flatten_piece(this.current_piece);
    var complete_lines = this.playfield.process_complete_lines();
    if (complete_lines > 0) {
        this.score.update(complete_lines);
        this.playfield.show();
    }
}

TetrisController.prototype.move = function(dx, dy, dz) {
    var new_position = this.current_piece.new_position(dx, dy, dz);
    if (this.playfield.position_ok(this.current_piece, new_position)) {
        this.current_piece.hide();
        this.current_piece.position = new_position;
        this.current_piece.show();
        return true;
    }
    return (dy == 0);
}

TetrisController.prototype.cmd_down = function() {
    var landed = this.move(0, 1, 0);
    this.screen.flush();
    if (landed) {
        return true;
    }
    this.process_fallen_piece();
    this.get_current_piece();
    return false;
}

TetrisController.prototype.cmd_right = function() {
    this.move(1, 0, 0);
}

TetrisController.prototype.cmd_left = function() {
    this.move(-1, 0, 0);
}

TetrisController.prototype.cmd_rotate = function() {
    this.move(0, 0, 1);
}

TetrisController.prototype.cmd_drop = function() {
    while(this.cmd_down()) {
    }
}

TetrisController.prototype.toggle_help = function() {
    this.help.toggle();
}

TetrisController.prototype.toggle_next = function() {
    this.next_piece.toggle();
}

TetrisController.prototype.toggle_color = function() {
    this.screen.toggle_color();
    this.redraw_screen();
}

function TetrisInputProcessor() {
    this.tick_time = INITIAL_MOVE_DOWN_DELAY;
    this.tick_timeout = null;
}

TetrisInputProcessor.prototype.run = function() {
    var tetris_controller = new TetrisController(this);

    var stdin = process.stdin;
    stdin.setRawMode(true);
    stdin.resume();
    stdin.setEncoding('utf8');
    var self = this;
    var ticker = function() {
        this.tick_timeout = setTimeout(ticker, self.tick_time);
        tetris_controller.cmd_down();
    };
    stdin.on('data', function(key) {
        tetris_controller.process_key(key);
    });
    ticker();
}

new TetrisInputProcessor().run();
