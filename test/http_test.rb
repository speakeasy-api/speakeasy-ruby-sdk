require 'test/unit'
require 'rack/test'
require 'json'
require_relative '../lib/speakeasy_ruby_sdk'
# require 'action_dispatch/http/response'

class BasicHttpTest < Test::Unit::TestCase
  include Rack::Test::Methods

  def simple_app
    ->(_env) { [200, { 'content-type' => 'text/javascript' }, ActionDispatch::Response::RackBody.new(['All responses are OK'])] }
  end

  def fuller_app
    ->(_env) { [200, {"X-Frame-Options"=>"SAMEORIGIN", "X-XSS-Protection"=>"0", "X-Content-Type-Options"=>"nosniff", "X-Download-Options"=>"noopen", "X-Permitted-Cross-Domain-Policies"=>"none", "Referrer-Policy"=>"strict-origin-when-cross-origin", "Content-Type"=>"application/json; charset=utf-8"}, ActionDispatch::Response::RackBody.new]}
  end

  def test_response_is_unchanged
    request = Rack::MockRequest.env_for('/', method: :get)

    subject = SpeakeasyRubySdk::Middleware.new(simple_app)
    status, _headers, _response = subject.call(request)
    assert_equal status, 200
  end

  def test_full_request
    request = Rack::MockRequest.env_for('/', method: :get)
    subject = SpeakeasyRubySdk::Middleware.new(fuller_app)
    status, _headers, _response = subject.call(request)
    assert_equal status, 200
  end

end
