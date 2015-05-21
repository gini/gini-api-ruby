module Gini
  module Api

    # Contains document related data from uploaded or fetched document
    #
    class Document

      attr_accessor :duration

      # Instantiate a new Gini::Api::Document object from URL
      #
      # @param [Gini::Api::Client] api       Gini::Api::Client object
      # @param [String]            location  Document URL
      # @param [Hash]              from_data Hash with doc data (from search for example)
      #
      def initialize(api, location, from_data = nil)
        @api      = api
        @location = location

        update(from_data)
      end

      # Fetch document resource and populate instance variables
      #
      # @param [Hash] from_data Ruby hash with doc data
      #
      def update(from_data = nil)
        data = {}

        if from_data.nil?
          response = @api.request(:get, @location)
          unless response.status == 200
            raise Gini::Api::DocumentError.new(
              "Failed to fetch document data (code=#{response.status})",
              response
            )
          end
          data = response.parsed
        else
          data = from_data
        end

        data.each do |k, v|
          instance_variable_set("@#{k}", v)

          # We skip pages as it's rewritted by method pages()
          next if k == :pages

          self.class.send(:attr_reader, k)
        end
      end

      # Poll document progress and return when state equals COMPLETED
      # Known states are PENDING, COMPLETED and ERROR
      #
      # @param [Float] interval API polling interval
      #
      def poll(interval, &block)
        until @progress =~ /(COMPLETED|ERROR)/ do
          update
          yield self if block_given?
          sleep(interval)
        end
        nil
      end

      # Indicate if the document has been processed
      #
      # @return [Boolean] true if progress == PENDING
      #
      def completed?
        @progress != 'PENDING'
      end

      # Was the document processed successfully?
      #
      # @return [Boolean] true/false based on @progress
      #
      def successful?
        @progress == 'COMPLETED'
      end

      # Get processed document
      #
      # @return [data] The binary representation of the processed document (pdf, jpg, png, ...)
      #
      def processed
        response = @api.request(
          :get,
          @_links[:processed],
          headers: { accept: 'application/octet-stream' }
        )
        unless response.status == 200
          raise Gini::Api::DocumentError.new(
            "Failed to fetch processed document (code=#{response.status})",
            response
          )
        end
        response.body
      end

      # Initialize extractions from @_links and return Gini::Api::Extractions object
      #
      # @param [Hash]    options  Options
      # @option options [Boolean] :refresh Invalidate extractions cache
      # @option options [Boolean] :incubator Return experimental extractions
      #
      # @return [Gini::Api::Document::Extractions] Return Gini::Api::Document::Extractions object for uploaded document
      #
      def extractions(options = {})
        opts = { refresh: false, incubator: false }.merge(options)
        if opts[:refresh] or @extractions.nil?
          @extractions = Gini::Api::Document::Extractions.new(@api, @_links[:extractions], opts[:incubator])
        else
          @extractions
        end
      end

      # Initialize layout from @_links[:layout] and return Gini::Api::Layout object
      #
      # @return [Gini::Api::Document::Layout] Return Gini::Api::Document::Layout object for uploaded document
      #
      def layout
        @layout ||= Gini::Api::Document::Layout.new(@api, @_links[:layout])
      end

      # Override @pages instance variable. Removes key :pageNumber, key :images and starts by index 0.
      # Page 1 becomes index 0
      #
      def pages
        @pages.map { |page| page[:images] }
      end

      # Submit feedback on extraction label
      #
      # @deprecated Use 'doc.extractions.LABEL = VALUE' instead. Will be removed in next version
      # @param [String] label Extraction label to submit feedback on
      # @param [String] value The new value for the given label
      #
      def submit_feedback(label, value)
        unless extractions.send(label.to_sym)
          raise Gini::Api::DocumentError.new("Unknown label #{label}: Not found")
        end
        response = @api.request(
          :put,
          "#{@_links[:extractions]}/#{label}",
          headers: { 'content-type' => @api.version_header[:accept] },
          body: { value: value }.to_json
        )
        unless response.status == 204
          raise Gini::Api::DocumentError.new(
            "Failed to submit feedback for label #{label} (code=#{response.status})",
            response
          )
        end
      end

      # Submit error report on document
      #
      # @param [String] summary Short summary on the error found
      # @param [String] description More detailed description of the error found
      #
      # @return [String] Error ID retured from API
      #
      def report_error(summary = nil, description = nil)
        response = @api.request(
          :post,
          "#{@_links[:document]}/errorreport",
          params: { summary: summary, description: description }
        )
        unless response.status == 200
          raise Gini::Api::DocumentError.new(
            "Failed to submit error report for document #{@id} (code=#{response.status})",
            response
          )
        end
        response.parsed[:errorId]
      end
    end
  end
end
