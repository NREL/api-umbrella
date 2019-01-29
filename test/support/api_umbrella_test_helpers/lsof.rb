module ApiUmbrellaTestHelpers
  module Lsof
    def lsof(*conditions)
      all_processes = api_umbrella_process.all_processes

      rows = run_lsof(conditions, all_processes.fetch(:pids))

      # If running as root, also run lsof as each user that might own
      # processes. This is for Docker environments running as root, where
      # Docker's default security results in permission denied errors when
      # gathering information for other users:
      # https://unix.stackexchange.com/q/136690
      if(::Process.euid == 0)
        all_processes.fetch(:owners).each do |owner|
          next if(owner == "root")

          rows += run_lsof(conditions, all_processes.fetch(:pids), ["sudo", "-u", owner])
        end
      end

      rows.uniq!

      rows
    end

    def run_lsof(conditions, pids, sudo = [])
      # Note, we don't check the status, since lsof may return unsuccessful
      # exit codes in various cases (eg, there's no matching results for the
      # PIDs passed in).
      output, _status = run_shell(
        *sudo,
        "lsof",
        "-n", # Disable IPs to hostname translations.
        "-P", # Disable port number to name translations.
        "-l", # Disable user ID to username translations.
        "-F", # Machine-readable output.
        "-a", # AND together conditions.
        "-p",
        pids.join(","), # Limit to just API Umbrella PIDs.
        *conditions,
      )

      files = []
      lines = output.split("\n")

      # Parse the "-F" output of lsof, as described in lsof's "Output for Other
      # Programs" part of the man page.
      #
      # Basically, each attribute is on it's own line with a single-character
      # prefix denoting the field. The output is separated into groups, where
      # the "p" field indicates attributes for a new process, which can then
      # have multiple "f" field grouping inside to indicate attributes for each
      # file belonging to that process.
      parsed = {}
      parsing = nil
      lines.each do |line|
        field_id = line[0..0]
        value = line[1..-1]
        field = nil

        case field_id
        when "p"
          # If a new process grouping is encountered, append any previous files
          # that were previously being processed.
          if parsed[:file]
            files << parsed.fetch(:process).merge(parsed.fetch(:file))
          end

          # Setup a new group for this process's data.
          parsing = :process
          parsed[:process] = {}
          parsed[:file] = nil

          field = :pid
        when "f"
          # If a new file grouping is encountered, append any previous files
          # that were previously being processed.
          if parsed[:file]
            files << parsed.fetch(:process).merge(parsed.fetch(:file))
          end

          # Setup a new group for this file's data (belonging to a process
          # group that's already opened).
          parsing = :file
          parsed[:file] = {}

          field = :fd

        # Define more human-readable names for the fields.
        when "a"
          field = :access_mode
        when "c"
          field = :command
        when "d"
          field = :device
        when "g"
          field = :group
        when "G"
          field = :flags
        when "l"
          field = :lock
        when "n"
          field = :file
        when "o"
          field = :offset
        when "P"
          field = :protocol
        when "R"
          field = :ppid
        when "t"
          field = :type
        when "T"
          # The "T" field is special, since it can be specified multiple times,
          # but has a further suffix indicating the type of TCP field.
          tcp_info = line.split("=", 2)
          field = :"tcp_#{tcp_info[0][1..-1]}".downcase
          value = tcp_info[1]
        when "u"
          field = :user
        else
          field = field_id.to_sym
        end

        parsed[parsing][field] = value
      end

      # Handle the last process group after looping through the rest.
      if parsed[:file]
        files << parsed.fetch(:process).merge(parsed.fetch(:file))
      end

      files
    end
  end
end
