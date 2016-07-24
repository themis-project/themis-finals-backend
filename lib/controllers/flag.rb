require './lib/utils/flag_generator'
require './lib/utils/logger'

module Themis
  module Finals
    module Controllers
      module Flag
        @logger = ::Themis::Finals::Utils::Logger.get

        def self.issue(team, service, round)
          flag = nil

          ::Themis::Finals::Models::DB.transaction do
              str, adjunct = ::Themis::Finals::Utils::FlagGenerator.get_flag
              flag = ::Themis::Finals::Models::Flag.create(
                flag: str,
                created_at: ::DateTime.now,
                pushed_at: nil,
                expired_at: nil,
                considered_at: nil,
                adjunct: adjunct,
                service_id: service.id,
                team_id: team.id,
                round_id: round.id
              )
          end

          flag
        end
      end
    end
  end
end
