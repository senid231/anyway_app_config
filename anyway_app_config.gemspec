# frozen_string_literal: true

require_relative 'lib/anyway_app_config/version'

Gem::Specification.new do |spec|
  spec.name = 'anyway_app_config'
  spec.version = AnywayAppConfig::VERSION
  spec.authors = ['Denis Talakevich']
  spec.email = ['senid231@gmail.com']

  spec.summary = 'Schema-driven application config built on top of anyway_config.'
  spec.description = <<~DESC
    AnywayAppConfig adds a small DSL on top of anyway_config for describing
    application configs with typed attributes, defaults, required fields and
    nested objects (single or array). Configs can be used as plain instances
    or as singletons, and load values from YAML and ENV via anyway_config.
  DESC
  spec.homepage = 'https://github.com/senid231/anyway_app_config'
  spec.license = 'MIT'
  spec.required_ruby_version = '>= 3.2.0'
  spec.metadata['homepage_uri'] = spec.homepage
  spec.metadata['source_code_uri'] = spec.homepage
  spec.metadata['changelog_uri'] = "#{spec.homepage}/blob/master/CHANGELOG.md"
  spec.metadata['rubygems_mfa_required'] = 'true'

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  gemspec = File.basename(__FILE__)
  spec.files = IO.popen(%w[git ls-files -z], chdir: __dir__, err: IO::NULL) do |ls|
    ls.readlines("\x0", chomp: true).reject do |f|
      (f == gemspec) ||
        f.start_with?(*%w[bin/ Gemfile .gitignore .rspec spec/ .gitlab-ci.yml .rubocop.yml])
    end
  end
  spec.bindir = 'exe'
  spec.executables = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ['lib']

  spec.add_dependency 'activesupport', '>= 6.1'
  spec.add_dependency 'anyway_config', '~> 2.0'
end
