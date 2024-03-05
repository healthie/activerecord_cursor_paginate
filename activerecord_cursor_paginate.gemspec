# frozen_string_literal: true

require_relative "lib/activerecord_cursor_paginate/version"

Gem::Specification.new do |spec|
  spec.name = "activerecord_cursor_paginate"
  spec.version = ActiveRecordCursorPaginate::VERSION
  spec.authors = ["fatkodima"]
  spec.email = ["fatkodima123@gmail.com"]

  spec.summary = "Cursor-based pagination for ActiveRecord."
  spec.homepage = "https://github.com/fatkodima/activerecord_cursor_paginate"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 2.7"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = spec.homepage
  spec.metadata["changelog_uri"] = "#{spec.homepage}/blob/master/CHANGELOG.md"

  spec.files = Dir["**/*.{md,txt}", "{lib}/**/*"]
  spec.require_paths = ["lib"]

  spec.add_dependency "activerecord", ">= 7.0"
end
