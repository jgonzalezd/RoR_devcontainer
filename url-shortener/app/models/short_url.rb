require 'sinatra/activerecord'

class ShortUrl < ActiveRecord::Base
  self.table_name = 'short_urls'

  validates :original_url, presence: true, uniqueness: true
  validates :short_code, presence: true, uniqueness: true
  validates :short_url, presence: true, uniqueness: true

  has_many :clicks, class_name: 'Click', dependent: :destroy

  SHORT_CODE_LENGTH = 8

  def self.generate_short_code(original_url)
    hash = Digest::SHA256.hexdigest(original_url)
    base62 = hash_to_base62(hash)
    base62[0, SHORT_CODE_LENGTH]
  end

  def self.find_by_code(code)
    find_by(short_code: code)
  end

  def self.find_by_url(url)
    find_by(original_url: url)
  end

  private

  def self.hash_to_base62(hex)
    chars = '0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ'
    base = 62
    num = hex.to_i(16)
    result = ''
    while num > 0
      result = chars[num % base] + result
      num /= base
    end
    result.ljust(SHORT_CODE_LENGTH, '0')
  end
end