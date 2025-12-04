require 'rails_helper'

RSpec.describe SpotifyClient do
  # ============================================================================
  # SETUP & MOCKS
  # ============================================================================
  let(:user_id) { "user123" }
  let(:valid_token) { "valid_access_token" }
  let(:expires_at) { 1.hour.from_now.to_i }

  let(:session) do
    {
      spotify_token: valid_token,
      spotify_expires_at: expires_at,
      "spotify_user" => { "id" => user_id },
      spotify_refresh_token: "refresh_123"
    }
  end

  let(:client) { described_class.new(session: session) }

  # Standard Successful Response
  let(:http_ok) { instance_double(Net::HTTPResponse, body: "{}", code: "200", message: "OK") }

  before do
    # Mock Environment Variables
    allow(ENV).to receive(:[]).and_call_original
    allow(ENV).to receive(:[]).with("SPOTIFY_CLIENT_ID").and_return("client_id")
    allow(ENV).to receive(:[]).with("SPOTIFY_CLIENT_SECRET").and_return("client_secret")

    # Mock Net::HTTP globally to return OK by default
    allow_any_instance_of(Net::HTTP).to receive(:start).and_yield(Net::HTTP.new("google.com"))
    allow_any_instance_of(Net::HTTP).to receive(:request).and_return(http_ok)

    # Mock Rails Cache and Logger to isolate the tests
    allow(Rails).to receive_message_chain(:cache, :fetch).and_yield
    allow(Rails).to receive_message_chain(:cache, :delete_matched)
    allow(Rails).to receive_message_chain(:logger, :info)
  end

  # ============================================================================
  # GROUP 1: SEARCH & GET METHODS
  # ============================================================================

  describe "#search_tracks" do
    let(:response_body) do
      { "tracks" => { "items" => [ { "id" => "t1", "name" => "Song", "duration_ms" => 100 } ] } }
    end

    it "returns mapped tracks" do
      allow(http_ok).to receive(:body).and_return(response_body.to_json)
      result = client.search_tracks("query")
      expect(result.first.name).to eq("Song")
    end

    it "handles empty results gracefully" do
      allow(http_ok).to receive(:body).and_return({}.to_json)
      expect(client.search_tracks("query")).to eq([])
    end

    it "uses cache" do
      allow(Rails.cache).to receive(:fetch).with(/spotify_user123_search_tracks/, any_args).and_return([ "cached" ])
      expect(client.search_tracks("query")).to eq([ "cached" ])
    end
  end

  describe "#profile" do
    let(:response_body) { { "id" => "u1", "display_name" => "Bob", "followers" => { "total" => 10 } } }

    it "returns mapped profile" do
      allow(http_ok).to receive(:body).and_return(response_body.to_json)
      expect(client.profile.display_name).to eq("Bob")
    end
  end

  describe "#new_releases" do
    let(:response_body) do
      { "albums" => { "items" => [ { "id" => "a1", "name" => "New Album", "artists" => [ { "name" => "Art" } ] } ] } }
    end

    it "returns mapped albums" do
      allow(http_ok).to receive(:body).and_return(response_body.to_json)
      result = client.new_releases(limit: 5)
      expect(result.first.name).to eq("New Album")
    end
  end

  describe "#followed_artists" do
    let(:response_body) do
      { "artists" => { "items" => [ { "id" => "art1", "name" => "Artist One", "genres" => [ "pop" ] } ] } }
    end

    it "returns mapped artists" do
      allow(http_ok).to receive(:body).and_return(response_body.to_json)
      result = client.followed_artists(limit: 10)
      expect(result.first.name).to eq("Artist One")
    end
  end

  describe "#saved_shows" do
    let(:response_body) do
      { "items" => [ { "show" => { "id" => "s1", "name" => "Show 1", "total_episodes" => 5 } } ], "total" => 1 }
    end

    it "fetches saved shows" do
      allow(http_ok).to receive(:body).and_return(response_body.to_json)
      result = client.saved_shows
      expect(result.items.first.name).to eq("Show 1")
    end
  end

  describe "#saved_episodes" do
    let(:response_body) do
      { "items" => [ { "episode" => { "id" => "e1", "name" => "Ep 1", "show" => { "name" => "S1" } } } ], "total" => 1 }
    end

    it "fetches saved episodes" do
      allow(http_ok).to receive(:body).and_return(response_body.to_json)
      result = client.saved_episodes
      expect(result.items.first.name).to eq("Ep 1")
    end
  end

  describe "#search_shows" do
    it "maps response correctly" do
      body = { "shows" => { "items" => [ { "id" => "s1", "name" => "Show" } ], "total" => 1 } }
      allow(http_ok).to receive(:body).and_return(body.to_json)
      result = client.search_shows("query")
      expect(result.items.first.name).to eq("Show")
    end
  end

  describe "#search_episodes" do
    it "maps response correctly" do
      body = { "episodes" => { "items" => [ { "id" => "e1", "name" => "Ep" } ], "total" => 1 } }
      allow(http_ok).to receive(:body).and_return(body.to_json)
      result = client.search_episodes("query")
      expect(result.items.first.name).to eq("Ep")
    end
  end

  describe "#get_episode" do
    let(:response_body) do
      { "id" => "e1", "name" => "Ep 1", "show" => { "name" => "S1" }, "duration_ms" => 60000 }
    end

    it "fetches a single episode" do
      allow(http_ok).to receive(:body).and_return(response_body.to_json)
      result = client.get_episode("e1")
      expect(result.name).to eq("Ep 1")
      expect(result.show_name).to eq("S1")
    end
  end

  describe "#get_show" do
    let(:response_body) do
      { "id" => "s1", "name" => "Show 1", "publisher" => "Pub", "total_episodes" => 10 }
    end

    it "fetches a single show" do
      allow(http_ok).to receive(:body).and_return(response_body.to_json)
      result = client.get_show("s1")
      expect(result.name).to eq("Show 1")
      expect(result.publisher).to eq("Pub")
    end
  end

  describe "#top_artists" do
    let(:response_body) { { "items" => [ { "id" => "ta1", "name" => "Top Art", "popularity" => 100 } ] } }

    it "fetches top artists" do
      allow(http_ok).to receive(:body).and_return(response_body.to_json)
      result = client.top_artists(limit: 10, time_range: 'medium_term')
      expect(result.first.name).to eq("Top Art")
    end
  end

  describe "#top_tracks" do
    let(:response_body) { { "items" => [ { "id" => "tt1", "name" => "Top Track", "album" => { "name" => "Alb" } } ] } }

    it "fetches top tracks" do
      allow(http_ok).to receive(:body).and_return(response_body.to_json)
      result = client.top_tracks(limit: 10, time_range: 'short_term')
      expect(result.first.name).to eq("Top Track")
    end
  end

  # ============================================================================
  # GROUP 2: MUTATION METHODS (POST/PUT/DELETE)
  # ============================================================================

  describe "Batch Operations" do
    it "save_shows returns true on success" do
      expect(client.save_shows([ "1" ])).to be true
    end
    it "save_shows returns true early for empty input" do
      expect(client.save_shows([])).to be true
    end

    it "save_episodes returns true on success" do
      expect(client.save_episodes([ "1" ])).to be true
    end
    it "save_episodes returns true early for empty input" do
      expect(client.save_episodes([])).to be true
    end

    it "remove_shows returns true on success" do
      expect(client.remove_shows([ "1" ])).to be true
    end
    it "remove_shows returns true early for empty input" do
      expect(client.remove_shows([])).to be true
    end

    it "remove_episodes returns true on success" do
      expect(client.remove_episodes([ "1" ])).to be true
    end
    it "remove_episodes returns true early for empty input" do
      expect(client.remove_episodes([])).to be true
    end

    it "follow_artists returns true on success" do
      expect(client.follow_artists([ "id1" ])).to be true
    end
    it "follow_artists returns true early for empty input" do
      expect(client.follow_artists([])).to be true
    end

    it "unfollow_artists returns true on success" do
      expect(client.unfollow_artists([ "id1" ])).to be true
    end
    it "unfollow_artists returns true early for empty input" do
      expect(client.unfollow_artists([])).to be true
    end
  end

  describe "#create_playlist_for" do
    it "returns the playlist id" do
      allow(http_ok).to receive(:body).and_return({ "id" => "new_playlist_id" }.to_json)
      result = client.create_playlist_for(user_id: "u1", name: "P1", description: "D1")
      expect(result).to eq("new_playlist_id")
    end

    it "raises Error if ID is missing in response" do
      allow(http_ok).to receive(:body).and_return({ "error" => "fail" }.to_json)
      expect {
        client.create_playlist_for(user_id: "u1", name: "P1", description: "D1")
      }.to raise_error(SpotifyClient::Error, "Failed to create playlist")
    end
  end

  describe "#add_tracks_to_playlist" do
    it "sends POST request" do
      expect(client.add_tracks_to_playlist(playlist_id: "p1", uris: [ "spotify:track:1" ])).to be true
    end
  end

  # ============================================================================
  # GROUP 3: COMPLEX LOGIC & UTILITIES
  # ============================================================================

  describe "#followed_artist_ids" do
    it "returns a Set of IDs" do
      allow(http_ok).to receive(:body).and_return([ true, false ].to_json)
      result = client.followed_artist_ids([ "exists", "not_exists" ])
      expect(result).to be_a(Set)
      expect(result).to include("exists")
      expect(result).not_to include("not_exists")
    end

    it "returns empty set for empty input" do
      expect(client.followed_artist_ids([])).to be_empty
    end

    it "handles chunking greater than 50 items" do
      ids = (1..55).map(&:to_s)
      expect_any_instance_of(Net::HTTP).to receive(:request).twice.and_return(http_ok)
      allow(http_ok).to receive(:body).and_return([ true ].to_json)
      client.followed_artist_ids(ids)
    end
  end

  describe "#current_user_id" do
    context "when id is in session" do
      it "returns session id without API call" do
        expect(client.current_user_id).to eq("user123")
      end
    end

    context "when id is NOT in session" do
      let(:session) { { spotify_token: valid_token, spotify_expires_at: expires_at } }

      it "fetches from API" do
        allow(http_ok).to receive(:body).and_return({ "id" => "fetched_id" }.to_json)
        expect(client.current_user_id).to eq("fetched_id")
      end

      it "raises error if API returns nothing" do
        allow(http_ok).to receive(:body).and_return({}.to_json)
        expect { client.current_user_id }.to raise_error(SpotifyClient::Error, "Could not determine Spotify user id")
      end
    end
  end

  describe "#clear_user_cache" do
    it "calls Rails.cache.delete_matched" do
      expect(Rails.cache).to receive(:delete_matched).with("spotify_user123_*")
      client.clear_user_cache
    end

    it "does nothing if user_id is missing" do
      allow(client).to receive(:current_user_id).and_return(nil)
      expect(Rails.cache).not_to receive(:delete_matched)
      client.clear_user_cache
    end
  end

  describe "#cache_for fallback" do
    it "yields if user_id is missing (no caching)" do
      allow(client).to receive(:current_user_id).and_return(nil)
      result = client.send(:cache_for, [ "test" ]) { "value" }
      expect(result).to eq("value")
    end
  end

  # ============================================================================
  # GROUP 4: INFRASTRUCTURE, ERRORS, AND TOKEN REFRESH
  # ============================================================================

  describe "Private Methods & Error Handling" do
    it "converts objects to spotify URIs" do
      track = OpenStruct.new(id: "123")
      result = client.send(:track_uris_from_tracks, [ track ])
      expect(result).to eq([ "spotify:track:123" ])
    end

    describe "Token Refresh Logic" do
      context "when token is expired" do
        let(:expires_at) { 1.hour.ago.to_i }

        let(:refresh_response) do
          instance_double(Net::HTTPResponse,
            body: { "access_token" => "new_token", "expires_in" => 3600 }.to_json,
            code: "200",
            message: "OK"
          )
        end

        it "refreshes the token automatically" do
          # We expect at least two calls: 1 refresh + 1 (or more) actual API calls
          expect_any_instance_of(Net::HTTP).to receive(:request).at_least(:twice) do |http, req|
            if req.is_a?(Net::HTTP::Post) && req.body.include?("grant_type=refresh_token")
               refresh_response # Return new token
            else
               http_ok # Return standard API response
            end
          end

          client.profile
          expect(session[:spotify_token]).to eq("new_token")
        end

        it "raises UnauthorizedError if refresh fails" do
           session[:spotify_expires_at] = 1.hour.ago.to_i

           # IMPORTANT: We mock a 200 OK but with an error body/missing token.
           # If we mock 400, perform_request raises 'Error' before refresh_access_token! can raise 'UnauthorizedError'
           failure_response = instance_double(Net::HTTPResponse,
             body: { "error" => "invalid_grant", "error_description" => "Bad Refresh" }.to_json,
             code: "200",
             message: "OK"
           )

           expect_any_instance_of(Net::HTTP).to receive(:request).and_return(failure_response)

           expect { client.profile }.to raise_error(SpotifyClient::UnauthorizedError, "Bad Refresh")
        end

        it "raises UnauthorizedError if refresh token is missing" do
          session[:spotify_refresh_token] = nil
          session[:spotify_expires_at] = 1.hour.ago.to_i
          expect { client.profile }.to raise_error(SpotifyClient::UnauthorizedError, /Missing Spotify refresh token/)
        end

        it "raises UnauthorizedError if client credentials are missing" do
          allow(ENV).to receive(:[]).with("SPOTIFY_CLIENT_ID").and_return(nil)
          session[:spotify_expires_at] = 1.hour.ago.to_i
          expect { client.profile }.to raise_error(SpotifyClient::UnauthorizedError, /Missing Spotify client credentials/)
        end
      end
    end

    describe "API Error Handling" do
      it "raises Error on 400+ response" do
        error_response = instance_double(Net::HTTPResponse,
          body: { "error" => { "message" => "Bad Request" } }.to_json,
          code: "400", message: "Bad Request"
        )
        allow_any_instance_of(Net::HTTP).to receive(:request).and_return(error_response)

        expect { client.profile }.to raise_error(SpotifyClient::Error, "Bad Request")
      end

      it "raises Error on SocketError (Network failure)" do
        allow_any_instance_of(Net::HTTP).to receive(:start).and_raise(SocketError.new("Network Error"))
        expect { client.profile }.to raise_error(SpotifyClient::Error, "Network Error")
      end

      it "handles invalid JSON responses gracefully" do
        garbage_response = instance_double(Net::HTTPResponse, body: "<html>Not JSON</html>", code: "500", message: "Server Error")
        allow_any_instance_of(Net::HTTP).to receive(:request).and_return(garbage_response)

        expect { client.profile }.to raise_error(SpotifyClient::Error, "Server Error")
      end
    end
  end
end
