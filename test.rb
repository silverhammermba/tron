#!/usr/bin/env ruby

require 'curses'
require 'xbox'
require 'player'

num_players = ARGV.shift.to_i

con = Dir.entries('/dev/input').reject { |dev| dev !~ /^js/ }.map { |dev| Xbox360Controller.new("/dev/input/" + dev) }

player = []

if num_players > 0
	player[0] = Player.new("Player 1", "#", 0, [scr.lines / 2, 1], :right, con[0])
end
if num_players > 1
	player[1] = Player.new("Player 2", "@", 1, [scr.lines / 2, scr.columns - 2], :left, con[1])
end
if num_players > 2
	#player[2] = Player.new("Player 3", "%", 2, :right, con[2])
end
if num_players > 3
	#player[3] = Player.new("Player 4", "&", 3, :right, con[3])
end


input_threads = []

Curses.init do |scr|
	Curses.echo = false
	Curses.curs_set 0
	Curses.ESCDELAY = 0
	scr.keypad = true

	con.each_with_index do |controller, i|
		input_threads << Thread.new(controller, i) do |c, j|
			while e = c.event
				scr.pos = j, 0
				scr.clrtoeol
				scr.print(j, 0, c.axis.inspect + ' ' + c.button.inspect)
				scr.refresh
				Thread.current.exit if e.type == :button and e.number == 7 and e.value == 1
			end
		end
	end

	input_threads << Thread.new do
		while ch = scr.getc
			scr.print(con.length, 0, ch.inspect)
			scr.refresh
			Thread.current.exit if ch == 27
		end
	end

	game = Thread.new do
		i = 0
		while true
			sleep 1
			scr.print(con.length + 1, 0, i = (i + 1) % 10)
			scr.refresh
		end
	end

	input_threads.each { |thread| thread.join }

	con.each { |controller| controller.close }
end
