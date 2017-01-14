require 'helpers'

RSpec.configure do |c|
  c.include Helpers
end

describe 'an example group' do
  it 'has access to the helper methods defined in the module' do
    expect(help).to be(:available)
  end
end

describe '#load_data_file' do
  it 'should load the test data correctly' do
    data = load_data_file(:test)
    expect(data['success']).to eq(true)
  end
end

describe '#fixture' do
  fixture :data, [:test]

  it 'should load the test data correctly' do
    expect(data['success']).to eq(true)
  end
end

describe '#fixture_property' do
  fixture :data, [:test]
  fixture_property :data_success, :data, ['success']

  it 'should define the test property correctly' do
    expect(data_success).to eq(true)
  end
end
