require 'date'

require './lib/constants/flag_poll_state'

module VolgaCTF
  module Final
    module Controllers
      class FlagPoll
        def create_flag_poll(flag)
          ::VolgaCTF::Final::Models::FlagPoll.create(
            state: ::VolgaCTF::Final::Constants::FlagPollState::NOT_AVAILABLE,
            created_at: ::DateTime.now,
            updated_at: nil,
            flag_id: flag.id
          )
        end
      end
    end
  end
end
