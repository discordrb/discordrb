require 'discordrb'

describe Discordrb do
  it 'should split messages correctly' do
    split = Discordrb.split_message('a' * 5234)
    expect(split).to eq(['a' * 2000, 'a' * 2000, 'a' * 1234])

    # regression test
    # there had been an issue where this would have raised an error,
    # and (if it hadn't raised) produced incorrect results
    split = Discordrb.split_message(('a' * 800 + "\n") * 6)
    expect(split).to eq([
                          'a' * 800 + "\n" + 'a' * 800 + "\n",
                          'a' * 800 + "\n" + 'a' * 800 + "\n",
                          'a' * 800 + "\n" + 'a' * 800
                        ])
  end
end
