import java.io.Console;
import java.io.IOException;
import java.io.Reader;
import java.util.Random;
import java.util.List;
import java.util.ArrayList;

public class Tetris {
    public static final int PLAYFIELD_W = 10;
    public static final int PLAYFIELD_H = 20;
    public static final int PLAYFIELD_X = 30;
    public static final int PLAYFIELD_Y = 1;
    public static final TetrisColor BORDER_COLOR = TetrisColor.YELLOW;

    public static final int HELP_X = 58;
    public static final int HELP_Y = 1;
    public static final TetrisColor HELP_COLOR = TetrisColor.CYAN;

    public static final int SCORE_X = 1;
    public static final int SCORE_Y = 2;
    public static final TetrisColor SCORE_COLOR = TetrisColor.GREEN;

    public static final int NEXT_X = 14;
    public static final int NEXT_Y = 11;

    public static final int GAMEOVER_X = 1;
    public static final int GAMEOVER_Y = PLAYFIELD_H + 3;

    public static final int INITIAL_MOVE_DOWN_DELAY = 1000;
    public static final double DELAY_FACTOR = 0.8;
    public static final int LEVEL_UP = 20;

    public static final String NEXT_EMPTY_CELL = "  ";
    public static final String PLAYFIELD_EMPTY_CELL = " .";
    public static final String FILLED_CELL = "[]";

    public static final Random RANDOM = new Random();

    public static void main(String[] args) {
        try {
            new Tetris().run();
        } catch (IOException ioe) {
        } catch (InterruptedException ie) {
        }
    }

    public void run() throws IOException, InterruptedException {
        try {
            String[] cmd = {"/bin/sh", "-c", "stty raw -echo </dev/tty"};
            Runtime.getRuntime().exec(cmd).waitFor();
            Console console = System.console();
            Reader reader = console.reader();
            TetrisScreen screen = new TetrisScreen();
            TetrisController tc = new TetrisController(screen);
            Object lock = new Object();
            TetrisTicker tt = new TetrisTicker(tc, lock);
            tt.start();
            char key[] = {0, 0, 0};
            while (tc.running) {
                key[2] = key[1];
                key[1] = key[0];
                if (key[2] == 27 && key[1] == '[') {
                    key[0] = (char)reader.read();
                } else {
                    key[0] = Character.toLowerCase((char)reader.read());
                }
                synchronized(lock) {
                    switch(key[0]) {
                        case 3:
                        case 'q':
                            tc.cmdQuit();
                            break;
                        case 'C':
                        case 'd':
                            tc.cmdRight();
                            break;
                        case 'D':
                        case 'a':
                            tc.cmdLeft();
                            break;
                        case 'A':
                        case 's':
                            tc.cmdRotate();
                            break;
                        case ' ':
                            tc.cmdDrop();
                            break;
                        case 'h':
                            tc.cmdToggleHelp();
                            break;
                        case 'n':
                            tc.cmdToggleNext();
                            break;
                        case 'c':
                            tc.cmdToggleColor();
                            break;
                        default:
                            break;
                    }
                    screen.flush();
                }
            }
            tt.shutdown();
        } finally {
            String[] cmd = new String[] {"/bin/sh", "-c", "stty sane </dev/tty"};
            Runtime.getRuntime().exec(cmd).waitFor();
        }
    }
}

class TetrisTicker extends Thread {
    private static int delay = Tetris.INITIAL_MOVE_DOWN_DELAY;
    private TetrisController tc = null;
    private Object lock = null;
    private boolean go = true;

    public TetrisTicker(TetrisController tc, Object lock) {
        this.tc = tc;
        this.lock = lock;
    }

    public static void decreaseDelay() {
        delay *= Tetris.DELAY_FACTOR;
    }

    public void shutdown() {
        go = false;
    }

    public void run() {
        while (go) {
            try {
                Thread.sleep(delay);
            } catch (java.lang.InterruptedException ie) {
            }
            if (go) {
                synchronized(lock) {
                    tc.cmdDown();
                    tc.screenFlush();
                }
            }
        }
    }
}

enum TetrisColor {
    RED (1),
    GREEN (2),
    YELLOW (3),
    BLUE (4),
    FUCHSIA (5),
    CYAN (6),
    WHITE (7);

    public final int value;

