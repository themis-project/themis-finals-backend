require 'sequel'

require './lib/constants/flag_poll_state'

module VolgaCTF
  module Final
    module Models
      class FlagPoll < ::Sequel::Model
        many_to_one :flag

        def success?
          state == ::VolgaCTF::Final::Constants::FlagPollState::SUCCESS
        end

        def error?
          state == ::VolgaCTF::Final::Constants::FlagPollState::ERROR
        end

        dataset_module do
          def relevant(flag)
            where(flag_id: flag.id).exclude(state: ::VolgaCTF::Final::Constants::FlagPollState::NOT_AVAILABLE)
          end
        end
      end
    end
  end
end
