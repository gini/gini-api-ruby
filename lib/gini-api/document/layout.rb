module Gini
  module Api

    # Contains document layout in XML & JSON
    #
    class Document::Layout

      # Instantiate a new Gini::Api::Layout object from layout url
      #
      # @param [Gini::Api::Client] api Gini::Api::Client object
      # @param [String] location Document URL
      def initialize(api, location, options = {})
        @api      = api
        @location = location
        @options  = options
      end

      # Return layout as XML string
      #
      # @return [String] Returns the layout as XML string
      def to_xml
        @xml ||= get_xml
      end

      # Return layout as JSON string
      #
      # @return [String] Returns the layout as JSON string
      def to_json
        @json ||= get_json
      end

      private

      # Get value of layout in XML
      #
      # @return [String] Returns layout XML
      def get_xml
        response = @api.request(:get, @location, @options.merge(type: 'xml'))
        response.body if response.status == 200
      end

      # Get value of extraction. Convinience method
      #
      # @return [String] Returns layout JSON
      def get_json
        response = @api.request(:get, @location, @options)
        response.body if response.status == 200
      end
    end
  end
end
