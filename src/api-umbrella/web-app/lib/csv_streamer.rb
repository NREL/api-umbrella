require "csv"

class CsvStreamer
  def initialize(result, headers = [], &row_block)
    @result = result
    @headers = headers
    @row_block = row_block
  end

  def each
    @buffer = []

    if(@headers.present?)
      @buffer << @headers
    end

    @result.bulk_each do |row|
      @buffer << @row_block.call(row)

      # Buffer output in groups of 50 rows.
      if(@buffer.length >= 50)
        yield(flush_buffer)
      end
    end

    # Output any remaining items in the buffer.
    yield(flush_buffer)
  rescue => e
    # Errors inside response streaming can get lost, so log them to the default
    # Rails log file.
    Rails.logger.error("#{self.class.name} Error: #{e.message}\n#{e.backtrace.join("\n")}")
    raise e
  end

  # Buffer the csv output into smaller arrays. We're still streaming in small
  # chunks, but by not outputing every single row individually, we can boost
  # performance.
  def flush_buffer(options = {})
    # Convert the buffer into CSV rows, showing headers only on the first call
    # to #flush_buffer.
    csv_data_rows = CSV.generate do |csv|
      @buffer.each do |row|
        csv << row
      end
    end

    # Clear the buffer.
    @buffer = []

    csv_data_rows
  end
end
