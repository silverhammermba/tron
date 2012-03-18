#!/usr/bin/env ruby

require 'curses'
require 'xbox'

class Curses::Window
	def safe_print y, x, string
		return nil unless (0...lines) === y and (0...columns) === x
		print y, x, string
	end
end

class Player
	def initialize name, worm, dir, color, ch, controller = nil
		@name = name # player name displayed on gameover screen
		@worm = [worm] # snake positions
		@last = []
		send(dir) # set the initial direction
		@sworm = @worm.dup # starting position for restarting
		@sdir = @dir.dup # starting direction for restarting
		@last = @dir.dup # previous direction, for preventing illegal moves
		@fail = false # if the player has crashed
		@color = color # Curses color pair number
		@ch = ch # character that the worm is made of
		@bind = {} # key bindings
		@controller = controller # joystick
		@ready = false # ready state for restarting
		@wins = 0 # score
	end

	attr_accessor :fail, :color, :bind, :ready, :wins
	attr_reader :name, :controller

	def reset
		@worm = @sworm.dup
		@dir = @sdir.dup
		@last = @dir.dup
		@fail = false
		@ready = false
	end

	def eat_tail i
		return if i % 2 == 1
		if @worm.length > 10 or (@fail and @worm.length > 1)
			Curses.stdscr.print *@worm.shift, ' '
		end
	end

	def print rev = true
		return if @fail
		Curses.stdscr.attron((rev ? 0 : Curses.color_pair(@color)) | Curses::A_BOLD) do
			Curses.stdscr.print *@worm[-1], @ch
		end
		@last = @dir
	end

	def next
		return nil if @fail
		[@worm[-1][0] + @dir[0], @worm[-1][1] + @dir[1]]
	end

	def call ch
		send(@bind[ch]) if @bind[ch]
	end

	def joy
		# deadzone
		if @controller.axis[0] and @controller.axis[1] and @controller.axis[0] ** 2 + @controller.axis[1] ** 2 > 169000000
			case Math.atan2(@controller.axis[1], @controller.axis[0])
			when (-Math::PI/4)..(Math::PI/4)
				right
			when (Math::PI/4)..(Math::PI*3/4)
				down
			when (-Math::PI*3/4)..(-Math::PI/4)
				up
			else
				left
			end
		end
	end

	def up
		@dir = [-1, 0] unless @last[0] == 1
	end
	
	def down
		@dir = [1, 0] unless @last[0] == -1
	end

	def left
		@dir = [0, -1] unless @last[1] == 1
	end

	def right
		@dir = [0, 1] unless @last[1] == -1
	end

	def move
		return if @fail
		print false
		@worm << self.next
		print
	end

	def explode
		return if @fail
		@fail = true
		return Explosion.new @worm[-1]
	end

	def check_collision
		return if @fail
		return Curses.stdscr[*self.next] != 32
	end

end

class Explosion
	def initialize pos
		@pos = pos.dup
		@done = false
		@count = (5 + rand(5)) / 2
	end

	attr_reader :done

	def animate
		Curses.stdscr.attron(Curses.color_pair(4)) do
			Curses.stdscr.safe_print(@pos[0] + rand(5) - 2, @pos[1] + rand(5) - 2, (33 + rand(94)).chr)
			Curses.stdscr.safe_print(@pos[0] + rand(5) - 2, @pos[1] + rand(5) - 2, (33 + rand(94)).chr)
		end
		@done = true if (@count -= 1) <= 0
	end
end


number = ARGV.shift.to_i

con = Dir.entries('/dev/input').reject { |dev| dev !~ /^js/ }.map { |dev| Xbox360Controller.new("/dev/input/" + dev) }

