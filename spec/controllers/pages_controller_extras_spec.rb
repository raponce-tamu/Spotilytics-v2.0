require 'rails_helper'

RSpec.describe PagesController, type: :controller do
  describe "helper methods" do
    # Accessing private method for testing purposes
    let(:controller_instance) { PagesController.new }

    describe "#artist_identifier" do
      it "returns id from object responding to id" do
        artist = OpenStruct.new(id: "123")
        expect(controller_instance.send(:artist_identifier, artist)).to eq("123")
      end

      it "returns id from hash with string key" do
        artist = { "id" => "456" }
        expect(controller_instance.send(:artist_identifier, artist)).to eq("456")
      end

      it "returns id from hash with symbol key" do
        artist = { id: "789" }
        expect(controller_instance.send(:artist_identifier, artist)).to eq("789")
      end

      it "returns nil if no id found" do
        artist = { name: "Unknown" }
        expect(controller_instance.send(:artist_identifier, artist)).to be_nil
      end
    end
  end
end
