class GamesController < ApplicationController

  before_action :require_login, :except => [:index, :show, :leaderboard, :archive]

  def index
    @games = Game.in_progress
    redirect_to new_game_path if @games.empty?
  end

  def show
    @game = Game.find(params[:id])
    @players = @game.players
    @blinds = @game.blinds.map {|small_blind| [small_blind, small_blind*2]}
    @current_blinds = @blinds[@game.round]
    respond_to do |format|
      format.html
      format.json { render json: @game }
    end
  end

  def new
    @game = Game.new
    @users = User.all
    @default_values = {
      game_length: 2.5,
      round_length: 15,
      chips: 2000,
      smallest_denomination: 1,
      first_small_blind: 1,
      buy_in: 10
    }
  end

  def edit
    @game = Game.find(params[:id])
  end

  def create
    game = Game.new(game_params)

    # If we're passed guests during creation
    (params["game"]["guest_ids"] || []).each do |guest|
      game.guests << Guest.find_or_create_by(name: guest)
    end

    if game.save
      flash[:alert] = game.warnings[:duplicates][0]
      redirect_to game_path(game)
    else
      flash[:alert] = game.errors[:blinds][0]
      redirect_to new_game_path
    end
  end

  def update
    game = Game.find(params[:id])

    players_out ||= params[:game][:players_out]

    if players_out
      if players_out[:player_type] == "user"
        user = {game.users.find(players_out[:player_id]) => [players_out[:roundid].to_i, game.players_out.length]}
        new_players_out = game.players_out.merge(user)
      elsif params[:game][:players_out][:player_type] == "guest"
        user = {game.guests.find(players_out[:player_id]) => [players_out[:roundid].to_i, game.players_out.length]}
        new_players_out = game.players_out.merge(user)
      end
      game.update_attribute(:players_out, new_players_out)
    end

    # See if a winner can be declared
    if game.players_out.length == game.number_of_players-1
      winner = (game.players - game.players_out.keys)[0]
      game.winner_id = winner.id
      game.winner_type = winner.class.to_s.downcase
      game.save()
    end

    flash[:alert] = "Problem updating game" unless game.update_attributes(game_params)

    respond_to do |format|
      format.html { redirect_to game_path(game) }
      format.json { render json: game }
    end
  end

  def destroy
    game = Game.find(params[:id])
    game.delete
    redirect_to games_path
  end

  def archive
    @games = Game.completed.includes(:users, :guests)
  end

  def leaderboard
    players = (User.all.includes(:games) + Guest.all.includes(:games)).map do |player|
      if player.games.empty?
        player = nil
      else
        player = {player: player, wins: Game.winner(player).length, win_perc: (Game.winner(player).length/player.games.length.to_f)*100 }
      end
    end
    players.select! {|player| !player.nil?}
    @players = players.sort_by {|player| player[:win_perc]}.reverse
  end

  private
  def game_params
    params.require(:game).permit({:user_ids => []},
                                 :game_length, :round_length, :buy_in, :round,
                                 :chips, :first_small_blind, :smallest_denomination)
  end

  def require_login
    unless user_signed_in?
      flash[:alert] = "You must log in to continue"
      redirect_to new_user_session_path
    end
  end


end
