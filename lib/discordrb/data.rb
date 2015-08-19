# These classes hold relevant Discord data, such as messages or channels.

module Discordrb
  class Message
    attr_reader :content, :author, :channel, :timestamp, :id, :mentions
    alias_method :user, :author
    alias_method :text, :content

    def initialize(data)
      @content = data['content']
      @author = User.new(data['author'])
      # TODO: Channel
      @timestamp = Time.at(data['timestamp'].to_i)
      @id = data['id'].to_i

      @mentions = []

      data['mentions'].each do |element|
        @mentions << User.new(element)
      end
    end
  end
end
