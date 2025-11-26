require 'rails_helper'

RSpec.describe SavedShowsController, type: :controller do
  let(:session_data) { { spotify_token: 'valid_token', spotify_expires_at: 1.hour.from_now.to_i } }
  let(:client) { instance_double(SpotifyClient) }

  before do
    session[:spotify_token] = session_data[:spotify_token]
    session[:spotify_expires_at] = session_data[:spotify_expires_at]
    allow(SpotifyClient).to receive(:new).and_return(client)
  end

  describe "GET #index" do
    it "assigns @shows and renders index" do
      shows = [OpenStruct.new(id: "1", name: "Show 1")]
      result = OpenStruct.new(items: shows, total: 1)
      allow(client).to receive(:saved_shows).and_return(result)

      get :index
      expect(assigns(:shows)).to eq(shows)
      expect(response).to render_template(:index)
    end

    it "handles errors" do
      allow(client).to receive(:saved_shows).and_raise(SpotifyClient::Error, "Error")
      get :index
      expect(assigns(:error)).to be_present
      expect(assigns(:shows)).to eq([])
    end

    it "handles UnauthorizedError" do
      allow(client).to receive(:saved_shows).and_raise(SpotifyClient::UnauthorizedError)
      get :index
      expect(response).to redirect_to(root_path)
      expect(flash[:alert]).to eq("Session expired. Please sign in again.")
    end
  end

  describe "GET #search" do
    it "assigns @shows and renders search" do
      shows = [OpenStruct.new(id: "1", name: "Show 1")]
      result = OpenStruct.new(items: shows, total: 1)
      allow(client).to receive(:search_shows).and_return(result)

      get :search, params: { query: "query" }
      expect(assigns(:shows)).to eq(shows)
      expect(response).to render_template(:search)
    end

    it "handles errors" do
      allow(client).to receive(:search_shows).and_raise(SpotifyClient::Error, "Error")
      get :search, params: { query: "query" }
      expect(assigns(:error)).to be_present
    end
  end

  describe "POST #create" do
    it "saves show and redirects" do
      allow(client).to receive(:save_shows).and_return(true)
      allow(client).to receive(:clear_user_cache)

      post :create, params: { id: "1" }
      expect(response).to redirect_to(saved_shows_path)
      expect(flash[:notice]).to be_present
    end

    it "handles errors" do
      allow(client).to receive(:save_shows).and_raise(SpotifyClient::Error, "Error")
      post :create, params: { id: "1" }
      expect(response).to redirect_to(saved_shows_path)
      expect(flash[:alert]).to be_present
    end
  end

  describe "DELETE #destroy" do
    it "removes show and redirects" do
      allow(client).to receive(:remove_shows).and_return(true)
      allow(client).to receive(:clear_user_cache)

      delete :destroy, params: { id: "1" }
      expect(response).to redirect_to(saved_shows_path)
      expect(flash[:notice]).to be_present
    end

    it "handles errors" do
      allow(client).to receive(:remove_shows).and_raise(SpotifyClient::Error, "Error")
      delete :destroy, params: { id: "1" }
      expect(response).to redirect_to(saved_shows_path)
      expect(flash[:alert]).to be_present
    end
  end
end