Curses.init do |scr|
	Curses.ESCDELAY = 0
	Curses.echo = false
	Curses.curs_set 0
	Curses.start_color

	Curses.init_pair 1, 1, 0
	Curses.init_pair 2, 4, 0
	Curses.init_pair 5, 2, 0
	Curses.init_pair 6, 5, 0
	Curses.init_pair 3, 6, 3
	Curses.init_pair 4, 3, 0

	scr.keypad = true

	players = nil
	explosions = []
	gameover = nil
	winner = nil
	wins = Hash.new(0)

	# player setup
	players = []
	start = [scr.lines / 2, 1]
	start = [scr.lines / 3, 1] if number >= 3
	p = Player.new("Player 1", start, :right, 1, ?#, con[0])
	p.bind[3] = :up
	p.bind[2] = :left
	p.bind[0] = :down
	p.bind[1] = :right
	p.bind[Curses::Key::UP]    = :up
	p.bind[Curses::Key::LEFT]  = :left
	p.bind[Curses::Key::DOWN]  = :down
	p.bind[Curses::Key::RIGHT] = :right
	players << p
	start = [scr.lines / 2, scr.columns - 2]
	start = [scr.lines / 3, scr.columns - 2] if number >= 3
	p = Player.new("Player 2", start, :left, 6, ?&, con[1])
	p.bind[3] = :up
	p.bind[2] = :left
	p.bind[0] = :down
	p.bind[1] = :right
	p.bind[Curses::Key::F2] = :up
	p.bind[?1] = :left
	p.bind[?2] = :down
	p.bind[?3] = :right
	players << p
	if number > 2
		start = [scr.lines - 2, scr.columns / 2]
		dir = :up
		if number >= 4
			start = [scr.lines * 2 / 3, 1] 
			dir = :right
		end
		p = Player.new("Player 3", start, dir, 2, ?@, con[2])
		p.bind[3] = :up
		p.bind[2] = :left
		p.bind[0] = :down
		p.bind[1] = :right
		p.bind[Curses::Key::F9] = :up
		p.bind[?7] = :left
		p.bind[?8] = :down
		p.bind[?9] = :right
		players << p
		if number > 3
			p = Player.new("Player 4", [scr.lines * 2 / 3, scr.columns - 2], :left, 5, ?%)
			p.bind[?w] = :up
			p.bind[?a] = :left
			p.bind[?s] = :down
			p.bind[?d] = :right
			p.bind[?t] = :up
			p.bind[?f] = :left
			p.bind[?g] = :down
			p.bind[?h] = :right
			players << p
		end
	end

	restart = Proc.new do
		gameover = false
		winner = nil

		scr.clear
		scr.attron(Curses.color_pair(3)) do
			scr.box ?|, ?-
		end

		players.each { |player| player.reset }

		players.each { |player| player.print }
	end

	restart[]

	gameover = true

	# declare threads for the quit Proc
	game = nil
	keyboard = nil
	controllers = []

	quit = Proc.new do
		# close all threads
		game.exit
		keyboard.exit
		controllers.each { |controller| controller.exit }
		# close joystick devices
		players.each { |player| player.controller.close }
	end

	players.each do |player|
		if player.controller
			controllers << Thread.new(player) do |p|
				Curses.stdscr.print(1, 0, p)
				Curses.stdscr.print(2, 0, p.controller)
				while e = p.controller.event(false)
					if gameover
						p.ready = true if e.type == :button and e.number == 7 and e.value == 1
					else
						p.joy if e.type == :axis and e.number <= 1
					end
				end
				Curses.stdscr.print_right(0, e.inspect)
				Curses.stdscr.refresh
			end
		end
	end

	# keyboard input control
	keyboard = Thread.new do
		while ch = scr.getc
			case ch
			when 10
				if gameover
					players.each { |player| player.ready = true unless player.controller }
				end
			when 27
				quit[]
			else
				unless gameover
					players.each { |player| player.call ch unless player.controller }
				end
			end
		end
	end

	game = Thread.new do

		# main loop
		i = 0
		while true
			sleep 0.05
			scr.print(0, 0, controllers)
			if gameover
				if players.all? { |player| player.ready }
					restart[]
				end
			end
			#players.each do |player|
			#	player.get_joystick
			#end

			# update players
			i += 1

			# remove completed explosions
			explosions.reject! { |explosion| explosion.nil? or explosion.done }

			# animate current explosions
			explosions.each { |explosion| explosion.animate }

			players.each { |player| player.eat_tail(i) }
			if gameover

				if winner
					scr.attron(Curses.color_pair(winner.color) | Curses::A_BOLD) do
						scr.print_center(scr.lines / 2, "#{winner.name} WINS!")
					end
				else
					scr.attron(Curses::A_BOLD) do
						scr.print_center(scr.lines / 2, "DRAW")
					end
				end

				players.each_with_index do |player, j|
					scr.attron(player.ready ? Curses.color_pair(player.color) | Curses::A_REVERSE : 0) do
						scr.print_center(scr.lines / 2 + 2 + j, "#{player.name}: #{player.wins}")
					end
				end
			else
				# check for collisions
				players.each do |p1|
					if p1.check_collision
						explosions << p1.explode
					else
						players.each do |p2| # TODO smarter way to do this / only check living players
							if p1 != p2 and p1.next == p2.next
								explosions << p1.explode
								explosions << p2.explode
							end
						end
					end
				end
				living = players.reject { |player| player.fail }
				if living.length <= 1
					winner = living[0]
					if winner
						winner.wins += 1
						winner.fail = true
					end
					gameover = true
				end

				# move players
				players.each { |player| player.move }
			end
			scr.refresh
		end
	end

	controllers.each { |controller| controller.join }
	keyboard.join
end
