module Gini
  module Api

    # Base api exception class
    #
    # @!attribute [r] api_response
    #   @return [Faraday::Response] Faraday response object
    # @!attribute [r] api_method
    #   @return [String] HTTP method (:get, :post, :put, :delete)
    # @!attribute [r] api_url
    #   @return [String] Request URL
    # @!attribute [r] api_status
    #   @return [Integer] HTTP status code
    # @!attribute [r] api_message
    #   @return [String] Message from API error object
    #   @see http://developer.gini.net/gini-api/html/overview.html#client-errors
    # @!attribute [r] api_reqid
    #   @return [String] Request id from API error object
    #   @see http://developer.gini.net/gini-api/html/overview.html#client-errors
    # @!attribute [r] docid
    #   @return [String] Optional document-id that caused the exception
    #
    class Error < StandardError
      attr_reader   :api_response, :api_method, :api_url
      attr_reader   :api_status, :api_message, :api_request_id
      attr_reader   :user_identifier
      attr_accessor :docid

      # Parse response object and set instance vars accordingly
      #
      # @param [String] msg Exception message
      # @param [OAuth2::Response] api_response Faraday/Oauth2 response object from API
      #
      def initialize(msg, api_response = nil)
        super(msg)

        # Automatically use included response object if possible
        @api_response = api_response.respond_to?(:response) ? api_response.response : api_response

        # Parse response and set instance vars
        parse_response unless @api_response.nil?
      end

      # Build api error message rom api response
      #
      def api_error
        return nil if @api_response.nil?

        m =  "#{@api_method.to_s.upcase} "
        m << "#{@api_url} : "
        m << "#{@api_status} - "
        m << "#{@api_message} (request Id: #{@api_request_id})"
        m
      end

      # Parse Faraday response and fill instance variables
      #
      def parse_response
        @api_method      = @api_response.env[:method]
        @api_url         = @api_response.env[:url].to_s
        @api_status      = @api_response.status
        @api_message     = 'undef'
        @api_request_id  = 'undef'

        if @api_response.env.key? :request_headers and @api_response.env[:request_headers].key? "X-User-Identifier"
          @user_identifier = @api_response.env[:request_headers]["X-User-Identifier"]
        end

        unless @api_response.body.empty?
          begin
            parsed = JSON.parse(@api_response.body, symbolize_names: true)
            @api_message    = parsed[:message]
            @api_request_id = parsed[:requestId]
          rescue JSON::ParserError
            # We fail silently as defaults have been set
          end
        end
      end
    end

    # OAuth related errors
    #
    OAuthError = Class.new(Error)

    # Document related errors
    #
    DocumentError = Class.new(Error)

    # Upload related errors
    #
    UploadError = Class.new(Error)

    # Processing related errors
    #
    ProcessingError = Class.new(Error)

    # Search related errors
    #
    SearchError = Class.new(Error)

    # Generic request errors
    #
    RequestError = Class.new(Error)
  end
end
