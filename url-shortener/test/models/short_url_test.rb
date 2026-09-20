require_relative '../test_helper'
require 'sinatra/activerecord'

class ShortUrlTest < Minitest::Test
  include TestHelpers

  def setup
    @short_url = ShortUrl.new
  end

  def test_validates_presence_of_original_url
    @short_url.original_url = nil
    refute @short_url.valid?
    assert_includes @short_url.errors[:original_url], "can't be blank"
  end

  def test_validates_presence_of_short_code
    @short_url.short_code = nil
    refute @short_url.valid?
    assert_includes @short_url.errors[:short_code], "can't be blank"
  end

  def test_validates_uniqueness_of_short_code
    ShortUrl.create!(
      original_url: 'https://example.com',
      short_code: 'abc123',
      short_url: 'http://localhost:4567/short/abc123'
    )

    duplicate = ShortUrl.new(
      original_url: 'https://example2.com',
      short_code: 'abc123',
      short_url: 'http://localhost:4567/short/abc123'
    )
    refute duplicate.valid?
    assert_includes duplicate.errors[:short_code], "has already been taken"
  end

  def test_generates_short_code_from_url
    url = 'https://example.com/test'
    code = ShortUrl.generate_short_code(url)
    assert_equal 8, code.length
    refute_nil code
  end

  def test_same_url_generates_same_code
    url = 'https://example.com/same'
    code1 = ShortUrl.generate_short_code(url)
    code2 = ShortUrl.generate_short_code(url)
    assert_equal code1, code2
  end

  def test_different_urls_generate_different_codes
    url1 = 'https://example.com/1'
    url2 = 'https://example.com/2'
    code1 = ShortUrl.generate_short_code(url1)
    code2 = ShortUrl.generate_short_code(url2)
    refute_equal code1, code2
  end

  def test_valid_url_format
    assert_short_url.valid_url?('https://example.com')
    assert_short_url.valid_url?('http://test.org/page?query=1')
    refute_short_url.valid_url?('not-a-url')
    refute_short_url.valid_url?('')
    refute_short_url.valid_url?(nil)
  end

  private

  def assert_short_url
    @short_url ||= ShortUrl.new
  end
end