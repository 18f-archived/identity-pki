# -*- encoding: utf-8 -*-
# stub: faraday 1.3.0 ruby lib spec/external_adapters

Gem::Specification.new do |s|
  s.name = "faraday".freeze
  s.version = "1.3.0"

  s.required_rubygems_version = Gem::Requirement.new(">= 0".freeze) if s.respond_to? :required_rubygems_version=
  s.metadata = { "bug_tracker_uri" => "https://github.com/lostisland/faraday/issues", "changelog_uri" => "https://github.com/lostisland/faraday/releases/tag/v1.3.0", "homepage_uri" => "https://lostisland.github.io/faraday", "source_code_uri" => "https://github.com/lostisland/faraday" } if s.respond_to? :metadata=
  s.require_paths = ["lib".freeze, "spec/external_adapters".freeze]
  s.authors = ["@technoweenie".freeze, "@iMacTia".freeze, "@olleolleolle".freeze]
  s.date = "2020-12-31"
  s.email = "technoweenie@gmail.com".freeze
  s.homepage = "https://lostisland.github.io/faraday".freeze
  s.licenses = ["MIT".freeze]
  s.required_ruby_version = Gem::Requirement.new(">= 2.4".freeze)
  s.rubygems_version = "3.4.10".freeze
  s.summary = "HTTP/REST API client library.".freeze

  s.installed_by_version = "3.4.10" if s.respond_to? :installed_by_version

  s.specification_version = 4

  s.add_runtime_dependency(%q<faraday-net_http>.freeze, ["~> 1.0"])
  s.add_runtime_dependency(%q<multipart-post>.freeze, [">= 1.2", "< 3"])
  s.add_runtime_dependency(%q<ruby2_keywords>.freeze, [">= 0"])
end
