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
      output = file.read
      @pos = file.pos
    end

    output
  end
end
