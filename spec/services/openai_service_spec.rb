require 'rails_helper'

RSpec.describe OpenaiService do
  let(:service) { described_class.new }
  let(:client) { instance_double(OpenAI::Client) }

  before do
    allow(OpenAI::Client).to receive(:new).and_return(client)
  end

  describe '#generate_search_query' do
    it 'returns the optimized query from OpenAI' do
      allow(client).to receive(:chat).and_return({
        "choices" => [ { "message" => { "content" => "optimized query" } } ]
      })

      expect(service.generate_search_query("complex query")).to eq("optimized query")
    end

    it 'returns the original query on error' do
      allow(client).to receive(:chat).and_raise(StandardError.new("API Error"))

      expect(Rails.logger).to receive(:error).with("OpenAI Error: API Error")
      expect(service.generate_search_query("complex query")).to eq("complex query")
    end
  end

  describe '#summarize_episode' do
    it 'returns the summary from OpenAI' do
      allow(client).to receive(:chat).and_return({
        "choices" => [ { "message" => { "content" => "Summary: Great episode\nTags: #fun" } } ]
      })

      expect(service.summarize_episode("Title", "Description")).to eq("Summary: Great episode\nTags: #fun")
    end

    it 'returns nil on error' do
      allow(client).to receive(:chat).and_raise(StandardError.new("API Error"))

      expect(Rails.logger).to receive(:error).with("OpenAI Error: API Error")
      expect(service.summarize_episode("Title", "Description")).to be_nil
    end
  end

  describe '#generate_recommendation' do
    let(:saved_shows) { [ double(name: "Show 1"), double(name: "Show 2") ] }

    it 'returns the recommendation from OpenAI' do
      allow(client).to receive(:chat).and_return({
        "choices" => [ { "message" => { "content" => "You will like this because..." } } ]
      })

      expect(service.generate_recommendation(saved_shows, "Target Show", "Publisher")).to eq("You will like this because...")
    end

    it 'returns nil on error' do
      allow(client).to receive(:chat).and_raise(StandardError.new("API Error"))

      expect(Rails.logger).to receive(:error).with("OpenAI Error: API Error")
      expect(service.generate_recommendation(saved_shows, "Target Show", "Publisher")).to be_nil
    end
  end

  describe '#suggest_similar_shows' do
    it 'returns a list of similar shows' do
      allow(client).to receive(:chat).and_return({
        "choices" => [ { "message" => { "content" => "Show A, Show B, Show C" } } ]
      })

      expect(service.suggest_similar_shows("Target Show", "Publisher")).to eq([ "Show A", "Show B", "Show C" ])
    end

    it 'returns empty list on error' do
      allow(client).to receive(:chat).and_raise(StandardError.new("API Error"))

      expect(Rails.logger).to receive(:error).with("OpenAI Error: API Error")
      expect(service.suggest_similar_shows("Target Show", "Publisher")).to eq([])
    end

    it 'returns empty list on empty content' do
      allow(client).to receive(:chat).and_return({
        "choices" => [ { "message" => { "content" => nil } } ]
      })

      expect(service.suggest_similar_shows("Target Show", "Publisher")).to eq([])
    end
  end

  describe '#generate_bulk_recommendations' do
    it 'returns a list of recommendations' do
      allow(client).to receive(:chat).and_return({
        "choices" => [ { "message" => { "content" => "Rec 1, Rec 2, Rec 3" } } ]
      })

      expect(service.generate_bulk_recommendations([ "Item 1", "Item 2" ], "shows")).to eq([ "Rec 1", "Rec 2", "Rec 3" ])
    end

    it 'returns empty list on error' do
      allow(client).to receive(:chat).and_raise(StandardError.new("API Error"))

      expect(Rails.logger).to receive(:error).with("OpenAI Error: API Error")
      expect(service.generate_bulk_recommendations([ "Item 1" ], "shows")).to eq([])
    end

    it 'returns empty list on empty content' do
      allow(client).to receive(:chat).and_return({
        "choices" => [ { "message" => { "content" => nil } } ]
      })

      expect(service.generate_bulk_recommendations([ "Item 1" ], "shows")).to eq([])
    end
  end
end
