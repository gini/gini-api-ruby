require 'spec_helper'

describe Gini::Api::Document::Extractions do

  before do
    expect(Gini::Api::OAuth).to \
      receive(:new) { oauth }

    api.login(auth_code: '1234567890')
    allow(api.token).to receive(:get).with(
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

  let(:incubator) { false }
  let(:header)    { 'application/vnd.gini.v1+json' }
  let(:location)  { 'https://api.gini.net/document/aaa-bbb-ccc/extractions' }
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
          },
          invalid: {
            this_is: 'wrong'
          },
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

  subject(:extractions) { Gini::Api::Document::Extractions.new(api, location, incubator) }

  it { should respond_to(:update) }
  it { should respond_to(:[]) }
  it { should respond_to(:raw) }

  describe '#update' do

    it 'populates instance vars' do
      expect(extractions.payDate).to be_a(Hash)
      expect(extractions.payDate[:entity]).to eq('date')
      extractions.update
    end

    it 'saves raw response' do
      expect(extractions.raw).to eql(JSON.parse(response.body, symbolize_names: true))
      extractions.update
    end

    context 'failed extraction fetch' do

      let(:response) { double('Response', :status => 404, env: {}, body: {}) }

      it 'raises exception' do
        expect { extractions.update }.to \
          raise_error(Gini::Api::DocumentError, /Failed to fetch extractions from #{location}/)
      end

    end

    context 'failed to parse response' do

      let(:response) do
        double('Response',
          status: 200,
          headers: {
            'content-type' => 'vnd/gini.not.supported+json',
          },
          env: {},
          body: {}.to_json
        )
      end

      it 'raises exception' do
        expect { extractions.update }.to \
          raise_error(Gini::Api::DocumentError, /Failed to parse extractions from #{location}/)
      end

    end

    context 'with incubator=true' do

      let(:extractions) { Gini::Api::Document::Extractions.new(api, location, incubator=true) }

      it do
        expect(api.token).to receive(:get).with(
          location,
          {
            headers: {
              accept: 'application/vnd.gini.incubator+json',
            }
          }
        ).and_return(OAuth2::Response.new(response))
        expect(extractions.instance_variable_get(:@req_opts)).to eql({ headers: { accept: 'application/vnd.gini.incubator+json' } })
      end

    end

  end

  describe '#[]' do

    context 'with missing key' do

      it 'raises exception' do
        expect { extractions[:unknown] }.to \
          raise_error(Gini::Api::DocumentError, /Invalid extraction key 'unknown'/)
      end

    end

    context 'with missing :value in response' do

      it 'raises exception' do
        expect { extractions[:invalid] }.to \
          raise_error(Gini::Api::DocumentError, /Extraction key 'invalid' has no :value defined/)
      end

    end

    context 'with valid key' do

      it 'returns extraction value' do
        expect(extractions[:payDate]).to eql('2012-06-20')
      end

    end

  end

  describe '#method_missing' do

    context 'with unknown extraction' do

      context 'and only value' do

        it 'will set instance variable to new hash' do
          expect(extractions).to receive(:instance_variable_set).with('@test', {value: :test})
          expect(extractions).to receive(:submit_feedback).with('test', {:value=>:test})
          extractions.test = :test
        end

      end

      context 'and hash' do

        it 'will set instance variable to supplied hash' do
          expect(extractions).to receive(:instance_variable_set).with('@test', {value: 'test', box: {}})
          expect(extractions).to receive(:submit_feedback).with('test', {value: 'test', box: {}})
          extractions.test = {value: 'test', box: {} }
        end

      end

    end

  end

  describe '#submit_feedback' do

    context 'with valid label' do

      before do
        allow(api.token).to receive(:put).with(
          "#{location}/test",
          {
            headers: {
              'content-type' => header,
              accept: 'application/vnd.gini.v1+json',
             },
            body: { value: 'Johnny Bravo' }.to_json
          }
        ).and_return(OAuth2::Response.new(double('Response', status: 204)))
      end

      it 'succeeds' do
        expect(extractions.submit_feedback(:test, {value: 'Johnny Bravo'})).to be_a(OAuth2::Response)
      end

    end

    context 'with invalid label (http code 422)' do

      before do
        allow(api.token).to receive(:put).with(
          "#{location}/test",
          {
            headers: {
              'content-type' => header,
              accept: 'application/vnd.gini.v1+json',
            },
            body: { value: 'Johnny Bravo' }.to_json
          }
        ).and_raise(Gini::Api::RequestError.new('dummy', double('xxx', status: 422, env: {}, body: {})))
      end

      it 'raises Gini::Api::DocumentError' do
        expect{extractions.submit_feedback(:test, {value: 'Johnny Bravo'})}.to \
        raise_error(Gini::Api::DocumentError, /Failed to submit feedback for label/)
      end

    end

    context 'with undefined error' do

      before do
        allow(api.token).to receive(:put).with(
          "#{location}/test",
          {
            headers: {
              'content-type' => header,
              accept: 'application/vnd.gini.v1+json',
            },
            body: { value: 'Johnny Bravo' }.to_json
          }
        ).and_raise(Gini::Api::RequestError.new('dummy', double('xxx', status: 500, env: {}, body: {})))
      end

      it 'raises Gini::Api::RequestError' do
        expect{extractions.submit_feedback(:test, {value: 'Johnny Bravo'})}.to \
        raise_error(Gini::Api::RequestError)
      end

    end

  end

end
