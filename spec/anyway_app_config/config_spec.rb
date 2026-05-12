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

  describe 'deep_freeze_values!' do
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

    it 'freezes contained values but leaves Config instances unfrozen' do
      cfg = config_class.new(
        tags: %w[a b],
        extras: { 'k' => 'v' },
        sentry: { dsn: 'd' },
        servers: [{ host: 'h' }]
      )
      cfg.deep_freeze_values!

      expect(cfg).not_to be_frozen
      expect(cfg.sentry).not_to be_frozen
      expect(cfg.servers.first).not_to be_frozen

      expect(cfg.tags).to be_frozen
      expect(cfg.tags.first).to be_frozen
      expect(cfg.extras).to be_frozen
      expect(cfg.servers).to be_frozen
    end

    it 'leaves Config instances stubbable via RSpec' do
      cfg = config_class.new(sentry: { dsn: 'd' }, servers: [{ host: 'h' }])
      cfg.deep_freeze_values!

      allow(cfg.sentry).to receive(:dsn).and_return('stubbed')
      allow(cfg.servers.first).to receive(:host).and_return('stubbed-host')

      expect(cfg.sentry.dsn).to eq('stubbed')
      expect(cfg.servers.first.host).to eq('stubbed-host')
    end
  end

  describe '.load!' do
    let(:config_class) do
      Class.new(described_class) do
        config_name 'test_load_bang'
        self.configuration_sources = []

        attribute :name, type: :string, default: 'x'
        attribute :tags, type: :string, array: true, default: %w[a]
      end
    end

    it 'returns an instance with frozen values but unfrozen instance' do
      cfg = config_class.load!
      expect(cfg).not_to be_frozen
      expect(cfg.tags).to be_frozen
      expect(cfg.name).to eq('x')
    end

    it 'returns a new instance each call (no caching)' do
      a = config_class.load!
      b = config_class.load!
      expect(a).not_to equal(b)
    end
  end

  describe 'skip_freeze_classes' do
    let(:skippable_class) { Class.new }
    let(:config_class) do
      sk = skippable_class
      Class.new(described_class) do
        config_name 'test_skip_freeze'
        self.configuration_sources = []
        self.skip_freeze_classes = [sk]

        attribute :extras, type: :hash, default: {}
        attribute :tags, type: :string, array: true
      end
    end

    it 'defaults to an empty array on the base class' do
      expect(described_class.skip_freeze_classes).to eq([])
    end

    it 'is inherited by subclasses' do
      sub = Class.new(config_class)
      expect(sub.skip_freeze_classes).to eq([skippable_class])
    end

    it 'leaves instances of listed classes unfrozen during deep-freeze' do
      widget = skippable_class.new
      cfg = config_class.new(extras: { 'w' => widget })
      cfg.deep_freeze_values!

      expect(widget).not_to be_frozen
      expect(cfg.extras).to be_frozen
    end

    it 'still freezes other values in the same container' do
      widget = skippable_class.new
      cfg = config_class.new(extras: { 'w' => widget, 's' => +'mutable' })
      cfg.deep_freeze_values!

      expect(cfg.extras['s']).to be_frozen
      expect(cfg.extras['w']).not_to be_frozen
    end

    it 'matches subclasses of listed classes via is_a?' do
      subclass = Class.new(skippable_class)
      widget = subclass.new
      cfg = config_class.new(extras: { 'w' => widget })
      cfg.deep_freeze_values!

      expect(widget).not_to be_frozen
    end

    it 'does not affect base Config when subclass overrides skip_freeze_classes' do
      Class.new(described_class) do
        config_name 'overrides_skip_freeze'
        self.configuration_sources = []
        self.skip_freeze_classes = [String]
      end
      expect(described_class.skip_freeze_classes).to eq([])
    end
  end

  describe 'explicit config_path' do
    let(:fixture_path) { File.expand_path('../fixtures/explicit_path.yml', __dir__) }
    let(:alt_fixture_path) { File.expand_path('../fixtures/explicit_path_alt.yml', __dir__) }
    let(:config_class) do
      Class.new(described_class) do
        config_name 'explicit_path'
        self.configuration_sources = [:yml]
        attribute :greeting, type: :string
      end
    end

    it 'loads YAML from a per-instance config_path: kwarg' do
      cfg = config_class.new(config_path: fixture_path)
      expect(cfg.greeting).to eq('from-explicit-yaml')
    end

    it 'accepts a Pathname for config_path:' do
      cfg = config_class.new(config_path: Pathname.new(fixture_path))
      expect(cfg.greeting).to eq('from-explicit-yaml')
    end

    it 'overrides any class-level explicit_config_path when both are set' do
      config_class.explicit_config_path = fixture_path
      cfg = config_class.new(config_path: alt_fixture_path)
      expect(cfg.greeting).to eq('from-alt-yaml')
    end

    context 'with class-level explicit_config_path as a String' do
      it 'uses it when no per-instance override is passed' do
        config_class.explicit_config_path = fixture_path
        expect(config_class.new.greeting).to eq('from-explicit-yaml')
      end
    end

    context 'with class-level explicit_config_path as a Pathname' do
      it 'stringifies and uses it' do
        config_class.explicit_config_path = Pathname.new(fixture_path)
        expect(config_class.new.greeting).to eq('from-explicit-yaml')
      end
    end

    context 'with class-level explicit_config_path as a Proc' do
      it 'calls it lazily and uses the returned path' do
        target = fixture_path
        called = 0
        config_class.explicit_config_path = -> {
          called += 1
          target
        }

        cfg1 = config_class.new
        cfg2 = config_class.new

        expect(cfg1.greeting).to eq('from-explicit-yaml')
        expect(cfg2.greeting).to eq('from-explicit-yaml')
        expect(called).to eq(2) # called per-instance, not once
      end

      it 'uses the Proc result not the Proc itself' do
        config_class.explicit_config_path = -> { fixture_path }
        expect(config_class.new.greeting).to eq('from-explicit-yaml')
      end
    end

    it 'falls back to the default lookup when explicit_config_path is nil' do
      config_class.explicit_config_path = nil
      expect { config_class.new.greeting }.not_to raise_error
      # default path (./config/explicit_path.yml) doesn't exist, so greeting stays nil
      expect(config_class.new.greeting).to be_nil
    end

    it 'is inherited by subclasses' do
      config_class.explicit_config_path = fixture_path
      sub = Class.new(config_class)
      expect(sub.explicit_config_path).to eq(fixture_path)
      expect(sub.new.greeting).to eq('from-explicit-yaml')
    end

    it 'works through .load!' do
      cfg = config_class.load!(config_path: fixture_path)
      expect(cfg.greeting).to eq('from-explicit-yaml')
      expect(cfg).not_to be_frozen
    end

    it 'still accepts attribute kwargs alongside config_path:' do
      cfg = config_class.new(greeting: 'override', config_path: fixture_path)
      # explicit overrides win over YAML
      expect(cfg.greeting).to eq('override')
    end

    it 'still accepts a positional overrides hash' do
      cfg = config_class.new({ greeting: 'positional' })
      expect(cfg.greeting).to eq('positional')
    end

    it 'raises on unknown keyword args when overrides is also positional' do
      expect { config_class.new({ greeting: 'a' }, bogus: 1) }
        .to raise_error(ArgumentError, /unknown keywords: bogus/)
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
