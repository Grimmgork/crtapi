use Rack::Static, :urls => ["/static"]

require './app.rb'
run App