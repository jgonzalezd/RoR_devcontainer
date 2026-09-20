require 'sinatra/activerecord'
require 'rack/test'
require 'minitest/autorun'
require 'minitest/reporters'
require 'json'
require 'securerandom'
require 'digest'

Minitest::Reporters.use! [Minitest::Reporters::DefaultReporter.new]

# Test database setup
ActiveRecord::Base.establish_connection(
  adapter: 'sqlite3',
  database: ':memory:'
)

# Schema
ActiveRecord::Schema.define do
  create_table :short_urls, force: true do |t|
    t.string :original_url, null: false
    t.string :short_code, null: false
    t.string :short_url, null: false
    t.timestamps
  end

  create_table :clicks, force: true do |t|
    t.integer :short_url_id, null: false
    t.string :ip_address, null: false
    t.string :user_agent
    t.datetime :created_at, null: false
  end

  add_index :short_urls, :short_code, unique: true
  add_index :short_urls, :original_url, unique: true
end

# Require all app files
Dir[File.join(__dir__, '..', 'app', '**', '*.rb')].each { |f| require f }

# Test helper methods
module TestHelpers
  def app
    UrlShortener
  end

  def app_key
    ENV['API_KEY'] = 'test-api-key'
    'test-api-key'
  end

  def valid_url
    'https://example.com/page'
  end

  def invalid_url
    'not-a-url'
  end
end