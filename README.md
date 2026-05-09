# AnywayAppConfig

Schema-driven application config built on top of [`anyway_config`][anyway_config].

`anyway_config` does the heavy lifting of loading values from YAML and ENV.
`anyway_app_config` adds a small DSL on top for describing app config with
typed attributes, defaults, required fields, and **nested objects** (single
or array). Configs can be used as plain instances or as a singleton.

## Installation

Add to your Gemfile:

```ruby
gem "anyway_app_config"
```

Then run `bundle install`.

## Defining a config

Inherit from `AnywayAppConfig::Config` and describe attributes with the
`attribute` DSL:

```ruby
require "anyway_app_config"

class AppConfig < AnywayAppConfig::Config
  config_name "app_config"
  env_prefix  "APP"

  attribute :deploy_env, type: :string, required: true
  attribute :version,    type: :string, default: "unknown"
  attribute :commit_sha, type: :string, default: "000000"

  attribute :sentry, required: true do
    attribute :dsn,         type: :string, default: ""
    attribute :environment, type: :string, required: true
    attribute :server_name, type: :string, required: true
    attribute :tags,        type: :hash,   default: {}
  end

  attribute :prometheus, required: true do
    attribute :enabled,        type: :boolean, default: false
    attribute :host,           type: :string,  default: "localhost"
    attribute :port,           type: :integer, default: 9394
    attribute :default_labels, type: :hash,    default: {}
  end
end
```

`attribute` accepts:

| option     | meaning                                                      |
| ---------- | ------------------------------------------------------------ |
| `type:`    | type id from `anyway_config`'s registry (`:string`, `:integer`, `:float`, `:boolean`, `:date`, `:datetime`, `:uri`, `:hash`, …), or any object responding to `#call(value)` |
| `array:`   | when `true`, value is an array of `type` (or nested objects) |
| `default:` | default value (defaults to `nil`, or `[]` when `array: true`) |
| `required:`| validate that the attribute is present and not empty         |
| block      | defines a nested config object (see below)                   |

### Nested attributes

Pass a block to define a nested config. The DSL builds a child config class
that inherits from `AnywayAppConfig::Config`, exposes the same DSL, and is
exposed as a constant (e.g. `AppConfig::SentryCfg`).

Combine with `array: true` to get a list of nested objects:

```ruby
class AppConfig < AnywayAppConfig::Config
  config_name "app_config"

  attribute :servers, array: true do
    attribute :host, type: :string, required: true
    attribute :port, type: :integer, default: 80
  end
end
```

### The `:hash` type

`AnywayAppConfig::Config` registers a `:hash` type on a per-class type
registry. It accepts any `Hash` value as-is and raises `ArgumentError` for
non-hash values. Anyway's global `TypeRegistry.default` is **not** mutated.

## Loading config

```ruby
config = AppConfig.load!  # frozen instance, with all sources merged
config.sentry.environment
config.servers.first.host
```

`load!` returns a frozen instance every call (no caching). Sources are loaded
through `anyway_config` (YAML + ENV by default).

### Singleton mode

Include `AnywayAppConfig::Singleton` to get a class-level singleton with
class-level access to all instance methods:

```ruby
class AppConfig < AnywayAppConfig::Config
  include AnywayAppConfig::Singleton
  # ...
end

AppConfig.load!                # frozen instance, cached on the class
AppConfig.deploy_env           # delegates to instance
AppConfig.sentry.environment   # delegates to instance
AppConfig.instance             # the cached instance
AppConfig.loaded?              # true / false

AppConfig.load!                # raises AnywayAppConfig::AlreadyLoadedError
AppConfig.foo                  # raises AnywayAppConfig::NotLoadedError if not loaded
```

The singleton is intentionally strict — there is no `reload!`. To re-read
config, restart the process.

> Note: class-level delegation goes through `method_missing`, so attribute
> names that clash with existing `Class` methods (`name`, `class`, `send`, …)
> are not delegated — pick non-clashing names.

### YAML and ENV

Loading is provided by `anyway_config`. A typical `config/app_config.yml`:

```yaml
development: &dev
  deploy_env: "development"

  sentry:
    dsn: ""
    environment: "development"
    server_name: "denis-t.localhost"
    tags:
      custom: "tag"

  prometheus:
    enabled: false
    host: "localhost"
    port: 9394

test:
  <<: *dev
  deploy_env: "test"

production:
  <<: *dev
```

ENV vars use the prefix declared via `env_prefix`, e.g. `APP_DEPLOY_ENV`,
`APP_SENTRY__ENVIRONMENT`. See the [anyway_config docs][anyway_config] for
the full source list and naming rules.

## Rails

Calling `AppConfig.load!` yourself in `config/application.rb` works fine:

```ruby
class Application < Rails::Application
  config.before_initialize do
    AppConfig.load!
  end
end
```

For an opt-in helper, register classes on the Railtie config and they will be
loaded just before initializers run:

```ruby
class Application < Rails::Application
  config.anyway_app_config.classes = [AppConfig]
end
```

The Railtie auto-loads when Rails is on the load path; if not, require it
explicitly with `require "anyway_app_config/railtie"`.

## Development

```
bundle install
bundle exec rspec
bundle exec rubocop
```

## Contributing

Bug reports and pull requests are welcome on GitHub at
<https://github.com/senid231/anyway_app_config>.

## License

MIT. See [LICENSE.txt](LICENSE.txt).

[anyway_config]: https://github.com/palkan/anyway_config
