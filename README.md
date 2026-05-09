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

There is no Railtie — Rails already exposes `Rails.configuration` as the
canonical place to hang application-wide settings, so wiring through it is
three lines. The pattern:

**1. Define the config class in `config/app_config.rb`:**

```ruby
require "anyway_app_config"

class AppConfig < AnywayAppConfig::Config
  config_name "app_config"
  env_prefix  "APP"

  attribute :deploy_env, type: :string, required: true
  attribute :version,    type: :string, default: "unknown"

  attribute :sentry, required: true do
    attribute :dsn,         type: :string, default: ""
    attribute :environment, type: :string, required: true
  end
end
```

**2. (Optional) Add `config/app_config.yml`:**

```yaml
development:
  deploy_env: "development"
  sentry:
    environment: "development"

production:
  deploy_env: "production"
  sentry:
    environment: "production"
```

Any value can be overridden via ENV using the `env_prefix` (`APP` above).
Examples:

- `APP_DEPLOY_ENV=staging` → `AppConfig#deploy_env`
- `APP_SENTRY__DSN=https://...` → `AppConfig#sentry.dsn` (double underscore for nesting)
- `APP_VERSION=1.2.3` → `AppConfig#version`

ENV wins over YAML. See the [anyway_config docs][anyway_config] for the full
source list and naming rules.

**3. Load and assign in `config/application.rb`:**

```ruby
require_relative "app_config"

module MyApp
  class Application < Rails::Application
    config.app_config = AppConfig.load!
    # ...
  end
end
```

**4. Use it anywhere via `Rails.configuration`:**

```ruby
Rails.configuration.app_config.deploy_env
Rails.configuration.app_config.sentry.dsn
```

