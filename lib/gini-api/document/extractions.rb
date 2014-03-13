module Gini
  module Api

    # Contains document related extractions
    #
    class Document::Extractions

      # Instantiate a new Gini::Api::Extractions object from hash
      #
      # @param [Gini::Api::Client] api Gini::Api::Client object
      # @param [String] location Document URL
      def initialize(api, location)
        @api      = api
        @location = location

        update
      end

      # Populate instance variables from fetched extractions
      #
      def update
        response = @api.request(:get, @location)

        unless response.status == 200
          raise Gini::Api::DocumentError.new(
            "Failed to fetch extractions from #{@location}",
            response
          )
        end

        response.parsed[:extractions].each do |k,v|
          instance_variable_set("@#{k}", v)
          self.class.send(:attr_reader, k)
        end

        instance_variable_set("@candidates", response.parsed[:candidates])
        self.class.send(:attr_reader, :candidates)
      end

      # Get filed value for given extraction key
      #
      # @param [String] item The extractions item to get the value of
      # @return [String, Integer] Returns the value from extractions hash
      #
      def [](item)
        unless instance_variable_get("@#{item}")
          raise Gini::Api::DocumentError.new("Invalid extraction key #{item}: Not found")
        end

        instance_variable_get("@#{item}")[:value]
      end
    end
  end
end
