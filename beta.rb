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

paused = true
winner = false # TODO hack so the beginning isn't a 'DRAW'

# find all joysticks
con = Dir.entries('/dev/input').reject { |dev| dev !~ /^js/ }.map { |dev| Joystick::Device.new("/dev/input/" + dev) }

# we need the stdscreen to set player positions
stdscr = Curses.init

# set up Curses
Curses.echo = false
Curses.curs_set 0
Curses.ESCDELAY = 0

Curses.start_color
Curses.init_pair 1, 1, 0 # player colors...
Curses.init_pair 2, 5, 0
Curses.init_pair 3, 4, 0
Curses.init_pair 4, 2, 0
Curses.init_pair 5, 6, 3
Curses.init_pair 6, 3, 0
wall_color = Curses.color_pair(5)
expl_color = Curses.color_pair(6)

stdscr.keypad = true

# initialize players
player = []
if num_players > 0
	player[0] = Player.new("Player 1", ?#, Curses.color_pair(1), [stdscr.lines / 2, 1], :right, con[0])
end
if num_players > 1
	player[1] = Player.new("Player 2", ?@, Curses.color_pair(2), [stdscr.lines / 2, stdscr.columns - 2], :left, con[1])
end
if num_players > 2
	player[2] = Player.new("Player 3", ?%, Curses.color_pair(3), [stdscr.lines - 2, stdscr.columns / 2], :up, con[2])
end
if num_players > 3
	#player[3] = Player.new("Player 4", ?&, 3, :right, con[3])
end

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

player.each { |p| p.crashed = true } # TODO hacky way of stopping players from moving initially

# game logic here
game = Thread.new do
	until player.all? { |p| p.ready }
		sleep 0.5

		stdscr.pos = (stdscr.lines / 2 + 1), 0
		stdscr.clrtoeol
		player.each_with_index do |p, i|
			stdscr.attron((p == winner ? Curses::A_REVERSE : 0) | p.color) do
				stdscr.print(stdscr.lines / 2, (stdscr.columns - p.name.length) * (i + 1) / (num_players + 1), p.name)
			end
			stdscr.attron((p.ready ? Curses::A_REVERSE | p.color : Curses.color_pair(0)) | Curses::A_BOLD) do
				stdscr.print(stdscr.lines / 2 + 1, (stdscr.columns - (p.ready ? 6 : 11)) * (i + 1) / (num_players + 1), p.ready ? "READY" : "PRESS START")
			end
		end

		stdscr.refresh

	end

	while true
		sleep 0.05

		# TODO possibly improve somehow?
		living = player.reject { |p| p.crashed }.each do |p1|
			living.each do |p2|
				if p1 != p2 and p1.next == p2.next
					p1.explode
					p2.explode
				end
			end
		end
		
		player.each do |p|
			p.move
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
	while ch = stdscr.getc
		if ch == 27
			game.exit
			input_threads.each { |thread| thread.exit }
			Thread.current.exit 
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
