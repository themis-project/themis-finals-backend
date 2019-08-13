require 'ip'

require './lib/controller/domain'

module VolgaCTF
  module Final
    module Controller
      class Identity
        def initialize
          @domain_ctrl = ::VolgaCTF::Final::Controller::Domain.new
        end

        def get_team(remote_ip)
          ::VolgaCTF::Final::Model::Team.all.detect do |team|
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
