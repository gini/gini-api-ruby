require 'spec_helper'

describe Gini::Api::DocumentSet do

  before do
    allow(Gini::Api::Document).to \
      receive(:new) { Gini::Api::Document }
  end

  let(:api) { double('API') }
  let(:data) do
    { totalCount: 42,
      next: 20,
      documents:[
        {
          _links: { document: 'dummy' }
        },
        {
          _links: { document: 'dummy' }
        }
      ]
    }
  end

  subject(:set) { Gini::Api::DocumentSet.new(api, data) }

  it { should respond_to(:total) }
  it { should respond_to(:offset) }
  it { should respond_to(:documents) }

  it do
    expect(set.total).to eql(42)
  end

  it do
    expect(set.offset).to eql(20)
  end

  it do
    expect(set.documents.length).to eql(2)
    expect(set.documents[0]).to eql(Gini::Api::Document)
  end

end
