s/.*error:.*/\x1b[1;30m&\x1b[0m/i
s/.*warning:.*/\x1b[1;30m&\x1b[0m/i
s/.*info:.*/\x1b[1;30m&\x1b[0m/i
s/^\(.*\)\(required from\)/\x1b[1;30m\1\x1b[0mnote: \2/
s/^\(.*\)\(In instantiation of\)/\x1b[1;30m\1\x1b[0mnote: \2/
s/^\(.*\)\(In member\)/\x1b[1;30m\1\x1b[0mnote: \2/