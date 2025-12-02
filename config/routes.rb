Rails.application.routes.draw do
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  # Defines the root path route ("/")
  # root "posts#index"
  get "/dashboard", to: "pages#dashboard", as: :dashboard
  get "/top-artists", to: "pages#top_artists", as: :top_artists
  get "/home", to: "pages#home", as: :home
  get "/view-profile", to: "pages#view_profile", as: :view_profile
  get "/clear", to: "pages#clear", as: :clear
  root "pages#home"

  # Callback from Spotify
  match "/auth/spotify/callback", to: "sessions#create", via: %i[get post]
  get    "/auth/failure",         to: "sessions#failure"
  get    "/login",                to: redirect("/auth/spotify"), as: :login
  delete "/logout", to: "sessions#destroy", as: :logout

  resources :artist_follows, only: [ :create, :destroy ], param: :spotify_id

  # GET /top_tracks (Merged from both branches)
  get "/top_tracks", to: "top_tracks#index", as: :top_tracks
  post "/top_tracks/hide", to: "top_tracks#hide", as: :hide_top_track
  post "/top_tracks/unhide", to: "top_tracks#unhide", as: :unhide_top_track

  # Playlists (Merged from both branches)
  post "/create_playlist", to: "playlists#create", as: :create_playlist
  post "/create_playlist_from_recommendations", to: "playlists#create_from_recommendations", as: :create_playlist_from_recommendations

  # Get Recommendations
  get  "recommendations",        to: "recommendations#recommendations",   as: :recommendations

  # Saved Shows & Episodes (From your feature branch)
  resources :saved_shows, only: [ :index, :create, :destroy ] do
    member do
      post :recommendation
      post :similar
    end
    collection do
      get :search
      get :bulk_recommendations
      post :bulk_save
    end
  end

  resources :saved_episodes, only: [ :index, :create, :destroy ] do
    member do
      post :summarize
    end
    collection do
      get :search
      get :bulk_recommendations
      post :bulk_save
    end
  end
end
