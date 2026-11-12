include std/pipeio.e as pipe
include std/cmdline.e

sequence list = command_line()
sequence interpreter = list[1]
sequence port = "54321"
sequence cmd = interpreter & " " & build_commandline( option_switches() ) & " ../demo/net/sock_server.ex " & port
printf(1, "cmd: %s\n", {cmd})
object p = pipe:exec(cmd, pipe:create())
? p
