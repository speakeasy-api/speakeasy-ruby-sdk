require 'test/unit'
require 'rack/test'
require 'json'
require 'ostruct'
require 'spy'
require 'hashdiff'
require 'timecop'
require_relative '../lib/speakeasy_ruby_sdk'

require 'speakeasy_pb'
include Ingest

def add_http_prefix header_dict
  modified_headers = {}
  for k, v in header_dict
    modified_headers["HTTP_#{k}"] = v
  end
  modified_headers
end

def header_to_dict headers
  modified_headers = {}
  for d in headers
    key = d['key']
    if d['values'].length > 1
      modified_headers[key] = d['values']
    else
      modified_headers[key] = d['values'][0]
    end
  end
  modified_headers
end

class BulkTest < Test::Unit::TestCase
  include Rack::Test::Methods

  def test_bulk
    file_pairs = []
    Dir.foreach("./test/testdata") do |file_name|
      if file_name == "." || file_name == ".."
        next
      end
      infile = nil
      outfile = nil
      if file_name.end_with?("input.json")
        prefix_name = file_name.slice(0..-11)
        output_filename = "#{prefix_name}output.json"
        pair = OpenStruct.new
        pair.infile = "./test/testdata/#{file_name}"
        pair.outfile = "./test/testdata/#{output_filename}"
        file_pairs << pair
      end
    end
    for pair in file_pairs
      input = JSON.parse(File.read(pair.infile))
      puts "Testing #{pair.infile}, #{pair.outfile}"
      config = {api_id: '123', version_id: '1.0'}

      masking = []
      if input['args'].include? 'query_string_masks'
        for k, v in input['args']['query_string_masks']
          masking << SpeakeasyRubySdk::MaskConfig.new(:query_params, [k], [v])
        end
      end
      if input['args'].include? 'request_header_masks'
        for k, v in input['args']['request_header_masks']
          masking << SpeakeasyRubySdk::MaskConfig.new(:request_headers, [k], [v])
        end
      end
      if input['args'].include? 'request_cookie_masks'
        for k, v in input['args']['request_cookie_masks']
          masking << SpeakeasyRubySdk::MaskConfig.new(:request_cookies, [k], [v])
        end
      end
      if input['args'].include? 'request_field_masks_string'
        for k, v in input['args']['request_field_masks_string']
          masking << SpeakeasyRubySdk::MaskConfig.new(:request_body_string, [k], [v])
        end
      end
      if input['args'].include? 'request_field_masks_number'
        for k, v in input['args']['request_field_masks_number']
          masking << SpeakeasyRubySdk::MaskConfig.new(:request_body_number, [k], [v])
        end
      end
      if input['args'].include? 'response_header_masks'
        for k, v in input['args']['response_header_masks']
          masking << SpeakeasyRubySdk::MaskConfig.new(:response_headers, [k], [v])
        end
      end
      if input['args'].include? 'response_cookie_masks'
        for k, v in input['args']['response_cookie_masks']
          masking << SpeakeasyRubySdk::MaskConfig.new(:response_cookies, [k], [v])
        end
      end
      if input['args'].include? 'response_field_masks_string'
        for k, v in input['args']['response_field_masks_string']
          masking << SpeakeasyRubySdk::MaskConfig.new(:response_body_string, [k], [v])
        end
      end
      if input['args'].include? 'response_field_masks_number'
        for k, v in input['args']['response_field_masks_number']
          masking << SpeakeasyRubySdk::MaskConfig.new(:response_body_number, [k], [v])
        end
      end

      config[:masking] = masking

      if input['fields'].include? 'max_capture_size'
        config[:max_capture_size] = input['fields']['max_capture_size']
      end
      response_status = input['args']['response_status']
      # if response_status < 0
      #   response_status = 200
      # end
      input['args']['response_status'] = response_status
      if input['args'].include? 'response_headers'
        input['args']['response_headers'] = header_to_dict(input['args']['response_headers'])
      else
        input['args']['response_headers'] = {}
      end

      def simple_app input
        ->(_env) { [input['args']['response_status'], input['args']['response_headers'], input['args']['response_body']]}
      end
      opts = {
        "SERVER_PROTOCOL" => 'HTTP/1.1'
      }
      if input['args'].include? 'method'
        opts[:method] = input['args']['method']
      end
      if input['args'].include? 'headers'
        opts = opts.merge add_http_prefix(header_to_dict(input['args']['headers']))
      end
      if input['args'].include? 'request_start_time'
        start_time = Time.parse(input['args']['request_start_time'])
      else
        start_time = Time.utc(2020, 1, 1, 0, 0, 0)
      end
      if input['args'].include? 'elapsed_time'
        elapsed_time = input['args']['elapsed_time']
      else
        elapsed_time = 1
      end
      opts['time_utils'] = SpeakeasyRubySdk::TimeUtils.new(start_time, elapsed_time)
      Timecop.freeze(2020, 1, 1, 0, 0, 0) ## override Time.now for the cookiejar library
      if input['args'].include? 'body'
        rack_input = StringIO.open(input['args']['body'])
        opts[:input] = rack_input
      end
      request = Rack::MockRequest.env_for(input['args']['url'], opts)
      
      subject = SpeakeasyRubySdk::Middleware.new(simple_app(input), config)
      subject.ingest_client = Spy.mock(Ingest::IngestService::Stub)
      
      spy = Spy.on(subject.ingest_client, :ingest).and_return(nil)

      status, _headers, _response = subject.call(request)

      har = JSON.parse(spy.calls.first.args[0].har)
      output = JSON.parse(File.read(pair.outfile))

      diff = Hashdiff.diff(har, output)
      assert_equal(har, output)
    end
  end

end
