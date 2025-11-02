/// Dumb plaintext terminal color library.
pub const FG = struct {
    pub const BLACK = "\x1b[30m";
    pub const RED = "\x1b[31m";
    pub const GREEN = "\x1b[32m";
    pub const YELLOW = "\x1b[33m";
    pub const BLUE = "\x1b[34m";
    pub const MAGENTA = "\x1b[35m";
    pub const CYAN = "\x1b[36m";
    pub const WHITE = "\x1b[37m";
    pub const BRIGHT_BLACK = "\x1b[90m";
    pub const BRIGHT_RED = "\x1b[91m";
    pub const BRIGHT_GREEN = "\x1b[92m";
    pub const BRIGHT_YELLOW = "\x1b[93m";
    pub const BRIGHT_BLUE = "\x1b[94m";
    pub const BRIGHT_MAGENTA = "\x1b[95m";
    pub const BRIGHT_CYAN = "\x1b[96m";
    pub const BRIGHT_WHITE = "\x1b[97m";

    pub const COLORS: []const []const u8 = &.{
        BLACK,        RED,        GREEN,        YELLOW,        BLUE,        MAGENTA,        CYAN,        WHITE,
        BRIGHT_BLACK, BRIGHT_RED, BRIGHT_GREEN, BRIGHT_YELLOW, BRIGHT_BLUE, BRIGHT_MAGENTA, BRIGHT_CYAN, BRIGHT_WHITE,
    };

    pub const EFFECT = struct {
        pub const BOLD = "\x1b[1m";
        pub const DIM = "\x1b[2m";
        pub const ITALIC = "\x1b[3m";
        pub const UNDERLINE = "\x1b[4m";
        pub const BLINK = "\x1b[5m";
        pub const REVERSE = "\x1b[7m";
        pub const HIDDEN = "\x1b[8m";

        pub const RESET = struct {
            pub const BOLD = "\x1b[21m";
            pub const DIM = "\x1b[22m";
            pub const ITALIC = "\x1b[23m";
            pub const UNDERLINE = "\x1b[24m";
            pub const BLINK = "\x1b[25m";
            pub const REVERSE = "\x1b[27m";
            pub const HIDDEN = "\x1b[28m";
        };
    };
};

pub const BG = struct {
    pub const BLACK = "\x1b[40m";
    pub const RED = "\x1b[41m";
    pub const GREEN = "\x1b[42m";
    pub const YELLOW = "\x1b[43m";
    pub const BLUE = "\x1b[44m";
    pub const MAGENTA = "\x1b[45m";
    pub const CYAN = "\x1b[46m";
    pub const WHITE = "\x1b[47m";
    pub const BRIGHT_BLACK = "\x1b[100m";
    pub const BRIGHT_RED = "\x1b[101m";
    pub const BRIGHT_GREEN = "\x1b[102m";
    pub const BRIGHT_YELLOW = "\x1b[103m";
    pub const BRIGHT_BLUE = "\x1b[104m";
    pub const BRIGHT_MAGENTA = "\x1b[105m";
    pub const BRIGHT_CYAN = "\x1b[106m";
    pub const BRIGHT_WHITE = "\x1b[107m";

    pub const COLORS: []const []const u8 = &.{
        BLACK,        RED,        GREEN,        YELLOW,        BLUE,        MAGENTA,        CYAN,        WHITE,
        BRIGHT_BLACK, BRIGHT_RED, BRIGHT_GREEN, BRIGHT_YELLOW, BRIGHT_BLUE, BRIGHT_MAGENTA, BRIGHT_CYAN, BRIGHT_WHITE,
    };
};

pub const RESET = "\x1b[0m";
pub const SEP = " " ** 2;
