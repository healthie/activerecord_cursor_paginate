# frozen_string_literal: true

require "activerecord_cursor_paginate"

require "minitest/autorun"

ActiveRecord::Base.establish_connection(adapter: "sqlite3", database: ":memory:")

if ENV["VERBOSE"]
  ActiveRecord::Base.logger = ActiveSupport::Logger.new($stdout)
else
  ActiveRecord::Base.logger = ActiveSupport::Logger.new("debug.log", 1, 100.megabytes)
  ActiveRecord::Migration.verbose = false
end

ActiveRecord::Schema.define do
  create_table :users do |t|
    t.integer :company_id
    t.timestamps
  end

  if ActiveRecord.gem_version >= Gem::Version.new("7.1")
    create_table :cpk_users, primary_key: [:company_id, :id] do |t|
      t.integer :company_id
      t.integer :id
      t.timestamps
    end
  end

  create_table :projects do |t|
    t.integer :user_id
    t.integer :stars
  end
end

class User < ActiveRecord::Base
  has_many :projects
end

class CpkUser < ActiveRecord::Base
end

class Project < ActiveRecord::Base
end

Minitest::Test.class_eval do
  alias_method :assert_not, :refute
  alias_method :assert_not_empty, :refute_empty
end

users = [
  { id: 9, company_id: 1, created_at: 1.minute.ago },
  { id: 1, company_id: 2, created_at: 3.minutes.ago },
  { id: 2, company_id: 3, created_at: 2.minutes.ago },
  { id: 6, company_id: 2, created_at: 4.minutes.ago },
  { id: 5, company_id: 3, created_at: 10.minutes.ago },
  { id: 7, company_id: 1, created_at: 7.minutes.ago },
  { id: 4, company_id: 4, created_at: 6.minutes.ago },
  { id: 10, company_id: 4, created_at: 5.minutes.ago },
  { id: 3, company_id: 1, created_at: 9.minutes.ago },
  { id: 8, company_id: 3, created_at: 8.minutes.ago }
]
User.insert_all!(users)
CpkUser.insert_all!(users) if ActiveRecord.gem_version >= Gem::Version.new("7.1")

projects = [
  { id: 1, user_id: 2, stars: 5 },
  { id: 2, user_id: 1, stars: 10 },
  { id: 3, user_id: 1, stars: 9 },
  { id: 4, user_id: 3, stars: 2 },
  { id: 5, user_id: 2, stars: 6 }
]
Project.insert_all!(projects)
