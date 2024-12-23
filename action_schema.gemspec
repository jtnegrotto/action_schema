# frozen_string_literal: true

require_relative "lib/action_schema/version"

Gem::Specification.new do |spec|
  spec.name = "action_schema"
  spec.version = ActionSchema::VERSION
  spec.authors = [ "Julien Negrotto" ]
  spec.email = [ "jtnegrotto@gmail.com" ]

  spec.summary = "A lightweight schema library for Rails controllers."
  spec.description = "ActionSchema provides a flexible, Rails-friendly approach to rendering and parsing structured data in your controllers."
  spec.homepage = "https://github.com/jtnegrotto/action_schema"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.0.0"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "https://github.com/jtnegrotto/action_schema"
  spec.metadata["changelog_uri"] = "https://github.com/jtnegrotto/action_schema/blob/master/CHANGELOG.md"

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  gemspec = File.basename(__FILE__)
  spec.files = IO.popen(%w[git ls-files -z], chdir: __dir__, err: IO::NULL) do |ls|
    ls.readlines("\x0", chomp: true).reject do |f|
      (f == gemspec) ||
        f.start_with?(*%w[bin/ test/ spec/ features/ .git .github appveyor Gemfile])
    end
  end
  spec.require_paths = [ "lib" ]

  # Uncomment to register a new dependency of your gem
  # spec.add_dependency "example-gem", "~> 1.0"
  spec.add_dependency "rails"
  spec.add_dependency "activesupport"
  spec.add_development_dependency "rspec", "~> 3.0"
  spec.add_development_dependency "rake", "13.0"
  spec.add_development_dependency "rubocop", "~> 1.21"
  spec.add_development_dependency "rubocop-rails-omakase", "~> 1.0"
  spec.add_development_dependency "simplecov", "~> 0.22"
  spec.add_development_dependency "rspec-rails"
  spec.add_development_dependency "pry"
  spec.add_development_dependency "pry-nav"

  # For more information and examples about making a new gem, check out our
  # guide at: https://bundler.io/guides/creating_gem.html
end
