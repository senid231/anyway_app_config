# frozen_string_literal: true

module AnywayAppConfig
  class AlreadyLoadedError < StandardError; end

  module Singleton
    def self.included(base)
      base.extend(ClassMethods)
    end

    module ClassMethods
      def load!(*, **)
        if instance_variable_defined?(:@instance) && @instance
          raise AlreadyLoadedError, "#{name || self} is already loaded"
        end

        @instance = new(*, **).tap(&:deep_freeze!)
      end

      def loaded?
        instance_variable_defined?(:@instance) && !@instance.nil?
      end

      def instance
        return @instance if instance_variable_defined?(:@instance) && @instance

        raise NotLoadedError, "#{name || self} is not loaded; call #{name || self}.load! first"
      end

      def respond_to_missing?(method_name, include_private = false)
        (loaded? && @instance.respond_to?(method_name, include_private)) || super
      end

      def method_missing(method_name, ...)
        if instance.respond_to?(method_name)
          instance.public_send(method_name, ...)
        else
          super
        end
      end
    end
  end
end
