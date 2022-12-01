require 'securerandom'

require './filelock.rb'

User = Struct.new(:name, :apikey, :tier)

class Users < FileLock

	def initialize()
		super("auth.csv")

		@users = []
		read_file_lines do |l|
			v = l.split("|",3)
			@users.push(User.new(v[0], v[1], v[2].to_i))
		end

		# make sure there is always a root user with tier 3
		if create_user("root")
			@users[get_user_index_by_name("root")].tier = 3
		end
	end

	def serialize_content
		@users.each do |u|
			yield "#{u.name}|#{u.apikey}|#{u.tier}\n"
		end
	end

	def get_new_apikey(name)
		if name.nil? || name.empty?
			return nil
		end
		key = SecureRandom.hex(10)
		@users[get_user_index_by_name(name)].apikey = key
		report_change()
		return key
	end

	def get_all_users_as_hash
		res = []
		@users.each_with_index do |u, i|
			name, tier = get_user_data(i)
			res.push({"name" => name, "tier" => tier})
		end
		return res
	end

	def get_user_by_apikey(apikey)
		if apikey.nil? || apikey.empty?
			return nil
		end
		@users.each_with_index do |u, i|
			if u.apikey == apikey
				return get_user_data(i)
			end
		end
		return nil
	end

	def get_user_by_name(name)
		return get_user_data(get_user_index_by_name(name))
	end

	def get_user_data(index)
		if index.nil?
			return nil
		end
		return @users[index].name, @users[index].tier
	end

	def get_user_index_by_name(name)
		@users.each_with_index do |u, i|
			if u.name == name
				return i
			end
		end
		return nil
	end

	def username_taken?(name)
		return !get_user_index_by_name(name).nil?
	end

	def rename_user(name, newname)
		i = get_user_index_by_name(name)
		if i.nil? || name == "root" || username_taken?(newname)
			return false
		end
		@users[i].name = newname
		report_change()
		return true
	end

	def set_user_tier(name, tier)
		i = get_user_index_by_name(name)
		if i.nil? || name == "root"
			return false
		end
		@users[i].tier = tier
		report_change()
		return true
	end

	def remove_user(name)
		i = get_user_index_by_name(name)
		if i.nil? || name == "root"
			return false
		end
		@users.delete_at(i)
		report_change()
		return true
	end

	def create_user(name)
		if username_taken?(name)
			return nil
		end
		@users.push(User.new(name, nil, 0))
		report_change()
		return get_new_apikey(name)
	end
end