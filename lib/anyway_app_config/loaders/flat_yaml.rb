# frozen_string_literal: true

require 'anyway/loaders/yaml'

module AnywayAppConfig
  module Loaders
    # YAML loader that always treats the file as a flat key/value document,
    # ignoring environment sections regardless of file content or global state.
    class FlatYAML < ::Anyway::Loaders::YAML
      private

      def environmental?(_parsed_yml)
        false
      end
    end
  end
end
