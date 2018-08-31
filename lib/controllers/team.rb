module Themis
  module Finals
    module Controllers
      class Team
        def initialize
          @logger = ::Themis::Finals::Utils::Logger.get
        end

        def all_teams(shuffle = false)
          res = ::Themis::Finals::Models::Team.all
          shuffle ? res.shuffle : res
        end

        def init_teams
          ::Themis::Finals::Models::DB.transaction do
            ::Themis::Finals::Configuration.get_teams.each { |p| create_team(p) }
          end
        end

        private
        def create_team(opts)
          ::Themis::Finals::Models::Team.create(
            name: opts.name,
            alias: opts.alias,
            network: opts.network,
            guest: opts.guest
          )
        end
      end
    end
  end
end
