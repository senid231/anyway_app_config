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

  describe '.build' do
    it 'returns an anonymous Config subclass when load: false' do
      klass = described_class.build do
        config_name 'build_class_only'
        self.configuration_sources = []

        attribute :name, type: :string, default: 'x'
      end

      expect(klass.ancestors).to include(AnywayAppConfig::Config)
      expect(klass.name).to be_nil
      expect(klass.new.name).to eq('x')
    end

    it 'returns an instance with frozen values (instance itself remains unfrozen) when load: true' do
      cfg = described_class.build(load: true) do
        config_name 'build_load'
        self.configuration_sources = []

        attribute :greeting, type: :string, default: 'hi'
        attribute :tags, type: :string, array: true, default: %w[a]
      end

      expect(cfg).to be_a(AnywayAppConfig::Config)
      expect(cfg).not_to be_frozen
      expect(cfg.tags).to be_frozen
      expect(cfg.greeting).to eq('hi')
    end

    it 'supports nested attributes' do
      klass = described_class.build do
        config_name 'build_nested'
        self.configuration_sources = []

        attribute :sentry, required: true do
          attribute :dsn, type: :string, required: true
        end
      end

      cfg = klass.new(sentry: { dsn: 'https://example' }).tap(&:deep_freeze_values!)

      expect(cfg.sentry.dsn).to eq('https://example')
      expect(cfg).not_to be_frozen
      expect(cfg.sentry).not_to be_frozen
    end

    it 'raises without a block' do
      expect { described_class.build }.to raise_error(ArgumentError, /requires a block/)
    end

    it 'inherits the per-class :hash type from AnywayAppConfig::Config' do
      klass = described_class.build do
        config_name 'build_hash_type'
        self.configuration_sources = []

        attribute :extras, type: :hash, default: {}
      end

      expect(klass.new(extras: { 'k' => 'v' }).extras).to eq({ 'k' => 'v' })
      expect { klass.new(extras: 'nope') }.to raise_error(ArgumentError, /expected Hash/)
    end

    it 'honors env_prefix and configuration_sources inside the block' do
      klass = described_class.build do
        config_name 'build_env_prefix'
        env_prefix  'BUILD_ENV_PREFIX_TEST'
        self.configuration_sources = %i[env]

        attribute :token, type: :string, required: true
      end

      ENV['BUILD_ENV_PREFIX_TEST_TOKEN'] = 'from-env'
      begin
        expect(klass.new.token).to eq('from-env')
      ensure
        ENV.delete('BUILD_ENV_PREFIX_TEST_TOKEN')
      end
    end
  end
end
