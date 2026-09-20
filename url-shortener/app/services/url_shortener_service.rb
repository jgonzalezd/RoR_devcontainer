require 'digest'

class UrlShortenerService
  SHORT_CODE_LENGTH = 8

  def initialize
    @short_url_model = ShortUrl
    @click_model = Click
  end

  def create(original_url)
    validate_url(original_url)

    existing = @short_url_model.find_by_url(original_url)
    return existing if existing

    short_code = generate_unique_code(original_url)
    short_url_path = generate_short_url_path(short_code)

    @short_url_model.create!(
      original_url: original_url,
      short_code: short_code,
      short_url: short_url_path
    )
  rescue ActiveRecord::RecordInvalid => e
    raise ServiceError, "Failed to create short URL: #{e.message}"
  rescue ServiceError => e
    raise e
  end

  def expand(code)
    @short_url_model.find_by_code(code)
  rescue ActiveRecord::RecordNotFound => e
    raise NotFoundError, "Short URL not found for code: #{code}"
  end

  def analytics(code)
    short_url = @short_url_model.find_by_code(code)
    return nil unless short_url

    {
      short_url: short_url,
      total_clicks: short_url.clicks.count,
      clicks: short_url.clicks.order(created_at: :desc)
    }
  rescue ActiveRecord::RecordNotFound
    nil
  end

  def track(code, ip, user_agent)
    short_url = @short_url_model.find_by_code(code)
    return false unless short_url

    @click_model.log_click(short_url.id, ip, user_agent)
    true
  end

  def valid_url?(url)
    uri = URI.parse(url)
    (uri.is_a?(URI::HTTP) || uri.is_a?(URI::HTTPS)) && !uri.host.nil?
  rescue URI::InvalidURIError
    false
  end

  private

  def generate_unique_code(original_url)
    hash = Digest::SHA256.hexdigest(original_url)
    generate_base62(hash)
  end

  def generate_short_url_path(code)
    base_url = ENV['BASE_URL'] || 'http://localhost:4567'
    "#{base_url}/short/#{code}"
  end

  def generate_base62(hex)
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

  def validate_url(url)
    raise ServiceError, 'URL is required' if url.nil? || url.empty?
    raise ServiceError, 'Invalid URL format' unless valid_url?(url)
  end
end

class ServiceError < StandardError; end
class NotFoundError < StandardError; end