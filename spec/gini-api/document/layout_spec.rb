require 'spec_helper'

describe Gini::Api::Document::Layout do

  let(:status)   { 200 }
  let(:body)     { '' }
  let(:api)      { double('API', :request => response) }
  let(:location) { 'http://api.gini.net/document/aaa-bbb-ccc/extractions' }
  let(:response) do
    double('Response',
      status: status,
      body: body
    )
  end

  subject(:layout) { Gini::Api::Document::Layout.new(api, location) }

  it { should respond_to(:to_xml) }
  it { should respond_to(:to_json) }

  describe '#to_xml' do

    let(:body) { '<XML>' }

    before do
      expect(api).to \
        receive(:request).with(
          :get,
          location,
          type: 'xml'
        ) { response }
    end

    it do
      expect(layout.to_xml).to eql('<XML>')
    end

    context 'without layout' do

      let(:status) { 404 }

      it do
        expect(layout.to_xml).to be_nil
      end

    end

  end

  describe '#to_json' do

    let(:body) { '{JSON}' }

    before do
      expect(api).to \
        receive(:request).with(
          :get,
          location
        )
    end

    it do
      expect(layout.to_json).to eql('{JSON}')
    end

    context 'without layout' do

      let(:status) { 404 }

      it do
        expect(layout.to_json).to be_nil
      end

    end

  end

end
