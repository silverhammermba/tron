#!/usr/bin/env ruby

class Player
	def initialize name, character, color_number, start_pos, direction, controller
		@name = name # player name displayed on gameover screen
		@ch = character # character that the worm is made of
		@color = color_number # Curses color pair number
		@start_pos = start_pos # starting position
		@start_dir = dir # starting direction (method)
		@ctrl = controller # Xbox controller
		@wins = 0 # score
		reset
	end

	def reset
		@worm = [@start_pos] # reset start position
		@last = [] # TODO hacky
		send(@start_dir) # reset start direction
		@last = @dir.dup # TODO hacky
		@fail = false # player has not crashed yet
		@ready = false # player is not ready yet
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

