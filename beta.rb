#!/usr/bin/env ruby

require 'curses'
require 'joystick'
require './player'

# variables for program state
num_players = ARGV.shift.to_i

if num_players <= 0
	STDERR.puts "usage: #{$0} PLAYERS"
	exit
end


# find all joysticks
con = Dir.entries('/dev/input').reject { |dev| dev !~ /^js/ }.map { |dev| Joystick::Device.new("/dev/input/" + dev) }

# we need the stdscreen to set player positions
stdscr = Curses.init

# set up Curses
Curses.echo = false
Curses.curs_set 0
Curses.ESCDELAY = 0

Curses.start_color
# player colors...
Curses.init_pair 1, 1, 0 
Curses.init_pair 2, 5, 0
Curses.init_pair 3, 4, 0
Curses.init_pair 4, 2, 0
# other colors
Curses.init_pair 5, 6, 3
Curses.init_pair 6, 3, 0
wall_color = Curses.color_pair(5)
expl_color = Curses.color_pair(6)

stdscr.keypad = true

binds = []
binds << {Curses::Key::UP    => :up,
          Curses::Key::LEFT  => :left,
		  Curses::Key::DOWN  => :down,
		  Curses::Key::RIGHT => :right}
binds << {Curses::Key::F2 => :up,
          ?1              => :left,
		  ?2              => :down,
		  ?3              => :right}
binds << {?t => :up,
          ?f => :left,
		  ?g => :down,
		  ?h => :right}
binds << {Curses::Key::F9 => :up,
          ?7 => :left,
		  ?8 => :down,
		  ?9 => :right}

# initialize players
player = []
if num_players > 0
	p = Player.new("Player 1", ?#, Curses.color_pair(1), [stdscr.lines / 2, 1], :right, con[0])
	p.bind = binds.shift unless p.ctrl
	player << p
end
if num_players > 1
	p = Player.new("Player 2", ?@, Curses.color_pair(2), [stdscr.lines / 2, stdscr.columns - 2], :left, con[1])
	p.bind = binds.shift unless p.ctrl
	player << p
end
if num_players > 2
	p = Player.new("Player 3", ?%, Curses.color_pair(3), [stdscr.lines - 2, stdscr.columns / 2], :up, con[2])
	p.bind = binds.shift unless p.ctrl
	player << p
end
if num_players > 3
	p = Player.new("Player 4", ?&, Curses.color_pair(4), [1, stdscr.columns / 2], :down, con[3])
	p.bind = binds.shift unless p.ctrl
	player << p
end

paused = true

# set up input threads
input_threads = []
num_players.times do |i|
	if ctrl = con[i] # TODO make sure this works with keyboard players
		input_threads << Thread.new do
			while e = ctrl.event
				if e.type == :axis and e.number >= 6 # for analog <= 1
					player[i].joystick
				elsif paused and e.type == :button and e.number == 7 and e.value == 1
					player[i].ready = true
				end
				#stdscr.pos = i, 0
				#stdscr.clrtoeol
				#stdscr.print(i, 0, ctrl.axis.inspect + ' ' + ctrl.button.inspect)
				#stdscr.refresh
			end
		end
	end
end

explosions = []

# TODO make the game work without these hacks!
player.each { |p| p.crashed = true } # TODO hacky way of stopping players from moving initially
winner = false # TODO hack so the beginning isn't a 'DRAW'

# game logic here
game = Thread.new do
	until player.all? { |p| p.ready }
		sleep 0.5

		stdscr.pos = (stdscr.lines / 2 + 1), 0
		stdscr.clrtoeol
		player.each_with_index do |p, i|
			stdscr.attron(p.color) do
				stdscr.print(stdscr.lines / 2, (stdscr.columns - p.name.length) * (i + 1) / (num_players + 1), p.name)
			end
			stdscr.attron((p.ready ? Curses::A_REVERSE | p.color : 0) | Curses::A_BOLD) do
				stdscr.print(stdscr.lines / 2 + 1, (stdscr.columns - (p.ready ? 6 : 11)) * (i + 1) / (num_players + 1), p.ready ? "READY" : "PRESS START")
			end
		end

		stdscr.refresh
	end

	while true
		sleep 0.05

		# check for draws
		# TODO possibly improve somehow?
		living = player.reject { |p| p.crashed }.each do |p1|
			living.each do |p2|
				if p1 != p2 and p1.next == p2.next
					explosions << p1.explode
					explosions << p2.explode
				end
			end
		end

		explosions.reject! { |e| e.done }
		stdscr.attron(expl_color) do
			explosions.each { |e| e.animate }
		end
		
		player.each do |p|
			if (e = p.move).class == Explosion
				explosions << e
			end
		end

		if paused
			unless winner == false
				player.each_with_index do |p, i|
					stdscr.attron((p == winner ? Curses::A_REVERSE : 0) | p.color) do
						stdscr.print(stdscr.lines / 2, (stdscr.columns - p.name.length) * (i + 1) / (num_players + 1), p.name)
					end
					stdscr.attron((p.ready ? Curses::A_REVERSE | p.color : 0) | Curses::A_BOLD) do
						stdscr.print(stdscr.lines / 2 + 1, (stdscr.columns - p.score.to_s.length) * (i + 1) / (num_players + 1), p.score)
					end
				end
				if winner.nil?
					stdscr.print_center(stdscr.lines / 2 - 1, "DRAW")
				end
			end

			if player.all? { |p| p.ready }
				# reset the game
				player.each { |p| p.reset }
				paused = false
				winner = nil

				stdscr.clear
				stdscr.attron(wall_color) do
					stdscr.box ?|, ?-
				end
			end
		else
			living.reject! { |p| p.crashed }

			if living.count < num_players and living.count <= 1
				paused = true
				winner = living[0]
				if winner
					winner.score += 1
					winner.crashed = true # TODO hacky way to stop the winner from moving around
				end
			end
		end

		stdscr.refresh
	end
end

# keyboard input
keyboard = Thread.new do
	while true
		case ch = stdscr.getc
		when 10
			if paused
				player.each { |p| p.ready = true unless p.ctrl }
			end
		when 27
			game.exit
			input_threads.each { |thread| thread.exit }
			Thread.current.exit 
		else
			player.each { |p| p.call ch } # might have to check for gameover
		end
	end
end

game.join
input_threads.each { |thread| thread.join } # why do I need TODO this?
# exit when the keyboard closes (ESC pressed)
keyboard.join

# close all joystick devices
con.each { |controller| controller.close }

# and Curses
Curses.close
