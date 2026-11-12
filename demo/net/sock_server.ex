include std/socket.e as sock
include std/convert.e

sequence cmd = command_line()
if length(cmd) < 3 then
    abort(1)
end if

object port_obj = to_integer(cmd[$])
if not integer(port_obj) then
    abort(1)
end if
integer port = port_obj

sock:socket server = sock:create(AF_INET, SOCK_STREAM, 0)
if atom(server) or server[1] < 0 then
    abort(1)
end if

object void
void = sock:set_option(server, SOL_SOCKET, SO_REUSEADDR, 1)

if sock:bind(server, "127.0.0.1", port) != 0 then
    abort(1)
end if

if sock:listen(server, 5) != 0 then
    abort(1)
end if

object client_info = sock:accept(server)
if sequence(client_info) and length(client_info) >= 1 then
    sock:socket client = client_info[1]
    while 1 do
        object data = sock:receive(client)
        if sequence(data) then
            if equal(data, "quit\n") then
                exit
            end if
            void = sock:send(client, data)
        else
            exit
        end if
    end while
    void = sock:close(client)
end if

void = sock:close(server)
