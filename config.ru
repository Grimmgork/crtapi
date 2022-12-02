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

	def respond(req, res, content, status=200)
		res.status = status
		res.write content
      	req.halt
	end

	def respond_permission_denied(req, res)
		respond(req, res, "permission denied!", 403)
	end

	def clean_username(name)
		name.strip
		if name.match(/[^a-z0-9_-]/)
			return nil
		end
		return name
	end

	route do |r|
		@users = Users.new()
		login_name, login_tier = @users.get_user_by_apikey(env["HTTP_APIKEY"])

		if login_name.nil?
			respond_permission_denied(r, response)
		end
		
		#/switch
		r.on "switch" do
			#/switch/[template]
			r.is String do |template|
				template = clean_username(template)
				if template.nil?
					respond(r, response, "malformed parameter!", 400)
				end
				#POST /switch/[template]
				r.post do
					res = forward_request(Net::HTTP::Post.new("/switch/#{template}"))
					respond(r, response, res.body, res.code)
				end
			end

			#GET /switch
			r.get do
				res = forward_request(Net::HTTP::Get.new("/switch"))
				respond(r, response, res.body, res.code)
			end
		end

		# /templates
		r.on "templates" do
			if(login_tier < 1)
				respond_permission_denied(r, response)
			end

			# GET /templates/key
			r.get "key" do
				sshkey = get_new_templates_sshkey(login_name) 
				if not sshkey
					respond(r, response, "internal error!", 500)
				end
				respond(r, response, sshkey)
			end

			# GET /templates
			r.get do
				res = forward_request(Net::HTTP::Get.new("/templates/"))
				respond(r, response, res.body, res.code)
			end
		end

		# /users
		r.on "users" do
			# /users/new
			r.on "new" do
				if(login_tier < 3)
					respond_permission_denied(r, response)
				end

				# /users/new/[name]
				r.is String do |username|
					username = clean_username(username)
					if username.nil?
						respond(r, response, "malformed parameter!", 400)
					end
					r.post do
						apikey = @users.create_user(username)
						if apikey.nil?
							respond(r, response, "username taken!", 400)
						end
						respond(r, response, apikey)
					end
				end
			end

			# /users/[username]
			r.is String do |username|
				username = clean_username(username)
				if username.nil?
					respond(r, response, "malformed parameter!", 400)
				end

				user_name, user_tier = @users.get_user_by_name(username)
				if user_name.nil?
					respond(r, response, "username not found!", 404)
				end

				# GET /users/[username]
				r.get do
					# only tier 2 should inspect other users
					if user_name != login_name
						if(login_tier < 2)
							respond_permission_denied(r, response)
						end
					end
					respond(r, response, { "name" => user_name, "tier" => user_tier }.to_json)
				end

				if(login_tier < 2 || login_tier <= user_tier)
					respond_permission_denied(r, response)
				end

				# POST /users/[username]?[field]=[value] -> update user
				r.post do
					r.params.each do |key, value|
						case key
						when "tier"
							@users.set_user_tier(user_name, value.to_i)
						when "name"
							n = clean_username(value)
							if !n.nil?
								@users.rename_user(user_name, n)
							end
						end
					end
					respond(r, response, "")
				end

				# DELETE /users/[username]
				r.delete do
					@users.remove_user(user_name)
					respond(r, response, "user removed!")
				end
			end

			if(login_tier < 2)
				respond_permission_denied(r, response)
			end

			# GET /users
			r.get do
				respond(r, response, @users.get_all_users_as_hash().to_json)
			end
		end

		# /key
		r.on "key" do
			# /key/[username]
			r.is String do |username|
				username = clean_username(username)
				if username.nil?
					respond(r, response, "malformed parameter!", 400)
				end
				# GET /key/[username]
				r.get do
					if(login_tier < 2)
						respond_permission_denied(r, response)
					end

					user_name, user_tier = @users.get_user_by_name(username)
					if(user_name.nil?)
						respond(r, response, "username not found!", 404)
					end

					if(login_name == user_name)
						respond(r, response, "cant reset own apikey here, use GET /key instead!", 400)
					end

					remove_templates_sshkey(user_name)
					respond(r, response, @users.get_new_apikey(user_name))
				end
			end

			# GET /key
			r.get do
				remove_templates_sshkey(login_name)
				respond(r, response, @users.get_new_apikey(login_name))
			end
		end

	ensure
		if defined?(@users)
			@users.end()
		end
	end
end

run App