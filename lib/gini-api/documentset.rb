module Gini
  module Api

    # Set of documents resulting from search or list query
    #
    class DocumentSet

      attr_reader :total, :offset, :documents

      # Enumerable mixin
      include Enumerable

      # Instantiate a new Gini::Api::Document object from URL
      #
      # @param [Gini::Api::Client]    api        Gini::Api::Client object
      # @param [Hash]                 data       Container for documents
      # @option data [Integer]        :totalCount Total number of documents
      # @option data [Aarray]         :documents  List of documents including all data
      #
      def initialize(api, data)
        @total     = data[:totalCount]
        @documents = data[:documents].map do |doc|
          Gini::Api::Document.new(api, doc[:_links][:document], doc)
        end
      end

      # Allow iteration on documents by yielding documents
      # Required by Enumerable mixin
      #
      def each
        @documents.each { |d| yield(d) }
      end
    end
  end
end
