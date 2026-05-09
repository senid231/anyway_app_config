# frozen_string_literal: true

RSpec.describe AnywayAppConfig do
  it 'has a version number' do
    expect(AnywayAppConfig::VERSION).not_to be_nil
  end

  it 'does not pollute Anyway::TypeRegistry.default with :hash' do
    expect {
      Anyway::TypeRegistry.default.deserialize({ 'a' => 1 }, :hash)
    }.to raise_error(ArgumentError, /Unknown type: hash/)
  end
end
