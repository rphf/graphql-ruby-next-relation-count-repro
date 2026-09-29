# Execution::Next runs an extra SELECT COUNT(*) for list fields that return an
# unloaded ActiveRecord relation. Run: ruby repro.rb
require "bundler/inline"

gemfile do
  source "https://rubygems.org"
  gem "graphql", ENV["GRAPHQL_PATH"] ? { path: ENV["GRAPHQL_PATH"] } : {}
  gem "activerecord"
  gem "sqlite3"
end

require "active_record"
require "graphql"

ActiveRecord::Base.establish_connection(adapter: "sqlite3", database: ":memory:")
ActiveRecord::Schema.verbose = false
ActiveRecord::Schema.define do
  create_table(:authors) { |t| t.string :name }
  create_table(:posts) { |t| t.string :title; t.references :author }
end

class Author < ActiveRecord::Base
  has_many :posts
end

class Post < ActiveRecord::Base; end

3.times { |i| Author.create!(name: "Author #{i}").posts.create!(title: "Post #{i}") }

class PostType < GraphQL::Schema::Object
  field :title, String
end

class AuthorType < GraphQL::Schema::Object
  field :name, String
  field :posts, [PostType] # `author.posts`, an unloaded association
end

class QueryType < GraphQL::Schema::Object
  field :authors, [AuthorType] # `Author.all`, an unloaded relation
end

class Schema < GraphQL::Schema
  query QueryType
  use GraphQL::Execution::Next
end

Root = Struct.new(:authors)
QUERY = "{ authors { name posts { title } } }"

def run(engine)
  sql = []
  log = ->(*, payload) { sql << payload[:sql] unless payload[:name] == "SCHEMA" }
  result = ActiveSupport::Notifications.subscribed(log, "sql.active_record") do
    Schema.public_send(engine, QUERY, root_value: Root.new(Author.all))
  end
  puts "#{engine}: #{sql.size} queries", sql.map { |s| "  #{s}" }, ""
  [result.to_h, sql.size]
end

puts "graphql #{GraphQL::VERSION}, activerecord #{ActiveRecord::VERSION::STRING}", ""
legacy = run(:execute)
nxt = run(:execute_next)
abort "Different results!" if legacy[0] != nxt[0]
if nxt[1] == legacy[1]
  puts "Both engines ran #{nxt[1]} queries."
else
  puts "execute_next ran #{nxt[1] - legacy[1]} more queries than execute."
end
