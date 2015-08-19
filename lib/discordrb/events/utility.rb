module Discordrb::Events
  module Utility
    def matches_all(attributes, to_check, &block)
      # "Zeroth" case: attributes is nil
      return true unless attributes

      # First case: there's only a single attribute
      unless attributes.is_a? Array
        return yield(attributes, to_check)
      end

      # Second case: it's an array of attributes
      attributes.reduce(true) { |result, element| result && yield(element, to_check) }
    end
  end
end
