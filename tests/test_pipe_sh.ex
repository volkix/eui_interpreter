include std/pipeio.e as pipe
sequence cmd = "/home/volkix/prj/intpret/eui-java ../demo/net/sock_server.ex 54321 2> child_err.log"
object p = pipe:exec(cmd, pipe:create())
pipe:kill(p)
