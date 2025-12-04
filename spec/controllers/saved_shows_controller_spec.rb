require 'rails_helper'

RSpec.describe SavedShowsController, type: :controller do
  let(:session_data) { { 'credentials' => { 'token' => 'fake_token' }, 'info' => { 'id' => 'user_id' } } }
  let(:spotify_client) { instance_double(SpotifyClient) }
  let(:openai_service) { instance_double(OpenaiService) }

  before do
    session[:spotify_user] = session_data
    session[:spotify_token] = 'fake_token'
    allow(SpotifyClient).to receive(:new).and_return(spotify_client)
    allow(OpenaiService).to receive(:new).and_return(openai_service)
  end

  describe 'GET #index' do
    it 'assigns @shows and renders index' do
      shows = [ double(name: 'Show 1') ]
      result = double(items: shows, total: 1)
      allow(spotify_client).to receive(:saved_shows).and_return(result)

      get :index
      expect(assigns(:shows)).to eq(shows)
      expect(response).to render_template(:index)
    end

    it 'handles Spotify errors' do
      allow(spotify_client).to receive(:saved_shows).and_raise(SpotifyClient::Error.new("Error"))
      get :index
      expect(assigns(:error)).to be_present
      expect(assigns(:shows)).to eq([])
    end
  end

  describe 'GET #search' do
    it 'searches for shows without AI' do
      shows = [ double(name: 'Show 1') ]
      result = double(items: shows, total: 1)
      allow(spotify_client).to receive(:search_shows).with('query', any_args).and_return(result)

      get :search, params: { query: 'query' }
      expect(assigns(:shows)).to eq(shows)
    end

    it 'searches for shows with AI' do
      allow(openai_service).to receive(:generate_search_query).and_return('optimized')
      shows = [ double(name: 'Show 1') ]
      result = double(items: shows, total: 1)
      allow(spotify_client).to receive(:search_shows).with('optimized', any_args).and_return(result)

      get :search, params: { query: 'complex query', ai_search: 'true' }
      expect(assigns(:shows)).to eq(shows)
    end
    it 'handles Spotify errors' do
      allow(spotify_client).to receive(:search_shows).and_raise(SpotifyClient::Error.new("Error"))
      get :search, params: { query: 'query' }
      expect(assigns(:error)).to be_present
    end
  end

  describe 'POST #recommendation' do
    it 'generates a recommendation' do
      show = double(name: 'Show 1', publisher: 'Pub')
      allow(spotify_client).to receive(:get_show).and_return(show)
      allow(spotify_client).to receive(:saved_shows).and_return(double(items: []))
      allow(openai_service).to receive(:generate_recommendation).and_return('Rec')

      post :recommendation, params: { id: '1' }, format: :turbo_stream
      expect(assigns(:recommendation)).to eq('Rec')
    end

    it 'handles Spotify errors' do
      allow(spotify_client).to receive(:get_show).and_raise(SpotifyClient::Error.new("Error"))
      post :recommendation, params: { id: '1' }, format: :turbo_stream
      expect(response).to redirect_to(saved_shows_path)
      expect(flash[:alert]).to be_present
    end
  end

  describe 'POST #similar' do
    it 'finds similar shows' do
      show = double(name: 'Show 1', publisher: 'Pub')
      allow(spotify_client).to receive(:get_show).and_return(show)
      allow(openai_service).to receive(:suggest_similar_shows).and_return([ 'Sim 1' ])

      sim_show = double(name: 'Sim 1')
      allow(spotify_client).to receive(:search_shows).with('Sim 1', limit: 1).and_return(double(items: [ sim_show ]))

      post :similar, params: { id: '1' }, format: :turbo_stream
      expect(assigns(:similar_shows)).to include(sim_show)
    end

    it 'handles Spotify errors' do
      allow(spotify_client).to receive(:get_show).and_raise(SpotifyClient::Error.new("Error"))
      post :similar, params: { id: '1' }, format: :turbo_stream
      expect(response).to redirect_to(saved_shows_path)
      expect(flash[:alert]).to be_present
    end
  end

  describe 'GET #bulk_recommendations' do
    it 'generates bulk recommendations' do
      saved = [ double(name: 'Saved 1') ]
      allow(spotify_client).to receive(:saved_shows).and_return(double(items: saved))
      allow(openai_service).to receive(:generate_bulk_recommendations).and_return([ 'Rec 1' ])

      rec_show = double(name: 'Rec 1')
      allow(spotify_client).to receive(:search_shows).with('Rec 1', limit: 1).and_return(double(items: [ rec_show ]))

      get :bulk_recommendations
      expect(assigns(:recommendations)).to include(rec_show)
    end

    it 'handles empty saved shows' do
      allow(spotify_client).to receive(:saved_shows).and_return(double(items: []))
      get :bulk_recommendations
      expect(assigns(:error)).to be_present
    end

    it 'handles Spotify errors' do
      allow(spotify_client).to receive(:saved_shows).and_raise(SpotifyClient::Error.new("Error"))
      get :bulk_recommendations
      expect(assigns(:error)).to be_present
    end
  end

  describe 'POST #bulk_save' do
    it 'saves multiple shows' do
      expect(spotify_client).to receive(:save_shows).with([ '1', '2' ])
      expect(spotify_client).to receive(:clear_user_cache)

      post :bulk_save, params: { ids: [ '1', '2' ] }
      expect(response).to redirect_to(saved_shows_path)
    end

    it 'handles Spotify errors' do
      allow(spotify_client).to receive(:save_shows).and_raise(SpotifyClient::Error.new("Error"))
      post :bulk_save, params: { ids: [ '1', '2' ] }
      expect(response).to redirect_to(saved_shows_path)
      expect(flash[:alert]).to be_present
    end
  end

  describe 'POST #create' do
    it 'saves a show' do
      expect(spotify_client).to receive(:save_shows).with([ '1' ])
      expect(spotify_client).to receive(:clear_user_cache)
      post :create, params: { id: '1' }
      expect(response).to redirect_to(saved_shows_path)
    end

    it 'handles Spotify errors' do
      allow(spotify_client).to receive(:save_shows).and_raise(SpotifyClient::Error.new("Error"))
      post :create, params: { id: '1' }
      expect(response).to redirect_to(saved_shows_path)
      expect(flash[:alert]).to be_present
    end
  end

  describe 'DELETE #destroy' do
    it 'removes a show' do
      expect(spotify_client).to receive(:remove_shows).with([ '1' ])
      expect(spotify_client).to receive(:clear_user_cache)
      delete :destroy, params: { id: '1' }
      expect(response).to redirect_to(saved_shows_path)
    end

    it 'handles Spotify errors' do
      allow(spotify_client).to receive(:remove_shows).and_raise(SpotifyClient::Error.new("Error"))
      delete :destroy, params: { id: '1' }
      expect(response).to redirect_to(saved_shows_path)
      expect(flash[:alert]).to be_present
    end
  end
end
