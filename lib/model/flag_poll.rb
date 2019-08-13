require 'sequel'

require './lib/const/flag_poll_state'

module VolgaCTF
  module Final
    module Model
      class FlagPoll < ::Sequel::Model
        many_to_one :flag

        def success?
          state == ::VolgaCTF::Final::Const::FlagPollState::SUCCESS
        end

        def error?
          state == ::VolgaCTF::Final::Const::FlagPollState::ERROR
        end

        dataset_module do
          def relevant(flag)
            where(flag_id: flag.id).exclude(state: ::VolgaCTF::Final::Const::FlagPollState::NOT_AVAILABLE)
          end
        end
      end
    end
  end
end
