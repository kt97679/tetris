#!/usr/bin/env ruby

# Tetris game written in pure ruby
#
# I tried to mimic as close as possible original tetris game
# which was implemented on old soviet DVK computers (PDP-11 clones)
#
# Videos of this tetris can be found here:
#
# http://www.youtube.com/watch?v=O0gAgQQHFcQ
# http://www.youtube.com/watch?v=iIQc1F3UuV4
#
# This script was created on ubuntu 13.10 x64 and ruby 1.9.3p194
# It was not tested on other unix like operating systems.
#
# Enjoy :-)!
#
# Author: Kirill Timofeev <kt97679@gmail.com>
#
# This program is free software. It comes without any warranty, to the extent
# permitted by applicable law. You can redistribute it and/or modify it under
# the terms of the Do What The Fuck You Want To Public License, Version 2, as
# published by Sam Hocevar. See http://www.wtfpl.net/ for more details.

require 'io/console'

PLAYFIELD_W = 10
PLAYFIELD_H = 20
PLAYFIELD_X = 30
PLAYFIELD_Y = 1
BORDER_COLOR = :yellow

HELP_X = 58
HELP_Y = 1
HELP_COLOR = :cyan

SCORE_X = 1
SCORE_Y = 2
SCORE_COLOR = :green

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

class TetrisScreen
    @@color = {
        :red => 1,
        :green => 2,
        :yellow => 3,
        :blue => 4,
        :fuchsia => 5,
        :cyan => 6,
        :white => 7
    }
    def initialize
        @s = ""
        @no_color = false
    end

    def print(s)
        @s += s
    end

    def xyprint(x, y, s)
        @s += "\e[#{y};#{x}H#{s}"
    end

    def show_cursor()
        @s += "\e[?25h"
    end

    def hide_cursor()
        @s += "\e[?25l"
    end

    def set_fg(c)
        return if @no_color
        @s += "\e[3#{@@color[c]}m"
    end

    def set_bg(c)
        return if @no_color
        @s += "\e[4#{@@color[c]}m"
    end

    def reset_colors()
        @s += "\e[0m"
    end

    def set_bold()
        @s += "\e[1m"
    end

    def clear_screen()
        @s += "\e[2J"
    end

    def flush()
        Kernel::print @s
        @s = ""
    end

    def get_random_color()
        return @@color.keys.shuffle.first
    end

    def toggle_color()
        @no_color ^= true
    end
end

class TetrisScreenItem
    def initialize(screen)
        @visible = true
        @screen = screen
    end

    def show()
        draw(true) if @visible
    end

    def hide()
        draw(false) if @visible
    end

    def toggle()
        @visible ^= true
        draw(@visible)
    end

    def set_visible(value)
        @visible = value
    end
end

