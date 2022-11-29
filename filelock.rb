require 'json'

class FileLock
	def initialize(filename)
		@filename = filename
		@file = File.open(filename, mode = 'r')
		while not @file.flock(File::LOCK_EX)
			sleep(0.1)
		end
		@root = JSON.parse(File.read(@filename)) || []
	end

	def report_change()
		@changes = true
	end

	def end()
		if not @file.closed?
			if @changes
				@file.close()
				@file = File.new(@filename, 'w')
				@file.write(@root.to_json)
			end
			@file.flock(File::LOCK_UN)
			@file.close()
		end
		@file = nil
	end
end