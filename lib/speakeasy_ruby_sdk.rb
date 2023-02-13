require_relative 'speakeasy_ruby_sdk/version'
require_relative 'speakeasy_ruby_sdk/config'
require_relative 'speakeasy_ruby_sdk/url_utils'
require_relative 'speakeasy_ruby_sdk/masker'
require_relative 'speakeasy_ruby_sdk/http_transaction'
require_relative 'speakeasy_ruby_sdk/har_builder'
require_relative 'speakeasy_ruby_sdk/time'

require "delegate"

require 'speakeasy_pb'
include Ingest
include Embedaccesstoken

module SpeakeasyRubySdk
  class RouteWrapper < SimpleDelegator
    def path
      super.spec.to_s
    end
  end

  class Middleware
    attr_accessor :ingest_client
    attr_reader :config

    def initialize(app, config=nil)
      @config = Config.default.merge config
      @app = app
      @masker = SpeakeasyRubySdk::Masker.new @config
      credentials = GRPC::Core::ChannelCredentials.new()
      @ingest_client = Ingest::IngestService::Stub.new(@config.ingestion_server_url, credentials)

    end
   
    def call(env)
      if env.include? 'time_utils'
        time_utils = env['time_utils']
      else
        time_utils = TimeUtils.new
      end

      status, response_headers, response_body = @app.call(env)

      if !env.include? 'time_utils'
        time_utils.set_end_time
      end

      http_transaction = HttpTransaction.new time_utils, env, status, response_headers, response_body, @masker

      path_hint = ''
      if @config.routes # todo - handle other routers if not rails
        req = ActionDispatch::Request.new(env)
        found_route = nil
        @config.routes.router.recognize(req) do |route, params|
          found_route = route
        end
        if ! found_route.nil?
          path_hint = RouteWrapper.new(found_route).path
        end
      end
      if ! env[:path_hint].nil?
        path_hint = env[:path_hint]
      end
 
      har_builder = HarBuilder.new @config
      har = har_builder.construct_har http_transaction

      request = Ingest::IngestRequest.new
      request.api_id = @config.api_id
      request.path_hint = path_hint
      request.version_id = @config.version_id
      if env.include? :customer_id
        request.customer_id = env[:customer_id].to_s
      end
      request.har = har

      metadata = {"x-api-key": @config.api_key}
      response = @ingest_client.ingest(request, metadata: metadata)

      [status, response_headers, response_body]
    end
  end

  def self.get_embedded_access_token key, operator, value, config=nil
    if config.nil?
      working_config = Middleware::Config.default
    else
      working_config = Middleware::Config.default.merge config
    end

    credentials = GRPC::Core::ChannelCredentials.new()
    embed_client = Embedaccesstoken::EmbedAccessTokenService::Stub.new(working_config.ingestion_server_url, credentials)
    request = Embedaccesstoken::EmbedAccessTokenRequest.new

    filter = Embedaccesstoken::EmbedAccessTokenRequest::Filter.new
    filter.key = key
    filter.operator = operator
    filter.value = value

    request.filters.push filter

    metadata = {"x-api-key": working_config.api_key}
    response = embed_client.get(request, metadata: metadata)

  end
end