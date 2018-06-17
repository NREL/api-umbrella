require "shellwords"

module ApiUmbrellaTestHelpers
  module Shell
    # Run a shell command, and cpature its exit code and output (combined
    # stdout and stderr).
    #
    # This is basically equivalent to Open3.capture2e, but we had randomly
    # encountered "IOError: closed stream" errors in our CI test suite when
    # using that. I'm not entirely sure why, but it's possibly related to
    # thread-safety issues, since some of our tests run shell commands inside
    # threads, and Open3 also has some internal threading. We could potentially
    # revisit this and debug the threading issues, but this approach using
    # backticks seems to have proven stable.
    def run_shell(*args)
      output = `#{Shellwords.join(args)} 2>&1`
      status = $CHILD_STATUS.to_i
      [output, status]
    end
  end
end
