class SavedShowsController < ApplicationController
  before_action :require_spotify_auth!

  def index
    client = SpotifyClient.new(session: session)
    @page = (params[:page] || 1).to_i
    @limit = 5
    offset = (@page - 1) * @limit

    begin
      result = client.saved_shows(limit: @limit, offset: offset)
      @shows = result.items
      @total = result.total
      @total_pages = (@total.to_f / @limit).ceil
    rescue SpotifyClient::UnauthorizedError
      redirect_to root_path, alert: "Session expired. Please sign in again."
    rescue SpotifyClient::Error => e
      Rails.logger.error "Spotify error: #{e.message}"
      @error = "Could not load saved shows."
      @shows = []
      @total = 0
      @total_pages = 0
    end
  end

  def destroy
    client = SpotifyClient.new(session: session)
    show_id = params[:id]

    begin
      client.remove_shows([show_id])
      client.clear_user_cache
      redirect_to saved_shows_path, notice: "Show removed from your library."
    rescue SpotifyClient::Error => e
      Rails.logger.error "Spotify error: #{e.message}"
      redirect_to saved_shows_path, alert: "Could not remove show."
    end
  end

  def search
    @query = params[:query]
    @shows = []
    @page = (params[:page] || 1).to_i
    @limit = 5
    offset = (@page - 1) * @limit
    
    if @query.present?
      client = SpotifyClient.new(session: session)
      begin
        result = client.search_shows(@query, limit: @limit, offset: offset)
        @shows = result.items
        @total = result.total
        @total_pages = (@total.to_f / @limit).ceil
      rescue SpotifyClient::Error => e
        Rails.logger.error "Spotify error: #{e.message}"
        @error = "Could not search for shows."
        @total = 0
        @total_pages = 0
      end
    end
  end

  def create
    client = SpotifyClient.new(session: session)
    show_id = params[:id]

    begin
      client.save_shows([show_id])
      client.clear_user_cache
      redirect_to saved_shows_path, notice: "Show saved to your library."
    rescue SpotifyClient::Error => e
      Rails.logger.error "Spotify error: #{e.message}"
      redirect_to saved_shows_path, alert: "Could not save show."
    end
  end
end
