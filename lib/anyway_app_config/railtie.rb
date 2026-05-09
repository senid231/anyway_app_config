# frozen_string_literal: true

require 'rails/railtie'
require 'active_support/ordered_options'

module AnywayAppConfig
  # Optional Rails integration. Activated automatically when Rails is loaded
  # before this gem, or explicitly via `require "anyway_app_config/railtie"`.
  #
  # Opt-in: register one or more config classes and they will be loaded just
  # before Rails initializers run.
  #
  #   # config/application.rb
  #   require_relative "app_config"
  #   class Application < Rails::Application
  #     config.anyway_app_config.classes = [AppConfig]
  #   end
  #
  # If you do not register any classes, the Railtie does nothing and you can
  # keep calling `MyConfig.load!` yourself.
  class Railtie < ::Rails::Railtie
    config.anyway_app_config = ::ActiveSupport::OrderedOptions.new
    config.anyway_app_config.classes = []

    initializer 'anyway_app_config.load', before: :load_config_initializers do |app|
      Array(app.config.anyway_app_config.classes).each(&:load!)
    end
  end
end
