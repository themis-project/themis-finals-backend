require './lib/configuration/team'
require './lib/configuration/service'
require './lib/configuration/contest_flow'
require './lib/configuration/network'


module Themis
    module Configuration
        def self.get_stream_config
            config = {
                network: {
                    internal: [],
                    other: [],
                    teams: []
                }
            }

            network_opts = get_network
            config[:network][:internal] = network_opts.internal
            config[:network][:other] = network_opts.other

            Themis::Configuration::get_teams.each do |team_opts|
                config[:network][:teams] << team_opts.network
            end

            config
        end
    end
end
