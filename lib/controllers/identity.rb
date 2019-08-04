require 'ip'

require './lib/controllers/domain'

module VolgaCTF
  module Final
    module Controllers
      class Identity
        def initialize
          @domain_ctrl = ::VolgaCTF::Final::Controllers::Domain.new
        end

        def get_team(remote_ip)
          ::VolgaCTF::Final::Models::Team.all.detect do |team|
            network = ::IP.new(team.network)
            remote_ip.is_in?(network)
          end
        end

        def is_internal?(remote_ip)
          return false unless @domain_ctrl.available?

          r = @domain_ctrl.network.internal.detect do |network|
            remote_ip.is_in?(network)
          end
          !r.nil?
        end
      end
    end
  end
end
