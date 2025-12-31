module Ethon
  class Easy
    module Callbacks
      @@debug_callback_exclude_types = []

      # Override Ethon's default debug callback
      # (https://github.com/typhoeus/ethon/blob/v0.9.1/lib/ethon/easy/callbacks.rb#L66-L73)
      # so it only captures the debug output and doesn't print it to the
      # screen. This seems to be the behavior we want more frequently, so
      # override this globally and only allow printing to STDOUT if the
      # DEBUG_HTTP environment variable is set.
      #
      # See https://github.com/typhoeus/typhoeus/issues/247
      def debug_callback
        @debug_callback ||= proc do |handle, type, data, size, udata|
          if !@@debug_callback_exclude_types.include?(type)
            message = data.read_string(size)
            @debug_info.add type, message
            if(ENV.fetch("DEBUG_HTTP", nil) == "true")
              print message unless [:data_in, :data_out].include?(type)
            end
          end
          0
        end
      end
    end
  end
end
