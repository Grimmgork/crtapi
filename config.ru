require "roda"
require 'uri'
require 'net/http'
require 'json'
require 'open3'

require './users.rb'

class App < Roda

	def forward_request(req)
		# req -> Net::HTTP::Post.new(path)
		https = Net::HTTP.new("localhost", 5000)
		return https.request(req)
	end

	def get_new_templates_sshkey(username)
		stdout, stderr, status = Open3.capture3("perl", "/trinitron/api/keys.pl", username, "new")
		if status != 0
			return nil
		end
		return stdout
	end

	def remove_templates_sshkey(username)
		stdout, stderr, status = Open3.capture3("perl", "/trinitron/api/keys.pl", username)
		if status != 0
			return false
		end
		return true
	end

	route do |r|
		@users = Users.new()
		apikey = env["HTTP_APIKEY"]
		login = @users.get_user_by_apikey(apikey)

		if login.nil?
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
			if(login["tier"] < 1)
				response.status = 403
				response.write "Permission denied!"
				r.halt
			end

			# GET /templates/key
			r.get "key" do
				sshkey = get_new_templates_sshkey(login["name"]) 
				if not sshkey
					response.status = 500
					response.write "internal error"
					r.halt
				end
				response.write sshkey
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

		# /users
		r.on "users" do
			# /users/new
			r.on "new" do
				if(login["tier"] < 3)
					response.status = 403
					response.write "Permission denied!"
					r.halt
				end

				# /users/new/[name]
				r.is String do |name|
					r.post do
						apikey = @users.create_user(name)
						if apikey.nil?
							response.write "username taken!"
							response.status = 403
							r.halt
						end

						response.write apikey
						response.status = 200
						r.halt
					end
				end
			end

			# /users/[name]
			r.is String do |name|
				edituser = @users.get_user_by_name(name)
				if edituser.nil?
					response.status = 404
					response.write "username not found!"
					r.halt
				end

				# GET /users/[name]
				r.get do
					# only tier 2 should inspect other users
					if edituser["name"] != login["name"]
						if(user.tier < 2)
							response.status = 403
							response.write "Permission denied!"
							r.halt
						end
					end
					response.write edituser.to_json
					response.status = 200
					r.halt
				end

				if(login["tier"] < 2 || login["tier"] <= edituser["tier"])
					response.status = 403
					response.write "Permission denied!"
					r.halt
				end

				# POST /users/[name] -> update user
				r.post do
					u = JSON.parse(r.body.read)
					if u["name"] != edituser["name"]
						@users.rename_user(edituser["name"], u["name"])
					end
					@users.update_user(u)
					response.status = 200
					response.write "kek"
					r.halt
					
				end
			end

			if(login["tier"] < 2)
				response.status = 403
				response.write "Permission denied!"
				r.halt
			end

			# GET /users
			r.get do
				response.status = 200
				response.write @users.get_all_users_as_hash().to_json
      			r.halt
			end
		end

		# /key
		r.on "key" do
			# /key/[username]
			r.is String do |username|
				# GET /key/[username]
				r.get do
					if(login["tier"] < 2)
						response.status = 403
						response.write "Permission denied!"
						r.halt
					end

					edituser = @users.get_user_by_name(username)
					# print edituser.nil?
					if(edituser.nil?)
						response.status = 404
						response.write "username not found!"
						r.halt
					end

					if(login["name"] == edituser["name"])
						response.status = 400
						response.write "cant reset own apikey here, use GET /key instead!"
						r.halt
					end

					remove_templates_sshkey(edituser["name"])
					response.write @users.get_new_apikey(edituser["name"])
					response.status = 200
					r.halt
				end
			end

			# GET /key
			r.get do
				remove_templates_sshkey(login["name"])
				response.write @users.get_new_apikey(login["name"])
				response.status = 200
				r.halt
			end
		end

	ensure
		if defined?(@users)
			@users.end()
		end
	end
end

run App