require 'sinatra/activerecord'

class Click < ActiveRecord::Base
  self.table_name = 'clicks'

  belongs_to :short_url, class_name: 'ShortUrl'

  validates :ip_address, presence: true
  validates :short_url_id, presence: true

  def self.log_click(short_url_id, ip, user_agent)
    create!(
      short_url_id: short_url_id,
      ip_address: ip,
      user_agent: user_agent,
      created_at: Time.now.utc
    )
  end
end