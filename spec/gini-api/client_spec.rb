require 'spec_helper'

describe Gini::Api::Client do

  let(:user)      { 'user@gini.net' }
  let(:pass)      { 'secret' }
  let(:auth_code) { '1234567890' }
  let(:header)    { 'application/vnd.gini.v1+json' }
  let(:oauth) do
    double(
      'Gini::Api::OAuth',
      :token => 'TOKEN',
      :destroy => nil
    )
  end

  subject(:api) do
    Gini::Api::Client.new(
      client_id: 'gini-rspec',
      client_secret: 'secret',
      log: (Logger.new '/dev/null'),
    )
  end

  it { should respond_to(:register_parser) }
  it { should respond_to(:login) }
  it { should respond_to(:logout) }
  it { should respond_to(:version_header) }
  it { should respond_to(:user_identifier_header) }
  it { should respond_to(:request) }
  it { should respond_to(:upload) }
  it { should respond_to(:delete) }
  it { should respond_to(:get) }
  it { should respond_to(:list) }
  it { should respond_to(:search) }

  describe '#new' do

    it 'fails with missing options' do
      expect { Gini::Api::Client.new }.to \
        raise_error(Gini::Api::Error, /Mandatory option key is missing/)
    end

    it do
      expect(api.log.class).to eq(Logger)
    end

  end

  describe '#register_parser' do

    it do
      expect(OAuth2::Response::PARSERS.keys).to \
        include(:gini_json)
    end

    it do
      expect(OAuth2::Response::PARSERS.keys).to \
        include(:gini_xml)
    end

    it do
      expect(OAuth2::Response::PARSERS.keys).to \
        include(:gini_incubator)
    end

  end

  describe '#login' do

    context 'with auth_code' do

      it 'sets @token' do
        expect(Gini::Api::OAuth).to \
          receive(:new).with(
            api, auth_code: auth_code
          ) { oauth }
        expect(oauth).to receive(:token)

        api.login(auth_code: auth_code)
        expect(api.token).to eql('TOKEN')
      end

    end

    context 'with username/password' do

      it 'sets @token' do
        expect(Gini::Api::OAuth).to \
          receive(:new).with(
            api, username:
            user, password: pass
          ) { oauth }
        expect(oauth).to receive(:token)

        api.login(username: user, password: pass)
        expect(api.token).to eql('TOKEN')
      end

    end

    context 'with {} (basic auth)' do

      it 'sets @token' do
        expect(Gini::Api::OAuth).to \
          receive(:new).with(api, {}) { oauth }
        expect(oauth).to receive(:token)

        api.login()
        expect(api.token).to eql('TOKEN')
      end

    end

  end

  describe '#logout' do

    it 'destroys token' do
      expect(Gini::Api::OAuth).to \
        receive(:new).with(
          api,
          auth_code: auth_code
        ) { oauth }
      expect(oauth).to receive(:token)
      api.login(auth_code: auth_code)

      expect(oauth).to receive(:destroy)
      api.logout
    end

  end

  describe '#version_header' do

    let(:api) do
      Gini::Api::Client.new(
        client_id: 1,
        client_secret: 2,
        log: (Logger.new '/dev/null')
      )
    end

    context 'with json' do

      it 'returns accept header with json type' do
        expect(api.version_header(:json)).to \
          eql({ accept: header })
      end

    end

    context 'with xml' do

      it 'returns accept header with xml type' do
        expect(api.version_header(:xml)).to \
          eql({ accept: 'application/vnd.gini.v1+xml' })
      end

    end

    context 'with incubator' do

      it 'returns accept header with incubator version' do
        expect(api.version_header(:json, :incubator)).to \
          eql({ accept: 'application/vnd.gini.incubator+json' })
      end

    end

  end

  describe '#user_identifier_header' do

    context 'with user identifier' do

      it 'returns X-User-Identifier header' do
        expect(api.user_identifier_header('johnny')).to \
          eql({ "X-User-Identifier" => 'johnny' })
      end

    end

    context 'without user identifier' do

      it 'returns empty hash' do
        expect(api.user_identifier_header(nil)).to \
          eql({})
      end

    end

  end

  context 'being logged in' do

    before do
      expect(Gini::Api::OAuth).to \
        receive(:new).with(
          api,
          auth_code: auth_code
        ) { oauth }
      api.login(auth_code: auth_code)
    end

    describe '#request' do

      let(:response) do
        double('Response',
          status: 200,
          headers: {
            'content-type' => header
          },
          body: body
        )
      end

      it 'token receives call' do
        expect(api.token).to receive(:get)
        api.request(:get, '/dummy')
      end

      it 'raises RequestError from OAuth2::Error' do
        expect(api.token).to \
          receive(:get).and_raise(
            OAuth2::Error.new(double.as_null_object)
          )
        expect { api.request(:get, '/invalid') }.to \
          raise_error(Gini::Api::RequestError)
      end

      it 'raises ProcessingError on timeout' do
        expect(api.token).to \
          receive(:get).and_raise(Timeout::Error)
        expect { api.request(:get, '/timeout') }.to \
          raise_error(Gini::Api::ProcessingError)
      end

      context 'return JSON as default' do

        let(:body) do
          {
            a: 1,
            b: 2
          }.to_json
        end

        it do
          expect(api.token).to \
            receive(:get).and_return(OAuth2::Response.new(response))
          expect(api.request(:get, '/dummy').parsed).to be_a Hash
        end

      end

      context 'return XML on request' do

        let(:header) { 'application/vnd.gini.v1+xml' }
        let(:body)   { '<data><a>1</a><b>2</b></data>' }

        it do
          expect(api.token).to \
            receive(:get).and_return(
              OAuth2::Response.new(response)
            )

          expect(api.request(
            :get,
            '/dummy',
            type: 'xml'
          ).parsed).to be_a Hash
        end

      end

      context 'return JSON on incubator request' do

        let(:header) { 'application/vnd.gini.incubator+json' }
        let(:body)   {
          {
            a: 1,
            b: 2
          }.to_json
        }

        it do
          expect(api.token).to \
            receive(:get).and_return(OAuth2::Response.new(response))
          expect(api.request(:get, '/dummy').parsed).to be_a Hash
        end

      end

      context 'set custom accept header' do

        let(:header) { 'application/octet-stream' }
        let(:body)   { 'Just a string' }

        it do
          expect(api.token).to \
            receive(:get).with(
              %r{/dummy},
              headers: {
                accept: 'application/octet-stream'
                }
            ).and_return(OAuth2::Response.new(response))
          expect(api.request(
            :get,
            '/dummy',
            headers: {
              accept: 'application/octet-stream'
            }
          ).body).to be_a String
        end

      end

    end

    describe '#upload' do

      let(:doc) { double(Gini::Api::Document, poll: true, id: 'abc-123') }
      let(:response) do
        double('Response', {
          status: status,
          headers: { 'location' => 'LOC' },
          env: {},
          body: '{}'.to_json
        })
      end

      before do
        allow(doc).to receive(:duration=)
          allow(Gini::Api::Document).to \
            receive(:new).with(api, 'LOC', nil, {:user_identifier=>nil}
          ) { doc }
        allow(api.token).to receive(:token).and_return('abc-123')
        allow(api.token).to receive(:post).and_return(OAuth2::Response.new(response))
      end

      context 'when failed' do

        let(:status) { 500 }

        it do
          expect { api.upload('spec/integration/files/test.pdf') }.to \
            raise_error(Gini::Api::UploadError)
        end

      end

      context 'when successful' do

        let(:status) { 201 }

        it 'Gini::Api::Document is created' do
          api.upload('spec/integration/files/test.pdf')
        end
      end

      context 'on timeout' do

        let(:status) { 201 }

        it 'raises ProcessingError on timeout' do
          expect(doc).to receive(:poll).and_raise(Timeout::Error)
          expect { api.upload('spec/integration/files/test.pdf') }.to \
            raise_error(Gini::Api::ProcessingError)
        end

      end

    end

    describe '#delete' do

      let(:response) do
        double('Response',
          status: status,
          env: {},
          body: {}
        )
      end

      context 'with invalid docId' do

        let(:status) { 203 }

        it do
          allow(api.token).to receive(:delete).and_return(response)
          expect { api.delete('abc-123') }.to \
            raise_error(Gini::Api::DocumentError, /Deletion of docId abc-123 failed/)
        end

      end

      context 'with valid docId' do

        let(:status) { 204 }

        it do
          allow(api.token).to receive(:delete).and_return(response)
          expect(api.delete('abc-123').class).to be_truthy
        end

      end

    end

    describe '#get' do

      it do
        expect(Gini::Api::Document).to \
          receive(:new) { double('Gini::Api::Document') }
        api.get('abc-123')
      end

    end

    describe '#list' do

      let(:response) do
        double('Response',
          status: 200,
          headers: {
            'content-type' => header
          },
          body: {
            totalCount: doc_count,
            next: nil,
            documents: documents
          }.to_json)
      end

      before do
        allow(api.token).to receive(:get).and_return(OAuth2::Response.new(response))
      end

      context 'with documents' do

        let(:doc_count) { 1 }
        let(:documents) do
          [
            {
              id: 42,
              :_links => {
                :document => 'https://rspec/123-abc'
              }
            }
          ]
        end

        it do
          expect(api.list.total).to eql(1)
          expect(api.list.offset).to be_nil
          expect(api.list.documents[0]).to be_a(Gini::Api::Document)
          expect(api.list).to be_a(Gini::Api::DocumentSet)
        end

      end

      context 'without documents' do

        let(:doc_count) { 0 }
        let(:documents) { [] }

        it do
          expect(api.list.total).to eql(0)
          expect(api.list.offset).to be_nil
          expect(api.list.documents).to eql([])
          expect(api.list).to be_a(Gini::Api::DocumentSet)
        end

      end

      context 'with failed http request' do

        let(:response) do
          double('Response',
            status: 500,
            env: {},
            body: {}
          )
        end

        it do
          expect { api.list }.to \
            raise_error(Gini::Api::DocumentError, /Failed to get list of documents/)
        end

      end

    end

    describe '#search' do

      before do
        allow(api.token).to receive(:get).and_return(OAuth2::Response.new(response))
      end

      let(:status) { 200 }
      let(:response) do
        double('Response',
          status: status,
          headers: {
            'content-type' => header
          },
          body: {
            totalCount: doc_count,
            next: nil,
            documents: documents
          }.to_json
        )
      end

      context 'with found documents' do

        let(:doc_count) { 1 }
        let(:documents) do
          [
            {
              id: '0f122e10-8dba-11e3-8a85-02015140775',
              _links: {
                document: 'https://rspec/123-abc'
              }
            }
          ]
        end

        it do
          result = api.search('invoice')

          expect(result.total).to eql(1)
          expect(result.offset).to be_nil
          expect(result.documents[0]).to be_a(Gini::Api::Document)
          expect(result).to be_a(Gini::Api::DocumentSet)
        end

      end

      context 'with no found documents' do

        let(:doc_count) { 0 }
        let(:documents) { [] }

        it do
          result = api.search('invoice')

          expect(result.total).to eql(0)
          expect(result.offset).to be_nil
          expect(result.documents).to eql([])
          expect(result).to be_a(Gini::Api::DocumentSet)
        end

      end

      context 'with failed query' do

        let(:response) { double('Response', status: 500, env: {}, body: {}) }

        it do
          expect{api.search('invoice')}.to \
            raise_error(Gini::Api::SearchError, /Search query failed with code 500/)
        end

      end

    end

  end

end
