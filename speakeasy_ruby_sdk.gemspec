$LOAD_PATH.push File.expand_path('lib', __dir__)
require 'speakeasy_ruby_sdk/version'

Gem::Specification.new do |s|
  s.name        = 'speakeasy_ruby_sdk'
  s.version     = SpeakeasyRubySdk::VERSION.dup
  s.platform    = Gem::Platform::RUBY
  s.licenses    = ['Apache-2.0']
  s.summary     = 'Speakeasy is your API Platform team as a service'
  s.homepage    = 'https://github.com/speakeasy-api/speakeasy_ruby_sdk'
  s.description = 'Speakeasy is your API Platform team as a service. Use our drop in SDK to manage all your API Operations including embeds for request logs and usage dashboards, test case generation from traffic, and understanding API drift.'
  s.authors     = ['Ian Bentley']
  s.metadata    = {
    'homepage_uri' => 'https://github.com/speakeasy-api/speakeasy_ruby_sdk',
    'documentation_uri' => 'https://docs.speakeasyapi.dev/docs/home',
    'source_code_uri' => 'https://github.com/speakeasy-api/speakeasy_ruby_sdk'
  }

  s.files         = Dir['{lib,test}/**/*', 'LICENSE', 'README.md']
  s.require_paths = ['lib']
  s.required_ruby_version = '>= 2.4'

  s.add_runtime_dependency('grpc', '~> 1.54.0')
  s.add_runtime_dependency('har', '~> 0.1.5')
  s.add_runtime_dependency('http-cookie', '~> 1.0')
  s.add_runtime_dependency('delegate', '~> 0.2')
  s.add_runtime_dependency('speakeasy_pb', '~> 1.0')
  s.add_runtime_dependency('uri', '~> 0.11')


  s.add_development_dependency('timecop', '~> 0.9')
  s.add_development_dependency('rack/test', '~> 2.0')
  s.add_development_dependency('json', '~> 2.6')
  s.add_development_dependency('ostruct', '~> 0.3')
  s.add_development_dependency('spy', '~> 1.0')

end
