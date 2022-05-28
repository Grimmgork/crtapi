require "roda"
require 'uri'
require 'net/http'

class Users

end

class Wlan

end

class Config

end

class App < Roda
	def ForwardRequest(req)
		# req -> Net::HTTP::Post.new(path)
		https = Net::HTTP.new("localhost", 5000)
		return https.request(req)
	end

	def GetAccessLevel(apiKey)
		#return -1 if not present
		if(apiKey == "kek")
			return 1
		end
		return -1
	end

	route do |r|

		apikey = env["HTTP_X_API_KEY"]
		tier = GetAccessLevel(apikey)
		
		#/switch
		r.on "switch" do
			if(tier < 0)
				response.status = 403
				response.write "Permission denied!"
				r.halt
			end

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
			if(tier < 1)
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
			if(tier < 2)
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
			if(tier < 0)
				response.status = 403
				response.write "Permission denied!"
				r.halt
			end
			#/key/[username]
			r.is String do |username|
				#GET /key/[username]
				r.get do
					"kek"
				end
			end
		end
	end
end

system("sudo systemctl start templates_sshkey_cleanup")
run App