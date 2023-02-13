module SpeakeasyRubySdk

  class MaskConfig
    attr_reader :type, :attributes, :masks, :controller
    def initialize type, attributes, masks=nil, controller=nil
      @type = type
      @contoller = controller
      @attributes = attributes
      @masks = masks
    end

    def get_mask_for_attribute attribute
      if @masks.nil? || @masks.empty?
        SpeakeasyRubySdk::Masker::SIMPLE_MASK
      elsif @masks.length == 1
        @masks[0]
      else
        i = @attributes.find_index{|att| att == attribute}
        if i > @masks.length
          SpeakeasyRubySdk::Masker::SIMPLE_MASK
        else
          @masks[i]
        end
      end
    end
  end

  class Masker

    SIMPLE_MASK = '__masked__'
    SIMPLE_NUMBER_MASK = -12321

    def initialize config
      @masks = {
        :query_params => [],
        :request_headers => [],
        :response_headers => [],
        :request_cookies => [],
        :response_cookies => [],
        :request_body_string => [],
        :request_body_number => [],
        :response_body_string => [],
        :response_body_number => []
      }
      # todo remove this dependency for other mask control
      @routes = config.routes

      if config.masking
        config.masking.map {|mask| @masks[mask.type] << mask}
      end
    end

    def mask_value mask, attribute, path
      if !mask.controller.nil?
        route = @routes.recognize_path path
        if mask.controller === route[:prefix]
          return mask.get_mask_for_attribute attribute
        else
          return value;
        end
      else
        return mask.get_mask_for_attribute attribute
      end      
    end

    def mask_pair masking_key, path, attribute, value
      masked_value = value
      if @masks.include? masking_key
        masks = @masks[masking_key]
        for mask in masks
          if mask.attributes.include? attribute.to_s.downcase
            masked_value = mask_value mask, attribute, path
          end
        end
      end
      return masked_value
    end
    
    def mask_dict masking_key, path, hash_map
      masked_dict = {}
      for key, value in hash_map
        masked_dict[key] = mask_pair masking_key, path, key, value
        if value.is_a? Array
          masked_dict[key] = value.map { |v| mask_pair masking_key, path, key, v }
        end
      end
      masked_dict
    end

    def mask_query_params path, query_params
      mask_dict :query_params, path, query_params
    end

    def mask_request_headers path, headers
      mask_dict :request_headers, path, headers
    end

    def mask_response_headers path, headers
      mask_dict :response_headers, path, headers
    end

    def mask_request_cookies path, cookies
      mask_dict :request_cookies, path, cookies
    end

    def mask_response_cookies path, cookies
      for cookie in cookies
        key = cookie.name
        value = cookie.value
        masked_value = self.mask_pair :response_cookies, path, key, value
        cookie.value = masked_value
      end
      cookies
    end

    def mask_body_string masking_key_prefix, path, body
      masking_key = "#{masking_key_prefix}_string".to_sym

      masked_body = body
      if @masks.include? masking_key
        for mask in @masks[masking_key]
          for attribute in mask.attributes

            regex_string = Regexp.new "(\"#{attribute}\": *)(\".*?[^\\\\]\")( *[, \\n\\r}]?)"
            
            matches = body.match(regex_string)
            if matches
              masked_body = masked_body.gsub(regex_string, "#{matches[1]}\"#{mask.get_mask_for_attribute(attribute)}\"#{matches[3]}")
            end
          end
        end
      end
      masked_body
    end
    def mask_body_number masking_key_prefix, path, body
      masking_key = "#{masking_key_prefix}_number".to_sym

      masked_body = body
      if @masks.include? masking_key
        for mask in @masks[masking_key]
          for attribute in mask.attributes
            regex_string = Regexp.new "(\"#{attribute}\": *)(-?[0-9]+\\.?[0-9]*)( *[, \\n\\r}]?)"
            matches = body.match(regex_string)
            if matches
              masked_body = masked_body.gsub(regex_string, "#{matches[1]}#{mask.get_mask_for_attribute(attribute)}#{matches[3]}")
            end
          end
        end
      end
      masked_body
    end

    def mask_request_body path, body
      masked_body = mask_body_string 'request_body', path, body
      mask_body_number 'request_body', path, masked_body
    end

    def mask_response_body path, body
      masked_body = mask_body_string 'response_body', path, body
      mask_body_number 'response_body', path, masked_body

    end


  end
end


