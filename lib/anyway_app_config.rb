# frozen_string_literal: true

require_relative 'anyway_app_config/version'
require_relative 'anyway_app_config/config'
require_relative 'anyway_app_config/singleton'
require_relative 'anyway_app_config/loaders/flat_yaml'
require_relative 'anyway_app_config/loaders/env_yaml'

Anyway.loaders.append(:flat_yml, AnywayAppConfig::Loaders::FlatYAML)
Anyway.loaders.append(:env_yml, AnywayAppConfig::Loaders::EnvYAML)

module AnywayAppConfig
  class Error < StandardError; end

  # Builds an anonymous AnywayAppConfig::Config subclass from a block,
  # for use without a separate file. The block is class_eval'd on the new
  # subclass, so `config_name`, `env_prefix`, and `attribute` are available.
  #
  # Returns the class by default; with `load: true` returns a frozen instance.
  # Anonymous classes have no name, so `config_name` is mandatory in the block.
  def self.build(load: false, &block)
    raise ArgumentError, 'AnywayAppConfig.build requires a block' unless block

    klass = Class.new(Config)
    klass.class_eval(&block)
    load ? klass.load! : klass
  end
end
