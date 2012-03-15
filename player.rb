#!/usr/bin/env ruby

class Player
	def initialize name, character, color, start_pos, direction, controller
		@name = name # player name displayed on gameover screen
		@ch = character # character that the worm is made of
		@color = color # Curses color pair
		@start_pos = start_pos # starting position
		@start_dir = direction # starting direction (method)
		@ctrl = controller # Xbox controller
		@score = 0
		@bind = {} # key binding hash
		reset
	end

	attr_accessor :crashed, :ready, :score
	attr_reader :name, :color

	def reset
		@pos = [@start_pos] # reset start position
		@last = [] # TODO hacky
		send(@start_dir) # reset start direction
		@last = @dir.dup # TODO hacky
		@crashed = false # player has not crashed yet
		@ready = false # player is not ready yet
		@i = false # for keeping track of when to eat the tail
	end

	def eat_tail
		# remove tail segments
		return if @i = !@i # eat the tail every other iteration
		if @pos.length > 10 or (@crashed and @pos.length > 1)
			Curses.stdscr.print *@pos.shift, ' '
		end
	end

	def print head = false
		# print a section of the snake
		Curses.stdscr.attron((head ? 0 : @color) | Curses::A_BOLD) do
			Curses.stdscr.print *@pos[-1], @ch
		end
		@last = @dir # a new segment has been drawn, so start accepting new directions
	end

	def next
		# generate a new segment
		[@pos[-1][0] + @dir[0], @pos[-1][1] + @dir[1]]
	end

	def call ch
		# call a key binding
		send(@bind[ch]) if @bind[ch]
	end

	def joystick
		# for D-pad
		case @ctrl.axis[6]
		when -32767
			left
		when 32767
			right
		end
		case @ctrl.axis[7]
		when -32767
			up
		when 32767
			down
		end
	end

	# movement methods
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
		# move the worm forward
		unless @crashed
			if can_move?
				print
				@pos << self.next
				print true
			else
				explode
			end
		end
		eat_tail
	end

	def explode
		@crashed = true
		# TODO explosions!!!
	end

	def can_move?
		Curses.stdscr[*self.next] == 32
	end
end

