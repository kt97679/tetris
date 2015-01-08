#!/usr/bin/env python

import sys
import select
import tty
import termios
import random
import os
import time
import fcntl
if (sys.hexversion >> 16) >= 0x202:
    FCNTL = fcntl
else:
    import FCNTL
import contextlib

PLAYFIELD_W = 10
PLAYFIELD_H = 20
PLAYFIELD_X = 30
PLAYFIELD_Y = 1
BORDER_COLOR = 'yellow'

HELP_X = 58
HELP_Y = 1
HELP_COLOR = 'cyan'

SCORE_X = 1
SCORE_Y = 2
SCORE_COLOR = 'green'

NEXT_X = 14
NEXT_Y = 11

GAMEOVER_X = 1
GAMEOVER_Y = PLAYFIELD_H + 3

INITIAL_MOVE_DOWN_DELAY = 1.0
DELAY_FACTOR = 0.8
LEVEL_UP = 20

NEXT_EMPTY_CELL = "  "
PLAYFIELD_EMPTY_CELL = " ."
FILLED_CELL = "[]"

class TetrisScreen:
    def __init__(self):
        self.s = ''
        self.no_color = False
        self.color = {
            'red': 1,
            'green': 2,
            'yellow': 3,
            'blue': 4,
            'fuchsia': 5,
            'cyan': 6,
            'white': 7
        }

    def xyprint(self, x, y, s):
        self.s += "\x1b[{0};{1}H{2}".format(y, x, s)

    def flush(self):
        sys.stdout.write(self.s)
        sys.stdout.flush()
        self.s = ''

    def puts(self, s):
        self.s += s

    def clear_screen(self):
        self.s += "\x1b[2J"

    def show_cursor(self):
        self.s += "\x1b[?25h"

    def hide_cursor(self):
        self.s += "\x1b[?25l"

    def set_fg(self, c):
        if self.no_color:
            return
        self.s += "\x1b[3{0}m".format(self.color.get(c, 7))

    def set_bg(self, c):
        if self.no_color:
            return
        self.s += "\x1b[4{0}m".format(self.color.get(c, 7))

    def reset_colors(self):
        self.s += "\x1b[0m"

    def set_bold(self):
        self.s += "\x1b[1m"

    def get_random_color(self):
        k = self.color.keys()
        random.shuffle(k)
        return k[0]

    def toggle_color(self):
        self.no_color ^= True

class TetrisScreenItem(object):
    def __init__(self, screen):
        self.visible = True
        self.screen = screen

    def show(self):
        if self.visible:
            self.draw(True)

    def hide(self):
        if self.visible:
            self.draw(False)

    def toggle(self):
        self.visible ^= True
        self.draw(self.visible)

