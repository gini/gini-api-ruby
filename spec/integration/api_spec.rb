require 'spec_helper'

# Disable coverage for integration tests
ENV['COVERAGE'] = nil

# Cancel integration test when mandatory env vars are missing
['GINI_API_USER', 'GINI_API_PASS', 'GINI_CLIENT_SECRET'].each do |m|
  fail "Unset ENV variable #{m}. Tests aborted" unless ENV.has_key?(m)
end

# Let's make some REAL requests
WebMock.allow_net_connect!

describe 'Gini::Api integration test' do

  before :all do
    @user    = ENV['GINI_API_USER']
    @pass    = ENV['GINI_API_PASS']
    @testdoc = "#{File.dirname(__FILE__)}/files/test.pdf"
    @api     = Gini::Api::Client.new(
      client_id: ENV['GINI_CLIENT_ID'],
      client_secret: ENV['GINI_CLIENT_SECRET'],
      oauth_site: 'https://user.gini.net/',
      api_uri: 'https://api.gini.net',
      log: Logger.new('/dev/null')
    )
  end

  context 'OAuth' do

    before do
      @api.login(username: @user, password: @pass)
    end

    it '#login sets token' do
      expect(@api.token.token).to match(/\w+-\w+/)
      expect(@api.token.expired?).to be_falsey
      @api.logout
    end

    it '#logout destroys token' do
      expect(@api.token.get("/accessToken/#{@api.token.token}").status).to eql(200)
      @api.logout
      expect { @api.token.get("/accessToken/#{@api.token.token}") }.to raise_error(OAuth2::Error)
    end

  end

  context 'document' do

    before do
      @api.login(username: @user, password: @pass)
      @doc = @api.upload(@testdoc)
    end

    it '#upload returns Gini::Api::Doucment' do
      @api.logout
      expect(@doc.id).to match(/\w+-\w+/)
      @api.delete(@doc.id)
    end

    it '#get returns Gini::Api::Doucment' do
      doc_get = @api.get(@doc.id)
      expect(@doc.id).to eql(doc_get.id)
      @api.delete(@doc.id)
      @api.logout
    end

    it '#list returns Gini::Api::DocumentSet' do
      list = @api.list
      expect(list).to be_a(Gini::Api::DocumentSet)
      expect(list.total).to eql(1)
      expect(list.documents[0]).to be_a(Gini::Api::Document)
      @api.delete(@doc.id)
      @api.logout
    end

    it '#delete returns true' do
      expect(@api.delete(@doc.id)).to be_truthy
      expect { @api.get(@doc.id) }.to raise_error(Gini::Api::RequestError)
      @api.logout
    end

    context 'data' do

      after do
        @api.delete(@doc.id)
        @api.logout
      end

      context 'extractions' do

        subject(:extractions) { @doc.extractions }

        it '#extractions populates instance vars' do
          expect(extractions).to be_kind_of(Gini::Api::Document::Extractions)
          expect(extractions.candidates).to be_kind_of(Hash)
          expect(extractions).to respond_to(:amountToPay)
          expect(extractions[:amountToPay]).to eql('1039.87:EUR')
        end

        it '#[] returns data' do
          expect(extractions[:docType]).to eql('Invoice')
        end

      end

      context 'layout' do

        subject(:layout) { @doc.layout }

        it '#to_xml returns XML string' do
          expect(layout).to be_kind_of(Gini::Api::Document::Layout)
          expect(layout.to_xml).to match(/xml/)
        end

        it '#to_json returns JSON string' do
          expect(layout).to be_kind_of(Gini::Api::Document::Layout)
          expect(layout.to_json).to satisfy { |json| JSON.parse(json).is_a?(Hash) }
        end

      end

    end

  end

end
