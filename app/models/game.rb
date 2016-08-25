class Game < ActiveRecord::Base

  before_validation :convert_game_length, on: [:create, :update]
  before_validation :generate_name, :generate_blinds, on: :create

  serialize :blinds, Array
  validates :name, :players, :chips,
            :game_length, :round_length, :blinds,
            :first_small_blind, :smallest_denomination, presence: true
  validates :players, :chips,
            :game_length, :round_length,
            :first_small_blind, :smallest_denomination, numericality: { only_integer: true, greater_than: 0 }

  protected

  def round_values(n, denominations)
    # Round to the closest denomination if within 10%
    closest_denom = denominations.min_by { |x| (n-x).abs }
    if (n-closest_denom).abs/closest_denom <= 0.1
      return n.round_to(closest_denom)
    end
    # Round to a roughly reasonable denomination
    denominations.sort.each_with_index do |denomination, i|
      if n < denomination*10
        return n.round_to(denomination)
      end
    end
    return n.round_to(denominations[-1])
  end

  # Convert game_length from hours to minutes
  # Validates to an integer, but is handled as a float in the db
  # This is done to allow users to enter partial hours
  def convert_game_length
    self.game_length = (game_length*60).to_i if game_length
  end

  # Randomly generate an appropriate name
  def generate_name
    names = ["High Card",
             "Ace King",
             "Pair",
             "Two Pair",
             "Three of a Kind",
             "Straight",
             "Flush",
             "Full House",
             "Four of a Kind",
             "Straight Flush",
             "Royal Flush"]
    self.name = names.sample
  end

  def generate_blinds
    if errors.empty?
      # first_small_blind should be configurable
      denominations = [1,5,10,25,50,100,250,500,1000,2000,5000]
      denominations.select! {|denom| denom >= self.smallest_denomination}

      total_chips = players*chips
      number_of_rounds = (self.game_length/round_length)+6
      # http://www.maa.org/book/export/html/115405
      k = (Math::log((total_chips*0.05).abs)-Math::log(first_small_blind.abs))/self.game_length

      blinds = []
      round = 0
      duplicate_errors = nil

      while blinds.length < number_of_rounds
        time = round_length*round
        small_blind = round_values(first_small_blind*(Math::E**(k*time)), denominations)
        if small_blind == blinds[-1]
          duplicate_errors ||= true
        else
          blinds << small_blind
        end
        round += 1
      end
      # Filter blinds larger than the pot
      blinds.select! {|blind| blind < total_chips/3}
      # If duplicate errors occured, adjust round_length to compensate
      if duplicate_errors
        last_blind = blinds.find_index(blinds.min_by { |x| ((total_chips*0.05)-x).abs })
        adjusted_round_length = round_values(self.game_length/last_blind, [1,2,5,10])
        # Promt the user with the option to adjust round_length
        if adjusted_round_length != round_length
          self.round_length = adjusted_round_length
        end
      end
      self.blinds = blinds
    end
  end

end
