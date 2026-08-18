# frozen_string_literal: true

module Lich
  module Genie
    # Resolver for Genie's `@...@` special variables (date/time + the script timer).
    # Ported from Genie4 Lists/Globals.cs ParseSpecialVariables + Script.cs @timer@.
    #
    # The clock and timer are injected so this is deterministic under test and so the
    # interpreter can supply the real elapsed-timer value.
    #
    # Faithful quirk preserved: Genie's `@month@` uses the .NET format "mm", which is
    # MINUTES, not the month. We reproduce that exactly (see #substitutions).
    class Specials
      # @param clock [#call] returns a Time (defaults to Time.now)
      # @param timer_elapsed [#call] returns elapsed script-timer seconds (defaults to 0)
      def initialize(clock: -> { Time.now }, timer_elapsed: -> { 0 })
        @clock = clock
        @timer_elapsed = timer_elapsed
      end

      # @return [Hash{String=>String}] token => current value, computed now
      def substitutions
        time = @clock.call
        {
          '@timer@'        => @timer_elapsed.call.to_s,
          '@time@'         => time.strftime('%I:%M:%S %p'),
          '@time24@'       => time.strftime('%H:%M:%S'),
          '@militarytime@' => time.strftime('%H%M'),
          '@date@'         => time.strftime('%m/%d/%Y'),
          '@datetime@'     => time.strftime('%m/%d/%Y %I:%M:%S %p'),
          '@datetime24@'   => time.strftime('%m/%d/%Y %H:%M:%S'),
          '@unixtime@'     => time.to_i.to_s,
          '@year@'         => time.strftime('%Y'),
          '@month@'        => time.strftime('%M'), # QUIRK: Genie's "mm" is minutes, not month
          '@dayofmonth@'   => time.strftime('%d'),
          '@dayofyear@'    => time.strftime('%j')
        }
      end
    end
  end
end
