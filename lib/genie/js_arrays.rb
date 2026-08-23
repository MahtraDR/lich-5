# frozen_string_literal: true

module Lich
  module Genie
    # Native Ruby port of the community `js_arrays.js` Genie library -- the ONLY
    # JavaScript used anywhere in the validated corpus (DR-Genie-Scripts `JS_Arrays/`,
    # `Miner/mining.cmd`, `mm_train/mm_train.cmd`). Genie's language has no array type,
    # so this library stores arrays as `|`-delimited strings in LOCAL variables and
    # manipulates them through `js`/`jscall`. Rather than embed a JavaScript engine we
    # reimplement its ~two dozen operations, because every real script copies this one
    # library verbatim, so a targeted shim covers 100% of observed JS usage.
    #
    # Semantics preserved from js_arrays.js:
    #   * arrays live in local vars: `getVar`/`setVar` == local_get/local_set;
    #   * mutating ops (`js doPush(...)`) write the array back in place and return nothing;
    #   * value ops (`jscall v doPop(...)`) return a value the caller stores into `v`;
    #   * `findMax/MinGlobal` treat the array's items as GLOBAL var NAMES and look them up.
    #
    # Deliberate divergence: `%name`/`$name` argument references are resolved by the
    # engine's substitution pass BEFORE we run (every other verb works that way), so --
    # unlike the JS, which resolves them itself via getVar/getGlobal -- we receive already
    # -resolved values and do NOT re-resolve (avoids double resolution). The JS's own
    # numeric findMax/Min do a buggy string `>`/`<` (and findMinIndex even returns the
    # value, not the index); since no real script uses those, we implement the documented
    # NUMERIC intent instead. The heavily-used ops (doXCompare, doPush, doInsert, doRemove,
    # doConcat, find/checkExists, pop/shift/unshift, doSort) are exact.
    class JsArrays
      SEP = '|'

      # @param store [#local_get, #local_set, #global_get] the variable store (Variables)
      def initialize(store)
        @store = store
      end

      # Dispatch one parsed call.
      # @param func [String] JS function name (case-sensitive, as authored)
      # @param args [Array<String>] positional args (quotes already stripped)
      # @return [String, nil, :unknown] a value for `jscall`; nil for pure mutators;
      #   :unknown when the function is not part of js_arrays.js (caller announces).
      def call(func, args)
        case func.to_s
        when 'doSort'        then mutate { do_sort(args[0], args[1]) }
        when 'doPush'        then mutate { do_push(args[0], args[1]) }
        when 'doUnshift'     then mutate { do_unshift(args[0], args[1]) }
        when 'doInsert'      then mutate { do_insert(args[0], args[1], args[2]) }
        when 'doRemove'      then mutate { do_remove(args[0], args[1]) }
        when 'doReplace'     then mutate { do_replace(args[0], args[1], args[2]) }
        when 'doConcat'      then mutate { do_concat(args[0], args[1]) }
        when 'buildArray'    then mutate { build_array(args[0], args[1]) }
        when 'buildArrayStr' then mutate { build_array_str(args[0], args[1], args[2]) }
        when 'doPop'         then do_pop(args[0])
        when 'doShift'       then do_shift(args[0])
        when 'findIndex'     then find_index(args[0], args[1])
        when 'checkExists'   then check_exists(args[0], args[1])
        when 'doXCompare'    then x_compare(args[0], args[1], args[2])
        when 'findMax'       then find_extreme(args[0], :max)
        when 'findMin'       then find_extreme(args[0], :min)
        when 'findMaxIndex'  then find_extreme_index(args[0], :max)
        when 'findMinIndex'  then find_extreme_index(args[0], :min)
        when 'findMaxGlobal' then find_extreme_global(args[0], :max)
        when 'findMinGlobal' then find_extreme_global(args[0], :min)
        when 'zipArrays'     then zip_arrays(args[0], args[1])
        else :unknown
        end
      end

      private

      # Run a mutator and report nothing (js-style void call).
      def mutate
        yield
        nil
      end

      # Read a local var as an array. Genie treats an unset/empty var as an empty array.
      def list_of(name)
        raw = @store.local_get(name).to_s
        raw.empty? ? [] : raw.split(SEP, -1)
      end

      def store_list(name, arr)
        @store.local_set(name, arr.join(SEP))
      end

      # --- mutators ---------------------------------------------------------

      def do_sort(name, sorting)
        arr = list_of(name).sort
        arr.reverse! if sorting.to_s == '1' # 0 ascending, 1 descending
        store_list(name, arr)
      end

      def do_push(name, item)
        store_list(name, list_of(name).push(item.to_s))
      end

      def do_unshift(name, item)
        store_list(name, list_of(name).unshift(item.to_s))
      end

      # Insert item(s) (a `|` string) at +position+ (clamped in range so we never pad nils).
      def do_insert(name, items, position)
        arr = list_of(name)
        pos = [[position.to_i, 0].max, arr.length].min
        arr.insert(pos, *items.to_s.split(SEP, -1))
        store_list(name, arr)
      end

      # Remove the first occurrence of +srch+ (js_arrays ignores its documented `amount`).
      def do_remove(name, srch)
        arr = list_of(name)
        idx = arr.index(srch.to_s)
        return if idx.nil?

        arr.delete_at(idx)
        store_list(name, arr)
      end

      def do_replace(name, position, item)
        arr = list_of(name)
        pos = position.to_i
        return if pos.negative? || pos > arr.length

        arr[pos] = item.to_s # pos == length appends, matching JS list[position] = item
        store_list(name, arr)
      end

      def do_concat(name, other)
        store_list(name, list_of(name) + other.to_s.split(SEP, -1))
      end

      # Build a Genie array from prose ("a foo, a bar and some baz" -> "foo|bar|baz").
      def build_array(name, raw)
        store_list(name, split_prose(raw))
      end

      def build_array_str(name, raw, pattern)
        regex = Regexp.new(pattern.to_s, Regexp::IGNORECASE)
        store_list(name, split_prose(raw).select { |item| regex.match?(item) })
      end

      def split_prose(raw)
        cleaned = raw.to_s.gsub(', ', SEP).sub(/ and (?:an?|some) /, SEP).gsub(/\ban? /, '')
        cleaned.empty? ? [] : cleaned.split(SEP, -1)
      end

      # --- value-returning --------------------------------------------------

      def do_pop(name)
        arr = list_of(name)
        return '0' if arr.empty?

        value = arr.pop
        store_list(name, arr)
        value
      end

      def do_shift(name)
        arr = list_of(name)
        return '0' if arr.empty?

        value = arr.shift
        store_list(name, arr)
        value
      end

      def find_index(name, srch)
        (list_of(name).index(srch.to_s) || -1).to_s
      end

      def check_exists(name, srch)
        list_of(name).include?(srch.to_s) ? '1' : '0'
      end

      # Find +srch+ in the source array; return the item at the same index of the target
      # array (the mining/mm_train workhorse). -1 when not found or target too short.
      def x_compare(source, target, srch)
        idx = list_of(source).index(srch.to_s)
        return '-1' if idx.nil?

        (list_of(target)[idx] || '-1').to_s
      end

      def find_extreme(name, dir)
        arr = list_of(name)
        return '' if arr.empty?

        (dir == :max ? arr.max_by { |v| v.to_f } : arr.min_by { |v| v.to_f }).to_s
      end

      def find_extreme_index(name, dir)
        arr = list_of(name)
        return '-1' if arr.empty?

        idx = extreme_index(arr.map { |v| v.to_f }, dir)
        idx.to_s
      end

      # Array items are GLOBAL var names; return the name whose global holds the max/min.
      def find_extreme_global(name, dir)
        names = list_of(name)
        return '' if names.empty?

        values = names.map { |global| @store.global_get(global).to_f }
        names[extreme_index(values, dir)].to_s
      end

      def extreme_index(values, dir)
        target = dir == :max ? values.max : values.min
        values.index(target)
      end

      def zip_arrays(first, second)
        merged = list_of(first)
        list_of(second).each { |item| merged << item unless merged.include?(item) }
        merged.join(SEP)
      end
    end
  end
end
