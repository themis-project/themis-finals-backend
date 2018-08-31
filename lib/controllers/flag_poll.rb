require 'date'

require './lib/constants/flag_poll_state'

module Themis
  module Finals
    module Controllers
      class FlagPoll
        def create_flag_poll(flag)
          ::Themis::Finals::Models::FlagPoll.create(
            state: ::Themis::Finals::Constants::FlagPollState::NOT_AVAILABLE,
            created_at: ::DateTime.now,
            updated_at: nil,
            flag_id: flag.id
          )
        end
      end
    end
  end
end
