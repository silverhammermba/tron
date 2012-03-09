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
	def initialize worm, dir, color, ch, controller = nil
		@worm = [worm]
		@dir = dir
		@fail = false
		@color = color
		@ch = ch
		@bind = {}
		@last = @dir.dup
		@controller = controller
		@ready = false
	end

	attr_accessor :worm, :dir, :fail, :color, :bind, :name
	attr_reader :ready

	def eat_tail i
		return if i % 2 == 1
		if @worm.length > 10 or (@fail and @worm.length > 1)
			Curses.stdscr.print *@worm.shift, ' '
		end
	end

	def print rev = true
		return if @fail
		Curses.stdscr.attron(Curses.color_pair(@color) | Curses::A_BOLD | (rev ? Curses::A_REVERSE : 0)) do
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

	def get_ready
		if @controller
			@ready = true if @controller.button == 7
		else
			@ready = true
		end
	end

	def get_joystick
		if @controller
			button = @controller.button
			send(@bind[button]) if @bind[button]
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
		Curses.stdscr.attron(Curses.color_pair(4)) do
			(5 + rand(5)).times do
				Curses.stdscr.safe_print(@worm[-1][0] + rand(5) - 2, @worm[-1][1] + rand(5) - 2, (33 + rand(94)).chr)
				Curses.stdscr.refresh
			end
		end
	end

	def check_collision
		return if @fail
		if Curses.stdscr[*self.next] != 32
			explode
		end
		@fail
	end

end

number = ARGV.shift.to_i

controller = Dir.entries('/dev/input').reject { |dev| dev !~ /^js/ }.map { |dev| Xbox360Controller.new("/dev/input/" + dev) }

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
	gameover = nil
	winner = nil
	wins = Hash.new(0)

	restart = Proc.new do
		gameover = false
		winner = nil
		# clear the event list from previous rounds
		controller.each { |c| c.button }
		scr.timeout = 0
		scr.clear
		scr.attron(Curses.color_pair(3)) do
			scr.box ?|, ?-
		end

		# player setup
		players = []
		p = Player.new([scr.lines / 2, scr.columns / 2], [0, -1], 1, ?#, controller[0])
		p.bind[3] = :up
		p.bind[2] = :left
		p.bind[0] = :down
		p.bind[1] = :right
		p.bind[Curses::Key::UP]    = :up
		p.bind[Curses::Key::LEFT]  = :left
		p.bind[Curses::Key::DOWN]  = :down
		p.bind[Curses::Key::RIGHT] = :right
		players << p
		p = Player.new([scr.lines / 2, scr.columns / 2], [0, 1], 6, ?&, controller[1])
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
			p = Player.new([scr.lines / 2, scr.columns / 2], [-1, 0], 2, ?@, controller[2])
			p.bind[3] = :up
			p.bind[2] = :left
			p.bind[0] = :down
			p.bind[1] = :right
			p.bind[Curses::Key::F9] = :up
			p.bind[?7]  = :left
			p.bind[?8]  = :down
			p.bind[?9] = :right
			players << p
			if number > 3
				p = Player.new([scr.lines / 2, scr.columns / 2], [1, 0], 5, ?%)
				p.bind[?w] = :up
				p.bind[?a] = :left
				p.bind[?s] = :down
				p.bind[?d] = :right
				p.bind[?t]    = :up
				p.bind[?f]  = :left
				p.bind[?g]  = :down
				p.bind[?h] = :right
				players << p
			end
		end

		players.each_index { |i| players[i].name = "Player #{i + 1}" }
		players.each { |player| player.print }
	end

	restart[]

	# main loop
	i = 0
	time = Time.new
	while true
		if gameover
			if players.all? { |player| player.ready }
				restart[]
			else
				case scr.getc
				when 10
					restart[]
				when 27
					controller.each { |dev| dev.close }
					exit
				else
					players.each do |player|
						player.get_ready
					end
				end
			end
		else
			case ch = scr.getc
			when 27
				controller.each { |dev| dev.close }
				exit
			else
				players.each do |player|
					player.call ch
					player.get_joystick
				end
			end
		end

		# update players
		if Time.new - time >= 0.05
			i += 1

			if gameover
				players.each { |player| player.eat_tail(i) }

				if winner
					scr.attron(Curses.color_pair(winner.color)) do
						scr.print_center(scr.lines / 2, "#{winner.name} WINS!")
					end
				else
					scr.print_center(scr.lines / 2, "DRAW")
				end

				players.each_with_index do |player, i|
					scr.attron(player.ready ? Curses.color_pair(player.color) | Curses::A_REVERSE : 1) do
						scr.print_center(scr.lines / 2 + 2 + i, "#{player.name}: #{wins[player.name]}")
					end
				end
			else
				# check for collisions
				players.each do |p1|
					unless p1.check_collision
						players.each do |p2|
							if p1 != p2 and p1.next == p2.next
								p1.explode
								p2.explode
							end
						end
					end
				end
				living = players.reject { |player| player.fail }
				if living.length <= 1
					winner = living[0]
					if winner
						wins[winner.name] += 1
						winner.fail = true
					end
					gameover = true
				end

				# move players
				players.each { |player| player.move }

				# remove tail
				players.each { |player| player.eat_tail(i) }

			end

			time = Time.new
		end
	end
end
