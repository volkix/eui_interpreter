include std/pipeio.e as pipe
include std/cmdline.e
include std/os.e

sequence list = command_line()
sequence interpreter = list[1]
sequence port = "54321"
sequence cmd = interpreter & " " & build_commandline( option_switches() ) & " ../demo/net/sock_server.ex " & port
object p = pipe:exec(cmd, pipe:create())
sleep(1)
object err = pipe:read(p[pipe:STDERR], 1024)
printf(1, "stderr: '%s'\n", {err})
object out = pipe:read(p[pipe:STDOUT], 1024)
printf(1, "stdout: '%s'\n", {out})
pipe:kill(p)
