#!/usr/bin/env ruby
#
# Checks Redis Sentinel Status
# ===
#
# Will check that a master/slave relationship in a redis pairing is as orginally
# setup and will warn if master/slave role swaps.

require 'rubygems' if RUBY_VERSION < '1.9.0'
require 'sensu-plugin/check/cli'
require 'redis'
require 'resolv'

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

  option :set_master,
    :short => "-m MASTER",
    :long => "--master MASTER",
    :description => "The expected master redis resolvable DNS name",
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

      # An assumption has been made that sentinel's status info
      # will allways in the same place
      master = redis.sentinel('masters')[0]
      master_ip = master[3]
      master_name = master[1]

      # resolve the supplied names
      set_master_ip = Resolv.getaddress config[:set_master]

      if (master_ip != set_master_ip)
        warning "Redis-sentinel running on #{config[:host]}:#{config[:port]} does not have the expected master: #{config[:set_master]}. #{config[:redis_group_name]} may have failed over"
      else
        ok 'Redis master/slave relationship is as expected'
      end
    rescue Resolv::ResolvError => dns_err
      critical "#{dns_err}"
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
