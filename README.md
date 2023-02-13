
![180100416-b66263e6-1607-4465-b45d-0e298a67c397](https://user-images.githubusercontent.com/68016351/181640742-31ab234a-3b39-432e-b899-21037596b360.png)

Speakeasy is your API Platform team as a service. Use our drop in SDK to manage all your API Operations including embeds for request logs and usage dashboards, test case generation from traffic, and understanding API drift.

The Speakeasy Ruby SDK for evaluating API requests/responses. Compatible with any HTTP framework implemented on top of rack.

## Supported Frameworkds

Tested and supported Frameworks include:

* rails
* sinatra

The Speakeasy Ruby SDK depends only upon Rack, however, so other frameworks should work.

## Installation

Simply install the Speakeasy Ruby SDK gem

```
  gem install speakeasy_ruby_sdk
```

or install using bundler

```
  bundle add speakeasy_ruby_sdk
```

### Minimum configuration

[Sign up for free on our platform](https://www.speakeasyapi.dev/). After you've created a workspace and generated an API key enable Speakeasy in your API as follows:

For a rails project, configure Speakeasy along with your other Middlewares in your `config/application.rb` function:

```ruby
    speakeasy_config = {
      ingestion_server_url: "localhost:443",
      api_key: "YOUR API KEY HERE",
      api_id: "YOUR API ID HERE",
      version_id: "YOUR API VERSION HERE"
    }

    config.middleware.insert_before 0, SpeakeasyRubySdk::Middleware, speakeasy_config
```

Build and deploy your app and that's it. Your API is being tracked in the Speakeasy workspace you just created
and will be visible on the dashboard next time you log in. Visit our [docs site](https://docs.speakeasyapi.dev/) to
learn more.

**warning** Some common middlewares, like `ActionDispatch::Cookies` remove or rewrite headers in order to provide additional functionality to your app.  In order to capture the original headers, we recommend using the `insert_before` rather than `use`ing so that it will be inserted at the front of the middleware stack.  The middleware will function at any position in the middleware stack, but may not be able to report all information to Speakeasy.

### Tracking Multiple APIs configuration

The Speakeasy SDK is confirgurable using a config parameter. If you want to use the SDK to track multiple Apis or Versions from the same service you can configure individual instances of the SDK, like so:

```ruby
    speakeasy_config_1 = {
      api_key: "YOUR API KEY HERE",
      api_id: "YOUR API ID HERE",
      version_id: "YOUR API VERSION HERE"
    }
    speakeasy_config_2 = {
      api_key: "YOUR API KEY HERE",
      api_id: "YOUR API ID HERE",
      version_id: "YOUR API VERSION HERE"
    }

    config.middleware.insert_before 0, SpeakeasyRubySdk::Middleware, speakeasy_config_1
    config.middleware.insert_before 0, SpeakeasyRubySdk::Middleware, speakeasy_config_2
```

This allows multiple instances of the SDK to be associated with different routers or routes within your service.

### Only Tracking Some Routes
 
We recommend using the approach native to your framework to limit the application of the Speakeasy middleware.  In Rails, that approach is [Engines](https://guides.rubyonrails.org/engines.html), in Sinatra, middleware are `use`'d by controllers, so add the directive to a Controller which is the parent of those routes you wish to track.

## todo - add Sinatra examples

     

## Request Matching

The Speakeasy SDK out of the box will do its best to match requests to your provided OpenAPI Schema. It does this by extracting the path template used by one of the supported routers or frameworks above for each request captured and attempting to match it to the paths defined in the OpenAPI Schema.  In order to enable this functionality include a `routes` directive in your speakeasy configuration - for example in Rails:

```ruby
  config = {
    routes: Application.routes,
    ..snip/..
  }
    config.middleware.use SpeakeasyRubySdk::Middleware, config

```
This isn't always successful or even possible, meaning requests received by Speakeasy will be marked as unmatched, and potentially not associated with your Api, Version or  in the Speakeasy DashApiEndpointsboard.

To help the SDK in these situations you can provide path hints per request handler that match the paths in your OpenAPI Schema:

```ruby
class YourController < ApplicationController 
    def action
      request.env[:path_hint] = '/api/v1/books'
      ..snip..
    end
    ..snip..
end

```

## Capturing Customer IDs

To help associate requests with customers/users of your APIs you can provide a customer ID from any controller or route:

```ruby
  def index
    request.env[:customer_id] = customer_id
  end
```

To easily set the `customer_id` on all requests from a Rails controller, use this standard pattern

```ruby
class myController < ApplicationController
    before_action set_customer_id

    def index
      ..snip..
    end
    
    private
    
      def set_customer_id
        req.env[:customer_id] = @session[:customer_id]
      end
end
```

Note: This is not required, but is highly recommended. By setting a customer ID you can easily associate requests with your customers/users in the Speakeasy Dashboard, powering filters in the Request Viewer.

## Masking sensitive data

Speakeasy can mask sensitive data in the query string parameters, headers, cookies and request/response bodies captured by the SDK. This is useful for maintaining sensitive data isolation, and retaining control over the data that is captured.

Using the Only Tracking Some Routes section above you can completely ignore certain routes, causing the SDK to not selectively capture requests.

But if you would like to be more selective you can mask certain sensitive data using our middleware controller allowing you to mask fields as needed in different handlers:

```ruby
  config = {
    ...
    masking: [
        SpeakeasyRubySdk::MaskConfig.new(:request_header, ['Authorization'])
      ],
  }
```
The `masking` section of the config map takes an array of different masking options

  - `SpeakeasyRubySdk::MaskConfig.new(:query_params, attributes, mask_strings)` will mask the specified query params with the optional string mask
  - `SpeakeasyRubySdk::MaskConfig.new(:request_headers, attributes, mask_strings)` will mask the specified request_headers with the optional string mask
  - `SpeakeasyRubySdk::MaskConfig.new(:response_headers, attributes, mask_strings)` will mask the specified response headers with the optional string mask
  - `SpeakeasyRubySdk::MaskConfig.new(:request_cookies, attributes, mask_strings)` will mask the specified request cookies with the optional string mask
  - `SpeakeasyRubySdk::MaskConfig.new(:response_cookies, attributes, mask_strings)` will mask the specified response cookies with the optional string mask
  - `SpeakeasyRubySdk::MaskConfig.new(:request_body_string, attributes, mask_strings)` specified request body fields with an optional mask. Supports string fields only. Matches using regex.
  - `SpeakeasyRubySdk::MaskConfig.new(:request_body_number, attributes, mask_strings)` specified request body fields with an optional mask. Supports numeric fields only. Matches using regex.
  - `SpeakeasyRubySdk::MaskConfig.new(:response_body_string, attributes, mask_strings)` specified response body fields with an optional mask. Supports string fields only. Matches using regex.
  - `SpeakeasyRubySdk::MaskConfig.new(:response_body_number, attributes, mask_strings)` specified response body fields with an optional mask. Supports numeric fields only. Matches using regex.

In all of the above instances, you may optionally provide an array of mask strings.  If you leave this field out, or pass an empty array, the system will mask with our default mask value "__masked__" (-12321 for numbers).  If you provide an array with a single value, then the system will mask all matches with that value.  If you provide more than one value, then each match will be replaced by the corresponding mask values (if there are too few, then the remaining matches will receive our default mask value).

You may provide as many MaskConfig objects as you desire.

## Embedded Request Viewer Access Tokens

The Speakeasy SDK can generate access tokens for the [https://docs.speakeasyapi.dev/speakeasy-user-guide/request-viewer/embedded-request-viewer](Embedded Request Viewer) that can be used to view requests captured by the SDK.

For documentation on how to configure filters, find that [https://docs.speakeasyapi.dev/speakeasy-user-guide/request-viewer/embedded-request-viewer](HERE).

You are able to request an `EmbeddedAccessToken` from any location in your application, but most likely you will make such a request inside of a `Controller` method.

```rb
class MyController < ApplicationController

  def action
    access_token = SpeakeasyRubySdk::get_embedded_access_token 'customer_id', '=', <some_customer_id>, {api_key: '..snip..'}
  end
end
```