class TetrisHelp(TetrisScreenItem):
    def __init__(self, screen):
        super(TetrisHelp, self).__init__(screen)
        self.color = HELP_COLOR
        self.text = [
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

    def draw(self, visible):
        self.screen.set_bold()
        self.screen.set_fg(self.color)
        i = 0
        for s in self.text:
            if not visible:
                s = ' ' * len(s)
            self.screen.xyprint(HELP_X, HELP_Y + i, s)
            i += 1
        self.screen.reset_colors()

class TetrisPlayField:
    def __init__(self, screen):
        self.screen = screen
        self.cells = [[None] * PLAYFIELD_W for i in range(0, PLAYFIELD_H)]

    def show(self):
        y = 0
        for row in self.cells:
            self.screen.xyprint(PLAYFIELD_X, PLAYFIELD_Y + y, "")
            y += 1
            for cell in row:
                if cell == None:
                    self.screen.puts(PLAYFIELD_EMPTY_CELL)
                else:
                    self.screen.set_fg(cell)
                    self.screen.set_bg(cell)
                    self.screen.puts(FILLED_CELL)
                    self.screen.reset_colors()

    def flatten_piece(self, piece):
        for cell in piece.get_cells():
            self.cells[cell[1]][cell[0]] = piece.color

    def process_complete_lines(self):
        cells = [row for row in self.cells if None in row]
        complete_lines = PLAYFIELD_H - len(cells)
        if complete_lines > 0:
            self.cells = [[None] * PLAYFIELD_W for i in range(0, complete_lines)] + cells
        return complete_lines

    def draw_border(self):
        self.screen.set_bold()
        self.screen.set_fg(BORDER_COLOR)
        for y in range(0, PLAYFIELD_H):
            # 2 because border is 2 characters thick
            self.screen.xyprint(PLAYFIELD_X - 2, PLAYFIELD_Y + y, "<|")
            # 2 because each cell on play field is 2 characters wide
            self.screen.xyprint(PLAYFIELD_X + PLAYFIELD_W * 2, PLAYFIELD_Y+ y, "|>")
        y = 0
        for s in ['==', '\/']:
            self.screen.xyprint(PLAYFIELD_X, PLAYFIELD_Y + PLAYFIELD_H + y, s * PLAYFIELD_W)
            y += 1
        self.screen.reset_colors()

    def position_ok(self, cells):
        return all(
            (0 <= x < PLAYFIELD_W) and
            (0 <= y < PLAYFIELD_H) and
            self.cells[y][x] is None
            for x, y in cells
        )

class TetrisPiece(TetrisScreenItem):
    configurations = [
        # 0123
        # 4567
        # 89ab
        # cdef
        [0x1256], # square
        [0x159d, 0x4567], # line
        [0x4512, 0x0459], # s
        [0x0156, 0x1548], # z
        [0x159a, 0x8456, 0x0159, 0x2654], # l
        [0x1598, 0x0456, 0x2159, 0xa654], # inverted l
        [0x1456, 0x1596, 0x4569, 0x4159]  # t
    ]

    def __init__(self, screen, origin, visible):
        super(TetrisPiece, self).__init__(screen)
        self.color = screen.get_random_color()
        self.data = random.choice(self.configurations)
        self.symmetry = len(self.data)
        self.position = 0, 0, random.randint(0, self.symmetry - 1)
        self.origin = origin
        self.visible = visible
        self.empty_cell = NEXT_EMPTY_CELL

    def get_cells(self, new_position=None):
        x, y, z = new_position or self.position
        data = self.data[z]
        return [[x + ((data >> (i * 4)) & 3), y + ((data >> (i * 4 + 2)) & 3)] for i in range(0, 4)]

    def draw(self, visible):
        if visible:
            self.screen.set_fg(self.color)
            self.screen.set_bg(self.color)
            s = FILLED_CELL
        else:
            s = self.empty_cell
        for cell in self.get_cells():
            self.screen.xyprint(self.origin[0] + cell[0] * 2, self.origin[1] + cell[1], s)
        self.screen.reset_colors()

    def set_xy(self, x, y):
        self.position = x, y, self.position[2]

    def new_position(self, dx, dy, dz):
        x, y, z = self.position
        return x + dx, y + dy, (z + dz) % self.symmetry

class TetrisScore:
    def __init__(self, screen, tetris_input_processor):
        self.screen = screen
        self.tetris_input_processor = tetris_input_processor
        self.score = 0
        self.level = 1
        self.lines_completed = 0

    def update(self, complete_lines):
        self.lines_completed += complete_lines
        self.score += (complete_lines * complete_lines)
        if self.score > LEVEL_UP * self.level:
            self.level += 1
            self.tetris_input_processor.decrease_delay()
        self.show()

    def show(self):
        self.screen.set_bold()
        self.screen.set_fg(SCORE_COLOR)
        self.screen.xyprint(SCORE_X, SCORE_Y,     "Lines completed: {0}".format(self.lines_completed))
        self.screen.xyprint(SCORE_X, SCORE_Y + 1, "Level:           {0}".format(self.level))
        self.screen.xyprint(SCORE_X, SCORE_Y + 2, "Score:           {0}".format(self.score))
        self.screen.reset_colors()

class TetrisController:

    def __init__(self, screen, tetris_input_processor):
        self.screen = screen
        self.next_piece_visible = True
        self.running = True
        self.help = TetrisHelp(screen)
        self.score = TetrisScore(screen, tetris_input_processor)
        self.play_field = TetrisPlayField(screen)
        self.get_next_piece()
        self.get_current_piece()
        self.redraw_screen()
        screen.flush()

    def get_current_piece(self):
        self.next_piece.hide()
        self.current_piece = self.next_piece
        self.current_piece.set_xy((PLAYFIELD_W - 4) / 2, 0)
        if not self.play_field.position_ok(self.current_piece.get_cells()):
            self.cmd_quit()
            return
        self.current_piece.visible = True
        self.current_piece.empty_cell = PLAYFIELD_EMPTY_CELL
        self.current_piece.origin = (PLAYFIELD_X, PLAYFIELD_Y)
        self.current_piece.show()
        self.get_next_piece()

    def get_next_piece(self):
        self.next_piece = TetrisPiece(
            self.screen,
            (NEXT_X, NEXT_Y),
            self.next_piece_visible,
        )
        self.next_piece.show()

    def redraw_screen(self):
        self.screen.clear_screen()
        self.screen.hide_cursor()
        self.play_field.draw_border()
        for o in [self.help, self.play_field, self.score, self.next_piece, self.current_piece]:
            o.show()

    def cmd_quit(self):
        self.running = False
        self.screen.xyprint(GAMEOVER_X, GAMEOVER_Y, "Game over!")
        self.screen.xyprint(GAMEOVER_X, GAMEOVER_Y + 1, "")
        self.screen.show_cursor()

    def process_fallen_piece(self):
        self.play_field.flatten_piece(self.current_piece)
        complete_lines = self.play_field.process_complete_lines()
        if complete_lines > 0:
            self.score.update(complete_lines)
            self.play_field.show()

    def move(self, dx, dy, dz):
        position = self.current_piece.new_position(dx, dy, dz)
        if self.play_field.position_ok(self.current_piece.get_cells(position)):
            self.current_piece.hide()
            self.current_piece.position = position
            self.current_piece.show()
            return True
        return (dy == 0)

    def cmd_right(self):
        self.move(1, 0, 0)

    def cmd_left(self):
        self.move(-1, 0, 0)

    def cmd_rotate(self):
        self.move(0, 0, 1)

    def cmd_down(self):
        if self.move(0, 1, 0):
            return True
        self.process_fallen_piece()
        self.get_current_piece()
        return False

    def cmd_drop(self):
        while self.cmd_down():
            pass

    def toggle_help(self):
        self.help.toggle()

    def toggle_next(self):
        self.next_piece_visible ^= True
        self.next_piece.toggle()

    def toggle_color(self):
        self.screen.toggle_color()
        self.redraw_screen()

@contextlib.contextmanager
def nonblocking_input():
    fd = sys.stdin
    try:
        flags = fcntl.fcntl(fd, FCNTL.F_GETFL)
        flags = flags | os.O_NONBLOCK
        fcntl.fcntl(fd, FCNTL.F_SETFL, flags)
        yield
    finally:
        flags = fcntl.fcntl(fd, FCNTL.F_GETFL)
        flags = flags & ~os.O_NONBLOCK
        fcntl.fcntl(fd, FCNTL.F_SETFL, flags)

@contextlib.contextmanager
def tcattr():
    try:
        old_settings = termios.tcgetattr(sys.stdin)
        yield
    finally:
        termios.tcsetattr(sys.stdin, termios.TCSADRAIN, old_settings)


class TetrisInputProcessor:
    delay = INITIAL_MOVE_DOWN_DELAY

    def decrease_delay(self):
        self.delay *= DELAY_FACTOR


def run():
    input_processor = TetrisInputProcessor()
    with nonblocking_input(), tcattr():
    #    tty.setcbreak(sys.stdin.fileno())
        tty.setraw(sys.stdin.fileno())

        key = [0, 0, 0]
        ts = TetrisScreen()
        ts.clear_screen()
        tc = TetrisController(ts, input_processor)
        commands = {
            "\x03": tc.cmd_quit,
            "q": tc.cmd_quit,
            "C": tc.cmd_right,
            "d": tc.cmd_right,
            "D": tc.cmd_left,
            "a": tc.cmd_left,
            "A": tc.cmd_rotate,
            "s": tc.cmd_rotate,
            " ": tc.cmd_drop,
            "h": tc.toggle_help,
            "n": tc.toggle_next,
            "c": tc.toggle_color
        }
        last_move_down_time = time.time()
        while tc.running:
            cmd = None
            now = time.time()
            select_timeout = input_processor.delay - (now - last_move_down_time)
            if select_timeout < 0:
                tc.cmd_down()
                ts.flush()
                last_move_down_time = now
                select_timeout = input_processor.delay
            if select.select([sys.stdin], [], [], input_processor.delay)[0]:
                s = sys.stdin.read(16)
                for c in s:
                    key[2] = key[1]
                    key[1] = key[0]
                    key[0] = c
                    if key[2] == '\x1b' and key[1] == '[':         # x1b is ESC
                        cmd = commands.get(key[0], None)
                    else:
                        cmd = commands.get(key[0].lower(), None)
                    if cmd:
                        cmd()
                        ts.flush()


if __name__ == '__main__':
    run()

