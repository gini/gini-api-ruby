require 'spec_helper'

describe Gini::Api::Document::Extractions do

  before do
    expect(Gini::Api::OAuth).to \
      receive(:new) { oauth }

    api.login(auth_code: '1234567890')
    api.token.stub(:get).with(
      location,
      {
        headers: {
          accept: header
        }
      }
    ).and_return(OAuth2::Response.new(response))
  end

  let(:api) do
    Gini::Api::Client.new(
      client_id: 'gini-rspec',
      client_secret: 'secret',
      oauth_site: 'https://rspec-oauth.gini.net',
      log: (Logger.new '/dev/null'),
    )
  end

  let(:oauth) do
    double('Gini::Api::OAuth',
      :token => 'TOKEN',
      :destroy => nil
    )
  end

  let(:header)   { 'application/vnd.gini.v1+json' }
  let(:location) { 'https://api.gini.net/document/aaa-bbb-ccc/extractions' }
  let(:response) do
    double('Response',
      status: 200,
      headers: {
        'content-type' => header
      },
      body: {
        extractions: {
          payDate: {
            entity: 'date',
            value: '2012-06-20',
            candidates: 'dates'
          }
        },
        candidates: {
          dates: [
            {
              entity: 'date',
              value: '2012-06-20'
            },
            {
              entity: 'date',
              value: '2012-05-10'
            },
          ]
        }
      }.to_json
    )
  end

  subject(:extractions) { Gini::Api::Document::Extractions.new(api, location) }

  it { should respond_to(:update) }
  it { should respond_to(:[]) }

  describe '#update' do

    it 'populates instance vars' do
      expect(extractions.payDate).to be_a(Hash)
      expect(extractions.payDate[:entity]).to eq('date')
      extractions.update
    end

    context 'failed extraction fetch' do

      let(:response) { double('Response', :status => 404, env: {}, body: {}) }

      it 'raises exception' do
        expect { extractions.update }.to \
          raise_error(Gini::Api::DocumentError, /Failed to fetch extractions from #{location}/)
      end

    end

  end

  describe '#[]' do

    context 'with invalid key' do

      it 'raises exception' do
        expect { extractions[:unknown] }.to \
          raise_error(Gini::Api::DocumentError, /Invalid extraction key unknown/)
      end

    end

    context 'with valid key' do

      it 'returns extraction value' do
        expect(extractions[:payDate]).to eql('2012-06-20')
      end

    end

  end

end
