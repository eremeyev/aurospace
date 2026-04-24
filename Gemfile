source 'https://rubygems.org'

gem 'rails', '~> 8.1.3'
gem 'devise'
gem 'pundit'
gem 'propshaft'
gem 'pg'
gem 'puma', '>= 5.0'
gem 'importmap-rails'
gem 'turbo-rails'
gem 'stimulus-rails'
gem 'jbuilder'
gem 'kaminari'

gem 'tzinfo-data', platforms: %i[ windows jruby ]

# Use the database-backed adapters for Rails.cache, Active Job, and Action Cable
gem 'solid_cache'
gem 'solid_queue'
gem 'solid_cable'

gem 'bootsnap', require: false

gem 'thruster', require: false

gem 'dry-initializer'
gem 'dry-monads'
gem 'dry-schema'
gem 'dry-struct'
gem 'dry-types'
gem 'dry-validation'

group :development, :test do
  # See https://guides.rubyonrails.org/debugging_rails_applications.html#debugging-with-the-debug-gem
  gem 'debug', platforms: %i[ mri windows ], require: 'debug/prelude'
  gem 'pry-rails'

  gem 'dotenv'
  gem 'rspec-rails', '~> 8.0.0'
  gem 'factory_bot_rails'

  gem 'bundler-audit', require: false
  gem 'brakeman', require: false

  gem 'rubocop-rails-omakase', require: false
  gem 'reek'
end

group :development do
  # Use console on exceptions pages [https://github.com/rails/web-console]
  gem 'web-console'
end

group :test do
  # Use system testing [https://guides.rubyonrails.org/testing.html#system-testing]
  gem 'capybara'
  gem 'selenium-webdriver'
  gem 'shoulda-matchers'
  gem 'rails-controller-testing'
  gem 'pundit-matchers'
end
