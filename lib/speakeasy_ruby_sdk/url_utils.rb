require 'uri'
module SpeakeasyRubySdk
  module UrlUtils
    def self.resolve_url env, query_params=nil
      if env.include?('SERVER_PORT') && env['SERVER_PORT'] != "80"
        request_uri = "#{env['SERVER_NAME']}:#{env['SERVER_PORT']}#{env['PATH_INFO']}"
      else
        request_uri = "#{env['SERVER_NAME']}#{env['PATH_INFO']}"
      end

      if request_uri.include? '?'
        request_uri = request_uri.split('?')[0]
      end
      scheme = env['rack.url_scheme']
      host = env['HTTP_HOST']
      if !query_params.nil? && !query_params.empty?
        updated_query_string = URI.encode_www_form query_params
        URI("#{scheme}://#{host}#{request_uri}?#{updated_query_string}")
      else 
        URI("#{scheme}://#{host}#{request_uri}")
      end
    end
  end
end