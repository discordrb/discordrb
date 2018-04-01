if Gem::Version.new(RUBY_VERSION) >= Gem::Version.new('2.5') && ENV['OS'] == 'Windows_NT'
    
  # @note In Ruby versions greater than 2.4 on Windows, Discordrb's
  # environment does not play nicely with the use of enumerators in
  # this specific function. The exact reason is unknown, but changing the use of
  # `Enumerator#next` into iteration via `Array#shift` prevents a silent crash.
  module RestClient
    module Utils
      def self.cgi_parse_header(line)
        parts = _cgi_parseparam(';' + line).to_a
        key = parts[0]
        pdict = {}

        while (p = parts.shift)
          i = p.index('=')
          next if !i

          name = p[0...i].strip.downcase
          value = p[i + 1..-1].strip
          if value.length >= 2 && value[0] == '"' && value[-1] == '"'
            value = value[1...-1]
            value = value.gsub('\\\\', '\\').gsub('\\"', '"')
          end
          pdict[name] = value
        end

        [key, pdict]
      end
    end
  end
end
