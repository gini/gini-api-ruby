module Gini
  module Api

    # Set of documents resulting from search or list query
    #
    class DocumentSet

      attr_reader :total, :offset, :documents

      # Instantiate a new Gini::Api::Document object from URL
      #
      # @param [Gini::Api::Client]    api        Gini::Api::Client object
      # @param [Hash]                 data       Container for documents
      # @option data [Integer]        :totalCount Total number of documents
      # @option data [Integer,String] :next       Start document from list (string) or offset from search (integer)
      # @option data [Aarray]         :documents  List of documents including all data
      #
      def initialize(api, data)
        @total     = data[:totalCount]
        @offset    = data[:next]
        @documents = data[:documents].map do |doc|
          Gini::Api::Document.new(api, doc[:_links][:document], doc)
        end
      end
    end
  end
end
