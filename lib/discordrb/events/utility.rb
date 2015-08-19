module Discordrb::Events::Utility
  def matches_all(attributes, to_check, &block)
    # First case: there's only a single attribute
    unless attributes.is_a? Array
      return true if yield(attributes, to_check)
    end

    # Second case: it's an array of attributes
    attributes.reduce(false) { |result, element| result || yield(element, to_check) }
  end
end
