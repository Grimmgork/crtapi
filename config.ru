require 'rack/rewrite'
require './app.rb'

use Rack::Rewrite do
	rewrite   '/',  '/static/index.html'
	rewrite   '/favicon.ico',  '/static/favicon.ico'
	rewrite	'/readme', '/static/readme.txt'
end

use Rack::Static, :urls => ["/static"]

map '/api' do
	run App
end