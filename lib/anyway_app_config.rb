# frozen_string_literal: true

require_relative "anyway_app_config/version"
require_relative "anyway_app_config/config"
require_relative "anyway_app_config/singleton"

module AnywayAppConfig
  class Error < StandardError; end
end

require_relative "anyway_app_config/railtie" if defined?(::Rails::Railtie)
