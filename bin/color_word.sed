#Specific word/phrase highlighting
s#\<error[ [:alnum:]]*#\x1b[1;31m&\x1b[1;30m#i
s#\<warning[ [:alnum:]]*#\x1b[1;35m&\x1b[1;30m#i
s#\<info[ [:alnum:]]*#\x1b[1;34m&\x1b[0m#i
s#\<note:#\x1b[1;34m&\x1b[0m#i
s#\<total#\x1b[1;34m&\x1b[0m#i
s#^start .*#\x1b[1;34m&\x1b[0m#i
s#^run .*#\x1b[41m&\x1b[0m#i
