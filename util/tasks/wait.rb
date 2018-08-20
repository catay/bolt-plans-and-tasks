#!/usr/bin/env ruby

require 'json'
require 'puppet'

params = JSON.parse(STDIN.read)
seconds = params['seconds']

sleep seconds
puts "{ status: 'success' }".to_json
exit 0
