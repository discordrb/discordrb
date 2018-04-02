# RestClient module, RestClient#get being the main scope of the issue
module RestClient
  # Utils contains the helper method that causes issues
  module Utils
    # @note In Ruby versions greater than 2.4 on Windows, Discordrb's 
    # environment does not play nicely with the use of enumerators in
    # this specific function. The exact reason is unknown, but changing the use of
    # `Enumerator#next` into iteration via `Array#shift` prevents a silent crash.
    def self.cgi_parse_header(line)
      parts = _cgi_parseparam(';' + line).to_a
      key = parts[0]
      pdict = {}

      while (p = parts.shift)
        i = p.index('=')
        next unless i

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
