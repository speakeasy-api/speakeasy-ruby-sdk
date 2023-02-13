require 'test/unit'
require 'rack/test'
require 'json'
require_relative '../lib/speakeasy_ruby_sdk'

class MaskerTest < Test::Unit::TestCase
  include Rack::Test::Methods

  def self.init_masker config
    config = SpeakeasyRubySdk::Middleware::Config.default.merge config
    SpeakeasyRubySdk::Masker.new config
  end

  def test_mask_query_param_simple
    masker_config = {
      routes: nil,
      masking: [SpeakeasyRubySdk::MaskConfig.new(:query_params, 'carrot')]
    }
    masker = MaskerTest::init_masker(masker_config)

    query_params = {'carrot': 'stick', 'parsnip': 'triangular'}

    masked_params = masker.mask_query_params '', query_params

    assert_equal(SpeakeasyRubySdk::Masker::SIMPLE_MASK, masked_params[:carrot])
    assert_equal(query_params[:parsnip], masked_params[:parsnip]) # Should be unchanged
  end

  def test_mask_query_param_multiple_attrs
    masker_config = {
      routes: nil,
      masking: [SpeakeasyRubySdk::MaskConfig.new(:query_params, ['carrot', 'parsnip', 'unknown'])]
    }
    masker = MaskerTest::init_masker(masker_config)

    query_params = {'carrot': 'stick', 'parsnip': 'triangular'}

    masked_params = masker.mask_query_params '', query_params

    assert_equal(SpeakeasyRubySdk::Masker::SIMPLE_MASK, masked_params[:carrot])
    assert_equal(SpeakeasyRubySdk::Masker::SIMPLE_MASK, masked_params[:parsnip])
  end

  def test_mask_query_param_custom_mask
    masker_config = {
      routes: nil,
      masking: [SpeakeasyRubySdk::MaskConfig.new(:query_params, ['carrot'], ['__MASK__'])]
    }
    masker = MaskerTest::init_masker(masker_config)

    query_params = {'carrot': 'stick', 'parsnip': 'triangular'}

    masked_params = masker.mask_query_params '', query_params

    assert_equal("__MASK__", masked_params[:carrot])
    assert_equal(query_params[:parsnip], masked_params[:parsnip]) # Should be unchanged
  end


  def test_mask_response_cookies_simple
    masker_config = {
      masking: [SpeakeasyRubySdk::MaskConfig.new(:response_cookies, ['magic'])]
    }
    masker = MaskerTest::init_masker(masker_config)

    response_cookies = HTTP::Cookie.parse("magic=itsnotmagic; path=/; max-age=86400; SameSite=Lax", 'http://localhost:8000')
    
    masked_cookies = masker.mask_response_cookies '', response_cookies
    
    first_cookie = masked_cookies[0]

    assert_equal(SpeakeasyRubySdk::Masker::SIMPLE_MASK, first_cookie.value)

  end

  def test_mask_body_string_simple
    masker_config = {
      masking: [SpeakeasyRubySdk::MaskConfig.new(:request_body_string, ['sign_in'])]
    }
    masker = MaskerTest::init_masker(masker_config)

    body = {'sign_in': 'wiley', 'nobody': 'somebody'}.to_json
      
    masked_body = masker.mask_request_body('', body)
    assert !masked_body.include?('wiley')
    assert masked_body.include?('somebody')
  end

  def test_mask_body_number_simple
    masker_config = {
      masking: [SpeakeasyRubySdk::MaskConfig.new(:request_body_number, ['sign_in'])]
    }
    masker = MaskerTest::init_masker(masker_config)

    body = {
      'sign_in': 5476,
      'nobody': 'somebody'
    }.to_json
    masked_body = masker.mask_request_body('', body)
    assert ! masked_body.include?('5476')
    assert masked_body.include?('somebody')
  end

  def test_mask_body_number_and_string
    masker_config = {
      masking: [
        SpeakeasyRubySdk::MaskConfig.new(:request_body_number, ['attr1']),
        SpeakeasyRubySdk::MaskConfig.new(:request_body_string, ['attr2']),
      ]
    }
    masker = MaskerTest::init_masker(masker_config)

    body = {
      'attr1': 5476,
      'attr2': 'somebody',
      'attr3': 'keep it'
    }.to_json

    masked_body = masker.mask_request_body('', body)
    assert !masked_body.include?('5476')
    assert !masked_body.include?('somebody')
    assert masked_body.include?('keep it')
  end
end
