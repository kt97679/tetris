#!/usr/bin/env ruby

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

class TetrisView
    attr_reader :color

    def initialize
        @s = ""
        @no_color = false
        @color = {
            :red => 1,
            :green => 2,
            :yellow => 3,
            :blue => 4,
            :fuchsia => 5,
            :cyan => 6,
            :white => 7
        }
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
        @s += "\e[3#{@color[c]}m"
    end

    def set_bg(c)
        return if @no_color
        @s += "\e[4#{@color[c]}m"
    end

    def reset_colors()
        @s += "\e[0m"
    end

    def set_bold()
        @s += "\033[1m"
    end

    def clear_screen()
        @s += "\e[2J"
    end

    def flush()
        Kernel::print @s
        @s = ""
    end

    def get_random_color()
        return @color.keys.shuffle.first
    end

    def toggle_color()
        @no_color = (! @no_color)
    end
end

class TetrisHelp
    def initialize()
        @color = HELP_COLOR
        @visible = true
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

    def draw(view)
        view.set_bold()
        view.set_fg(@color)
        @text.each_with_index do |s, i|
            view.xyprint(HELP_X, HELP_Y + i, @visible ? s : ' ' * s.length)
        end
        view.reset_colors()
    end

    def toggle(view)
        @visible = (! @visible)
        draw(view)
    end
end

