pub fn shellwords(args: []const u8, back: [][]const u8) [][]const u8 {
    var store: usize = 0;
    var start: usize = 0;

    var quote_back = state.nil;
    var s = state.nil;

    var i: usize = 0;
    while (i < args.len) : (i += 1) {
        const ch = args[i];
        const blank = ch == ' ' or ch == '\t';
        const quote = ch == '\'' or ch == '"';

        switch (s) {
            .nil => {
                if (!blank) {
                    start = i;
                    s = .capture;
                }

                if (quote) {
                    start = i + 1;
                    quote_back = s;
                    s = .quote;
                }
            },

            .capture => {
                if (blank) {
                    back[store] = args[start..i];
                    store += 1;

                    s = .nil;
                }

                if (quote) {
                    quote_back = s;
                    s = .quote;
                }
            },

            .quote => {
                if (quote) {
                    back[store] = args[start..i];
                    store += 1;

                    s = .nil;
                }
            },
        }
    }

    if (s != .nil) {
        back[store] = args[start..args.len];
        store += 1;
    }

    return back[0..store];
}

const state = enum {
    nil,
    capture,
    quote,
};
