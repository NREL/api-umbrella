local execx = require("posix").execx
local signal = require "posix.signal"
local unistd = require "posix.unistd"
local wait = require("posix.sys.wait").wait

local STDERR_FILENO = unistd.STDERR_FILENO
local STDOUT_FILENO = unistd.STDOUT_FILENO
local close = unistd.close
local dup2 = unistd.dup2
local fork = unistd.fork
local pipe = unistd.pipe
local read = unistd.read

local READ_BUFFER_SIZE = 10240

-- Setup an empty SIGCHLD handler to replace the one in nginx. Otherwise,
-- waitpid is unreliable when run inside the "resty" CLI since nginx's SIGCHLD
-- handler prevents "wait" from waiting for the forked process.
--
-- Some related explanations:
-- https://stackoverflow.com/a/1609031/222487
-- https://github.com/openresty/resty-cli/issues/35#issuecomment-332676170
signal.signal(signal.SIGCHLD, function()
end)

-- Run a command line program and return its exit code and output.
return function(args)
  local output_pipe_read, output_pipe_write = pipe()
  if output_pipe_read == nil then
    return nil, nil, "Pipe error: " .. (output_pipe_write or "")
  end

  local pid, fork_err = fork()
  if pid == nil then
    return nil, nil, "Fork error: " .. (fork_err or "")
  end

  if pid == 0 then
    -- Forked child process:

    -- Capture the command's stdout and stderr in a single stream.
    dup2(output_pipe_write, STDOUT_FILENO)
    dup2(output_pipe_write, STDERR_FILENO)
    close(output_pipe_read)
    close(output_pipe_write)

    -- Replace the current process with the command to execute.
    execx(args)

    -- We should never get here, since execx should replace the current forked
    -- process.
    os.exit(1)
  else
    -- Original parent process:

    -- Close the write pipe.
    close(output_pipe_write)

    -- Read the output from the child process.
    local output = {}
    local read_chunk, read_err
    repeat
      read_chunk, read_err = read(output_pipe_read, READ_BUFFER_SIZE)
      if not read_err and read_chunk then
        table.insert(output, read_chunk)
      end
    until read_err or not read_chunk or #read_chunk == 0
    output = table.concat(output, "")
    close(output_pipe_read)

    -- Check the exit status of the child process once it exits.
    local err
    local _, reason, status = wait(pid)
    if status ~= 0 then
      err = reason
    end

    return status, output, err
  end
end
