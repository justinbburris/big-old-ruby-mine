# f + typo = no direction
# directional typos should be handled
# attack players
# Replace screen instead of drawing more
# client/sever
# active turn battle
# cool intro

module MineObject
  attr_reader :position

  def mineable?
    false
  end
end

class Game
  STATE_PLAYING = 'playing'
  STATE_DEATH = 'death'
  STATE_WIN = 'win'
  WIN_SCORE = 70
  FOG_OF_WAR = true

  def initialize
    @mine = Mine.new
    @players = PlayerManager.new(2)
    @rubies = RubyManager.new({seeded_positions: @players.position_keys,
                               num_normal_rubies: 25,
                               num_big_ole_rubies: 1})
    @dirt = DirtManager.new
    @dirt.fill_mine(@mine)
    @mine.place_objects(@players)
    @mine.place_objects(@rubies)
    @current_player = @players.next_player
    @game_state = STATE_PLAYING
    puts @mine.prospect(@current_player)

    while(@game_state == STATE_PLAYING)
      ask_and_move
      if(@current_player.health <= 0)
        @game_state = STATE_DEATH
      end

      if(@current_player.score >= WIN_SCORE)
         @game_state = STATE_WIN
      end

      if(@game_state == STATE_PLAYING)
        @current_player = @players.next_player
        puts @mine.prospect(@current_player)
      end
    end

    if(@game_state == STATE_DEATH)
      puts "Player #{@current_player.display_id} loses. Game over man, game over."
    elsif(@game_state == STATE_WIN)
      puts "Player #{@current_player.display_id} did it! They really did it! They've sucessfully prospected the crap out of the Big Ole Ruby Mine"
    end

    puts ''
  end

  def self.position_key(pos)
    "#{pos[0]}#{pos[1]}"
  end

  private

  def ask_and_move
    puts "Player: player #{@current_player.display_id}"
    puts "Health: #{@current_player.health}"
    puts "Score: #{@current_player.score} of #{WIN_SCORE}"
    puts "Your move:"
    puts "You may move: #{@players.available_moves(@current_player).join(', ')}"
    puts "You may face: #{@current_player.available_facings.join(', ')}"
    action = gets.strip

    if action[0] == 'f'
      change_tunneler(action[1..-1])
    elsif valid_move?(action)
      make_move(action)
      if @current_player.left_home
        @mine.place_object(@current_player.homebase)
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

class Tunnel
  ICON = "\u2591\u2591"
  include ::MineObject

  def initialize(position)
    @position = position
  end

  def icon
    ICON
  end

end

class Mine
  MINE_SIZE = 12

  RUBY = '<>'
  BIG_OLE_RUBY = '{}'
  HORIZONTAL = '-'
  VERTICAL = '|'

  attr_reader :mine

  def initialize
    @mine = Array.new(MINE_SIZE)
    @mine = @mine.map { |level| level = Array.new(MINE_SIZE, '') }
  end

  def each_with_index
    @mine.each_with_index do |row, index|
      yield row, index
    end
  end

  def mineable?(position)
    if(item_at_position(*position).mineable?)
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
    set_space(object, *object.position)
  end

  def remove_player(player)
    tunnel = Tunnel.new(player.position.clone)
    place_object(tunnel)
  end

  def set_space(item, x, y)
    @mine[x][y] = item
  end

  def item_at_position(y, x)
    @mine[y][x]
  end

  def prospect(player)
    mine_map = [horizontal_edge]
    mine_map << @mine.map do |row|
      row.reduce(':') do |column, object|
        if(Game::FOG_OF_WAR && object != player && ! player.position_visible?(@mine, object.position))
          column << " \u2588\u2588"
        else
          column << " #{object.icon}"
        end
      end
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

class Homebase
  include ::MineObject

  def initialize(player_id, position)
    @id = player_id
    @position = position
  end

  def icon
    "@#{@id}"
  end

end