class TetrisHelp < TetrisScreenItem
    def initialize(screen)
        super(screen)
        @color = HELP_COLOR
        @text = [
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
    end

    def draw(visible)
        @screen.set_bold()
        @screen.set_fg(@color)
        @text.each_with_index do |s, i|
            @screen.xyprint(HELP_X, HELP_Y + i, visible ? s : ' ' * s.length)
        end
        @screen.reset_colors()
    end
end

class TetrisPlayField
    def initialize(screen)
        @screen = screen
        @cells = Array.new(PLAYFIELD_H) { Array.new(PLAYFIELD_W) }
    end

    def show()
        @cells.each_with_index do |row, y|
            @screen.xyprint(PLAYFIELD_X, PLAYFIELD_Y + y, "")
            row.each do |cell|
                if cell == nil
                    @screen.print(PLAYFIELD_EMPTY_CELL)
                else
                    @screen.set_fg(cell)
                    @screen.set_bg(cell)
                    @screen.print(FILLED_CELL)
                    @screen.reset_colors()
                end
            end
        end
    end

    def flatten_piece(piece)
        piece.get_cells().each do |cell|
            @cells[cell[1]][cell[0]] = piece.color
        end
    end

    def process_complete_lines()
        @cells.select! {|row| row.include?(nil) }
        complete_lines = PLAYFIELD_H - @cells.size
        complete_lines.times { @cells.unshift(Array.new(PLAYFIELD_W)) }
        return complete_lines
    end

    def draw_border()
        @screen.set_bold()
        @screen.set_fg(BORDER_COLOR)
        (0..PLAYFIELD_H).map {|y| y + PLAYFIELD_Y}.each do |y|
            # 2 because border is 2 characters thick
            @screen.xyprint(PLAYFIELD_X - 2, y, "<|")
            # 2 because each cell on play field is 2 characters wide
            @screen.xyprint(PLAYFIELD_X + PLAYFIELD_W * 2, y, "|>")
        end

        ['==', '\/'].each_with_index do |s, y|
            @screen.xyprint(PLAYFIELD_X, PLAYFIELD_Y + PLAYFIELD_H + y, s * PLAYFIELD_W)
        end
        @screen.reset_colors()
    end

    def position_ok?(piece)
        piece.get_cells().each do |cell|
            if cell[0] < 0 || cell[0] >= PLAYFIELD_W || cell[1] < 0 || cell[1] >= PLAYFIELD_H
                return false
            end
            if @cells[cell[1]][cell[0]] != nil
                return false
            end
        end
        return true
    end
end

class TetrisPiece < TetrisScreenItem
    attr_accessor :empty_cell
    attr_reader :color

    # 0123
    # 4567
    # 89ab
    # cdef
    @@piece_data = [
        [0x1256], # square
        [0x159d, 0x4567], # line
        [0x4512, 0x0459], # s
        [0x0156, 0x1548], # z
        [0x159a, 0x8456, 0x0159, 0x2654], # l
        [0x1598, 0x0456, 0x2159, 0xa654], # inverted l
        [0x1456, 0x1596, 0x4569, 0x4159]  # t
    ]

    def initialize(screen)
        super(screen)
        @color = @screen.get_random_color()
        @piece_index = rand(@@piece_data.size)
        @symmetry = @@piece_data[@piece_index].size
        @x = 0
        @y = 0
        @z = rand(@symmetry)
        @empty_cell = NEXT_EMPTY_CELL
    end

    def get_cells()
        data = @@piece_data[@piece_index][@z]
        (0..3).map {|i| data >> (4 * i)}.inject([]) {|x, i| x << [@x + (i & 3), @y + ((i >> 2) & 3)]}
    end

    def draw(visible)
        if visible
            @screen.set_fg(@color)
            @screen.set_bg(@color)
        end
        get_cells().each do |cell|
            @screen.xyprint(@origin_x + cell[0] * 2, @origin_y + cell[1], visible ? FILLED_CELL : @empty_cell)
        end
        @screen.reset_colors()
    end

    def set_origin(x, y)
        @origin_x = x
        @origin_y = y
    end

    def set_xy(x, y)
        @x = x
        @y = y
    end

    def move(dx, dy, dz)
        @_x = @x
        @_y = @y
        @_z = @z
        @x += dx
        @y += dy
        @z = (@z + dz) % @symmetry
    end

    def unmove()
        @x = @_x
        @y = @_y
        @z = @_z
    end
end

class TetrisScore
    def initialize(screen)
        @screen = screen
        @score = 0
        @level = 1
        @lines_completed = 0
    end

    def update(complete_lines)
        @lines_completed += complete_lines
        @score += (complete_lines * complete_lines)
        if @score > LEVEL_UP * @level
            @level += 1
            TetrisInputProcessor.decrease_move_down_delay()
        end
        show()
    end

    def show()
        @screen.set_bold()
        @screen.set_fg(SCORE_COLOR)
        @screen.xyprint(SCORE_X, SCORE_Y,     "Lines completed: #{@lines_completed}")
        @screen.xyprint(SCORE_X, SCORE_Y + 1, "Level:           #{@level}")
        @screen.xyprint(SCORE_X, SCORE_Y + 2, "Score:           #{@score}")
        @screen.reset_colors()
    end
end

class TetrisController
    attr_reader :running

    def initialize(screen)
        @screen = screen
        @next_piece_visible = true
        @running = true
        @help = TetrisHelp.new(@screen)
        @score = TetrisScore.new(@screen)
        @play_field = TetrisPlayField.new(@screen)
        get_next_piece()
        get_current_piece()
        redraw_screen()
        @screen.flush()
    end

    def get_current_piece()
        @next_piece.hide()
        @current_piece = @next_piece
        @current_piece.set_xy((PLAYFIELD_W - 4) / 2, 0)
        if ! @play_field.position_ok?(@current_piece)
            process(:cmd_quit)
            return
        end
        @current_piece.set_visible(true)
        @current_piece.empty_cell = PLAYFIELD_EMPTY_CELL
        @current_piece.set_origin(PLAYFIELD_X, PLAYFIELD_Y)
        @current_piece.show()
        get_next_piece()
    end

    def get_next_piece()
        @next_piece = TetrisPiece.new(@screen)
        @next_piece.set_origin(NEXT_X, NEXT_Y)
        @next_piece.set_visible(@next_piece_visible)
        @next_piece.show()
    end

    def redraw_screen()
        @screen.clear_screen()
        @screen.hide_cursor()
        @play_field.draw_border()
        [@help, @play_field, @score, @next_piece, @current_piece].each {|o| o.show()}
    end

    def cmd_quit
        @running = false
        @screen.xyprint(GAMEOVER_X, GAMEOVER_Y, "Game over!")
        @screen.xyprint(GAMEOVER_X, GAMEOVER_Y + 1, "")
        @screen.show_cursor()
    end

    def process_fallen_piece()
        @play_field.flatten_piece(@current_piece)
        complete_lines = @play_field.process_complete_lines()
        if complete_lines > 0
            @score.update(complete_lines)
            @play_field.show()
        end
    end

    def move(dx, dy, dz)
        @current_piece.move(dx, dy, dz)
        new_position_ok = @play_field.position_ok?(@current_piece)
        @current_piece.unmove()
        if new_position_ok
            @current_piece.hide()
            @current_piece.move(dx, dy, dz)
            @current_piece.show()
            return true
        end
        if dy == 0
            return true
        end
        process_fallen_piece()
        return false
    end

    def cmd_right
        move(1, 0, 0)
    end

    def cmd_left
        move(-1, 0, 0)
    end

    def cmd_rotate
        move(0, 0, 1)
    end

    def cmd_down
        return true if move(0, 1, 0)
        get_current_piece()
        return false
    end

    def cmd_drop
        while cmd_down()
        end
    end

    def toggle_help
        @help.toggle()
    end

    def toggle_next
        @next_piece_visible ^= true
        @next_piece.toggle()
    end

    def toggle_color
        @screen.toggle_color()
        redraw_screen()
    end

    def process(cmd)
        return if cmd == nil
        send(cmd)
        @screen.flush()
    end
end

class TetrisInputProcessor
    @@move_down_delay = INITIAL_MOVE_DOWN_DELAY

    def self.decrease_move_down_delay()
        @@move_down_delay *= DELAY_FACTOR
    end

    def initialize(controller)
        @commands = {
            "\u0003" => :cmd_quit,
            "q" => :cmd_quit,
            "C" => :cmd_right,
            "d" => :cmd_right,
            "D" => :cmd_left,
            "a" => :cmd_left,
            "A" => :cmd_rotate,
            "s" => :cmd_rotate,
            " " => :cmd_drop,
            "h" => :toggle_help,
            "n" => :toggle_next,
            "c" => :toggle_color
        }
        @controller = controller
    end

    def run()
        begin
            STDIN.echo = false
            STDIN.raw!
            key = []
            last_move_down_time = Time.now.to_f
            while @controller.running
                now = Time.now.to_f
                select_timeout = @@move_down_delay - (now - last_move_down_time)
                if select_timeout < 0
                    @controller.process(:cmd_down)
                    last_move_down_time = now
                    select_timeout = @@move_down_delay
                end
                a = select([STDIN], [], [], select_timeout)
                cmd = nil
                if a
                    key[2] = key[1]
                    key[1] = key[0]
                    key[0] = a[0][0].getc()
                    if key[2] == "\e" && key[1] == "["
                        cmd = @commands[key[0]]
                    else
                        cmd = @commands[key[0].downcase()]
                    end
                end
                @controller.process(cmd)
            end
        ensure
            STDIN.echo = true
            STDIN.cooked!
        end
    end
end

ts = TetrisScreen.new
tc = TetrisController.new(ts)
tip = TetrisInputProcessor.new(tc)
tip.run()
