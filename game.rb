# player position
# change players
# attack players
# Replace screen instead of drawing more
# fog of war
# client/sever
# active turn battle
# cool intro

class Game
  STATE_PLAYING = 'playing'
  STATE_DEATH = 'death'
  STATE_WIN = 'win'
  WIN_SCORE = 100

  def initialize
    @mine = Mine.new
    @players = PlayerManager.new(2)
    @rubies = RubyManager.new({seeded_positions: @players.position_keys,
                               num_normal_rubies: 25,
                               num_big_ole_rubies: 1})
    @mine.place_objects(@players)
    @mine.place_objects(@rubies)
    @current_player = @players[0]
    @game_state = STATE_PLAYING

    while(@game_state == STATE_PLAYING)
      puts @mine.prospect
      ask_and_move

      if(@current_player.health <= 0)
        @game_state = STATE_DEATH
      end

      if(@current_player.score >= WIN_SCORE)
         @game_state = STATE_WIN
      end
    end

    if(@game_state == STATE_DEATH)
      puts "Game over man, game over."
    elsif(@game_state == STATE_WIN)
      puts "You did it! You really did it! You've sucessfully prospected the crap out of the Big Ole Ruby Mine"
    end
  end

  def self.position_key(pos)
    "#{pos[0]}#{pos[1]}"
  end

  private

  def ask_and_move
    puts "Current Health: #{@current_player.health}"
    puts "Your move:"
    puts "You may move: #{@players.available_moves(@current_player).join(', ')}"
    puts "You may face: #{@current_player.available_facings.join(', ')}"
    action = gets.strip

    if action[0] == 'f'
      change_tunneler(action[1..-1])
    elsif valid_move?(action)
      make_move(action)
      if @current_player.left_home
        @mine.set_space(@current_player.homebase_icon, *@current_player.homebase)
        @current_player.left_home = false
      end
    end
  end

  def make_move(direction)
    position = @current_player.position.clone
    @mine.remove_player(@current_player)
    @current_player.move(direction)
    @mine.place_object(@current_player)
  end

  def change_tunneler(direction)
    @current_player.tunneler = direction
    @mine.place_object(@current_player)
  end

  # There's some serious conflation of concerns here
  def valid_move?(move)
    new_position = @current_player.position_after_move(move)

    if(@players.available_moves(@current_player).include? move)
      if(@mine.mineable?(new_position) && @current_player.tunneler != move)
        @current_player.damage(5, "bumping into the wall")
        return false
      elsif(@rubies.ruby_at_position(new_position))
        puts "Found a ruby! Take it home!"
        @current_player.load_up(@rubies.ruby_at_position(new_position))
      elsif(@current_player.home?(new_position))
        @current_player.unload_ruby
      end
      return true
    end

    false
  end
end

class Mine
  MINE_SIZE = 12
  MINEABLE = 'XX'
  RUBY = '<>'
  BIG_OLE_RUBY = '{}'
  TUNNEL = '  '
  HORIZONTAL = '-'
  VERTICAL = '|'

  attr_reader :mine

  def initialize
    @mine = Array.new(MINE_SIZE)
    @mine = @mine.map { |level| level = Array.new(MINE_SIZE, MINEABLE) }
    @mine[0][1] = TUNNEL
    @mine[1][1] = TUNNEL
  end

  def mineable?(position)
    if(item_at_position(*position) == MINEABLE)
      true
    else
      false
    end
  end

  def place_objects(objects)
    objects.each do |object|
      place_object(object)
    end
  end

  def place_object(object)
    set_space(object.icon, *object.position)
  end

  def remove_player(player)
    set_space(TUNNEL, *player.position)
  end

  def set_space(item, x, y)
    @mine[x][y] = item
  rescue
    binding.pry
  end

  def item_at_position(y, x)
    @mine[y][x]
  end

  def prospect
    mine_map = [horizontal_edge]
    mine_map << @mine.map do |level|
      level.reduce('>') { |x, contents| x << " #{contents}" }
    end
    mine_map << [horizontal_edge]
  end

  private

  def horizontal_edge
    space_width = 2
    padding = 1
    edge_length = 1 + (MINE_SIZE * (space_width + padding))

    edge_length.times.reduce('') { |edge| edge << HORIZONTAL }
  end
end

