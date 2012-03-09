#!/usr/bin/env ruby

require 'curses'
require 'xbox'

class Curses::Window
	def safe_print y, x, string
		return nil unless (0...lines) === y and (0...columns) === x
		print y, x, string
	end
end

$hspeed = 0.05
$vspeed = 0.10

class Player
	def initialize worm, dir, color, ch, controller = nil
		@worm = [worm]
		send(dir)
		@fail = false
		@color = color
		@ch = ch
		@bind = {}
		@last = @dir.dup
		@controller = controller
		@time = Time.new
	end

	attr_accessor :worm, :dir, :fail, :color, :bind

	def update players
		if Time.new - @time >= @speed
			unless check_collision
				players.each do |player|
					if self != player and self.next == player.next
						explode
						player.explode
					end
				end
			end

			unless @fail
				move
				eat_tail
			end
			@time = Time.new
		end
		return @fail
	end


	def eat_tail
		if @i and (@worm.length > 10 or (@fail and @worm.length > 1))
			Curses.stdscr.print *@worm.shift, ' '
		end
		@i = !@i
	end

	def print
		return if @fail
		Curses.stdscr.attron(Curses.color_pair(@color) | Curses::A_BOLD) do
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

	def get_joystick
		if @controller
			button = @controller.button
			send(@bind[button]) if @bind[button]
		end
	end

	def up
		unless @last and @last[0] == 1
			@dir = [-1, 0] 
			@speed = $vspeed
		end
	end
	
	def down
		unless @last and @last[0] == -1
			@dir = [1, 0]
			@speed = $vspeed
		end
	end

	def left
		unless @last and @last[1] == 1
			@dir = [0, -1]
			@speed = $hspeed
		end
	end

	def right
		unless @last and @last[1] == -1
			@dir = [0, 1]
			@speed = $hspeed
		end
	end

	def move
		return if @fail
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
	count = Array.new(4, 0)

	restart = Proc.new do
		# clear the event list from previous rounds
		controller.each { |c| c.button }
		scr.timeout = 0
		scr.clear
		scr.attron(Curses.color_pair(3)) do
			scr.box ?|, ?-
		end

		scr.print(0, 0, count.join(?,))

		# player setup
		players = []
		p = Player.new([scr.lines / 2, scr.columns / 2], :left, 1, ?#, controller[0])
		p.bind[3] = :up
		p.bind[2] = :left
		p.bind[0] = :down
		p.bind[1] = :right
		p.bind[Curses::Key::UP]    = :up
		p.bind[Curses::Key::LEFT]  = :left
		p.bind[Curses::Key::DOWN]  = :down
		p.bind[Curses::Key::RIGHT] = :right
		players << p
		p = Player.new([scr.lines / 2, scr.columns / 2], :right, 6, ?&, controller[1])
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
		p = Player.new([scr.lines / 2, scr.columns / 2], :up, 2, ?@, controller[2])
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
		p = Player.new([scr.lines / 2, scr.columns / 2], :down, 5, ?%)
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

		players.each { |player| player.print }
	end

	restart[]

	# main loop
	i = 0
	time = Time.new
	while true
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

		# update players
		death = false
		players.each do |player|
			death = true if player.update(players)
		end

		if death
			living = players.reject { |player| player.fail }.length
			if living <= 1
				if living == 0
					scr.print_center(scr.lines / 2, "DRAW")
				else
					players.each_with_index do |player, i|
						unless player.fail
							scr.attron(Curses.color_pair(player.color)) do
								scr.print_center(scr.lines / 2, "Player #{i + 1} WINS!")
							end
							count[i] += 1
						end
					end
				end

				while true
					case scr.getc
					when 10
						break
					when 27
						controller.each { |dev| dev.close }
						exit
					end
				end
				restart[]
			end
		end
	end
end
