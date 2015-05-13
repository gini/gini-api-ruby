require 'uri'
require 'json'
require 'logger'
require 'faraday'
require 'benchmark'
require 'deep_merge'

module Gini
  module Api

    # Main class to operate on the Gini API
    #
    class Client

      attr_reader :token, :log

      # Instantiate a new Gini::Api::Client object with OAuth capabilities
      #
      # @param [Hash] options Hash of available config settings
      # @option options [String]  :client_id OAuth client_id
      # @option options [String]  :client_secret OAuth client_secret
      # @option options [String]  :oauth_site OAuth site to connect to (https://user.gini.net)
      # @option options [String]  :oauth_redirect Redirect URI
      # @option options [Integer] :upload_timeout Upload timeout in seconds
      # @option options [Integer] :processing_timeout API operational timeout in seconds
      # @option options [String]  :api_uri API URI (https://api.gini.net)
      # @option options [String]  :api_version API version to use (v1)
      # @option options [Logger]  :log logger object to use (initialized with STDOUT otherwise)
      # @option options [String]  :user_agent HTTP User-Agent (gini-api-ruby/VERSION (Faraday vFaraday::VERSION))
      #
      # @example
      #   api = Gini::Api::Client.new(
      #     client_id: 'my_client_id',
      #     client_secret: 'my_client_secret',
      #   )
      #
      def initialize(options = {})
        opts = {
          oauth_site: 'https://user.gini.net/',
          oauth_redirect: 'http://localhost',
          api_uri: 'https://api.gini.net',
          api_version: 'v1',
          api_type: 'json',
          upload_timeout: 90,
          processing_timeout: 180,
          log: Logger.new(STDOUT),
          user_agent: "gini-api-ruby/#{VERSION} (Faraday v#{Faraday::VERSION})"
        }.merge(options)

        # Ensure mandatory keys are set
        [:client_id, :client_secret].each do |k|
          raise Gini::Api::Error.new("Mandatory option key is missing: #{k}") unless opts.key?(k)
        end

        # Populate instance variables from merged opts
        opts.each do |k, v|
          instance_variable_set("@#{k}", v)
          self.class.send(:attr_reader, k)
        end

        # Ensure STDOUT is flushed
        STDOUT.sync = true

        # Sanitize api_uri
        @api_uri.sub!(/(\/)+$/, '')

        # Register parser (json+xml) based on API version
        register_parser

        @log.info('Gini API client initialized')
        @log.info("Target: #{@api_uri}")
      end

      # Register OAuth2 response parser
      #
      def register_parser
        OAuth2::Response.register_parser(:gini_json, [version_header(:json)[:accept]]) do |body|
          MultiJson.load(body, symbolize_keys: true) rescue body
        end
        OAuth2::Response.register_parser(:gini_xml, [version_header(:xml)[:accept]]) do |body|
          MultiXml.parse(body) rescue body
        end
        OAuth2::Response.register_parser(:gini_incubator, [version_header(:json, :incubator)[:accept]]) do |body|
          MultiJson.load(body, symbolize_keys: true) rescue body
        end
      end

      # Acquire OAuth2 token and popolate @oauth (instance of Gini::Api::OAuth.new)
      # and @token (OAuth2::AccessToken).  Supports 2 strategies: username/password and authorization code
      #
      # @param [Hash] opts Your authorization credentials
      # @option opts [String] :auth_code OAuth authorization code. Will be exchanged for a token
      # @option opts [String] :username API username
      # @option opts [String] :password API password
      #
      # @example
      #   api.login(auth_code: '1234567890')
      # @example
      #   api.login(username: 'me@example.com', password: 'secret')
      #
      def login(opts = {})
        @oauth = Gini::Api::OAuth.new(self, opts)
        @token = @oauth.token
      end

      # Destroy OAuth2 token
      #
      def logout
        @oauth.destroy
      end

      # Version accept header based on @api_version
      #
      # @param [Symbol, String] type Expected response type (:xml, :json)
      # @param [Symbol, String] version API version (:v1, :incubator)
      #
      # @return [Hash] Return accept header or empty hash
      #
      def version_header(type = @api_type, version = @api_version)
        { accept: "application/vnd.gini.#{version}+#{type}" }
      end

      # X-USER-IDENTIFIER header
      #
      # @param [Symbol, String] user_id User identifier
      #
      # @return [Hash] Return X-USER-IDENTIFIER header or empty hash
      #
      def user_identifier_header(user_id)
        if user_id
          { "X-User-Identifier" => user_id }
        else
          {}
        end
      end

      # Request wrapper that sets URI and accept header
      #
      # @param [Symbol] verb     HTTP request verb (:get, :post, :put, :delete)
      # @param [String] resource API resource like /documents
      # @param [Hash]   options  Optional type and custom headers
      # @option options [String] :type Type to pass to version_header (:xml, :json)
      # @option options [Hash]   :headers Custom headers. Must include accept
      #
      def request(verb, resource, options = {})
        opts = { headers: version_header(options.delete(:type) || @api_type).deep_merge(
                   user_identifier_header(options[:user_identifier]))
               }.deep_merge!(options)

        timeout(@processing_timeout) do
          @token.send(verb.to_sym, resource_to_location(resource).to_s , opts)
        end
      rescue OAuth2::Error => e
        raise Gini::Api::RequestError.new(
          "API request failed: #{verb} #{resource} (code=#{e.response.status})",
          e.response
        )
      rescue Timeout::Error => e
        raise Gini::Api::ProcessingError.new(
          "API request timed out: #{verb} #{resource} (#{e.message})"
        )
      end

      # Upload a document
      #
      # @param [String] file path or open filehandle of the document to upload
      # @param [Hash] options Hash of available upload settings
      # @option options [String] :doctype_hint Document type hint to optimize results or get incubator results
      # @option options [String] :text Use given file-string as text upload
      # @option options [Float]  :interval Interval to poll progress
      #
      # @return [Gini::Api::Document] Return Gini::Api::Document object for uploaded document
      #
      # @example Upload and wait for completion
      #   doc = api.upload('/tmp/myfile.pdf')
      # @example Upload with doctype hint
      #   doc = api.upload('/tmp/myfile.pdf', doctype_hint: 'Receipt')
      # @example Upload and monitor progress
      #   doc = api.upload('/tmp/myfile.pdf') { |d| puts "Progress: #{d.progress}" }
      # @example Upload and monitor progress
      #   doc = api.upload('This is a text message i would love to get extractions from', text: true)
      #
      def upload(file, options = {}, &block)
        opts = {
          doctype_hint: nil,
          text: false,
          interval: 0.5,
          user_identifier: nil,
        }.merge(options)

        duration = Hash.new(0)

        # Document upload
        response = nil

        if opts[:text]
          file = StringIO.new(file.force_encoding('UTF-8'))
        end

        duration[:upload] = Benchmark.realtime do
          response = request(:post,
                             "#{@api_uri}/documents",
                             user_identifier: opts[:user_identifier],
                             body: { file: Faraday::UploadIO.new(file, 'application/octet-stream') }
                            )
        end

        # Start polling (0.5s) when document has been uploaded successfully
        if response.status == 201
          doc = Gini::Api::Document.new(self, response.headers['location'], nil, user_identifier: opts[:user_identifier])
          duration[:processing] = poll_document(doc, opts[:interval], &block)
          duration[:total] = duration.values.inject(:+)
          doc.duration = duration

          doc
        else
          fail Gini::Api::UploadError.new(
            "Document upload failed with HTTP code #{response.status}",
            response
          )
        end
      end

      # Delete document
      #
      # @param [String] id document ID
      #
      def delete(id, options = {})
        response = request(:delete, "/documents/#{id}", options)
        unless response.status == 204
          raise Gini::Api::DocumentError.new(
            "Deletion of docId #{id} failed (code=#{response.status})",
            response
          )
        end
        @log.info("Deleted document #{id}")
      end

      # Get document by Id
      #
      # @param [String] id document ID
      #
      # @return [Gini::Api::Document] Return Gini::Api::Document object
      #
      def get(id, options = {})
        @log.error("GET OPTIONS: #{options.inspect}")
        Gini::Api::Document.new(self, "/documents/#{id}", nil, options)
      end

      # List all documents
      #
      # @param [Hash] options List options (offset and limit)
      # @option options [Integer] :limit Maximum number of documents to return (defaults to 20)
      # @option options [Integer] :offset Start offset. Defaults to 0
      # @option options [String]  :user_identifier User to act for
      #
      # @return [Gini::Api::DocumentSet] Returns a DocumentSet with total, offset and a list of Document objects
      #
      def list(options = {})
        opts   = { limit: 20, offset: 0 }.merge(options)
        limit  = Integer(opts[:limit])
        offset = Integer(opts[:offset])

        response = request(:get, "/documents?limit=#{limit}&next=#{offset}", user_identifier: opts[:user_identifier])
        unless response.status == 200
          raise Gini::Api::DocumentError.new(
            "Failed to get list of documents (code=#{response.status})",
            response
          )
        end
        Gini::Api::DocumentSet.new(self, response.parsed)
      end

      # Fulltext search for documents
      #
      # @param [String, Array] query  The search term(s), separated by space. Multiple terms as array
      # @param [Hash] options Search options
      # @option options [String]  :type   Only include documents with the given doctype
      # @option options [Integer] :limit  Number of results per page. Must be between 1 and 250. Defaults to 20
      # @option options Integer]  :offset Start offset. Defaults to 0
      #
      # @return [Gini::Api::DocumentSet] Returns a DocumentSet with total, offset and a list of Document objects
      #
      def search(query, options = {})
        opts   = { type: '', limit: 20, offset: 0 }.merge(options)
        query  = URI.escape(query)
        type   = URI.escape(opts[:type])
        limit  = Integer(opts[:limit])
        offset = Integer(opts[:offset])

        response = request(:get, "/search?q=#{query}&type=#{type}&limit=#{limit}&next=#{offset}", user_identifier: opts[:user_identifier])
        unless response.status == 200
          raise Gini::Api::SearchError.new(
            "Search query failed with code #{response.status}",
            response
          )
        end
        Gini::Api::DocumentSet.new(self, response.parsed)
      end

      private

      # Helper to covert resource to a valid location.
      #
      # @param [String] resource URI to be converted
      #
      # @return [URI::HTTPS] URI::HTTPS object create from resource
      #
      def resource_to_location(resource)
        parsed_resource = URI.parse(resource)
        @api_host ||= URI.parse(@api_uri).host

        URI::HTTPS.build(
          host:  @api_host,
          path:  parsed_resource.path,
          query: parsed_resource.query
        )
      end

      # Poll document and duration
      #
      # @param [Gini::Api::Document] doc Document instance to poll
      # @param [Float] interval Polling interval for completion
      #
      # @return [Integer] Processing duration
      #
      def poll_document(doc, interval, &block)
        duration = 0
        timeout(@processing_timeout) do
          duration = Benchmark.realtime do
            doc.poll(interval, &block)
          end
        end
        duration
      rescue Timeout::Error => e
        ex = Gini::Api::ProcessingError.new(e.message)
        ex.docid = doc.id
        raise ex
      end

    end
  end
end
