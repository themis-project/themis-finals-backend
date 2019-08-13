require 'date'

require './lib/const/flag_poll_state'

module VolgaCTF
  module Final
    module Controller
      class FlagPoll
        def create_flag_poll(flag)
          ::VolgaCTF::Final::Model::FlagPoll.create(
            state: ::VolgaCTF::Final::Const::FlagPollState::NOT_AVAILABLE,
            created_at: ::DateTime.now,
            updated_at: nil,
            flag_id: flag.id
          )
        end
      end
    end
  end
end
