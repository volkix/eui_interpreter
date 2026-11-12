include std/socket.e as sock
sock:socket s = sock:create(AF_INET, SOCK_STREAM, 0)
atom res = sock:connect(s, "127.0.0.1", 54321)
printf(1, "connect res: %d\n", {res})
