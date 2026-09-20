require 'sinatra/base'
require 'sinatra/activerecord'
require 'json'
require 'securerandom'
require 'digest'

# Main application
class UrlShortener < Sinatra::Base
  use Rack::Cors do
    allow do
      origins '*'
      resource '*',
        headers: :any,
        methods: [:get, :post, :put, :patch, :delete, :options, :head]
    end
  end

  # Rate limiting middleware
  use Rack::Builder do
    map '/shorten' do
      run RateLimiter.new
    end
  end

  configure do
    set :database_file, File.join(__dir__, 'config', 'database.yml')
    set :session_secret, ENV['SESSION_SECRET'] || SecureRandom.hex(32)
    set :public_folder, 'public'
    set :logging, ENV['LOG_LEVEL'] || 'info'
  end

  helpers do
    def h(text)
      Rack::Utils.escape_html(text)
    end

    def json_params
      JSON.parse(request.body.read)
    rescue JSON::ParserError => e
      halt 400, { error: 'Invalid JSON' }.to_json
    end

    def halt_with_json(status, message)
      halt status, { error: message }.to_json
    end

    def require_api_key
      api_key = ENV['API_KEY']
      halt_with_json(401, 'Unauthorized') unless request.env['HTTP_X_API_KEY'] == api_key
    end

    def rate_limit
      client_ip = request.ip
      key = "rate_limit:#{client_ip}"
      current = $redis.incr(key)
      $redis.expire(key, 60) if current == 1
      halt_with_json(429, 'Too Many Requests') if current > 100
    end
  end

  before do
    content_type :json
  end

  get '/health' do
    { status: 'ok' }.to_json
  end

  post '/shorten' do
    require_api_key
    rate_limit

    data = json_params
    original_url = data['original_url']

    halt_with_json(400, 'original_url is required') unless original_url
    halt_with_json(400, 'Invalid URL format') unless valid_url?(original_url)

    service = UrlShortenerService.new
    short_url = service.create(original_url)

    { short_code: short_url.short_code, short_url: short_url.short_url, original_url: original_url }.to_json
  end

  get '/short/:code' do
    require_api_key
    rate_limit

    service = UrlShortenerService.new
    short_url = service.expand(params[:code])

    halt_with_json(404, 'Short URL not found') unless short_url

    service.track(params[:code], request.ip, request.user_agent)

    redirect short_url.original_url, 302
  end

  get '/analytics/:code' do
    require_api_key
    rate_limit

    service = UrlShortenerService.new
    analytics = service.analytics(params[:code])

    halt_with_json(404, 'Short URL not found') unless analytics

    analytics.to_json
  end

  error Sinatra::NotFound do
    halt_with_json(404, 'Not Found')
  end

  error StandardError do
    halt_with_json(500, 'Internal Server Error')
  end

  private

  def valid_url?(url)
    uri = URI.parse(url)
    uri.is_a?(URI::HTTP) || uri.is_a?(URI::HTTPS)
  rescue URI::InvalidURIError
    false
  end
end