require "httparty"
require "active_support"
require "active_support/core_ext/object/blank"
require "active_support/core_ext/object/to_query"
require "active_support/core_ext/hash/keys"
require "active_support/core_ext/hash/indifferent_access"
require "ostruct"

require "lms/canvas_urls"

module LMS

  CANVAS_HELPER_URLs = {
    "HELPER_ALL_ACCOUNTS" => :all_accounts
  }

  class Canvas

    # a model that encapsulates authentication state. By default, it
    # is nil, but it may be set to any object that responds to:
    #   - #transaction { .. }
    #   - #lock(true) -> returns self
    #   - #find(id) -> returns an authentication object (see
    #     the `authentication` parameter of #initialize, below).
    class <<self
      attr_accessor :auth_state_model
    end

    # instance accessor, for convenience
    def auth_state_model
      self.class.auth_state_model
    end

    # callback must accept a single parameter (the API object itself)
    # and return the new authentication object.
    def self.on_auth(callback = nil, &block)
      @@on_auth = callback || block
    end

    # set up a default auth callback. It assumes that #auth_state_model
    # is set. If #auth_state_model will not be set, the client app must
    # define a custom on_auth callback.
    on_auth do |api|
      api.lock do |record|
        if record.token == api.authentication.token
          record.update token: api.refresh_token
        end
      end
    end

    attr_reader :authentication

    # The authentication parameter must be either a string (indicating
    # a token), or an object that responds to:
    #   - #id
    #   - #token
    #   - #update(hash) -- which should update #token with hash[:token]:noh
    def initialize(lms_uri, authentication, refresh_token_options = nil)
      @per_page = 100
      @lms_uri = lms_uri
      @refresh_token_options = refresh_token_options
      @authentication = if authentication.is_a?(String)
                          OpenStruct.new(token: authentication)
                        else
                          authentication
                        end

      if refresh_token_options.present?
        required_options = [:client_id, :client_secret, :redirect_uri, :refresh_token]
        extra_options = @refresh_token_options.keys - required_options
        unless extra_options.empty?
          raise InvalidRefreshOptionsException,
                "Invalid option(s) provided: #{extra_options.join(', ')}"
        end
        missing_options = required_options - @refresh_token_options.keys
        unless missing_options.empty?
          raise InvalidRefreshOptionsException,
                "Missing required option(s): #{missing_options.join(', ')}"
        end
      end
    end

    # Obtains a lock (via the API.auth_state_model interface) and
    # yields an authentication object corresponding to
    # self.authentication.id. The object is returned when the block
    # finishes.
    def lock
      auth_state_model.transaction do
        record = auth_state_model.
          lock(true).
          find(authentication.id)

        yield record

        record
      end
    end

    def headers(additional_headers = {})
      {
        "Authorization" => "Bearer #{@authentication.token}",
        "User-Agent" => "LMS-API Ruby"
      }.merge(additional_headers)
    end

    def full_url(api_url, use_api_prefix = true)
      if api_url[0...4] == "http"
        api_url
      elsif use_api_prefix
        "#{@lms_uri}/api/v1/#{api_url}"
      else
        "#{@lms_uri}/#{api_url}"
      end
    end

    def api_put_request(api_url, payload, additional_headers = {})
      url = full_url(api_url)
      refreshably do
        HTTParty.put(url, headers: headers(additional_headers), body: payload)
      end
    end

    def api_post_request(api_url, payload, additional_headers = {})
      url = full_url(api_url)
      refreshably do
        HTTParty.post(url, headers: headers(additional_headers), body: payload)
      end
    end

    def api_get_request(api_url, additional_headers = {})
      url = full_url(api_url)
      refreshably do
        HTTParty.get(url, headers: headers(additional_headers))
      end
    end

    def api_delete_request(api_url, additional_headers = {})
      url = full_url(api_url)
      refreshably do
        HTTParty.delete(url, headers: headers(additional_headers))
      end
    end

    def api_get_all_request(api_url, additional_headers = {})
      [].tap do |results|
        api_get_blocks_request(api_url, additional_headers) do |result|
          results.concat(result)
        end
      end
    end

    def api_get_blocks_request(api_url, additional_headers = {})
      connector = api_url.include?("?") ? "&" : "?"
      next_url = "#{api_url}#{connector}per_page=#{@per_page}"
      while next_url
        result = api_get_request(next_url, additional_headers)
        yield result
        next_url = get_next_url(result.headers["link"])
      end
    end

    def refreshably
      result = yield
      check_result(result)
    rescue LMS::Canvas::RefreshTokenRequired => ex
      raise ex if @refresh_token_options.blank?
      @authentication = @@on_auth.call(self)
      retry
    end

    def refresh_token
      payload = {
        grant_type: "refresh_token"
      }.merge(@refresh_token_options)
      url = full_url("login/oauth2/token", false)
      result = HTTParty.post(url, headers: headers, body: payload)
      unless [200, 201].include?(result.response.code.to_i)
        raise LMS::Canvas::RefreshTokenFailedException, api_error(result)
      end
      result["access_token"]
    end

    def check_result(result)
      code = result.response.code.to_i

      return result if [200, 201].include?(code)

      if code == 401 && result.headers["www-authenticate"] == 'Bearer realm="canvas-lms"'
        raise LMS::Canvas::RefreshTokenRequired
      end

      raise LMS::Canvas::InvalidAPIRequestException, api_error(result)
    end

    def api_error(result)
      error = "Status: #{result.headers['status']} \n"
      error << "Http Response: #{result.response.code} \n"
      error << "Error: #{result['errors'] || result.response.message} \n"
    end

    def get_next_url(link)
      return nil if link.blank?
      if url = link.split(",").detect { |l| l.split(";")[1].strip == 'rel="next"' }
        url.split(";")[0].gsub(/[\<\>\s]/, "")
      end
    end

    def proxy(type, params, payload = nil, get_all = false)

      # Helper methods call several Canvas methods to return a block of data to the client
      if helper = CANVAS_HELPER_URLs[type]
        result = self.send(helper)
        return OpenStruct.new(
          code: 200,
          headers: {},
          body: result.to_json
        )
      end

      additional_headers = {
        "Content-Type" => "application/json"
      }
      payload = {} if payload.blank?
      payload_json = payload.is_a?(String) ? payload : payload.to_json
      parsed_payload = payload.is_a?(String) ? JSON.parse(payload) : payload
      parsed_payload = parsed_payload.with_indifferent_access

      method = LMS::CANVAS_URLs[type][:method]
      url = LMS::Canvas.lms_url(type, params, parsed_payload)

      case method
      when "GET"
        if block_given?
          api_get_blocks_request(url, additional_headers) do |result|
            yield result
          end
        elsif get_all
          api_get_all_request(url, additional_headers)
        else
          api_get_request(url, additional_headers)
        end
      when "POST"
        api_post_request(url, payload_json, additional_headers)
      when "PUT"
        api_put_request(url, payload_json, additional_headers)
      when "DELETE"
        api_delete_request(url, additional_headers)
      else
        raise LMS::Canvas::InvalidAPIMethodRequestException "Invalid method type: #{method}"
      end

    rescue LMS::Canvas::InvalidAPIRequestException => ex
      error = ex.to_s
      error << "API Request Url: #{url} \n"
      error << "API Request Params: #{params} \n"
      error << "API Request Payload: #{payload} \n"
      new_ex = LMS::Canvas::InvalidAPIRequestFailedException.new(error)
      new_ex.set_backtrace(ex.backtrace)
      raise new_ex
    end

    # Ignore required params for specific calls. For example, the external tool calls
    # have required params "name, privacy_level, consumer_key, shared_secret". However, those
    # params are not required if the call specifies config_type: "by_xml".
    def self.ignore_required(type)
      [
        "CREATE_EXTERNAL_TOOL_COURSES",
        "CREATE_EXTERNAL_TOOL_ACCOUNTS"
      ].include?(type)
    end

    def self.lms_url(type, params, payload = nil)
      endpoint = LMS::CANVAS_URLs[type]
      parameters = endpoint[:parameters]

      # Make sure all required parameters are present
      missing = []
      if !ignore_required(type)
        parameters.select { |p| p["required"] }.map { |p| p["name"] }.each do |p|
          if p.include?("[") && p.include?("]")
            parts = p.split("[")
            parent = parts[0].to_sym
            child = parts[1].gsub("]", "").to_sym
            missing << p unless (params[parent].present? && params[parent][child].present?) ||
                (payload.present? && payload[parent].present? && payload[parent][child].present?)
          else
            missing << p unless params[p.to_sym].present? ||
                (payload.present? && !payload.is_a?(String) && payload[p.to_sym].present?)
          end
        end
      end

      if !missing.empty?
        raise LMS::Canvas::MissingRequiredParameterException,
              "Missing required parameter(s): #{missing.join(', ')}"
      end

      # Generate the uri. Only allow path parameters
      uri_proc = endpoint[:uri]
      path_parameters = parameters.select { |p| p["paramType"] == "path" }.
        map { |p| p["name"].to_sym }
      args = params.slice(*path_parameters).symbolize_keys
      uri = args.blank? ? uri_proc.call : uri_proc.call(**args)

      # Generate the query string
      query_parameters = parameters.select { |p| p["paramType"] == "query" }.
        map { |p| p["name"].to_sym }

      # always allow paging parameters
      query_parameters << :per_page
      query_parameters << :page

      allowed_params = params.slice(*query_parameters)

      if allowed_params.present?
        "#{uri}?#{allowed_params.to_query}"
      else
        uri
      end
    end

    #
    # Helper methods
    #

    # Get all accounts including sub accounts
    def all_accounts
      all = []
      proxy("LIST_ACCOUNTS", {}, nil, true).each do |account|
        all << account
        sub_accounts = proxy("GET_SUB_ACCOUNTS_OF_ACCOUNT",
                             {
                                account_id: account["id"],
                                recursive: true,
                             },
                             nil,
                             true)
        all = all.concat(sub_accounts)
      end
      all
    end

    #
    # Exceptions
    #

    class CanvasException < RuntimeError
    end

    class RefreshTokenRequired < CanvasException
    end

    class InvalidRefreshOptionsException < CanvasException
    end

    class RefreshTokenFailedException < CanvasException
    end

    class InvalidAPIRequestException < CanvasException
    end

    class InvalidAPIRequestFailedException < CanvasException
    end

    class InvalidAPIMethodRequestException < CanvasException
    end

    class MissingRequiredParameterException < CanvasException
    end

  end
end
