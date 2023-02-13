module SpeakeasyRubySdk
  class HarBuilder

    def initialize api_config
      @api_config = api_config
    end

    def construct_creator name, version
      return {
        "name": name,
        "version": version
      }
    end

    def construct_log version, creator, entries, comment
      return {
        'log': {
          "version": version,
          "creator": creator,
          "entries": entries,
          "comment": comment
        }
      }
    end


    def construct_empty_cache
      return {
      }
    end
    def construct_empty_params
      return []
    end

    def construct_query_records query_params
      query_params.map {|k, v| {
        "name": k,
        "value": v
      } }.sort_by(&lambda{ |h| h[:name] })
    end

    def construct_response_cookies cookies
      final_cookies = []
      if ! cookies.nil?
        for cookie in cookies
          new_cookie = {
            'name': cookie.name, 
            'value': cookie.value,
          }
          if cookie.path && cookie.path != '/'
            new_cookie['path'] = cookie.path
          end
          if cookie.domain
            new_cookie['domain'] = cookie.domain
          end
          if cookie.expires
            new_cookie['expires'] = cookie.expires.strftime("%Y-%m-%dT%H:%M:%S.%NZ")
          end
          if cookie.httponly
            new_cookie['httpOnly'] = cookie.httponly
          end
          if cookie.secure
            new_cookie['secure'] = cookie.secure
          end
          final_cookies << new_cookie
        end
      end
      return final_cookies.sort_by(&lambda{ |c| c[:name] })
    end

    def construct_request_cookies cookies
      if cookies.nil?
        return []
      else
        return cookies.map{ |cookie|
          {
            'name': cookie[0],
            'value': cookie[1]
          }
        }.sort_by(&lambda{ |c| c[:name] })
      end
    end

    def construct_header_records headers
      final_headers = []
      for k, v in headers
        if v.is_a? Array
          for value in v
            final_headers << {
              "name": k,
              "value": value
            }
          end
        else
          final_headers << {
            "name": k,
            "value": v
          }
        end
      end
      final_headers.sort_by(&lambda{ |h| h[:name] })
    end

    def construct_post_data request
      content_type = request.headers['content-type']
      if content_type.nil? || content_type.length == 0
        content_type = "application/octet-stream"
      end
      if request.body.empty?
        return nil
      elsif (request.headers.include?('content-length')) && (!request.headers['content-length'].nil?) && (request.headers['content-length'].to_i > @api_config.max_capture_size)
        return {
          "mimeType": content_type,
          "text": "--dropped--"
        }
      else
        return {
          "mimeType": content_type,
          "text": request.body
        }
      end
    end

    def construct_response_content status, body, headers
      content_type = headers['content-type']
      if content_type.nil? || content_type.length == 0
        content_type = "application/octet-stream"
      end
      if status == 304
        return {
          "mimeType": content_type,
          "size": -1
        }
      elsif (headers.include?('content-length')) && (!headers['content-length'].nil?) && (headers['content-length'].to_i > @api_config.max_capture_size)
        return {
          "mimeType": content_type,
          "text": "--dropped--",
          "size": -1
        }
      elsif ! headers.include?('content-length')
        return {
          "mimeType": content_type,
          "size": -1
        }
      else
        return {
          "mimeType": content_type,
          "text": body,
          "size": headers['content-length'].to_i
        }
      end
    end

    def calculate_header_size headers
      raw_headers = ''
      for k, v in headers
        if v.is_a? Array
          for value in v
            raw_headers += "#{k}: #{value}\r\n"
          end
        else
          raw_headers += "#{k}: #{v}\r\n"
        end
      end
      raw_headers.bytesize
    end

    def construct_request request
      req = {
        "method": request.method,
        "url": request.url,
        "httpVersion": request.transaction.protocol,
        "cookies": self.construct_request_cookies(request.cookies),
        "headers": self.construct_header_records(request.headers),
        "queryString": self.construct_query_records(request.query_params),
        "headersSize": self.calculate_header_size(request.headers),
        "bodySize": request.content_length.to_i,
      }
      if ! self.construct_post_data(request).nil?
        req["postData"] = self.construct_post_data(request)
      end
      req
    end

    def construct_response response
      res = {
        "status": response.status,
        "statusText":  Rack::Utils::HTTP_STATUS_CODES[response.status],
        "httpVersion":  response.transaction.protocol,
        "cookies":  self.construct_response_cookies(response.cookies),
        "headers":  self.construct_header_records(response.headers),
        "content":  self.construct_response_content(response.status, response.body, response.headers),
        "redirectURL":  response.headers.fetch('location', ''),
        "headersSize": self.calculate_header_size(response.headers)
      }

      if response.status == 304
        res["bodySize"] = 0
      elsif !response.headers.include?('content-length')
        res["bodySize"] = -1
      else
        res["bodySize"] = response.body.bytesize
      end
      res
    end

    def construct_timings
      return {
        "send": -1,
        "wait": -1,
        "receive": -1,
      }
    end
    
    def construct_entries http_transaction
      entry = {
        "startedDateTime": http_transaction.time_utils.start_time.strftime("%Y-%m-%dT%H:%M:%S.%NZ"),
        "time": http_transaction.time_utils.elapsed_time,
        "request": self.construct_request(http_transaction.request),
        "response": self.construct_response(http_transaction.response),
        "serverIPAddress": http_transaction.request.url.hostname,
        "cache": self.construct_empty_cache,
        "timings": self.construct_timings
      }
      if !http_transaction.port.nil? && http_transaction.port != "80"
        entry["connection"] = http_transaction.port
      end
      return [entry]
    end

    def construct_har http_transaction
      creator = construct_creator SpeakeasyRubySdk.to_s, SpeakeasyRubySdk::VERSION
      version = "1.2"
      comment = "request capture for #{http_transaction.request.url.to_s}"

      entries = construct_entries http_transaction

      log = construct_log version, creator, entries, comment
      log.to_json
    end
  end
end
