class LogTail
  def initialize(filename)
    @path = File.join($config["log_dir"], filename)
    File.open(@path) do |file|
      file.seek(0, IO::SEEK_END)
      @pos = file.pos
    end
  end

  def read
    output = nil
    File.open(@path) do |file|
      file.seek(@pos)
      output = file.read.encode("UTF-8", invalid: :replace)
      @pos = file.pos
    end

    output
  end

  def read_until(regex, timeout: 5)
    output = ""
    begin
      Timeout.timeout(timeout) do
        loop do
          output << self.read.encode("UTF-8", invalid: :replace)
          break if output.match(regex)

          sleep 0.1
        end
      end
    rescue Timeout::Error
      raise "Timed out (#{timeout}s) waiting for content in log (#{@path}): #{regex}\nLog Output: #{output.inspect}"
    end

    output
  end
end
