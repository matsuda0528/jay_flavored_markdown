# frozen_string_literal: true

require_relative "lib/jay_flavored_markdown/version"

Gem::Specification.new do |spec|
  spec.name          = "jay_flavored_markdown"
  spec.version       = JayFlavoredMarkdown::VERSION
  spec.authors       = ["Nomura Laboratory"]
  spec.email         = [""]

  spec.summary       = "JayFlavoredMarkdown Converter"
  spec.description   = "JayFlavoredMarkdown Converter"
  spec.homepage      = "https://github.com/nomlab/jay_flavored_markdown"
  spec.license       = "MIT"
  spec.required_ruby_version = ">= 2.4.0"

  spec.metadata["allowed_push_host"] = "https://rubygems.org"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "https://github.com/nomlab/jay_flavored_markdown"
  spec.metadata["changelog_uri"] = "https://github.com/nomlab/jay_flavored_markdown/blob/master/CHANGELOG.md"

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  spec.files = Dir.chdir(File.expand_path(__dir__)) do
    `git ls-files -z`.split("\x0").reject { |f| f.match(%r{\A(?:test|spec|features)/}) }
  end
  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  # Uncomment to register a new dependency of your gem
  # spec.add_dependency "example-gem", "~> 1.0"
  spec.add_dependency "kramdown", "~> 2.0"
  spec.add_dependency "kramdown-parser-gfm"
  spec.add_dependency "html-pipeline", "~> 2.14.0"
  spec.add_dependency "rinku"
  spec.add_dependency "gemoji"
  spec.add_dependency "sanitize"
  spec.add_dependency "rouge"
  spec.add_dependency "activesupport", "~> 6.1.4"

  spec.add_development_dependency "rake", "~> 13.0"
  spec.add_development_dependency "minitest", "~> 5.0"
  spec.add_development_dependency "rubocop", "~> 1.7"


  # For more information and examples about making a new gem, checkout our
  # guide at: https://bundler.io/guides/creating_gem.html
end
