require 'spec_helper'

describe Gini::Api::Document do

  before do
    expect(Gini::Api::OAuth).to receive(:new) do
      double('Gini::Api::OAuth', token: 'TOKEN', destroy: nil)
    end
    api.login(auth_code: '1234567890')
    api.token.stub(:get).with(
      location,
      { headers: { accept: header } }
    ).and_return(OAuth2::Response.new(response))
  end

  let(:api) do
    Gini::Api::Client.new(
      client_id: 'gini-rspec',
      client_secret: 'secret',
      log: Logger.new('/dev/null')
    )
  end

  let(:header)   { 'application/vnd.gini.v1+json' }
  let(:location) { 'https://api.gini.net/documents/aaa-bbb-ccc' }
  let(:response) do
    double('Response', {
      status: 200,
      headers: { 'content-type' => header },
      body: {
        a: 1,
        b: 2,
        progress: 'PENDING',
        _links: {
          extractions: "#{location}/extractions",
          layout: "#{location}/layout",
          processed: "#{location}/processed"
        }
      }.to_json
    })
  end

  subject(:document) { Gini::Api::Document.new(api, location) }

  it { should respond_to(:update) }
  it { should respond_to(:poll) }
  it { should respond_to(:processed) }
  it { should respond_to(:extractions) }
  it { should respond_to(:layout) }
  it { should respond_to(:pages) }
  it { should respond_to(:completed?) }
  it { should respond_to(:successful?) }

  it 'does accept duration' do
    expect(document.duration).to be_nil
    document.duration = 'test'
    expect(document.duration).to eql('test')
  end

  describe '#update' do

    it 'does set instance vars' do
      expect(document.a).to eql(1)
      expect(document.b).to eql(2)
    end

    context 'with unknown document' do

      let(:response) { double('Response', status: 404, env: {}, body: {}) }

      it do
        expect { Gini::Api::Document.new(api, location) }.to \
          raise_error(Gini::Api::DocumentError, /Failed to fetch document data/)
      end

    end

  end

  describe '#poll' do

    context 'without code block' do
      let(:response) do
        double('Response', {
          status: 200,
          headers: { 'content-type' => header },
          body: {
            a: 1,
            b: 2,
            progress: 'COMPLETED',
            _links: { extractions: 'ex', layout: 'lay' }
          }.to_json
        })
      end

      it do
        expect(document.poll(0)).to be_nil
      end

    end

  end

  describe '#completed?' do

    context 'with state = PENDING' do

      let(:response) do
        double('Response', {
          status: 200,
          headers: { 'content-type' => header },
          body: {
            progress: 'PENDING'
          }.to_json
        })
      end

      it do
        expect(document.completed?).to be_false
      end

    end

    context 'with state != PENDING' do

      let(:response) do
        double('Response', {
          status: 200,
          headers: { 'content-type' => header },
          body: {
            progress: 'COMPLETED'
          }.to_json
        })
      end

      it do
        expect(document.completed?).to be_true
      end

    end

  end

  describe '#successful?' do

    context 'with state = COMPLETED' do

      let(:response) do
        double('Response', {
          status: 200,
          headers: { 'content-type' => header },
          body: {
            progress: 'COMPLETED'
          }.to_json
        })
      end

      it do
        expect(document.successful?).to be_true
      end

    end

    context 'with state == ERROR' do

      let(:response) do
        double('Response', {
          status: 200,
          headers: { 'content-type' => header },
          body: {
            progress: 'ERROR'
          }.to_json
        })
      end

      it do
        expect(document.successful?).to be_false
      end

    end

  end

  describe '#processed' do

    let(:pd_response) do
      double('Response', {
        status: 200,
        headers: { 'content-type' => 'application/octet-stream' },
        body: '1001'
      })
    end

    it do
      api.token.stub(:get).with(
        "#{location}/processed",
        { headers: { accept: 'application/octet-stream' } }
      ).and_return(OAuth2::Response.new(pd_response))
      expect(document.processed).to eql('1001')
    end

    context 'with status != 200' do

      let(:pd_response) do
        double('Response', {
          status: 500,
          headers: { 'content-type' => 'application/octet-stream' },
          body: {},
          env: {}
        })
      end

      it do
        api.token.stub(:get).with(
          "#{location}/processed",
          { headers: { accept: 'application/octet-stream' } }
        ).and_return(OAuth2::Response.new(pd_response))
        expect { document.processed }.to raise_error(Gini::Api::DocumentError)
      end

    end

  end

  describe '#extractions' do

    let(:ex_response) do
      double('Response', {
        status: 200,
        headers: { 'content-type' => header },
        body: {
          extractions: { payDate: {} },
          candidates: {}
        }.to_json
      })
    end

    it do
      api.token.stub(:get).with(
        "#{location}/extractions",
        { headers: { accept: header } }
      ).and_return(OAuth2::Response.new(ex_response))
      expect(document.extractions).to be_a(Gini::Api::Document::Extractions)
    end

  end

  describe '#layout' do

    it do
      expect(document.layout).to be_a Gini::Api::Document::Layout
    end

  end

  describe '#pages' do

    let(:response) do
      double('Response', {
        status: 200,
        headers: { 'content-type' => header },
        body: {
          pages: [
            {
              :pageNumber => 1,
              :images =>
              {
                :"750x900"   => "750x900",
                :"1280x1810" => "1280x1810"
              }
            },
            {
              :pageNumber => 2,
              :images => {
                :"750x900"   => "750x900",
                :"1280x1810" => "1280x1810"
              }
            }
          ]
        }.to_json
      })
    end

    it do
      expect(document.pages).to be_an(Array)
      expect(document.pages[0][:"750x900"]).to eql("750x900")
      expect(document.pages[1][:"750x900"]).to eql("750x900")
      expect{document.pages[2][:"750x900"]}.to raise_error(NoMethodError)
    end

  end

  describe '#submit_feedback' do

    let(:response) do
      double('Response', {
        status: 200,
        headers: { 'content-type' => header },
        body: {
          a: 1,
          b: 2,
          progress: 'PENDING',
          _links: {
            extractions: "#{location}/extractions"
          }
        }.to_json
      })
    end

    context 'succeeds' do

      let(:fb_response) { double('Response', status: 204) }

      it do
        document.stub(:extractions) { double('Extractions').as_null_object }
        api.token.stub(:put).with(
          "#{location}/extractions/bic",
          {
            headers: { 'content-type' => header },
            body: { value: 'XXXXXXXX' }.to_json
          }
        ).and_return(OAuth2::Response.new(fb_response))

        expect(document.submit_feedback(:bic, 'XXXXXXXX')).to be_nil
      end

    end

    context 'failes' do

      let(:fb_response) { double('Response', status: 204) }

      it 'on invalid label' do
        document.stub(:extractions) { double('Extractions', bic: nil) }
        api.token.stub(:put).with(
          "#{location}/extractions/bic",
          {
            headers: { 'content-type' => header },
            body: { value: 'XXXXXXXX' }.to_json
          }
        ).and_return(OAuth2::Response.new(fb_response))

        expect { document.submit_feedback(:bic, 'XXXXXXXX') }.to \
          raise_error(Gini::Api::DocumentError, /Unknown label bic/)
      end

    end

    context 'failes' do

      let(:fb_response) { double('Response', status: 404, body: {}, env: {}) }

      it 'on invalid http code' do
        document.stub(:extractions) { double('Extractions').as_null_object }
        api.token.stub(:put).with(
          "#{location}/extractions/bic",
          {
            headers: { 'content-type' => header },
            body: { value: 'XXXXXXXX' }.to_json
          }
        ).and_return(OAuth2::Response.new(fb_response))

        expect { document.submit_feedback(:bic, 'XXXXXXXX') }.to \
          raise_error(Gini::Api::DocumentError, /Failed to submit feedback for label bic/)
      end

    end

  end

end
