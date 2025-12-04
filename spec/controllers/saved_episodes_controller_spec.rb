require 'rails_helper'

RSpec.describe SavedEpisodesController, type: :controller do
  let(:session_data) { { 'credentials' => { 'token' => 'fake_token' }, 'info' => { 'id' => 'user_id' } } }
  let(:spotify_client) { instance_double(SpotifyClient) }
  let(:openai_service) { instance_double(OpenaiService) }

  before do
    session[:spotify_user] = session_data
    session[:spotify_token] = 'fake_token'
    allow(SpotifyClient).to receive(:new).and_return(spotify_client)
    allow(OpenaiService).to receive(:new).and_return(openai_service)
  end

  # --- New Context: Authentication Guard ---
  context 'when user is not logged in' do
    before do
      session[:spotify_token] = nil
    end

    it 'redirects to root for index' do
      get :index
      expect(response).to redirect_to(root_path)
      expect(flash[:alert]).to eq("Please sign in with Spotify first.")
    end

    it 'redirects to root for create' do
      post :create, params: { id: '1' }
      expect(response).to redirect_to(root_path)
    end
  end
  # -----------------------------------------

  describe 'GET #index' do
    it 'assigns @episodes and renders index with standard limit' do
      episodes = [ double(name: 'Ep 1', show_name: 'Show A') ]
      result = double(items: episodes, total: 1)

      # Expect limit 5 for default page
      expect(spotify_client).to receive(:saved_episodes).with(limit: 5, offset: 0).and_return(result)

      get :index
      expect(assigns(:episodes)).to eq(episodes)
      expect(assigns(:limit)).to eq(5)
      expect(response).to render_template(:index)
    end

    it 'groups episodes by show and uses higher limit' do
      episodes = [ double(name: 'Ep 1', show_name: 'Show A') ]
      result = double(items: episodes, total: 1)

      # Expect limit 50 when grouping
      expect(spotify_client).to receive(:saved_episodes).with(limit: 50, offset: 0).and_return(result)

      get :index, params: { group_by: 'show' }
      expect(assigns(:grouped_episodes)).to be_present
      expect(assigns(:limit)).to eq(50)
    end

    it 'handles SpotifyClient::UnauthorizedError by redirecting to root' do
      allow(spotify_client).to receive(:saved_episodes).and_raise(SpotifyClient::UnauthorizedError.new("Expired"))
      get :index
      expect(response).to redirect_to(root_path)
      expect(flash[:alert]).to eq("Session expired. Please sign in again.")
    end

    it 'handles generic Spotify errors' do
      allow(spotify_client).to receive(:saved_episodes).and_raise(SpotifyClient::Error.new("Error"))
      get :index
      expect(assigns(:error)).to be_present
      expect(assigns(:episodes)).to eq([])
    end
  end

  describe 'GET #search' do
    let(:result_obj) { double(items: [ double(name: 'Ep 1') ], total: 1) }

    context "when query is missing" do
      it "initializes empty results and skips search" do
        expect(spotify_client).not_to receive(:search_episodes)
        get :search
        expect(assigns(:episodes)).to eq([])
        expect(assigns(:query)).to be_nil
      end
    end

    context "when AI search is forced" do
      it "uses OpenaiService to optimize query" do
        allow(openai_service).to receive(:generate_search_query).with("messy query").and_return("clean query")
        expect(spotify_client).to receive(:search_episodes).with("clean query", any_args).and_return(result_obj)

        get :search, params: { query: "messy query", ai_search: "true" }
      end
    end

    context "when AI search is implicitly triggered by long query" do
      it "uses OpenaiService for queries > 3 words" do
        long_query = "one two three four"
        allow(openai_service).to receive(:generate_search_query).with(long_query).and_return("optimized")
        expect(spotify_client).to receive(:search_episodes).with("optimized", any_args).and_return(result_obj)

        get :search, params: { query: long_query }
      end
    end

    context "when AI search is NOT triggered" do
      it "uses raw query for short queries" do
        short_query = "one two"
        expect(spotify_client).to receive(:search_episodes).with(short_query, any_args).and_return(result_obj)
        expect(openai_service).not_to receive(:generate_search_query)

        get :search, params: { query: short_query }
      end

      it "uses raw query when ai_search is explicitly false" do
        long_query = "one two three four"
        # Even though query is long, explicit false should disable AI
        expect(spotify_client).to receive(:search_episodes).with(long_query, any_args).and_return(result_obj)
        expect(openai_service).not_to receive(:generate_search_query)

        get :search, params: { query: long_query, ai_search: "false" }
      end
    end

    it 'handles Spotify errors' do
      allow(spotify_client).to receive(:search_episodes).and_raise(SpotifyClient::Error.new("Error"))
      get :search, params: { query: 'query' }
      expect(assigns(:error)).to be_present
      expect(assigns(:total)).to eq(0)
    end
  end

  describe 'POST #summarize' do
    let(:episode) { double(name: 'Ep 1', description: 'Desc') }

    before do
      allow(spotify_client).to receive(:get_episode).with('1').and_return(episode)
      allow(openai_service).to receive(:summarize_episode).and_return('Summary')
    end

    it 'summarizes an episode via Turbo Stream' do
      post :summarize, params: { id: '1' }, format: :turbo_stream
      expect(assigns(:summary)).to eq('Summary')
      expect(response.media_type).to eq Mime[:turbo_stream]
    end

    it 'summarizes an episode via HTML redirect' do
      post :summarize, params: { id: '1' }, format: :html
      expect(response).to redirect_to(saved_episodes_path)
      expect(flash[:notice]).to eq("Summary generated.")
    end

    it 'handles Spotify errors' do
      allow(spotify_client).to receive(:get_episode).and_raise(SpotifyClient::Error.new("Error"))
      post :summarize, params: { id: '1' }, format: :turbo_stream
      expect(response).to redirect_to(saved_episodes_path)
      expect(flash[:alert]).to be_present
    end
  end

  describe 'GET #bulk_recommendations' do
    it 'generates bulk recommendations' do
      saved = [ double(name: 'Saved 1') ]
      allow(spotify_client).to receive(:saved_episodes).and_return(double(items: saved))
      allow(openai_service).to receive(:generate_bulk_recommendations).and_return([ 'Rec 1', 'Rec 2' ])

      rec_ep = double(name: 'Rec 1')
      # Mock Rec 1 found, Rec 2 not found to test both branches of "if results.items.any?"
      allow(spotify_client).to receive(:search_episodes).with('Rec 1', limit: 1).and_return(double(items: [ rec_ep ]))
      allow(spotify_client).to receive(:search_episodes).with('Rec 2', limit: 1).and_return(double(items: []))

      get :bulk_recommendations
      expect(assigns(:recommendations)).to include(rec_ep)
      expect(assigns(:recommendations).size).to eq(1)
    end

    it 'handles empty saved episodes' do
      allow(spotify_client).to receive(:saved_episodes).and_return(double(items: []))
      get :bulk_recommendations
      expect(assigns(:error)).to eq("You need to save some episodes first!")
      expect(assigns(:recommendations)).to eq([])
    end

    it 'handles Spotify errors' do
      allow(spotify_client).to receive(:saved_episodes).and_raise(SpotifyClient::Error.new("Error"))
      get :bulk_recommendations
      expect(assigns(:error)).to eq("Could not generate recommendations.")
    end
  end

  describe 'POST #bulk_save' do
    it 'saves multiple episodes when IDs are present' do
      expect(spotify_client).to receive(:save_episodes).with([ '1', '2' ])
      expect(spotify_client).to receive(:clear_user_cache)

      post :bulk_save, params: { ids: [ '1', '2' ] }
      expect(response).to redirect_to(saved_episodes_path)
      expect(flash[:notice]).to include("Saved 2 episodes")
    end

    it 'redirects with alert when IDs are missing' do
      post :bulk_save, params: { ids: [] }
      expect(response).to redirect_to(saved_episodes_path)
      expect(flash[:alert]).to eq("No episodes selected.")
    end

    it 'handles Spotify errors during save' do
      allow(spotify_client).to receive(:save_episodes).and_raise(SpotifyClient::Error.new("Error"))
      post :bulk_save, params: { ids: [ '1', '2' ] }
      expect(response).to redirect_to(saved_episodes_path)
      expect(flash[:alert]).to eq("Could not save episodes.")
    end
  end

  describe 'POST #create' do
    it 'saves an episode' do
      expect(spotify_client).to receive(:save_episodes).with([ '1' ])
      expect(spotify_client).to receive(:clear_user_cache)
      post :create, params: { id: '1' }
      expect(response).to redirect_to(saved_episodes_path)
      expect(flash[:notice]).to eq("Episode saved to your library.")
    end

    it 'handles Spotify errors' do
      allow(spotify_client).to receive(:save_episodes).and_raise(SpotifyClient::Error.new("Error"))
      post :create, params: { id: '1' }
      expect(response).to redirect_to(saved_episodes_path)
      expect(flash[:alert]).to eq("Could not save episode.")
    end
  end

  describe 'DELETE #destroy' do
    it 'removes an episode' do
      expect(spotify_client).to receive(:remove_episodes).with([ '1' ])
      expect(spotify_client).to receive(:clear_user_cache)
      delete :destroy, params: { id: '1' }
      expect(response).to redirect_to(saved_episodes_path)
      expect(flash[:notice]).to eq("Episode removed from your library.")
    end

    it 'handles Spotify errors' do
      allow(spotify_client).to receive(:remove_episodes).and_raise(SpotifyClient::Error.new("Error"))
      delete :destroy, params: { id: '1' }
      expect(response).to redirect_to(saved_episodes_path)
      expect(flash[:alert]).to eq("Could not remove episode.")
    end
  end
end
