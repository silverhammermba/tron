#!/usr/bin/env ruby

class Curses::Window
	def safe_print y, x, str
		if (0...lines) === y and (0...columns) === x
			print y, x, str
		end
	end
end

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

	attr_accessor :crashed, :ready, :score, :bind
	attr_reader :name, :color, :ctrl

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
		eat_tail
		unless @crashed
			if can_move?
				print
				@pos << self.next
				print true
			else
				explode
			end
		end
	end

	def explode
		@crashed = true
		Explosion.new(self.next, @dir)
	end

	def can_move?
		Curses.stdscr[*self.next] == 32
	end
end

class Explosion
	def initialize pos, dir
		@pos = pos
		@dir = dir
		@debris = []
		# debris store [position, lifetime, character they overlap]
		# TODO perhaps they should be their own class
		(5 + rand(6)).times do
			@debris << Debris.new(self)
		end
		@done = false
	end

	attr_reader :done, :pos, :dir

	def animate
		@done = true
		@debris.each do |d|
			if d.moving?
				d.move
				@done = false
			end
		end
		@debris.each do |d|
			if d.moving?
				d.print
			end
		end
	end
end

class Debris
	def initialize explosion
		@explosion = explosion
		@pos = explosion.pos.dup
		@lifetime = rand(5)
		@ch = Curses.stdscr[*@pos].chr
	end

	def moving?
		@lifetime > 0
	end

	def move
		Curses.stdscr.safe_print(*@pos, @ch)
		if @explosion.dir[0] == 0 # horiztonal
			@pos[0] += rand(3) - 1
			@pos[1] += @explosion.dir[1] * (rand(5) - 1) / 2
		else # vertical
			@pos[0] += @explosion.dir[0] * (rand(5) - 1) / 2
			@pos[1] += rand(3) - 1
		end
		@ch = Curses.stdscr[*@pos].chr
	end

	def print
		@lifetime -= 1
		Curses.stdscr.safe_print(*@pos, (33 + rand(94)).chr)
	end
end