    TetrisColor(int value) {
        this.value = value;
    }

    private static final TetrisColor VALUES[] = values();

    public static TetrisColor getRandomColor() {
        return VALUES[Tetris.RANDOM.nextInt(VALUES.length)];
    }
}

class TetrisScreen {
    private boolean useColor = true;
    private String s = "";

    public void print(String s) {
        this.s += s;
    }

    public void xyprint(int x, int y, String s) {
        this.s += ("\u001B[" + y + ";" + x + "H" + s);
    }

    public void showCursor() {
        s += "\u001B[?25h";
    }

    public void hideCursor() {
        s += "\u001B[?25l";
    }

    public void setFg(TetrisColor c) {
        if (useColor) {
            s += ("\u001B[3" + c.value + "m");
        }
    }

    public void setBg(TetrisColor c) {
        if (useColor) {
            s += ("\u001B[4" + c.value + "m");
        }
    }

    public void resetColors() {
        s += "\u001B[0m";
    }

    public void setBold() {
        s += "\u001B[1m";
    }

    public void clearScreen() {
        s += "\u001B[2J";
    }

    public void flush() {
        System.out.print(s);
        s = "";
    }

    public void toggleColor() {
        useColor ^= true;
    }
}

abstract class TetrisScreenItem {
    public boolean visible = true;
    protected TetrisScreen screen = null;

    public abstract void draw(boolean visible);

    public TetrisScreenItem(TetrisScreen screen) {
        visible = true;
        this.screen = screen;
    }

    public void show() {
        if (visible) {
            draw(true);
        }
    }

    public void hide() {
        if (visible) {
            draw(false);
        }
    }

    public void toggle() {
        visible ^= true;
        draw(visible);
    }
}

class TetrisHelp extends TetrisScreenItem {
    private final TetrisColor color = Tetris.HELP_COLOR;
    private String[] text = {
        "  Use cursor keys",
        "       or",
        "    s: rotate",
        "a: left,  d: right",
        "    space: drop",
        "      q: quit",
        "  c: toggle color",
        "n: toggle show next",
        "h: toggle this help"
    };

    public TetrisHelp(TetrisScreen screen) {
        super(screen);
    }

    public void draw(boolean visible) {
        screen.setBold();
        screen.setFg(color);
        for (int i = 0; i < text.length; i++) {
            String s = text[i];
            if (! visible) {
                s = new String(new char[s.length()]).replace("\0", " ");
            }
            screen.xyprint(Tetris.HELP_X, Tetris.HELP_Y + i, s);
        }
        screen.resetColors();
    }
}

class TetrisScore {
    private int score = 0;
    private int level = 1;
    private int linesCompleted = 0;
    private TetrisScreen screen = null;

    TetrisScore(TetrisScreen screen) {
        this.screen = screen;
    }

    public void update(int completeLines) {
        linesCompleted += completeLines;
        score += (completeLines * completeLines);
        if (score > Tetris.LEVEL_UP * level) {
            level += 1;
            TetrisTicker.decreaseDelay();
        }
        show();
    }

    public void show() {
        screen.setBold();
        screen.setFg(Tetris.SCORE_COLOR);
        screen.xyprint(Tetris.SCORE_X, Tetris.SCORE_Y,     "Lines completed: " + linesCompleted);
        screen.xyprint(Tetris.SCORE_X, Tetris.SCORE_Y + 1, "Level:           " + level);
        screen.xyprint(Tetris.SCORE_X, Tetris.SCORE_Y + 2, "Score:           " + score);
        screen.resetColors();
    }
}

class TetrisPlayField {
    private TetrisScreen screen = null;
    private List<List<TetrisColor>> cells = new ArrayList<List<TetrisColor>>();

    public TetrisPlayField(TetrisScreen screen) {
        this.screen = screen;
        for (int i = 0; i < Tetris.PLAYFIELD_H; i++) {
            cells.add(getEmptyRow());
        }
    }

    public List<TetrisColor> getEmptyRow() {
        List<TetrisColor> row = new ArrayList<TetrisColor>();
        for (int i = 0; i < Tetris.PLAYFIELD_W; i++) {
            row.add(null);
        }
        return row;
    }