`AppConfig.load!` returns a frozen instance, so `Rails.configuration.app_config`
is safe to read from any thread. If you want class-level access
(`AppConfig.deploy_env`) instead, use [Singleton mode](#singleton-mode) and
just call `AppConfig.load!` in `config/application.rb` without assigning it
to `config.app_config`.

### Replacing `Rails.application.credentials` (unencrypted)

Rails 7.2+ encrypts `config/credentials.yml.enc` by default. If your secrets
are already injected by your deploy pipeline (Helm, Kubernetes secrets, CI/CD
vault, ENV) you don't need encryption-at-rest in the repo — and the encrypted
credentials flow becomes pure overhead. `anyway_app_config` is a drop-in
replacement: typed, required-checked, frozen, and ENV-overridable.

**1. Define the credentials class in `config/credentials.rb`:**

```ruby
require "anyway_app_config"

class Credentials < AnywayAppConfig::Config
  config_name "credentials"
  env_prefix  ""   # no prefix — read raw ENV like SECRET_KEY_BASE, DATABASE_PASSWORD

  attribute :secret_key_base,       type: :string, required: true
  attribute :database_password,     type: :string, required: true
  attribute :aws_access_key_id,     type: :string, default: ""
  attribute :aws_secret_access_key, type: :string, default: ""
end
```

An empty `env_prefix` matches ENV var names directly against attribute names
(uppercased), so `SECRET_KEY_BASE` populates `:secret_key_base`. Useful for
secrets that have well-known unprefixed names — `SECRET_KEY_BASE`,
`DATABASE_URL`, `RAILS_MASTER_KEY`. Other ENV vars are simply ignored unless
they match a declared attribute. **Caveat:** pick attribute names carefully
— if you declare `attribute :path` or `:home` with empty prefix, you'll pick
up `PATH`/`HOME` from the shell. When in doubt, keep a prefix.

**2. Add `config/credentials.yml`** (gitignore it, or commit only the dev/test
branches and inject production values via ENV):

```yaml
development:
  secret_key_base: "dev-only-not-a-real-secret"
  database_password: "postgres"

test:
  secret_key_base: "test-only-not-a-real-secret"
  database_password: "postgres"

production:
  # Leave empty here and inject via ENV (SECRET_KEY_BASE=..., etc) at deploy time.
  secret_key_base: ""
  database_password: ""
```

**3. Wire it in `config/application.rb` before configuration:**

```ruby
require_relative "credentials"

module MyApp
  class Application < Rails::Application
    config.before_configuration do
      self.credentials = Credentials.load!
      # Rails 7.2+ generates a dynamic secret_key_base in dev/test when one
      # is not set. Pin it from credentials so it stays stable across boots.
      # See Rails::Application::Configuration#generate_local_secret?
      config.secret_key_base = credentials.secret_key_base
    end
  end
end
```

**4. Use it like the standard credentials object:**

```ruby
Rails.application.credentials.secret_key_base
Rails.application.credentials.database_password
```

ENV overrides use raw names because of the empty `env_prefix`:
`SECRET_KEY_BASE=...`, `DATABASE_PASSWORD=...`.

> **Trade-off:** you lose encryption-at-rest. Only do this if `credentials.yml`
> is gitignored or contains placeholders only, with real values injected via
> ENV at deploy time. The win is that secrets become typed, required-checked,
> and centrally declared — instead of an opaque `EncryptedConfiguration` blob
> that silently returns `nil` for typos.

### Inline form: `AnywayAppConfig.build`

For small Rails apps where dedicated `config/app_config.rb` and
`config/credentials.rb` files feel like overkill, declare configs inline in
`config/application.rb` with `AnywayAppConfig.build`:

```ruby
module MyApp
  class Application < Rails::Application
    config.before_configuration do
      self.credentials = AnywayAppConfig.build(load: true) do
        config_name "credentials"
        env_prefix  ""   # no prefix — read raw ENV like SECRET_KEY_BASE

        attribute :secret_key_base,       type: :string, required: true
        attribute :database_password,     type: :string, required: true
        attribute :aws_access_key_id,     type: :string, default: ""
        attribute :aws_secret_access_key, type: :string, default: ""
      end
      config.secret_key_base = credentials.secret_key_base
    end

    config.app_config = AnywayAppConfig.build(load: true) do
      config_name "app_config"
      env_prefix  "APP"

      attribute :deploy_env, type: :string, required: true
      attribute :version,    type: :string, default: "unknown"

      attribute :sentry, required: true do
        attribute :dsn,         type: :string, default: ""
        attribute :environment, type: :string, required: true
      end
    end
  end
end
```

`AnywayAppConfig.build(&block)` returns an anonymous `AnywayAppConfig::Config`
subclass; `build(load: true, &block)` calls `load!` and returns the frozen
instance. The block is `class_eval`'d on the new subclass, so `config_name`,
`env_prefix`, and `attribute` are available exactly as in a named class.

`config_name` is **mandatory** — anonymous classes have no name, so
`anyway_config` can't infer it. Otherwise YAML loading and ENV nesting work
identically (so `config/credentials.yml`, `config/app_config.yml`, and
`APP_SENTRY__DSN` all behave the same as the file-based form).

#### Disabling ENV loading entirely

If you want a config to read **only** from YAML and ignore the environment
(e.g. for credentials that must never leak in via stray ENV vars, or to make
behavior deterministic in tests), restrict `configuration_sources` on the
class to the YAML loader:

```ruby
class Credentials < AnywayAppConfig::Config
  config_name "credentials"
  self.configuration_sources = [:yml]   # YAML only — ignore ENV, ignore Rails secrets/credentials loaders

  attribute :secret_key_base,   type: :string, required: true
  attribute :database_password, type: :string, required: true
end
```

`configuration_sources` is an array of loader IDs registered on
`Anyway.loaders` (`:yml`, `:env`, `:credentials`, etc — Rails adds a few).
Only listed loaders run for this class. With just `[:yml]`, ENV variables
have no effect on the values, regardless of `env_prefix`.

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
