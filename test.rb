#!/usr/bin/env ruby

require 'curses'
require 'xbox'
require './player'

num_players = ARGV.shift.to_i

# find all joysticks
con = Dir.entries('/dev/input').reject { |dev| dev !~ /^js/ }.map { |dev| Xbox360Controller.new("/dev/input/" + dev) }

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
Curses.init_pair 5, 6, 3 # walls
Curses.init_pair 6, 3, 0 # explosions

stdscr.keypad = true

# initialize players
player = []
if num_players > 0
	player[0] = Player.new("Player 1", "#", 1, [stdscr.lines / 2, 1], :right, con[0])
end
if num_players > 1
	player[1] = Player.new("Player 2", "@", 2, [stdscr.lines / 2, stdscr.columns - 2], :left, con[1])
end
if num_players > 2
	#player[2] = Player.new("Player 3", "%", 2, :right, con[2])
end
if num_players > 3
	#player[3] = Player.new("Player 4", "&", 3, :right, con[3])
end

# set up input threads
input_threads = []
con.each_with_index do |controller, i|
	input_threads << Thread.new(controller, i) do |c, j|
		while e = c.event
			if e.type == :axis and e.number <= 1
				player[j].joystick
			end
			stdscr.pos = j, 0
			stdscr.clrtoeol
			stdscr.print(j, 0, c.axis.inspect + ' ' + c.button.inspect)
			stdscr.refresh
			#Thread.current.exit if e.type == :button and e.number == 7 and e.value == 1
		end
	end
end
# keyboard input
keyboard = Thread.new do
	while ch = stdscr.getc
		if ch == 27
			input_threads.each { |thread| thread.exit }
			Thread.current.exit 
		end
	end
end

# game logic here
game = Thread.new do
	while true
		sleep 0.1

		player.each do |p|
			p.move
		end

		stdscr.refresh
	end
end

input_threads.each { |thread| thread.join } # why do I need TODO this?
# exit when the keyboard closes (ESC pressed)
keyboard.join

# close all joystick devices
con.each { |controller| controller.close }

# and Curses
Curses.close
