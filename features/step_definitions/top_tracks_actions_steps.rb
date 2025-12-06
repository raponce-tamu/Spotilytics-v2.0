Given("top tracks controller auth is bypassed") do
  visit root_path
  allow_any_instance_of(TopTracksController).to receive(:require_spotify_auth!).and_return(true)
  allow_any_instance_of(ApplicationController).to receive(:require_spotify_auth!).and_return(true)
  sess = page.driver.request.session
  sess[:spotify_user] ||= { "id" => "user-1" }
  sess[:spotify_token] ||= "token"
end

Given("top tracks client is stubbed") do
  client = instance_double(SpotifyClient, top_tracks: [], followed_artist_ids: Set.new)
  allow(SpotifyClient).to receive(:new).and_return(client)
end

Given("top tracks session has no user") do
  sess = page.driver.request.session
  sess[:spotify_user] = nil
  sess[:spotify_token] = nil
  allow_any_instance_of(TopTracksController).to receive(:spotify_user_id).and_return(nil)
  @top_tracks_no_user = true
end

Given("hiding tracks will succeed") do
  allow_any_instance_of(TopTracksController).to receive(:spotify_user_id).and_return("user-1")
  allow_any_instance_of(TopTracksController).to receive(:add_hidden_top_track).and_return(true)
end

Given("hiding tracks will fail") do
  allow_any_instance_of(TopTracksController).to receive(:spotify_user_id).and_return("user-1")
  allow_any_instance_of(TopTracksController).to receive(:add_hidden_top_track).and_return(false)
end

When("I post hide track {string} for time range {string}") do |track_id, range|
  page.driver.submit :post, hide_top_track_path, { track_id: track_id, time_range: range }
end

When("I post unhide track {string} for time range {string}") do |track_id, range|
  driver = page.driver
  driver.submit :post, unhide_top_track_path, { track_id: track_id, time_range: range }
  unless @top_tracks_no_user
    if driver.respond_to?(:follow_redirect!)
      2.times { driver.follow_redirect! }
    else
      visit top_tracks_path
    end
  end
end

Then("I should be on the top tracks page") do
  expect(page.current_path).to eq(top_tracks_path)
end

Then("I should be redirected to home") do
  driver = page.driver
  location =
    if driver.respond_to?(:response) && driver.response.respond_to?(:location)
      driver.response.location
    elsif driver.respond_to?(:response_headers)
      driver.response_headers["Location"]
    end
  expect(location || page.current_path).to include(root_path)
end