    public void show() {
        for (int y = 0; y < cells.size(); y++ ) {
            List<TetrisColor> row = cells.get(y);
            screen.xyprint(Tetris.PLAYFIELD_X, Tetris.PLAYFIELD_Y + y, "");
            for (TetrisColor cell : row) {
                if (cell == null) {
                    screen.print(Tetris.PLAYFIELD_EMPTY_CELL);
                } else {
                    screen.setFg(cell);
                    screen.setBg(cell);
                    screen.print(Tetris.FILLED_CELL);
                    screen.resetColors();
                }
            }
        }
    }

    public void flattenPiece(TetrisPiece piece) {
        for (int[] cell : piece.getCells(null)) {
            int x = cell[0];
            int y = cell[1];
            cells.get(y).set(x, piece.color);
        }
    }

    public int processCompleteLines() {
        List<List<TetrisColor>> newCells = new ArrayList<List<TetrisColor>>();
        for (List<TetrisColor> row : cells) {
            if (row.indexOf(null) != -1) {
                newCells.add(row);
            }
        }
        int completeLines = Tetris.PLAYFIELD_H - newCells.size();
        for (int i = 0; i < completeLines; i++) {
            newCells.add(0, getEmptyRow());
        }
        cells = newCells;
        return completeLines;
    }

    public void drawBorder() {
        screen.setBold();
        screen.setFg(Tetris.BORDER_COLOR);
        for (int y = 0; y < Tetris.PLAYFIELD_H; y++) {
            // 2 because border is 2 characters thick
            screen.xyprint(Tetris.PLAYFIELD_X - 2, y + Tetris.PLAYFIELD_Y, "<|");
            // 2 because each cell on play field is 2 characters wide
            screen.xyprint(Tetris.PLAYFIELD_X + Tetris.PLAYFIELD_W * 2, y + Tetris.PLAYFIELD_Y, "|>");
        }

        screen.xyprint(Tetris.PLAYFIELD_X, Tetris.PLAYFIELD_Y + Tetris.PLAYFIELD_H, new String(new char[Tetris.PLAYFIELD_W]).replace("\0", "=="));
        screen.xyprint(Tetris.PLAYFIELD_X, Tetris.PLAYFIELD_Y + Tetris.PLAYFIELD_H + 1, new String(new char[Tetris.PLAYFIELD_W]).replace("\0", "\\/"));
        screen.resetColors();
    }

    public boolean positionOk(TetrisPiece piece, int[] position) {
        for (int[] cell : piece.getCells(position)) {
            int x = cell[0];
            int y = cell[1];
            if (x < 0 || x >= Tetris.PLAYFIELD_W || y < 0 || y >= Tetris.PLAYFIELD_H || cells.get(y).get(x) != null) {
                return false;
            }
        }
        return true;
    }
}

class TetrisPiece extends TetrisScreenItem {
    public TetrisColor color = null;
    public String emptyCell = Tetris.NEXT_EMPTY_CELL;
    public int[] origin = {0, 0};

    private int symmetry = 0;
    private int[] position = {0, 0, 0};
    private int[] data = null;
    // 0123
    // 4567
    // 89ab
    // cdef
    private static int[][] pieceData = {
        {0x1256}, // square
        {0x159d, 0x4567}, // line
        {0x4512, 0x0459}, // s
        {0x0156, 0x1548}, // z
        {0x159a, 0x8456, 0x0159, 0x2654}, // l
        {0x1598, 0x0456, 0x2159, 0xa654}, // inverted l
        {0x1456, 0x1596, 0x4569, 0x4159}  // t
    };

    public TetrisPiece(TetrisScreen screen, int[] origin, boolean visible) {
        super(screen);
        this.origin = origin;
        this.visible = visible;
        color = TetrisColor.getRandomColor();
        data = pieceData[Tetris.RANDOM.nextInt(pieceData.length)];
        symmetry = data.length;
        position = new int[]{0, 0, Tetris.RANDOM.nextInt(symmetry)};
    }

    public int[][] getCells(int[] newPosition) {
        int x = position[0];
        int y = position[1];
        int z = position[2];
        if (newPosition != null) {
            x = newPosition[0];
            y = newPosition[1];
            z = newPosition[2];
        }
        int currentData = data[z];
        int result[][] = {{0, 0}, {0, 0}, {0, 0}, {0, 0}};
        for (int i = 0; i < 4; i++) {
            result[i][0] = x + ((currentData >> 4 * i) & 3);
            result[i][1] = y + ((currentData >> 4 * i + 2) & 3);
        }
        return result;
    }

