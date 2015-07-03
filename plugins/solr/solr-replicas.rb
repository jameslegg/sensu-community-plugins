#!/usr/bin/env ruby
## encoding: UTF-8
##  check-solr-cluster-replicas.rb
##
## DESCRIPTION:
##   Checks the a solr cluster's replicas to make sure there are not
##   more than one replica per node for each colletion
##
## OUTPUT:
##   plain text
##
## PLATFORMS:
##   Linux
##
## DEPENDENCIES:
##   gem: sensu-plugin
##   gem: rest-client
##   gem: json
##
## USAGE:
##   # Basic usage
##   check-solr-cluster-replicas.rb -u 'http://solr-host:8983/solr'
##
## LICENSE:
##   Copyright 2015 James Legg <mail@jameslegg.co.uk>
##   Released under the same terms as Sensu (the MIT license); see LICENSE for
##   details.
##
require 'sensu-plugin/check/cli'
require 'rest-client'
require 'json'

class CheckSolrReplicas < Sensu::Plugin::Check::CLI
  option :solr_url,
         description: 'The url of the solr node to check',
         short: '-s SOLRURL',
         long: '--solrurl SOLRURL',
         default: 'http://localhost:8983/solr'

  def cluster_state
    clust = 'admin/collections?action=clusterstatus&wt=json'
    r = RestClient.get("#{config[:solr_url]}/#{clust}")
    warning "HTTP#{r.code} recieved from API" unless r.code == 200
    JSON.parse(r.body)
  end

  def run
    cs = cluster_state
    dupes = Array.new
    cs['cluster']['collections'].each do |c, coll|
      cs['cluster']['collections'][c]['shards'].each do |s,shard|
        shard['replicas'].each do |r,rep|
          cs['cluster']['collections'][c]['shards'].each do |is,ishard|
            ishard['replicas'].each do |ir,irep|
              if s != is && r != ir && rep['node_name'] == irep['node_name']
                doop = { name: rep['node_name'],
                         coll: c,
                         shards: [s, is].sort }
                unless dupes.include?(doop)
                  dupes << doop
                end
              end
            end
          end
        end
      end
    end
    if dupes.length > 0
      dupes.each do |dupe|
        puts "Node: #{dupe[:name]} in collection #{dupe[:coll]} is in #{dupe[:shards].join (", ")}"
      end
      critical
    else
      ok
    end
  end
end
