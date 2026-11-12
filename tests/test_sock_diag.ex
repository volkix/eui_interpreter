include std/pipeio.e as pipe
include std/socket.e as sock
include std/os.e

sequence port = "54321"
sequence cmd = "/home/volkix/prj/intpret/eui-java ../demo/net/sock_server.ex " & port
printf(1, "Launching: %s\n", {cmd})
object p = pipe:exec(cmd, pipe:create())
printf(1, "Process: %s\n", {sprint(p)})

sock:socket client = sock:create(AF_INET, SOCK_STREAM, 0)
integer connected = 0
for i = 1 to 5 do
    sleep(1)
    atom c = sock:connect(client, "127.0.0.1", 54321)
    printf(1, "Attempt %d: %d\n", {i, c})
    if c = 0 then
        connected = 1
        exit
    end if
end for

object void
if connected then
    puts(1, "Connected successfully!\n")
    void = sock:send(client, "Hello, ")
    object r = sock:receive(client)
    printf(1, "Received: '%s'\n", {r})
    void = sock:send(client, "quit\n")
    void = sock:close(client)
else
    puts(1, "Failed to connect!\n")
end if

pipe:kill(p)
