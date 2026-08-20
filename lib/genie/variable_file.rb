# frozen_string_literal: true

require 'fileutils'

module Lich
  module Genie
    # Read/write Genie's `variables.cfg` format: one variable per line as
    #   #var {key} {value}
    # parsed with Genie's ParseArgs rules (ported as {Text.parse_args}). Faithful to
    # Genie4 Globals.cs Variables.Load/Save (LoadRow takes any 3-arg line's [1],[2];
    # Save writes only bSaveToFile vars as `#var {key} {value}`).
    module VariableFile
      module_function

      # @param path [String, nil]
      # @return [Hash{String=>String}] key => value (empty if the file is absent)
      def load(path)
        entries = {}
        return entries unless path && File.exist?(path)

        File.foreach(path) do |line|
          args = Text.parse_args(line.chomp)
          entries[args[1]] = args[2] if args.length == 3
        end
        entries
      end

      # @param entries [Hash{String=>String}]
      # @return [String] serialized variables.cfg content
      def dump(entries)
        return '' if entries.empty?

        "#{entries.map { |key, value| "#var {#{key}} {#{value}}" }.join("\n")}\n"
      end

      # Atomically write +entries+ to +path+ (temp file + rename), tolerating
      # Windows' transient rename locks. `variables.cfg` is rewritten on every
      # `#var`, so under combat churn (and concurrent scripts) the rename can hit
      # "Permission denied" when an AV/indexer/other handle briefly holds the file.
      # Retry a few times, then fall back to a direct overwrite; the temp file is
      # always cleaned up. Callers treat persistence as best-effort.
      # @param path [String]
      # @param entries [Hash{String=>String}]
      # @return [void]
      def save(path, entries)
        FileUtils.mkdir_p(File.dirname(path))
        tmp = "#{path}.tmp.#{Process.pid}"
        File.write(tmp, dump(entries))
        atomic_replace(tmp, path)
      ensure
        File.delete(tmp) if tmp && File.exist?(tmp)
      end

      # @return [void]
      def atomic_replace(tmp, path)
        attempts = 0
        begin
          File.rename(tmp, path)
        rescue SystemCallError
          attempts += 1
          if attempts < 10
            sleep 0.05
            retry
          end
          # Rename can't replace a locked target on Windows; try a direct write.
          File.binwrite(path, File.binread(tmp))
        end
      end
    end
  end
end
