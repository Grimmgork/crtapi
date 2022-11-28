require "roda"
require 'uri'
require 'net/http'
require 'json'
require 'securerandom'
require 'open3'

class FileAccess
	def initialize(filename)
		@filename = filename
		@file = File.open(filename, mode = 'r')
		while not @file.flock(File::LOCK_EX)
			sleep(0.1)
		end
		@root = JSON.parse(File.read(@filename))
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
	end
end

class Users < FileAccess

	def initialize()
		super("users.json")
		@index = Hash.new
		@root.each_with_index do |u, i|
			@index[u["name"]] = i
		end
	end

	def get_new_apikey(name)
		user = get_user_by_name(name)
		if user.nil?
			return nil
		end
		key = generate_api_key
		user.apikey = key
		update_user(user)
		return key
	end

	def generate_api_key()
		return SecureRandom.hex(10)
	end

	def construct_new_user(name)
		return OpenStruct.new({ name: name, apikey: generate_api_key, tier: 0 })
	end

	def get_user_by_apikey(apikey)
		if apikey.nil? || apikey.empty?
			return nil
		end
		@root.each do |u|
			if(u["apikey"] == apikey)
				return OpenStruct.new(u)
			end
		end
		return nil
	end

	def get_user_by_name(name)
		if name.nil? || name.empty? || @index[name].nil?
			return nil
		end
		return OpenStruct.new(@root[@index[name]])
	end

	def update_user(user)
		if user.nil? || not remove_user(user.name)
			return
		end
		add_user(user)
	end

	def remove_user(name)
		if @index[name].nil?
			return false
		end
		@root.delete_at(@index[name])
		@index.delete(name)
		report_change()
		return true
	end

	def add_user(user)
		if @index[user.name]
			return false
		end
		@root.push(user.to_h)
		@index[user.name] = @root.length()-1
		report_change()
		return true
	end
end


class App < Roda

	def forward_request(req)
		# req -> Net::HTTP::Post.new(path)
		https = Net::HTTP.new("localhost", 5000)
		return https.request(req)
	end

	route do |r|
		@users = Users.new()
		apikey = env["HTTP_APIKEY"]
		user = @users.get_user_by_apikey(apikey)

		if user.nil?
			response.status = 403
			response.write "Permission denied!"
			r.halt
		end
		
		#/switch
		r.on "switch" do
			#/switch/[template]
			r.is String do |template|
				#POST /switch/[template]
				r.post do
					res = forward_request(Net::HTTP::Post.new("/switch/#{template}"))
					response.status = res.code
					response.write res.body
      				r.halt
				end
			end

			#GET /switch
			r.get do
				res = forward_request(Net::HTTP::Get.new("/switch"))
				response.status = res.code
				response.write res.body
      			r.halt
			end
		end

		# /templates
		r.on "templates" do
			if(user.tier < 1)
				response.status = 403
				response.write "Permission denied!"
				r.halt
			end

			# GET /templates/key
			r.get "key" do
				stdout, stderr, status = Open3.capture3("perl", "/trinitron/api/keys.pl", user.name, "new")
				if status != 0
					response.status = 500
					response.write "internal error"
					r.halt
				end
				response.write stdout
				r.halt
			end

			# GET /templates
			r.get do
				res = forward_request(Net::HTTP::Get.new("/templates/"))
				response.status = res.code
				response.write res.body
      			r.halt
			end
		end

		# /config
		r.on "config" do
			if(user.tier < 2)
				response.status = 403
				response.write "Permission denied!"
				r.halt
			end

			# /config/users
			r.on "users" do
				# /config/users/name
				r.is String do |name|
					#GET /config/users/name
					r.get do
						"kek"
					end

					#POST /config/users/name
					r.post do
						"kek"
					end
				end

				#GET /config/users
				r.get do
					"kek"
				end
			end
		end

		# /key
		r.on "key" do
			# /key/[username]
			r.is String do |username|
				# GET /key/[username]
				r.get do
					edituser = @users.get_user_by_name(username)
					# print edituser.nil?
					if(edituser.nil?)
						response.status = 404
						response.write "Username not found!"
						r.halt
					end

					if(user.tier < edituser.tier)
						response.status = 403
						response.write "Permission denied!"
						r.halt
					end

					if(user.tier == edituser.tier && user.name != edituser.name)
						response.status = 403
						response.write "Permission denied!"
						r.halt
					end

					response.status = 200
					response.write @users.get_new_apikey(edituser.name)
					r.halt
				end
			end
		end

	ensure
		if defined?(@users)
			@users.end()
		end
	end
end

# system("sudo systemctl start templates_sshkey_cleanup")
run App