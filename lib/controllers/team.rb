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
      end
    end
  end
end
