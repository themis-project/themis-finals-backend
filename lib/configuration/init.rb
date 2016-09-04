require './lib/configuration/team'
require './lib/configuration/service'
require './lib/configuration/contest_flow'
require './lib/configuration/network'

module Themis
  module Finals
    module Configuration
      def self.get_stream_config
        config = {
          network: {
            internal: [],
            team: []
          }
        }

        network_opts = get_network
        config[:network][:internal] = network_opts.internal

        ::Themis::Finals::Configuration.get_teams.each do |team_opts|
          config[:network][:team] << team_opts.network
        end

        config
      end
    end
  end
end
