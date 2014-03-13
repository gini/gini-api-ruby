require 'spec_helper'

describe Gini::Api::Error do

  let(:location) { 'https://api.rspec/v0/documents/aaa-bbb-ccc' }
  let(:api) do
    double('API',
      token: double('Token')
    )
  end
  let(:response) do
    double('Response',
      status: 200,
      body: {
        a: 1,
        b: 2,
        progress: 'PENDING',
        _links: {
          extractions: 'ex',
          layout: 'lay'
        }
      }.to_json
    )
  end

  before do
    api.token.stub(:get).and_return(response)
  end

  context 'without request obj' do

    subject(:ex) { Gini::Api::Error.new('Error message') }

    it do
      expect(ex.message).to eql('Error message')
    end

    it do
      expect(ex.api_response).to be_nil
      should respond_to(:api_response)
    end

    it do
      expect(ex.api_method).to be_nil
      should respond_to(:api_method)
    end

    it do
      expect(ex.api_url).to be_nil
      should respond_to(:api_url)
    end

    it do
      expect(ex.api_status).to be_nil
      should respond_to(:api_status)
    end

    it do
      expect(ex.api_message).to be_nil
      should respond_to(:api_message)
    end

    it do
      expect(ex.api_request_id).to be_nil
      should respond_to(:api_request_id)
    end

    it do
      expect(ex.docid).to be_nil
      should respond_to(:docid)
    end

    it 'does accept docid' do
      expect(ex.docid).to be_nil
      ex.docid = 'abc-123'
      expect(ex.docid).to eql('abc-123')
    end

  end

  context 'with request obj' do

    let(:request) do
      double('Request',
        status: 500,
        body: {
          message: 'Validation of the request entity failed',
          requestId: '8896f9dc-260d-4133-9848-c54e5715270f'
        }.to_json,
        env: {
          method: :post,
          url: 'https://api.gini.net/abc-123',
        }
      )
    end

    subject(:ex) { Gini::Api::Error.new('Error message', request) }

    it do
      expect(ex.api_response).to eql(request)
    end

    it do
      expect(ex.api_method).to eql(:post)
    end

    it do
      expect(ex.api_status).to eql(500)
    end

    it do
      expect(ex.api_url).to \
        eql('https://api.gini.net/abc-123')
    end

    it do
      expect(ex.api_message).to \
        eql('Validation of the request entity failed')
    end

    it do
      expect(ex.api_request_id).to \
        eql('8896f9dc-260d-4133-9848-c54e5715270f')
    end

    it do
      expect(ex.api_error).to \
        eql('POST https://api.gini.net/abc-123 : 500 - Validation of the request entity failed (request Id: 8896f9dc-260d-4133-9848-c54e5715270f)')
    end

  end

  context 'with unparsable body' do

    let(:request) do
      double('Request',
        status: 500,
        body: 'NO Json. Sorry',
        env: {
          method: :post,
          url: 'https://api.gini.net/abc-123',
        }
      )
    end

    subject(:ex) { Gini::Api::Error.new('Error message', request) }

    it 'ignores message and request_id' do
      expect(ex.api_message).to eql('undef')
      expect(ex.api_request_id).to eql('undef')
    end

  end

end
