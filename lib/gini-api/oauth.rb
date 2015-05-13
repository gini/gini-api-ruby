require 'oauth2'
require 'base64'

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
          token_url: '/oauth/token',
          max_redirects: 0,
          raise_errors: true,
          connection_opts: { headers: { user_agent: api.user_agent } }
        )

        # Verify opts. Prefered authorization methis is auth_code. If no auth_code is present a login from
        # "Resource Owner Password Credentials Grant" flow.
        # @token is a Oauth2::AccessToken object. Accesstoken is @token.token
        @token =
          if opts.key?(:auth_code) && !opts[:auth_code].empty?
            # Exchange code for a token
            exchange_code_for_token(api, client, opts[:auth_code])
          elsif (opts.key?(:username) && !opts[:username].empty?) && (opts.key?(:password) && !opts[:password].empty?)
            # Login with username and password
            login_with_resource_owner_password_credentials(
              client,
              opts[:username],
              opts[:password],
            )
          else
            # Gini backend gateway auth (basic auth)
            # Details: http://developer.gini.net/gini-api/html/guides/anonymous-users.html#guide-anonymous-accounts-trusted
            client.connection()
            OAuth2::AccessToken.new(
              client,
              nil,
              mode: :header,
              header_format: "Basic #{Base64.encode64(api.client_id + ':' + api.client_secret).gsub("\n", '')}"
            )
          end

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
        return "Not implemented yet. Come back later!"

      #   @token.refresh_token && @token.refresh!
      #   response = token.delete("/accessToken/#{@token.token}")
      #   unless response.status == 204
      #     fail_with_oauth_error(
      #       "Failed to destroy token /accessToken/#{@token.token} "\
      #       "(code=#{response.status})",
      #       response
      #     )
      #   end
      # rescue OAuth2::Error => e
      #   fail_with_oauth_error(
      #     "Failed to destroy token (code=#{e.response.status})",
      #     e.response
      #   )
      end

      private

      # Helper method to fail with Gini::Api::OAuthError
      #
      # @param [String] msg Exception message
      # @param [OAuth2::Response] response Response object
      #
      def fail_with_oauth_error(msg, response = nil)
        raise Gini::Api::OAuthError.new(
          msg,
          response
        )
      end

      # Login with resource owner password credentials
      #
      # @param [OAuth2::Client] client OAuth2 client object
      # @param [String] username API username
      # @param [String] password API password
      #
      # @return [OAuth2::AccessToken] AccessToken object
      #
      def login_with_resource_owner_password_credentials(client, username, password)
        client.password.get_token(username, password)
      rescue OAuth2::Error => e
        fail_with_oauth_error(
          "Failed to acquire token with resource owner credentials (code=#{e.response.body})",
          e.response
        )
      end

      # Exchange auth_code for a access token
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
        fail_with_oauth_error(
          "Failed to exchange auth_code for token (code=#{e.response.status})",
          e.response
        )
      end
    end
  end
end
