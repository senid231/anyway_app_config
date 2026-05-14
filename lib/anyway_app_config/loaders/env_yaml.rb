# frozen_string_literal: true

require 'anyway/loaders/yaml'

module AnywayAppConfig
  module Loaders
    # YAML loader that always reads the section matching
    # `Anyway::Settings.current_environment`, regardless of file content or
    # global detection. Raises if the current environment is not set.
    class EnvYAML < ::Anyway::Loaders::YAML
      def call(**)
        if ::Anyway::Settings.current_environment.nil?
          raise ArgumentError,
                'Anyway::Settings.current_environment must be set to use the :env_yml loader'
        end

        super
      end

      private

      def environmental?(_parsed_yml)
        true
      end
    end
  end
end
