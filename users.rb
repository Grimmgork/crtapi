require 'securerandom'

require './filelock.rb'

class Users < FileLock

	def initialize()
		super("users.json")
		@index = Hash.new
		@root.each_with_index do |u, i|
			@index[u["name"]] = i
		end

		# make sure there is always a root user
		if create_user("root")
			update_user({"name" => "root", "tier" => 3})
		end
	end

	def get_new_apikey(name)
		puts @index
		h = @root[@index[name]]
		if h.nil?
			return nil
		end
		key = SecureRandom.hex(10)
		h["apikey"] = key
		report_change()
		return key
	end

	def get_user_by_apikey(apikey)
		if apikey.nil? || apikey.empty?
			return nil
		end
		@root.each do |u|
			ukey = u["apikey"]
			if(ukey != nil && ukey == apikey)
				return { "name" => u["name"], "tier" => u["tier"] }
			end
		end
		return nil
	end

	def extract_user_from_index(hash)
		res = {}
		["name", "tier"].each do |k|
			res[k] = hash[k]
		end
		return res
	end

	def get_all_users_as_hash()
		users = []
		@root.each do |u|
			users.push(get_user_by_name(u["name"]))
		end
		return users
	end

	def get_user_by_name(name)
		i = @index[name]
		if i.nil?
			return nil
		end
		return extract_user_from_index(@root[i])
	end

	def update_user(user)
		if @index[user["name"]].nil? || user["name"] == "root"
			return false
		end
		u = @root[@index[user["name"]]]
		["name", "tier"].each do |k|
			u[k] = user[k]
		end
		report_change()
		return true
	end

	def rename_user(name, newname)
		if not @index[newname].nil? || @index[name].nil?
			return false
		end
		i = @index[name]
		@root[i]["name"] = newname
		@index.delete(name)
		@index[newname] = i
		report_change()
		return true
	end

	def remove_user(name)
		if @index[name].nil? || name == "root"
			return false
		end
		@root.delete_at(@index[name])
		@index.delete(name)
		report_change()
		return true
	end

	def create_user(name)
		if @index[name]
			return nil
		end
		@root.push({"name" => name, "tier" => 0})
		@index[name] = @root.length-1
		report_change()
		return get_new_apikey(name)
	end
end