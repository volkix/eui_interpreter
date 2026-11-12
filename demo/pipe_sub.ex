include std/io.e
object line = gets(0)
if sequence(line) and length(line) > 0 and line[$] = '\n' then
    line = line[1..$-1]
end if
printf(1, "pipe_sub.ex: read from STDIN: '%s'", { line })
