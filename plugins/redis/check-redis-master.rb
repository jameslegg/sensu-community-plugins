#!/usr/bin/env ruby
#
# Checks Redis INFO stats and limits values
# ===
#
# Copyright (c) 2012, Panagiotis Papadomitsos <pj@ezgr.net>
#
# Released under the same terms as Sensu (the MIT license); see LICENSE
# for details.

require 'rubygems' if RUBY_VERSION < '1.9.0'
require 'sensu-plugin/check/cli'
require 'redis'

class RedisChecks < Sensu::Plugin::Check::CLI

  option :host,
    :short => "-h HOST",
    :long => "--host HOST",
    :description => "Redis Host to connect to",
    :required => false,
    :default => '127.0.0.1'

  option :port,
    :short => "-p PORT",
    :long => "--port PORT",
    :description => "Redis Port to connect to",
    :proc => proc {|p| p.to_i },
    :required => false,
    :default => 26379

  option :password,
    :short => "-P PASSWORD",
    :long => "--password PASSWORD",
    :required => false,
    :description => "Redis Password to connect with"

  option :set_master_ip,
    :short => "-m MASTER",
    :long => "--master MASTER",
    :description => "The expected master redis instance IP",
    :required => true

  option :set_slave_ip,
    :short => "-s SLAVE",
    :long => "--slave SLAVE",
    :description => "The expected slave redis instance IP",
    :required => true

  option :redis_group_name,
    :short => "-n NAME",
    :long => "--name NAME",
    :description => "identifiable name for redis group to appear in warnings",
    :required => true

  option :crit_conn,
    :long => "--crit-conn-failure",
    :boolean => true,
    :description => "Critical instead of warning on connection failure",
    :default => false

  def run
    begin
      options = {:host => config[:host], :port => config[:port]}
      options[:password] = config[:password] if config[:password]
      redis = Redis.new(options)

      masters = redis.sentinel('masters')
      #assumption made the sentinel always stores things in the same place
      master_ip = masters[0][3]
      slave = redis.sentinel('slaves', "#{masters[0][1]}")
      slave_ip = slave[0][3]
      if (master_ip != config[:set_master_ip])
        warning "Redis-sentinel running on #{config[:host]}:#{config[:port]} does not have the expected master: #{config[:set_master_ip]}. #{config[:redis_group_name]} may have failed over"
      elsif (slave_ip != config[:set_slave_ip])
        warning "Redis-sentinel running on #{config[:host]}:#{config[:port]} does not have the expecte slave with ip: #{config[:set_slave_ip]} #{config[:redis_group_name]} may have failed over"
      else
        ok 'Redis master/slave relationship is as expected'
      end
    rescue
      message = "Could not connect to Redis server on #{config[:host]}:#{config[:port]}"
      if config[:crit_conn]
        critical message
      else
        warning message
      end
    end
  end

end
