require 'rails_helper'

RSpec.describe SpotifyClient do
  let(:session) { { spotify_token: 'valid_token', spotify_expires_at: 1.hour.from_now.to_i, "spotify_user" => { "id" => "user_id" }, spotify_refresh_token: "refresh_token" } }
  let(:client) { described_class.new(session: session) }
  let(:http_response) { instance_double(Net::HTTPResponse, body: "{}", code: "200", message: "OK") }

  before do
    allow(ENV).to receive(:[]).and_call_original
    allow(ENV).to receive(:[]).with("SPOTIFY_CLIENT_ID").and_return("client_id")
    allow(ENV).to receive(:[]).with("SPOTIFY_CLIENT_SECRET").and_return("client_secret")

    # Standard mock for Net::HTTP requests
    allow_any_instance_of(Net::HTTP).to receive(:request).and_return(http_response)
    allow_any_instance_of(Net::HTTP).to receive(:start).and_yield(Net::HTTP.new("api.spotify.com"))
  end

  describe "#new_releases" do
    let(:response_body) do
      {
        "albums" => {
          "items" => [
            {
              "id" => "album1",
              "name" => "New Album",
              "images" => [ { "url" => "http://image.url" } ],
              "total_tracks" => 12,
              "release_date" => "2024-01-01",
              "external_urls" => { "spotify" => "http://spotify.url" },
              "artists" => [ { "name" => "Artist 1" } ]
            }
          ]
        }
      }
    end

    it "fetches new releases" do
      allow(http_response).to receive(:body).and_return(response_body.to_json)
      result = client.new_releases(limit: 10)
      expect(result).not_to be_empty
      expect(result.first.name).to eq("New Album")
      expect(result.first.total_tracks).to eq(12)
    end
  end

  describe "#followed_artists" do
    let(:response_body) do
      {
        "artists" => {
          "items" => [
            {
              "id" => "artist1",
              "name" => "Artist 1",
              "images" => [ { "url" => "http://image.url" } ],
              "genres" => [ "pop" ],
              "popularity" => 80,
              "external_urls" => { "spotify" => "http://spotify.url" }
            }
          ]
        }
      }
    end

    it "fetches followed artists" do
      allow(http_response).to receive(:body).and_return(response_body.to_json)
      result = client.followed_artists(limit: 10)
      expect(result).not_to be_empty
      expect(result.first.name).to eq("Artist 1")
      expect(result.first.genres).to eq([ "pop" ])
    end
  end

  describe "#create_playlist_for" do
    it "creates playlist and returns id" do
      allow(http_response).to receive(:body).and_return({ id: "playlist_id" }.to_json)
      id = client.create_playlist_for(user_id: "u1", name: "P1", description: "D1", public: false)
      expect(id).to eq("playlist_id")
    end
  end

  describe "#add_tracks_to_playlist" do
    it "adds tracks" do
      allow(http_response).to receive(:body).and_return({ snapshot_id: "s1" }.to_json)
      expect(client.add_tracks_to_playlist(playlist_id: "p1", uris: [ "uri1" ])).to be_truthy
    end
  end

  describe "#follow_artists" do
    it "follows artists" do
      allow(http_response).to receive(:body).and_return("") # 204 No Content usually, but 200 OK with empty body works for mock
      expect(client.follow_artists([ "a1" ])).to be_truthy
    end
  end

  describe "#unfollow_artists" do
    it "unfollows artists" do
      allow(http_response).to receive(:body).and_return("")
      expect(client.unfollow_artists([ "a1" ])).to be_truthy
    end
  end

  describe "#followed_artist_ids" do
    it "returns set of followed ids" do
      # API returns [true, false] for check
      allow(http_response).to receive(:body).and_return([ true, false ].to_json)
      ids = client.followed_artist_ids([ "a1", "a2" ])
      expect(ids).to include("a1")
      expect(ids).not_to include("a2")
    end
  end

  describe "#current_user_id" do
    it "returns current user id from API if not in session" do
      session["spotify_user"] = {} # Clear user id from session to force API call
      allow(http_response).to receive(:body).and_return({ id: "user_123" }.to_json)
      expect(client.current_user_id).to eq("user_123")
    end
  end

  describe "#clear_user_cache" do
    it "clears cache" do
      # The implementation uses "spotify_#{user_id}_*"
      # user_id comes from session: "user_id"
      expect(Rails.cache).to receive(:delete_matched).with(/spotify_user_id_/)
      client.clear_user_cache
    end
  end

  describe "token refresh" do
    let(:expired_session) { { spotify_token: 'expired', spotify_expires_at: 1.hour.ago.to_i, spotify_refresh_token: "refresh", "spotify_user" => { "id" => "u1" } } }
    let(:expired_client) { described_class.new(session: expired_session) }

    it "refreshes token when expired" do
      refresh_response = instance_double(Net::HTTPResponse, body: { access_token: "new_token", expires_in: 3600 }.to_json, code: "200", message: "OK")

      # Sequence: 1. Refresh token request, 2. API request
      allow_any_instance_of(Net::HTTP).to receive(:request).and_return(refresh_response, http_response)

      expired_client.new_releases(limit: 1)
      expect(expired_session[:spotify_token]).to eq("new_token")
    end
  end

  describe "error handling" do
    let(:error_body) { { error: { message: "Error message" } }.to_json }

    it "raises Error on 401" do
      allow(http_response).to receive(:code).and_return("401")
      allow(http_response).to receive(:message).and_return("Unauthorized")
      allow(http_response).to receive(:body).and_return(error_body)
      # perform_request raises Error on 4xx/5xx, not UnauthorizedError specifically
      expect { client.new_releases(limit: 1) }.to raise_error(SpotifyClient::Error, /Error message/)
    end

    it "raises Error on 403" do
      allow(http_response).to receive(:code).and_return("403")
      allow(http_response).to receive(:message).and_return("Forbidden")
      allow(http_response).to receive(:body).and_return(error_body)
      expect { client.new_releases(limit: 1) }.to raise_error(SpotifyClient::Error, /Error message/)
    end

    it "raises Error on 429" do
      allow(http_response).to receive(:code).and_return("429")
      allow(http_response).to receive(:message).and_return("Too Many Requests")
      allow(http_response).to receive(:body).and_return(error_body)
      expect { client.new_releases(limit: 1) }.to raise_error(SpotifyClient::Error, /Error message/)
    end

    it "raises Error on 500" do
      allow(http_response).to receive(:code).and_return("500")
      allow(http_response).to receive(:message).and_return("Server Error")
      allow(http_response).to receive(:body).and_return(error_body)
      expect { client.new_releases(limit: 1) }.to raise_error(SpotifyClient::Error, /Error message/)
    end
  end
end
