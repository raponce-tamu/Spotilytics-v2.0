require "ostruct"

Given("pages controller client defaults are stubbed") do
  allow_any_instance_of(PagesController).to receive(:require_spotify_auth!).and_return(true)
  allow_any_instance_of(ApplicationController).to receive(:require_spotify_auth!).and_return(true)

  @pages_default ||= instance_double(
    SpotifyClient,
    clear_user_cache: true,
    profile: { name: "Me" },
    top_artists: [ OpenStruct.new(id: "a1", genres: [ "rock" ], name: "Artist") ],
    top_tracks: [ OpenStruct.new(id: "t1") ],
    followed_artists: [],
    followed_artist_ids: Set.new,
    new_releases: [],
    saved_shows: OpenStruct.new(items: []),
    saved_episodes: OpenStruct.new(items: []),
    user_playlists_all: [],
  )
  allow(SpotifyClient).to receive(:new).and_return(@pages_default)
end

Given("spotify clear cache raises unauthorized") do
  mock = instance_double(SpotifyClient)
  allow(SpotifyClient).to receive(:new).and_return(mock)
  allow(mock).to receive(:clear_user_cache).and_raise(SpotifyClient::UnauthorizedError.new("missing"))
end

Given("spotify top artists raises unauthorized for dashboard") do
  mock = instance_double(SpotifyClient)
  allow(SpotifyClient).to receive(:new).and_return(mock)
  allow(mock).to receive(:top_artists).and_raise(SpotifyClient::UnauthorizedError.new("expired"))
end

Given("spotify top artists raises generic error for dashboard") do
  mock = instance_double(SpotifyClient)
  allow(SpotifyClient).to receive(:new).and_return(mock)
  allow(mock).to receive(:top_artists).and_raise(SpotifyClient::Error.new("fail"))
end

Given("spotify top artists raises insufficient scope") do
  mock = instance_double(SpotifyClient)
  allow(SpotifyClient).to receive(:new).and_return(mock)
  allow(mock).to receive(:top_artists).and_raise(SpotifyClient::Error.new("Insufficient client scope"))
  allow(mock).to receive(:followed_artist_ids).and_return(Set.new)
  allow_any_instance_of(PagesController).to receive(:reset_spotify_session!).and_return(true)
end

Then("I should be redirected to login") do
  uri = Addressable::URI.parse(page.current_url)
  expect([ login_path, "/auth/spotify", "/" ]).to include(uri.path)
end

Given("spotify top artists raises generic error") do
  mock = instance_double(SpotifyClient)
  allow(SpotifyClient).to receive(:new).and_return(mock)
  allow(mock).to receive(:top_artists).and_raise(SpotifyClient::Error.new("boom"))
  allow(mock).to receive(:followed_artist_ids).and_return(Set.new)
end

Given("spotify playlists raises error") do
  mock = instance_double(SpotifyClient)
  allow(SpotifyClient).to receive(:new).and_return(mock)
  allow(mock).to receive(:user_playlists_all).and_raise(SpotifyClient::Error.new("fail"))
end

Given("spotify profile raises unauthorized") do
  mock = instance_double(SpotifyClient)
  allow(SpotifyClient).to receive(:new).and_return(mock)
  allow(mock).to receive(:profile).and_raise(SpotifyClient::UnauthorizedError.new("expired"))
end
