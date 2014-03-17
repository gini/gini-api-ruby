require 'oauth2'

module Gini
  module Api

    # OAuth2 related methods to access API resources
    #
    class OAuth

      attr_reader :token

      # Instantiate a new Gini::Api::OAuth object and acquire token(s)
      #
      # @param [Gini::Api::Client] api Instance of Gini::Api::Client that contains all required params
      # @param [Hash] opts Your authorization credentials
      # @option opts [String] auth_code OAuth authorization code. Will be exchanged for a token
      # @option opts [String] username API username
      # @option opts [String] password API password
      #
      def initialize(api, opts)
        # Initialize client. max_redirect is required as oauth2 will otherwise redirect to location from header (localhost)
        # https://github.com/intridea/oauth2/blob/master/lib/oauth2/client.rb#L100
        # Our code is encoded in the URL and has to be parsed from there.
        client = OAuth2::Client.new(
          api.client_id,
          api.client_secret,
          site: api.oauth_site,
          authorize_url: '/authorize',
          token_url: '/token',
          max_redirects: 0,
          raise_errors: true,
        )

        # Verify opts. Prefered authorization methis is auth_code. If no auth_code is present a login from username/password
        # is done.
        auth_code =
          if opts.key?(:auth_code) && !opts[:auth_code].empty?
            opts[:auth_code]
          else
            # Generate CSRF token to verify the response
            csrf_token = SecureRandom.hex
            location  = login_with_credentials(
                          api,
                          client,
                          csrf_token,
                          opts[:username],
                          opts[:password])
            extract_auth_code(location, csrf_token)
          end

        # Exchange code for a real token.
        # @token is a Oauth2::AccessToken object. Accesstoken is @token.token
        @token = exchange_code_for_token(api, client, auth_code)

        # Override OAuth2::AccessToken#refresh! to update self instead of returnign a new object
        # Inspired by https://github.com/intridea/oauth2/issues/116#issuecomment-8097675
        #
        # @param [Hash] opts Refresh opts passed to original refresh! method
        #
        # @return [OAuth2::AccessToken] Updated access token object
        #
        def @token.refresh!(opts = {})
          new_token = super
          (new_token.instance_variables - %w[@refresh_token]).each do |name|
            instance_variable_set(name, new_token.instance_variable_get(name))
          end
          self
        end

        # Override OAuth2::AccessToken#request to refresh token when less then 60 seconds left
        #
        # @param [Symbol] verb the HTTP request method
        # @param [String] path the HTTP URL path of the request
        # @param [Hash] opts the options to make the request with
        #
        def @token.request(verb, path, opts = {}, &block)
          refresh! if refresh_token && (expires_at < Time.now.to_i + 60)
          super
        end
      end

      # Destroy token
      #
      def destroy
        @token.refresh_token && @token.refresh!
        response = token.delete("/accessToken/#{@token.token}")
        unless response.status == 204
          raise Gini::Api::OAuthError.new(
            "Failed to destroy token /accessToken/#{@token.token} "\
            "(code=#{response.status})",
            response
          )
        end
      rescue OAuth2::Error => e
        raise Gini::Api::OAuthError.new(
          "Failed to destroy token (code=#{e.response.status})",
          e.response
        )
      end

      private

      # Extract auth_code from URI
      #
      # @param [String] location Location URI containing the auth_code
      # @param [String] csrf_token CSRF token to verify request
      #
      # @return [String] Collected authorization code
      #
      def extract_auth_code(location, csrf_token)
        query_params = parse_location(location)

        unless query_params['state'] == csrf_token
          raise Gini::Api::OAuthError.new(
            "CSRF token mismatch detected (should=#{csrf_token}, "\
            "is=#{query_params['state']})"
          )
        end

        unless query_params.key?('code') && !query_params['code'].empty?
          raise Gini::Api::OAuthError.new(
            "Failed to extract code from location #{location}"
          )
        end

        query_params['code']
      end

      # Parse auth_code and state from URI
      #
      # @param [String] location Location URI with auth_code and state
      #
      # @return [Hash] Hash with auth_code and state
      #
      def parse_location(location)
        # Parse the location header from the response and return hash
        # {'code' => '123abc', 'state' => 'supersecret'}
        q = URI.parse(location).query
        Hash[*q.split(/\=|\&/)]
      rescue => e
        raise Gini::Api::OAuthError.new("Failed to parse location header: #{e.message}")
      end

      # Login with username/password
      #
      # @param [Gini::Api::Client] api API object
      # @param [OAuth2::Client] client OAuth2 client object
      # @param [String] csrf_token CSRF token to verify request
      # @param [String] username API username
      # @param [String] password API password
      #
      # @return [String] Location header
      #
      def login_with_credentials(api, client, csrf_token, username, password)
        # Build authentication URI
        auth_uri = client.auth_code.authorize_url(
          redirect_uri: api.oauth_redirect,
          state: csrf_token
        )

        # Accquire auth code
        response = client.request(
          :post,
          auth_uri,
          body: { username: username, password: password }
        )
        unless response.status == 303
          raise Gini::Api::OAuthError.new(
            "API login failed (code=#{response.status})",
            response
          )
        end
        response.headers['location']
      rescue OAuth2::Error => e
        raise Gini::Api::OAuthError.new(
          "Failed to acquire auth_code (code=#{e.response.status})",
          e.response
        )
      end

      # Exchange auth_code for a real token
      #
      # @param [Gini::Api::Client] api API object
      # @param [OAuth2::Client] client OAuth2 client object
      # @param [String] auth_code authorization code
      #
      # @return [OAuth2::AccessToken] AccessToken object
      #
      def exchange_code_for_token(api, client, auth_code)
        client.auth_code.get_token(auth_code, redirect_uri: api.oauth_redirect)
      rescue OAuth2::Error => e
        raise Gini::Api::OAuthError.new(
          "Failed to exchange auth_code for token (code=#{e.response.status})",
          e.response
        )
      end
    end
  end
end
