# frozen_string_literal: true

require 'discordrb'

describe Discordrb::Paginator do
  context 'direction down' do
    it 'requests all pages until empty' do
      data = [
        [1, 2, 3],
        [4, 5],
        [],
        [6, 7]
      ]

      index = 0
      paginator = Discordrb::Paginator.new(nil, :down) do |last_page|
        expect(last_page).to eq data[index - 1] if last_page
        next_page = data[index]
        index += 1
        next_page
      end

      expect(paginator.to_a).to eq [1, 2, 3, 4, 5]
    end
  end

  context 'direction up' do
    it 'requests all pages until empty' do
      data = [
        [6, 7],
        [4, 5],
        [],
        [1, 2, 3]
      ]

      index = 0
      paginator = Discordrb::Paginator.new(nil, :up) do |last_page|
        expect(last_page).to eq data[index - 1] if last_page
        next_page = data[index]
        index += 1
        next_page
      end

      expect(paginator.to_a).to eq [7, 6, 5, 4]
    end
  end

  it 'only returns up to limit items' do
    data = [
      [1, 2, 3],
      [4, 5],
      []
    ]

    index = 0
    paginator = Discordrb::Paginator.new(2, :down) do |_last_page|
      next_page = data[index]
      index += 1
      next_page
    end

    expect(paginator.to_a).to eq [1, 2]
  end
end
