# frozen_string_literal: true

require 'anyway_config'
require 'active_support/core_ext/class/attribute'
require 'active_support/core_ext/hash/keys'
require 'active_support/core_ext/string/inflections'

module AnywayAppConfig
  class NotLoadedError < StandardError; end

  class Config < ::Anyway::Config
    class_attribute :nested_config_class, instance_accessor: false

    class << self
      def attribute(name, type: nil, array: false, default: nil, required: false, &block)
        if block
          raise ArgumentError, "nested attribute #{name} does not support type" unless type.nil?
          raise ArgumentError, "nested attribute #{name} does not support default" unless default.nil?

          attr_nested(name, array: array, required: required, &block)
        else
          attr_value(name, type: type, array: array, default: default, required: required)
        end
      end

      def attr_value(name, type:, array: false, default: nil, required: false)
        default_val = default.nil? && array ? [] : default
        attr_config(name => default_val)
        coerce_types(name => { type: type, array: array })
        self.required(name) if required
      end

      def attr_nested(name, array: false, required: false, &block)
        klass = Class.new(nested_config_class)
        const_set("#{name.to_s.classify}Cfg", klass)
        klass.config_name :"#{config_name}_#{name}"
        klass.configuration_sources = []
        klass.class_eval(&block) if block

        if array
          attr_config(name => [])
          caster = ->(v) { klass.new(v) }
          coerce_types(name => { type: caster, array: true })
        else
          attr_config(name => {})
          coerce_types(name => { config: klass })
        end

        self.required(name) if required
      end

      def load!(*, **)
        new(*, **).tap(&:deep_freeze!)
      end

      def type_registry
        return @type_registry if instance_variable_defined?(:@type_registry)

        @type_registry =
          if superclass < AnywayAppConfig::Config
            superclass.type_registry.dup
          else
            ::Anyway::TypeRegistry.default.dup.tap do |r|
              r.accept(:hash) do |v|
                raise ArgumentError, "expected Hash, got #{v.class}" unless v.is_a?(::Hash)

                v
              end
            end
          end
      end

      def type_caster
        @type_caster ||=
          if coercion_mapping.empty?
            fallback_type_caster
          else
            ::Anyway::TypeCaster.new(
              coercion_mapping,
              registry: type_registry,
              fallback: fallback_type_caster
            )
          end
      end
    end

    def deep_freeze!
      return self if frozen?

      deep_freeze_value(values)
      freeze
    end

    def load(overrides = nil)
      overrides = overrides.deep_stringify_keys if overrides.is_a?(::Hash)
      super
    end

    private

    def deep_freeze_value(val)
      case val
      when AnywayAppConfig::Config
        val.deep_freeze!
      when Array
        val.each { |item| deep_freeze_value(item) }
        val.freeze
      when Hash
        val.each_value { |item| deep_freeze_value(item) }
        val.freeze
      else
        val.freeze if val.respond_to?(:freeze) && !val.frozen?
      end
      val
    end
  end

  Config.nested_config_class = Config
end
