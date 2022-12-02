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

	def respondtest
		puts "kek"
		return "kek"
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
		
		# /switch
		r.on "switch" do
			# /switch/[template]
			r.is String do |template|
				unless template = clean_username(template)
					response.status = 400
					next "malformed parameter!"
				end

				# POST /switch/[template]
				r.post do
					res = forward_request(Net::HTTP::Post.new("/switch/#{template}"))
					response.status = res.code
					res.body
				end
			end

			# GET /switch
			r.get do
				res = forward_request(Net::HTTP::Get.new("/switch"))
				response.status = res.code
				res.body
			end
		end

		# /templates
		r.on "templates" do
			if(login_tier < 1)
				response.status = 403
				next "permission denied!"
			end

			# GET /templates/key
			r.get "key" do
				sshkey = get_new_templates_sshkey(login_name)
				sshkey = nil
				if sshkey.nil?
					if 1 == 1
						response.status = 500
						next "internal error!"
					end
				end
				sshkey
			end

			# GET /templates
			r.get do
				res = forward_request(Net::HTTP::Get.new("/templates/"))
				response.status = res.code
				res.body
			end
		end

		# /users
		r.on "users" do
			# /users/new
			r.on "new" do
				if(login_tier < 3)
					response.status = 403
					next "permission denied!"
				end

				# /users/new/[name]
				r.is String do |username|
					unless username = clean_username(username)
						response.status = 400
						next "malformed parameter!"
					end

					r.post do
						unless apikey = @users.create_user(username)
							response.status = 400
							next "username taken!"
						end
						apikey
					end
				end
			end

			# /users/[username]
			r.is String do |username|
				unless username = clean_username(username)
					response.status = 400
					next "malformed parameter!"
				end

				user_name, user_tier = @users.get_user_by_name(username)
				unless user_name
					response.status = 404
					next "username not found!"
				end

				# GET /users/[username]
				r.get do
					# only tier 2 should inspect other users
					if user_name != login_name
						if(login_tier < 2)
							response,status = 403
							next "permission denied!"
						end
					end
					{ "name" => user_name, "tier" => user_tier }.to_json
				end

				if(login_tier < 2 || login_tier <= user_tier)
					response,status = 403
					next "permission denied!"
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
					"done!"
				end

				# DELETE /users/[username]
				r.delete do
					@users.remove_user(user_name)
					"user removed!"
				end
			end

			if(login_tier < 2)
				response,status = 403
				next "permission denied!"
			end

			# GET /users
			r.get do
				@users.get_all_users_as_hash().to_json
			end
		end

		# /key
		r.on "key" do
			# /key/[username]
			r.is String do |username|
				unless username = clean_username(username)
					response.status = 400
					next "malformed parameter!"
				end

				# GET /key/[username]
				r.get do
					if login_tier < 2
						response.status = 403
						next "permission denied!"
					end

					user_name, user_tier = @users.get_user_by_name(username)
					unless user_name
						response.status = 404
						next "username not found!"
					end

					if login_name == user_name
						response.static = 400
						next "cant reset own apikey here, use GET /key instead!"
					end

					remove_templates_sshkey(user_name)
					@users.get_new_apikey(user_name)
				end
			end

			# GET /key
			r.get do
				remove_templates_sshkey(login_name)
				@users.get_new_apikey(login_name)
			end
		end
	ensure
		if defined?(@users)
			@users.end()
		end
	end
end