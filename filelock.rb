require 'json'

class FileLock
	def initialize(filename)
		@filename = filename
		file = File.open(@filename, mode = 'r')
		while not file.flock(File::LOCK_EX)
			sleep(0.1)
		end
		file.close()
	end

	def report_change
		@changes = true
	end

	def read_file_lines
		file = File.open(@filename, mode = 'r')
		file.each_line do |l|
			yield l
		end
		file.close()
	end

	def serialize_content
		yield("line")
	end

	def end()
		if @changes
			file = File.new(@filename, 'w')
			serialize_content do |s|
				file.puts(s)
			end
		else
			file = File.open(@filename, 'r')
		end
		file.flock(File::LOCK_UN)
		file.close()
	end
end