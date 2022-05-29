require "roda"
require 'uri'
require 'net/http'
require 'json'
require 'securerandom'
require 'sqlite3'

User = Struct.new(:name, :apikey, :tier)

class Users

	def initialize()
		@db = SQLite3::Database.open 'test.db'
		@db.execute "CREATE TABLE IF NOT EXISTS images(path TEXT, thumbs_up INT)"
		text = File.open("users.json").read
		hash = JSON.parse(text)
		@users = Array.new
		hash.each do |e|
			@users.push(User.new(e["name"], e["apikey"], e["tier"]))
		end
	end

	def GetNewApiKey(apikey)
		key = SecureRandom.hex
		GetUser(apikey).apikey = key
		Save()
		return key
	end

	def Save()
		#puts JSON.generate(@users.)
		# File.open("users.json", "w") { |f| f.write JSON.generate(@users) }
	end

	def GetUser(apikey)
		if apikey.nil? || apikey.empty?
			return nil
		end

		@users.each do |u|
			if(u.apikey == apikey)
				return u
			end
		end

		return nil
	end

	def GetUserByName(name)
		if name.nil? || name.empty?
			return nil
		end

		@users.each do |u|
			if(u.name == name)
				return u
			end
		end

		return nil
	end

	def UpsertUser(user)
		
	end
end

class App < Roda

	def ForwardRequest(req)
		# req -> Net::HTTP::Post.new(path)
		https = Net::HTTP.new("localhost", 5000)
		return https.request(req)
	end

	users = Users.new()

	route do |r|
		apikey = env["HTTP_X_API_KEY"]
		user = users.GetUser(apikey)

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
					res = ForwardRequest(Net::HTTP::Post.new("/switch/#{template}"))
					response.status = res.code
					response.write res.body
      				r.halt
				end
			end

			#GET /switch
			r.get do
				res = ForwardRequest(Net::HTTP::Get.new("/switch"))
				response.status = res.code
				response.write res.body
      			r.halt
			end
		end

		#/templates
		r.on "templates" do
			if(user.tier < 1)
				response.status = 403
				response.write "Permission denied!"
				r.halt
			end

			#GET /templates/key
			r.get "key" do
				res = `sudo bash /trinitron/api/addkey.sh`
				res
			end

			#GET /templates
			r.get do
				res = ForwardRequest(Net::HTTP::Get.new("/templates/"))
				response.status = res.code
				response.write res.body
      			r.halt
			end
		end

		#/config
		r.on "config" do
			if(user.tier < 2)
				response.status = 403
				response.write "Permission denied!"
				r.halt
			end

			#/config/users
			r.on "users" do
				#/config/users/name
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

		#/key
		r.on "key" do
			#/key/[username]
			r.is String do |username|
				#GET /key/[username]
				r.get do
					edituser = users.GetUserByName(username)
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

					users.GetNewApiKey(edituser.apikey)
				end
			end
		end
	end
end

# system("sudo systemctl start templates_sshkey_cleanup")
run App