class TetrisPiece
    attr_accessor :empty_cell, :x, :y, :orientation

    @@play_field = []
    @@score = 0
    @@level = 1
    @@lines_completed = 0
    @@move_down_delay = INITIAL_MOVE_DOWN_DELAY

    def initialize(color)
        # abcd
        # efgh
        # ijkl
        # mnop
        @piece_data = [
            [[[0, 0], [0, 1], [1, 0], [1, 1]]], # square piece
            [[[0, 2], [1, 2], [2, 2], [3, 2]], [[1, 0], [1, 1], [1, 2], [1, 3]]], # line piece
            [[[0, 0], [0, 1], [1, 1], [1, 2]], [[0, 1], [1, 0], [1, 1], [2, 0]]], # S piece
            [[[0, 1], [0, 2], [1, 0], [1, 1]], [[0, 0], [1, 0], [1, 1], [2, 1]]], # Z piece
            [[[0, 1], [0, 2], [1, 1], [2, 1]], [[1, 0], [1, 1], [1, 2], [2, 2]], [[0, 1], [1, 1], [2, 0], [2, 1]], [[0, 0], [1, 0], [1, 1], [1, 2]]], # L piece
            [[[0, 1], [1, 1], [2, 1], [2, 2]], [[1, 0], [1, 1], [1, 2], [2, 0]], [[0, 0], [0, 1], [1, 1], [2, 1]], [[0, 2], [1, 0], [1, 1], [1, 2]]], # inverted L piece
            [[[0, 1], [1, 1], [1, 2], [2, 1]], [[1, 0], [1, 1], [1, 2], [2, 1]], [[0, 1], [1, 0], [1, 1], [2, 1]], [[0, 1], [1, 0], [1, 1], [1, 2]]]  # T piece
        ]
        @x = 0
        @y = 0
        @visible = true
        @color = color
        @piece_index = rand(@piece_data.length)
        @orientation = rand(@piece_data[@piece_index].size)
        @empty_cell = NEXT_EMPTY_CELL
    end

    def draw(view, visible = nil)
        if visible == nil
            visible = @visible
        end
        if visible
            view.set_fg(@color)
            view.set_bg(@color)
        end
        @piece_data[@piece_index][@orientation].each do |cell|
            view.xyprint(@origin_x + (@x + cell[0]) * 2, @origin_y + @y + cell[1], visible ? FILLED_CELL : @empty_cell)
        end
        view.reset_colors()
    end

    def show(view)
        if @visible
            draw(view, true)
        end
    end

    def hide(view)
        if @visible
            draw(view, false)
        end
    end

    def toggle(view)
        @visible = (! @visible)
        draw(view, @visible)
    end

    def set_origin(x, y)
        @origin_x = x
        @origin_y = y
    end

    def position_ok?(x, y, orientation)
        @piece_data[@piece_index][orientation].each do |cell|
            cell_x = x + cell[0]
            cell_y = y + cell[1]
            if cell_x < 0 || cell_x >= PLAYFIELD_W || cell_y < 0 || cell_y >= PLAYFIELD_H
                return false
            end
            if @@play_field[cell_x + cell_y * PLAYFIELD_W] != nil
                return false
            end
        end
        return true
    end

    def redraw_playfield(view) 
        xp = PLAYFIELD_X
        (0...PLAYFIELD_H).each do |y|
            yp = y + PLAYFIELD_Y
            i = y * PLAYFIELD_W
            view.xyprint(xp, yp, "")
            (0...PLAYFIELD_W).each do |x|
                j = i + x
                if @@play_field[j] == nil
                    view.print(PLAYFIELD_EMPTY_CELL)
                else
                    view.set_fg(@@play_field[j])
                    view.set_bg(@@play_field[j])
                    view.print(FILLED_CELL)
                    view.reset_colors()
                end
            end
        end
    end

    def move(view, dx, dy, dr)
        new_orientation = (@orientation + dr) % @piece_data[@piece_index].size
        new_x = @x + dx
        new_y = @y + dy
        if position_ok?(new_x, new_y, new_orientation)
            hide(view)
            @x = new_x
            @y = new_y
            @orientation = new_orientation
            show(view)
            return true
        end
        if dy == 0
            return true
        end
        process_fallen_piece(view)
        return false
    end

    def process_fallen_piece(view)
        flatten_playfield()
        complete_lines = process_complete_lines()
        if complete_lines > 0
            update_score(view, complete_lines)
            redraw_playfield(view)
        end
    end

    def flatten_playfield()
        @piece_data[@piece_index][@orientation].each do |cell|
            cell_x = @x + cell[0]
            cell_y = @y + cell[1]
            @@play_field[cell_x + cell_y * PLAYFIELD_W] = @color
        end
    end

    def process_complete_lines()
        complete_lines = 0
        j = -PLAYFIELD_W
        while j < PLAYFIELD_W * PLAYFIELD_H
            j += PLAYFIELD_W
            i = j + PLAYFIELD_W - 1
            while i >= j
                break if @@play_field[i] == nil # empty cell found
                i -= 1
            end
            next if i >= j  # previous loop was interrupted because empty cell was found
            complete_lines += 1
            # move lines down
            i = j - 1
            while i >= 0
                @@play_field[i + PLAYFIELD_W] = @@play_field[i]
                @@play_field[i] = nil
                i -= 1
            end
        end
        return complete_lines
    end

    def update_score(view, complete_lines)
        @@lines_completed += complete_lines
        @@score += (complete_lines * complete_lines)
        if @@score > LEVEL_UP * @@level
            @@level += 1
            @@move_down_delay *= DELAY_FACTOR
        end
        view.set_bold()
        view.set_fg(SCORE_COLOR)
        view.xyprint(SCORE_X, SCORE_Y,     "Lines completed: #{@@lines_completed}")
        view.xyprint(SCORE_X, SCORE_Y + 1, "Level:           #{@@level}")
        view.xyprint(SCORE_X, SCORE_Y + 2, "Score:           #{@@score}")
        view.reset_colors()
    end

    def get_move_down_delay()
        @@move_down_delay
    end
end

