class SavedEpisodesController < ApplicationController
  before_action :require_spotify_auth!

  def index
    client = SpotifyClient.new(session: session)
    @page = (params[:page] || 1).to_i
    @limit = 5
    offset = (@page - 1) * @limit

    begin
      result = client.saved_episodes(limit: @limit, offset: offset)
      @episodes = result.items
      @total = result.total
      @total_pages = (@total.to_f / @limit).ceil
    rescue SpotifyClient::UnauthorizedError
      redirect_to root_path, alert: "Session expired. Please sign in again."
    rescue SpotifyClient::Error => e
      Rails.logger.error "Spotify error: #{e.message}"
      @error = "Could not load saved episodes."
      @episodes = []
      @total = 0
      @total_pages = 0
    end
  end

  def destroy
    client = SpotifyClient.new(session: session)
    episode_id = params[:id]

    begin
      client.remove_episodes([episode_id])
      client.clear_user_cache
      redirect_to saved_episodes_path, notice: "Episode removed from your library."
    rescue SpotifyClient::Error => e
      Rails.logger.error "Spotify error: #{e.message}"
      redirect_to saved_episodes_path, alert: "Could not remove episode."
    end
  end

  def search
    @query = params[:query]
    @episodes = []
    @page = (params[:page] || 1).to_i
    @limit = 5
    offset = (@page - 1) * @limit
    
    if @query.present?
      client = SpotifyClient.new(session: session)
      begin
        result = client.search_episodes(@query, limit: @limit, offset: offset)
        @episodes = result.items
        @total = result.total
        @total_pages = (@total.to_f / @limit).ceil
      rescue SpotifyClient::Error => e
        Rails.logger.error "Spotify error: #{e.message}"
        @error = "Could not search for episodes."
        @total = 0
        @total_pages = 0
      end
    end
  end

  def create
    client = SpotifyClient.new(session: session)
    episode_id = params[:id]

    begin
      client.save_episodes([episode_id])
      client.clear_user_cache
      redirect_to saved_episodes_path, notice: "Episode saved to your library."
    rescue SpotifyClient::Error => e
      Rails.logger.error "Spotify error: #{e.message}"
      redirect_to saved_episodes_path, alert: "Could not save episode."
    end
  end
end
