# frozen_string_literal: true

RSpec.describe AnywayAppConfig::Config do
  describe 'attribute DSL' do
    let(:config_class) do
      Class.new(described_class) do
        config_name 'test_attr_dsl'
        env_prefix 'TEST_ATTR_DSL'
        self.configuration_sources = []

        attribute :name, type: :string, default: 'hello'
        attribute :count, type: :integer, default: 0
        attribute :flag, type: :boolean, default: false
        attribute :tags, type: :string, array: true
        attribute :extras, type: :hash, default: {}
        attribute :must, type: :string, required: true
      end
    end

    it 'applies defaults' do
      cfg = config_class.new(must: 'x')
      expect(cfg.name).to eq('hello')
      expect(cfg.count).to eq(0)
      expect(cfg.flag).to be(false)
      expect(cfg.tags).to eq([])
      expect(cfg.extras).to eq({})
    end

    it 'coerces typed values' do
      cfg = config_class.new(must: 'x', count: '42', flag: 'true', tags: 'a,b,c')
      expect(cfg.count).to eq(42)
      expect(cfg.flag).to be(true)
      expect(cfg.tags).to eq(%w[a b c])
    end

    it 'supports the :hash type' do
      cfg = config_class.new(must: 'x', extras: { 'k' => 'v' })
      expect(cfg.extras).to eq({ 'k' => 'v' })
    end

    it 'rejects non-hash for :hash type' do
      expect { config_class.new(must: 'x', extras: 'not a hash') }
        .to raise_error(ArgumentError, /expected Hash/)
    end

    it 'raises on missing required attribute' do
      expect { config_class.new }.to raise_error(Anyway::Config::ValidationError)
    end
  end

  describe 'nested attribute (single)' do
    let(:config_class) do
      Class.new(described_class) do
        config_name 'test_nested'
        self.configuration_sources = []

        attribute :sentry, required: true do
          attribute :dsn, type: :string, default: ''
          attribute :environment, type: :string, required: true
          attribute :tags, type: :hash, default: {}
        end
      end
    end

    it 'wires up the nested config class' do
      cfg = config_class.new(sentry: { environment: 'test', tags: { 'custom' => 'tag' } })
      expect(cfg.sentry).to be_a(described_class)
      expect(cfg.sentry.environment).to eq('test')
      expect(cfg.sentry.dsn).to eq('')
      expect(cfg.sentry.tags).to eq({ 'custom' => 'tag' })
    end

    it 'validates required fields on the nested class' do
      expect { config_class.new(sentry: {}) }.to raise_error(Anyway::Config::ValidationError)
    end

    it 'exposes the nested class as a constant' do
      expect(config_class.const_defined?(:SentryCfg)).to be(true)
      expect(config_class::SentryCfg).to be < described_class
    end
  end

  describe 'nested attribute (array)' do
    let(:config_class) do
      Class.new(described_class) do
        config_name 'test_nested_array'
        self.configuration_sources = []

        attribute :servers, array: true do
          attribute :host, type: :string, required: true
          attribute :port, type: :integer, default: 80
        end
      end
    end

    it 'casts each element to the nested class' do
      cfg = config_class.new(servers: [
                               { host: 'a', port: '8080' },
                               { host: 'b' }
                             ])
      expect(cfg.servers.size).to eq(2)
      expect(cfg.servers[0]).to be_a(described_class)
      expect(cfg.servers[0].host).to eq('a')
      expect(cfg.servers[0].port).to eq(8080)
      expect(cfg.servers[1].port).to eq(80)
    end

    it 'defaults to an empty array' do
      cfg = config_class.new
      expect(cfg.servers).to eq([])
    end
  end

  describe 'deep_freeze!' do
    let(:config_class) do
      Class.new(described_class) do
        config_name 'test_deep_freeze'
        self.configuration_sources = []

        attribute :name, type: :string, default: 'x'
        attribute :tags, type: :string, array: true
        attribute :extras, type: :hash, default: {}

        attribute :sentry do
          attribute :dsn, type: :string, default: ''
        end

        attribute :servers, array: true do
          attribute :host, type: :string, required: true
        end
      end
    end

    it 'freezes the instance and nested values' do
      cfg = config_class.new(
        tags: %w[a b],
        extras: { 'k' => 'v' },
        sentry: { dsn: 'd' },
        servers: [{ host: 'h' }]
      )
      cfg.deep_freeze!

      expect(cfg).to be_frozen
      expect(cfg.tags).to be_frozen
      expect(cfg.tags.first).to be_frozen
      expect(cfg.extras).to be_frozen
      expect(cfg.sentry).to be_frozen
      expect(cfg.servers).to be_frozen
      expect(cfg.servers.first).to be_frozen
    end
  end

  describe '.load!' do
    let(:config_class) do
      Class.new(described_class) do
        config_name 'test_load_bang'
        self.configuration_sources = []

        attribute :name, type: :string, default: 'x'
      end
    end

    it 'returns a frozen instance' do
      cfg = config_class.load!
      expect(cfg).to be_frozen
      expect(cfg.name).to eq('x')
    end

    it 'returns a new instance each call (no caching)' do
      a = config_class.load!
      b = config_class.load!
      expect(a).not_to equal(b)
    end
  end

  describe 'type registry isolation' do
    it "registers :hash on the class registry, not anyway's default" do
      expect { Anyway::TypeRegistry.default.deserialize({}, :hash) }
        .to raise_error(ArgumentError, /Unknown type: hash/)

      expect(described_class.type_registry.deserialize({ 'k' => 'v' }, :hash))
        .to eq({ 'k' => 'v' })
    end
  end
end
