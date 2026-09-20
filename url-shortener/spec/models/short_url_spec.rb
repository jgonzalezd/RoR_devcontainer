require 'spec_helper'
require 'sinatra/activerecord'
require 'sinatra/activerecord/rake'

ActiveRecord::Base.establish_connection(
  adapter: 'sqlite3',
  database: 'tmp/test.db'
)

RSpec.describe ShortUrl do
  ...
end
