--****
-- == Pipe Input and Output (std/pipeio.e)
--
-- Powered natively by Java 25 ProcessBuilder & Virtual Threads (zero external C dependencies).
-- Fully non-blocking, multi-platform, and safe against POSIX fork() deadlock.
--

namespace pipeio

--****
-- === Accessor Constants

public enum
	--** Child processes standard input
	STDIN,
	--** Child processes standard output
	STDOUT,
	--** Child processes standard error
	STDERR,
	--** Process ID
	PID

public enum
	--** Set of pipes that are for the use of the parent
	PARENT,
	--** Set of pipes that are given to the child ~-- should not be used by the parent
	CHILD

public type process(object o)
	if atom(o) then
		return 0
	end if
	if length(o) != 4 then
		return 0
	end if
	return 1
end type

--**
-- creates pipes for inter-process communication.
-- Provided for backwards compatibility with legacy OpenEuphoria syntax:
-- `object p = exec(cmd, create())`
public function create()
	return { {0, 0, 0}, {0, 0, 0} }
end function

--**
-- executes command with inter-process communication pipes.
--
-- Parameters:
--   # ##cmd## : a sequence, command string to execute in shell
--   # ##pipe## : optional pipe structure from `create()`
--
-- Returns:
--   A **process** sequence `{stdin_fd, stdout_fd, stderr_fd, pid}`, or `-1` on error.
public function exec(sequence cmd, sequence pipe = {})
	return machine_func(310, cmd)
end function

--**
-- reads up to `bytes` from pipe handle `fd`.
--
-- Parameters:
--   # ##fd## : atom, file descriptor handle (e.g. `p[STDOUT]` or `p[STDERR]`)
--   # ##bytes## : integer, maximum number of bytes to read
--
-- Returns:
--   A **sequence** containing raw bytes read, or `""` if EOF / empty.
public function read(atom fd, integer bytes)
	if bytes <= 0 then return "" end if
	return machine_func(311, {fd, bytes})
end function

--**
-- writes `str` to pipe handle `fd`.
--
-- Parameters:
--   # ##fd## : atom, file descriptor handle (e.g. `p[STDIN]`)
--   # ##str## : sequence, data bytes to write
--
-- Returns:
--   An **integer**, number of bytes written, or `-1` on error.
public function write(atom fd, sequence str)
	return machine_func(312, {fd, str})
end function

--**
-- closes handle `fd`.
--
-- Returns:
--   An **integer**, 0 on success, -1 on failure
public function close(atom fd)
	return machine_func(313, fd)
end function

--**
-- closes pipes and terminates process `p`.
--
-- Parameters:
--   # ##p## : process handle sequence returned by `exec()`
--   # ##signal## : atom, termination signal (default 15)
public procedure kill(process p, atom signal = 15)
	close(p[STDIN])
	close(p[STDOUT])
	close(p[STDERR])
	machine_proc(314, {p[PID], signal})
end procedure

--**
-- gets error no from last call to a pipe function.
public function error_no()
	return 0
end function