class Player
  include ::MineObject

  UP = 'up'
  DOWN = 'down'
  LEFT = 'left'
  RIGHT = 'right'
  DIRECTIONS = [UP, DOWN, LEFT, RIGHT]

  attr_reader :id, :health, :score, :homebase
  attr_accessor :tunneler, :left_home

  def initialize(player_id, position)
    @tunneler = RIGHT
    @id = player_id
    @position = position
    @homebase = Homebase.new(@id, position.clone)
    @left_home = false
    @health = 50
    @cart = []
    @score = 0
  end

  def position_visible?(mine, position)
    if visible_tunnel?(mine, position) ||
        directly_ahead?(position) ||
      position == @homebase.position
      true
    else
      false
    end
  end

  def display_id
    "#{id + 1}"
  end

  def directly_ahead?(position)
    tunnel_y = position[0]
    tunnel_x = position[1]
    y = @position[0]
    x = @position[1]

    if(tunnel_x == x && y - 1 == tunnel_y)
      true
    elsif(tunnel_x == x && y + 1 == tunnel_y)
      true
    elsif(tunnel_y == y && x - 1 == tunnel_x)
      true
    elsif(tunnel_y == y && x + 1 == tunnel_x)
      true
    else
      false
    end
  end

  def visible_tunnel?(mine, position)
    tunnel_y = position[0]
    tunnel_x = position[1]
    y = @position[0]
    x = @position[1]

    tunnels_all_the_way_down = true
    if(tunnel_x == x && tunnel_y < y) #up
      (y-1).downto(tunnel_y).each do |rpos|
        if mine[rpos][x].class != Tunnel
          tunnels_all_the_way_down = false
        end
      end
      tunnels_all_the_way_down
    elsif(tunnel_x == x && tunnel_y > y) #down
      (y+1...tunnel_y).each do |rpos|
        if mine[rpos][x].class != Tunnel
          tunnels_all_the_way_down = false
        end
      end
      tunnels_all_the_way_down
    elsif(tunnel_y == y && tunnel_x < x) #left
      (x-1).downto(tunnel_x).each do |cpos|
        if mine[y][cpos].class != Tunnel
          tunnels_all_the_way_down = false
        end
      end
      tunnels_all_the_way_down
    elsif(tunnel_y == y && tunnel_x > x) #right
      (x+1...tunnel_x).each do |cpos|
        if mine[y][cpos].class != Tunnel
          tunnels_all_the_way_down = false
        end
      end
      tunnels_all_the_way_down
    else
      false
    end
  end

  def home?(position)
    @homebase.position == position
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
    @left_home = @position == @homebase.position
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

class Dirt
  include ::MineObject

  ICON_NORMAL = "XX"

  def initialize(position)
    @position = position
  end

  def icon
    ICON_NORMAL
  end
end

class DirtManager
  def initialize
    @dirt = []
  end

  def fill_mine(mine)
    mine.each_with_index do |row, rindex|
      row.each_with_index do |space, cindex|
        if(space).empty?
          dirt = Dirt.new([rindex, cindex])
          @dirt << dirt
          mine.place_object(dirt)
        end
      end
    end
  end
end

class TheElusiveRuby
  include ::MineObject

  ICON_NORMAL = "\u25BD "
  ICON_BIG_OLE = "\u25BC "

  VALUE_NORMAL = 10
  VALUE_BIG_OLE = 50

  KIND_NORMAL = 'normal'
  KIND_BIG_OLE = 'big ole ruby'
  KINDS = %w{KIND_NORMAL, KIND_BIG_OLE}

  attr_reader :value

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
    @current_player = num_players - 1
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

  def next_player
    if @current_player == @players.length - 1
      @current_player = 0
    else
      @current_player = @current_player + 1
    end

    @players[@current_player]
  end

  def each
    @players.each { |player| yield player }
  end

  def position_keys
    @players.map { |player| Game.position_key(player.position) }
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

  def ruby_at_position(position)
    @rubies.find { |ruby| ruby.position == position }
  end

  private

  def ruby_positions
    @rubies.map(&:position)
  end
end

Game.new