class Player
  UP = 'up'
  DOWN = 'down'
  LEFT = 'left'
  RIGHT = 'right'
  DIRECTIONS = [UP, DOWN, LEFT, RIGHT]

  attr_reader :position, :id, :health, :score, :homebase
  attr_accessor :tunneler, :left_home

  def initialize(player_id, position)
    @tunneler = RIGHT
    @id = "#{player_id}"
    @position = position
    @homebase = position.clone
    @left_home = false
    @health = 50
    @cart = []
    @score = 0
  end

  def home?(position)
    @homebase == position
  end

  def load_up(ruby)
    @cart << ruby
  end

  def unload_ruby
    num_rubies = @cart.length
    @cart.pop(num_rubies).each do |ruby|
      @score += ruby.value
    end

    puts "#{num_rubies} ruby GET!"
  end

  def damage(amount, reason)
    puts "Ouch! #{amount} damage for #{reason}"
    @health = @health - amount
  end

  def move(direction)
    @left_home = @position == @homebase
    case(direction)
    when UP
      move_up
    when DOWN
      move_down
    when LEFT
      move_left
    when RIGHT
      move_right
    end
  end

  def available_facings
    DIRECTIONS.map { |direction| "f#{direction}" }
  end

  def available_moves
    moves = []
    moves << UP if(up(1) >= 0)
    moves << DOWN if(down(1) < Mine::MINE_SIZE)
    moves << LEFT if(left(1) >= 0)
    moves << RIGHT if(right(1) < Mine::MINE_SIZE)

    moves
  end

  def position_after_move(move)
    case(move)
    when UP
      [up(1), @position[1]]
    when DOWN
      [down(1), @position[1]]
    when LEFT
      [@position[0], left(1)]
    when RIGHT
      [@position[0], right(1)]
    end
  end

  def up(magnitude)
    @position[0] - 1
  end

  def down(magnitude)
    @position[0] + 1
  end

  def left(magnitude)
    @position[1] - 1
  end

  def right(magnitude)
    @position[1] + 1
  end

  def icon
    if @tunneler == LEFT
      "#{tunneler_symbol}#{cart_icon}"
    else
      "#{cart_icon}#{tunneler_symbol}"
    end
  end

  def homebase_icon
    "#{id}#{id}"
  end

  private

  def cart_icon
    if @cart.empty?
      "="
    else
      "~"
    end
  end

  def tunneler_symbol
    case(@tunneler)
    when UP
      "^"
    when DOWN
      "v"
    when LEFT
      "<"
    when RIGHT
      ">"
    end

  end

  def move_up
    @position[0] = up 1
  end

  def move_down
    @position[0] = down 1
  end

  def move_left
    @position[1] = left 1
  end

  def move_right
    @position[1] = right 1
  end
end

class TheElusiveRuby
  ICON_NORMAL = "\u25BD "
  ICON_BIG_OLE = "\u25BC "

  VALUE_NORMAL = 10
  VALUE_BIG_OLE = 100

  KIND_NORMAL = 'normal'
  KIND_BIG_OLE = 'big ole ruby'
  KINDS = %w{KIND_NORMAL, KIND_BIG_OLE}

  attr_reader :position, :value

  def initialize(kind, position)
    @kind = kind
    @value = VALUE_NORMAL
    @position = position
  end

  def icon
    # impassible? \u2042
    case(@kind)
    when KIND_NORMAL
      ICON_NORMAL
    when KIND_BIG_OLE
      ICON_BIG_OLE
    end
  end

  def kind_from_icon(icon)
    case(icon)
    when ICON_NORMAL
      VALUE_NORMAL
    when ICON_BIG_OLE
      VALUE_NORMAL
    end
  end
end

module Positional
  def generate_random_position(positions)
    pos = random_position
    position_key = Game.position_key(pos)

    while(positions.include?(position_key))
      pos = random_position
      position_key = Game.position_key(pos)
    end
    pos
  end

  def random_position
    [rand(Mine::MINE_SIZE), rand(Mine::MINE_SIZE)]
  end
end

class PlayerManager
  include ::Positional

  def initialize(num_players)
    @players = []
    num_players.times do |id|
      position = [id, 0]
      @players << Player.new(id, generate_random_position(player_positions))
    end
  end

  def available_moves(player)
    player.available_moves.reject do |move|
      position = player.position_after_move(move)
      (players_at_position(position) & other_players(player)).empty? ? false : true
    end
  end

  def [](index)
    @players[index]
  end

  def each
    @players.each { |player| yield player }
  end

  private

  def player_positions
    @players.map(&:position)
  end

  def players_at_position(position)
    @players.find_all { |player| player.position == position }
  end

  def other_players(player)
    @players.reject { |possible_player| possible_player.id == player.id }
  end
end

class RubyManager
  include ::Positional

  def initialize(seeded_positions: [], num_normal_rubies: 0, num_big_ole_rubies: 0)
    @rubies = []

    num_normal_rubies.times do
      position = generate_random_position(seeded_positions + ruby_positions)
      @rubies << TheElusiveRuby.new(TheElusiveRuby::KIND_NORMAL, position)
    end

    num_big_ole_rubies.times do
      position = generate_random_position(seeded_positions + ruby_positions)
      @rubies << TheElusiveRuby.new(TheElusiveRuby::KIND_BIG_OLE, position)
    end
  end

  # def [](index)
  #   @rubies[index]
  # end
  #
  def each
    @rubies.each { |ruby| yield ruby }
  end

  def position_keys
    @players.map { |player| Game.position_key(player.position) }
  end

  def ruby_at_position(position)
    @rubies.find { |ruby| ruby.position == position }
  end

  private

  def ruby_positions
    @rubies.map(&:position)
  end
end