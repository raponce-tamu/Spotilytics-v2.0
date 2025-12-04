require 'rails_helper'

RSpec.describe PlaylistsController, type: :controller do
  let(:session_data) { { spotify_token: 'valid_token', spotify_expires_at: 1.hour.from_now.to_i } }
  let(:client) { instance_double(SpotifyClient) }

  before do
    session[:spotify_token] = session_data[:spotify_token]
    session[:spotify_expires_at] = session_data[:spotify_expires_at]
    allow(SpotifyClient).to receive(:new).and_return(client)
  end

  describe "POST #create" do
    context "when session[:spotify_user] is missing id" do
      before do
        session[:spotify_user] = { "email" => "test@example.com" }
      end

      it "fetches current_user_id from client and updates session" do
        # Mock client calls
        allow(client).to receive(:current_user_id).and_return("fetched_user_id")

        # Mock top_tracks to return empty so we don't proceed to playlist creation (simpler test)
        # or return tracks and mock the rest. Let's return empty to hit the redirect and stop.
        # Wait, if tracks empty it redirects. We just want to verify user_id fetching.

        allow(client).to receive(:top_tracks).with(limit: 10, time_range: "short_term").and_return([])

        post :create, params: { time_range: "short_term" }

        expect(client).to have_received(:current_user_id)
        expect(session[:spotify_user]["id"]).to eq("fetched_user_id")
      end
    end
  end
end
