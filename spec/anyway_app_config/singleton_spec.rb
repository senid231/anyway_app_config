# frozen_string_literal: true

RSpec.describe AnywayAppConfig::Singleton do
  let(:config_class) do
    Class.new(AnywayAppConfig::Config) do
      include AnywayAppConfig::Singleton

      config_name 'test_singleton'
      self.configuration_sources = []

      attribute :title, type: :string, default: 'hello'
      attribute :count, type: :integer, default: 1

      def upcased_title
        title.upcase
      end
    end
  end

  describe '.load!' do
    it 'returns an instance that is not frozen (to remain stubbable)' do
      cfg = config_class.load!
      expect(cfg).not_to be_frozen
      expect(cfg.title).to eq('hello')
    end

    it 'raises if called twice' do
      config_class.load!
      expect { config_class.load! }
        .to raise_error(AnywayAppConfig::AlreadyLoadedError)
    end

    it 'caches the instance and returns the same object via .instance' do
      cfg = config_class.load!
      expect(config_class.instance).to equal(cfg)
    end

    it 'allows RSpec to stub methods on the loaded instance' do
      config_class.load!
      allow(config_class.instance).to receive(:title).and_return('stubbed')
      expect(config_class.title).to eq('stubbed')
    end
  end

  describe '.instance' do
    it 'raises NotLoadedError before load!' do
      expect { config_class.instance }
        .to raise_error(AnywayAppConfig::NotLoadedError, /not loaded/)
    end
  end

  describe '.loaded?' do
    it 'is false before load! and true after' do
      expect(config_class.loaded?).to be(false)
      config_class.load!
      expect(config_class.loaded?).to be(true)
    end
  end

  describe 'class-level delegation to instance' do
    it 'delegates attribute readers' do
      config_class.load!
      expect(config_class.title).to eq('hello')
      expect(config_class.count).to eq(1)
    end

    it 'delegates user-defined instance methods' do
      config_class.load!
      expect(config_class.upcased_title).to eq('HELLO')
    end

    it 'raises NotLoadedError when delegating before load!' do
      expect { config_class.title }
        .to raise_error(AnywayAppConfig::NotLoadedError)
    end

    it 'answers respond_to? after load!' do
      config_class.load!
      expect(config_class.respond_to?(:title)).to be(true)
      expect(config_class.respond_to?(:upcased_title)).to be(true)
    end

    it 'falls back to NoMethodError for unknown methods' do
      config_class.load!
      expect { config_class.totally_unknown_method }.to raise_error(NoMethodError)
    end
  end
end
