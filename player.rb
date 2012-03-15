#!/usr/bin/env ruby

class Player
	def initialize name, character, color_number, start_pos, direction, controller
		@name = name # player name displayed on gameover screen
		@ch = character # character that the worm is made of
		@color = color_number # Curses color pair number
		@start_pos = start_pos # starting position
		@start_dir = direction # starting direction (method)
		@ctrl = controller # Xbox controller
		@score = 0
		@bind = {} # key binding hash
		reset
	end

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
		Curses.stdscr.attron((head ? 0 : Curses.color_pair(@color)) | Curses::A_BOLD) do
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
		# deadzone
		if @ctrl.axis[0] and @ctrl.axis[1] and @ctrl.axis[0] ** 2 + @ctrl.axis[1] ** 2 > 169000000
			case Math.atan2(@ctrl.axis[1], @ctrl.axis[0])
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
			print
			@pos << self.next
			print true
		end
		eat_tail
	end

	def explode
		@crashed = true
		#return Explosion.new @worm[-1]
	end

	def can_move?
		Curses.stdscr[*self.next] == 32
	end
end

