use Rack::Static, :urls => {'/' => 'index.html'}, :root => "static"
use Rack::Static, :urls => {'/index.html' => 'index.html'}, :root => "static"
use Rack::Static, :urls => {'/favicon.ico' => 'favicon.ico'}, :root => "static"
use Rack::Static, :urls => ['/static'], :root => "static"

require './app.rb'
run App