    public void draw(boolean visible) {
        if (visible) {
            screen.setFg(color);
            screen.setBg(color);
        }
        int ox = origin[0];
        int oy = origin[1];
        for (int[] cell : getCells(null)) {
            int x = cell[0];
            int y = cell[1];
            screen.xyprint(ox + x * 2, oy + y, visible ? Tetris.FILLED_CELL : emptyCell);
        }
        screen.resetColors();
    }

    public void setPosition(int[] p) {
        position = new int[]{p[0], p[1], p[2] < 0 ? position[2] : p[2]};
    }

    public int[] newPosition(int dx, int dy, int dz) {
        int x = position[0];
        int y = position[1];
        int z = position[2];
        return new int[]{x + dx, y + dy, (z + dz) % symmetry};
    }
}

class TetrisController {
    public boolean running = true;

    private TetrisScreen screen = null;
    private TetrisHelp help = null;
    private TetrisScore score = null;
    private TetrisPlayField playfield = null;
    private boolean nextPieceVisible = true;
    private TetrisPiece nextPiece = null;
    private TetrisPiece currentPiece = null;

    public TetrisController(TetrisScreen screen) {
        this.screen = screen;
        help = new TetrisHelp(screen);
        score = new TetrisScore(screen);
        playfield = new TetrisPlayField(screen);
        getNextPiece();
        getCurrentPiece();
        redrawScreen();
        screen.flush();
    }

    public void getCurrentPiece() {
        nextPiece.hide();
        currentPiece = nextPiece;
        currentPiece.setPosition(new int[]{(Tetris.PLAYFIELD_W - 4) / 2, 0, -1});
        if (! playfield.positionOk(currentPiece, null)) {
            cmdQuit();
            return;
        }
        currentPiece.visible = true;
        currentPiece.emptyCell = Tetris.PLAYFIELD_EMPTY_CELL;
        currentPiece.origin = new int[]{Tetris.PLAYFIELD_X, Tetris.PLAYFIELD_Y};
        currentPiece.show();
        getNextPiece();
    }

    public void getNextPiece() {
        nextPiece = new TetrisPiece(screen, new int[]{Tetris.NEXT_X, Tetris.NEXT_Y}, nextPieceVisible);
        nextPiece.show();
    }

    public void cmdToggleColor() {
        screen.toggleColor();
        redrawScreen();
    }

    public void cmdToggleNext() {
        nextPieceVisible ^= true;
        nextPiece.toggle();
    }

    public void cmdToggleHelp() {
        help.toggle();
    }

    public void cmdQuit() {
        running = false;
        screen.xyprint(Tetris.GAMEOVER_X, Tetris.GAMEOVER_Y, "Game over!");
        screen.xyprint(Tetris.GAMEOVER_X, Tetris.GAMEOVER_Y + 1, "");
        screen.showCursor();
    }

    public void cmdRotate() {
        move(0, 0, 1);
    }

    public void cmdLeft() {
        move(-1, 0, 0);
    }

    public void cmdRight() {
        move(1, 0, 0);
    }

    public boolean cmdDown() {
        if (move(0, 1, 0)) {
            return true;
        }
        getCurrentPiece();
        return false;
    }

    public void cmdDrop() {
        while (cmdDown()) {};
    }

    public void redrawScreen() {
        screen.clearScreen();
        screen.hideCursor();
        playfield.drawBorder();
        help.show();
        playfield.show();
        score.show();
        nextPiece.show();
        currentPiece.show();
    }

    public void processFallenPiece() {
        playfield.flattenPiece(currentPiece);
        int completeLines = playfield.processCompleteLines();
        if (completeLines > 0) {
            score.update(completeLines);
            playfield.show();
        }
    }

    public boolean move(int dx, int dy, int dz) {
        int[] newPosition = currentPiece.newPosition(dx, dy, dz);
        if (playfield.positionOk(currentPiece, newPosition)) {
            currentPiece.hide();
            currentPiece.setPosition(newPosition);
            currentPiece.show();
            return true;
        }
        if (dy == 0) {
            return true;
        }
        processFallenPiece();
        return false;
    }

    public void screenFlush() {
        screen.flush();
    }
}

