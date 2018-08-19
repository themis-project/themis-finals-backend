require 'ip'

module Themis
  module Finals
    module Controllers
      class Identity
        def get_team(remote_ip)
          ::Themis::Finals::Models::Team.all.detect do |team|
            network = ::IP.new(team.network)
            remote_ip.is_in?(network)
          end
        end

        def is_internal?(remote_ip)
          r = ::Themis::Finals::Configuration.get_network.internal.detect do |network|
            remote_ip.is_in?(network)
          end
          !r.nil?
        end
      end
    end
  end
end