class TetrisModel
    attr_reader :running

    def initialize(view)
        @view = view
        @running = true
        @help = TetrisHelp.new()
        get_next_piece()
        get_next_piece()
        redraw_screen()
        @view.flush()
    end

    def get_next_piece()
        if @next_piece
            @next_piece.hide(@view)
            @current_piece = @next_piece
            if ! @current_piece.position_ok?((PLAYFIELD_W - 4) / 2, 0, @current_piece.orientation)
                process(:cmd_quit)
                return
            end
            @current_piece.empty_cell = PLAYFIELD_EMPTY_CELL
            @current_piece.x = (PLAYFIELD_W - 4) / 2
            @current_piece.y = 0
            @current_piece.set_origin(PLAYFIELD_X, PLAYFIELD_Y)
            @current_piece.show(@view)
        end
        @next_piece = TetrisPiece.new(@view.get_random_color())
        @next_piece.set_origin(NEXT_X, NEXT_Y)
        @next_piece.show(@view)
    end

    def redraw_screen()
        @view.clear_screen()
        @view.hide_cursor()
        draw_border()
        @help.draw(@view)
        @current_piece.redraw_playfield(@view)
        @current_piece.update_score(@view, 0)
        @next_piece.draw(@view)
        @current_piece.draw(@view)
    end

    def draw_border()
        @view.set_bold()
        @view.set_fg(BORDER_COLOR)
        x1 = PLAYFIELD_X - 2               # 2 here is because border is 2 characters thick
        x2 = PLAYFIELD_X + PLAYFIELD_W * 2 # 2 here is because each cell on play field is 2 characters wide
        (0..PLAYFIELD_H).each do |i|
            y = i + PLAYFIELD_Y
            @view.xyprint(x1, y, "<|")
            @view.xyprint(x2, y, "|>")
        end

        y = PLAYFIELD_Y + PLAYFIELD_H
        (0...PLAYFIELD_W).each do |i|
            x1 = i * 2 + PLAYFIELD_X # 2 here is because each cell on play field is 2 characters wide
            @view.xyprint(x1, y, '==')
            @view.xyprint(x1, y + 1, '\/')
        end
        @view.reset_colors()
    end

    def cmd_quit
        @running = false
        @view.xyprint(GAMEOVER_X, GAMEOVER_Y, "Game over!")
        @view.xyprint(GAMEOVER_X, GAMEOVER_Y + 1, "")
        @view.show_cursor()
    end

    def cmd_right
        @current_piece.move(@view, 1, 0, 0)
    end

    def cmd_left
        @current_piece.move(@view, -1, 0, 0)
    end

    def cmd_rotate
        @current_piece.move(@view, 0, 0, -1)
    end

    def cmd_down
        return if @current_piece.move(@view, 0, 1, 0)
        get_next_piece()
    end

    def cmd_drop
        while @current_piece.move(@view, 0, 1, 0)
        end
        get_next_piece()
    end

    def toggle_help
        @help.toggle(@view)
    end

    def toggle_next
        @next_piece.toggle(@view)
    end

    def toggle_color
        @view.toggle_color()
        redraw_screen()
    end

    def process(cmd)
        if cmd == nil
            return
        end
        send(cmd)
        @view.flush()
    end

    def get_move_down_delay()
        @current_piece.get_move_down_delay()
    end
end

class TetrisController
    def initialize(model)
        @commands = {
            "\u0003" => :cmd_quit,
            "q" => :cmd_quit,
            "C" => :cmd_right,
            "D" => :cmd_left,
            "A" => :cmd_rotate,
            " " => :cmd_drop,
            "h" => :toggle_help,
            "n" => :toggle_next,
            "c" => :toggle_color
        }
        @model = model
    end

    def run()
        last_move_down_time = Time.now.to_f

        begin
            STDIN.echo = false
            STDIN.raw!
            key = []
            while @model.running
                now = Time.now.to_f
                select_timeout = @model.get_move_down_delay() - (now - last_move_down_time)
                if select_timeout < 0
                    @model.process(:cmd_down)
                    last_move_down_time = now
                    select_timeout = @model.get_move_down_delay()
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
                @model.process(cmd)
            end
        ensure
            STDIN.echo = true
            STDIN.cooked!
        end
    end
end

tv = TetrisView.new
tm = TetrisModel.new(tv)
tc = TetrisController.new(tm)
tc.run()
