module Gini
  module Api

    # Contains document related extractions
    #
    class Document::Extractions

      attr_reader :raw

      # Instantiate a new Gini::Api::Extractions object from hash
      #
      # @param [Gini::Api::Client] api Gini::Api::Client object
      # @param [String] location Document URL
      # @param [Boolean] incubator Return experimental extractions
      #
      def initialize(api, location, incubator = false, options = {})
        @api       = api
        @location  = location
        @api.log.error("init OPTS: #{options.inspect}")
        @req_opts  = options

        if incubator
          @req_opts = { headers: @api.version_header(:json, :incubator) }.deep_merge(options)
        end

        api.log.error("EXT_OPTIONS: #{options.inspect}")
        api.log.error("EXT_REQ_OPTS: #{req_opts.inspect}")

        update(@req_opts)
      end

      # Populate instance variables from fetched extractions
      #
      def update(options = @req_opts)
        response = @api.request(:get, @location, options)

        unless response.status == 200
          raise Gini::Api::DocumentError.new(
            "Failed to fetch extractions from #{@location}",
            response
          )
        end

        # Entire response
        @raw = response.parsed

        # raise exception if parsing failed
        if response.parsed.nil?
          raise Gini::Api::DocumentError.new(
            "Failed to parse extractions from #{@location}",
            response
          )
        end

        response.parsed[:extractions].each do |k,v|
          instance_variable_set("@#{k}", v)
        end

        instance_variable_set("@candidates", response.parsed[:candidates])
      end

      # Get filed value for given extraction key
      #
      # @param [String] item The extractions item to get the value of
      # @return [String, Integer] Returns the value from extractions hash
      #
      def [](item)
        unless instance_variable_get("@#{item}")
          raise Gini::Api::DocumentError.new("Invalid extraction key '#{item}': Not found")
        end

        # method_missing requires some additional checks
        label = instance_variable_get("@#{item}")

        unless label.is_a? Hash and label.has_key? :value
          raise Gini::Api::DocumentError.new("Extraction key '#{item}' has no :value defined")
        end

        instance_variable_get("@#{item}")[:value]
      end

      # Submit feedback on extraction label
      #
      # @param [String] label Extraction label to submit feedback on
      # @param [Hash] feedback Hash containing at least key :value (:box is optional)
      #
      def submit_feedback(label, feedback)
        response = @api.request(
          :put,
          "#{@location}/#{label}",
          { headers: { 'content-type' => @api.version_header[:accept] },
            body: feedback.to_json,
          }.deep_merge(@options)
        )
      rescue Gini::Api::RequestError => e
        if e.api_status == 422
          raise Gini::Api::DocumentError.new(
            "Failed to submit feedback for label '#{label}' (code=#{e.api_status}, msg=#{e.api_response.body})",
            response
          )
        end
        raise
      end

      # Create setter and getter dynamically with method_missing
      #
      # @param [Symbol] m method name
      # @param [Array] args method arguments
      # @param [Block] block Block passed to the missing method
      # @return [Hash, Nil] Return extraction hash or nil
      #
      def method_missing(m, *args, &block)
        m_name = m.to_s
        label = m_name.split('=')[0]

        if m_name.end_with? '='
          # setter method. Set instance variable and submit feedback
          if args[0].is_a? Hash
            feedback = args[0]
          else
            feedback = { value: args[0] }
          end
          instance_variable_set("@#{label}", feedback)
          submit_feedback(label, feedback)
        else
          # getter. return instance variable or nil
          instance_variable_get("@#{label}")
        end
      end
    end
  end
end
