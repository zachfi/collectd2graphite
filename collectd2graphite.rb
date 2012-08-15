#! /usr/bin/env ruby

require 'sinatra'
#require 'pp'
require 'json'
require 'json2graphite'
require 'yaml'

config = YAML::load(File.read('etc/c2g.yaml'))

set :graphiteserver, config[:server]
set :graphiteport, config[:port]
set :port, 47654

post '/post-collectd' do
  request.body.rewind  # in case someone already read it
  received = JSON.parse request.body.read
  received.each do |r|
    #pp r

    # Values retrieved from the raw json
    time            = r["time"].to_i
    values          = r["values"]
    host            = r["host"].gsub('.', '_')
    type            = r["type"]
    type_instance   = r["type_instance"]
    plugin          = r["plugin"]
    plugin_instance = r["plugin_instance"]
    pluginstring    = [r["plugin"], ["plugin_instance"]].join('-')

    # Set the typestring for better target specification
    if type_instance.empty?
      typestring = r["type"]
    else
      typestring = [r["type"],r["type_instance"]].join('-')
    end

    # Set the pluginstring for better target specification
    if plugin_instance.empty?
      pluginstring = r["plugin"]
    else
      pluginstring = [r["plugin"],r["plugin_instance"]].join('-')
    end

    # Create some empty hashes to work with
    data = Hash.new
    data[:agents] = Hash.new
    data[:agents][host] = Hash.new
    data[:agents][host][pluginstring] = Hash.new

    # Fill in the hash
    values.each_index do |i|
      data[:agents][host][pluginstring][typestring] = r["values"][i]
    end

    #puts data.to_json
    # Convert the hash to graphite formatted data
    processed = Json2Graphite.get_graphite(data, time)
    #puts processed
    s = TCPSocket.open(settings.graphiteserver, settings.graphiteport)
    processed.each do |line|
      s.puts(line)
    end
    s.close
  end
end
