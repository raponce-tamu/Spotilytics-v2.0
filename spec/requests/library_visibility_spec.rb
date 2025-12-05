require "rails_helper"
require "nokogiri"

RSpec.describe "Library visibility", type: :request do
  let(:playlists) do
    [
      OpenStruct.new(
        id: "pl1",
        name: "My Playlist",
        owner: "Me",
        owner_id: "spotify-uid-123",
        public: false,
        tracks_total: 3,
        image_url: nil,
        spotify_url: nil
      )
    ]
  end

  def sign_in
    get "/auth/spotify/callback"
  end

  before do
    allow_any_instance_of(SpotifyClient).to receive(:user_playlists_all).with(skip_cache: true).and_return(playlists)
  end

  it "shows visibility controls for owned playlists" do
    sign_in

    get library_path

    html = Nokogiri::HTML(response.body)
    form = html.at_css("form[action='#{playlist_visibility_path('pl1')}']")
    expect(form).not_to be_nil
    button = form.at_css("input[type='submit']")
    expect(button["value"]).to eq("Private")
  end

  it "shows Make Private when playlist is already public" do
    public_playlists = playlists.map { |p| p.dup.tap { |pp| pp.public = true } }
    allow_any_instance_of(SpotifyClient).to receive(:user_playlists_all).with(skip_cache: true).and_return(public_playlists)

    sign_in
    get library_path

    html = Nokogiri::HTML(response.body)
    button = html.at_css("form[action='#{playlist_visibility_path('pl1')}'] input[type='submit']")
    expect(button["value"]).to eq("Public")
  end

  it "updates visibility when owner submits" do
    public_playlists = playlists.map { |p| p.dup.tap { |pp| pp.public = true } }
    allow_any_instance_of(SpotifyClient).to receive(:user_playlists_all).with(skip_cache: true).and_return(public_playlists)
    sign_in
    expect_any_instance_of(SpotifyClient).to receive(:update_playlist_visibility).with(playlist_id: "pl1", public: true).and_return(true)
    expect_any_instance_of(SpotifyClient).to receive(:clear_user_cache)

    patch playlist_visibility_path("pl1"), params: { public: "true", owner_id: "spotify-uid-123" }

    expect(response).to redirect_to(library_path(refresh_playlists: 1))
    follow_redirect!
    expect(response.body).to include("Playlist added to profile.")

    html = Nokogiri::HTML(response.body)
    button = html.at_css("form[action='#{playlist_visibility_path('pl1')}'] input[type='submit']")
    expect(button["value"]).to eq("Public")
  end

  it "rejects visibility change when not the owner" do
    sign_in

    patch playlist_visibility_path("pl1"), params: { public: "false", owner_id: "someone-else" }

    expect(response).to redirect_to(library_path)
    follow_redirect!
    expect(response.body).to include("You can only change visibility for playlists you own.")
  end
end
