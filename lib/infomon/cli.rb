# frozen_string_literal: true

module Infomon
  # CLI commands for Infomon
  def self.sync
    # since none of this information is 3rd party displayed, silence is golden.
    respond 'Infomon sync requested.'
    request = { 'info'            => /<a exist=.+#{XMLData.name}/,
                'skill'           => /<a exist=.+#{XMLData.name}/,
                'spell'           => %r{<output class="mono"/>},
                'experience'      => %r{<output class="mono"/>},
                'society'         => %r{<pushBold/>},
                'citizenship'     => /^You don't seem|^You currently have .+ in/,
                'armor list all'  => /<a exist=.+#{XMLData.name}/,
                'cman list all'   => /<a exist=.+#{XMLData.name}/,
                'feat list all'   => /<a exist=.+#{XMLData.name}/,
                'shield list all' => /<a exist=.+#{XMLData.name}/,
                'weapon list all' => /<a exist=.+#{XMLData.name}/,
                'warcry'          => /^You have learned the following War Cries:|^You must be an active member of the Warrior Guild to use this skill/ }

    request.each do |command, start_capture|
      respond "Retrieving character #{command}." if $infomon_debug
      Lich::Util.issue_command(command.to_s, start_capture, /<prompt/, true, 5, false, true, true)
      respond "Did #{command}." if $infomon_debug
    end
    respond 'Requested Infomon sync complete.'
  end

  def self.redo!
    # Destructive - deletes char table, recreates it, then repopulates it
    respond 'Infomon complete reset reqeusted.'
    Infomon.reset!
    Infomon.sync
    respond 'Infomon reset is now complete.'
  end

  def self.show(full = false)
    response = []
    # display all stored db values
    respond "Displaying stored information for #{XMLData.name}"
    Infomon.table.map([:key, :value]).each { |k, v|
      response << "#{k} : #{v.inspect}\n"
    }
    unless full
      response.each { |_line|
        response.reject! do |line|
          line.match?(/\s:\s0$/)
        end
      }
    end
    respond response
  end
end
