require 'sequel'

require './lib/constants/flag_poll_state'

module Themis
  module Finals
    module Models
      class FlagPoll < ::Sequel::Model
        many_to_one :flag

        def success?
          state == ::Themis::Finals::Constants::FlagPollState::SUCCESS
        end

        def error?
          state == ::Themis::Finals::Constants::FlagPollState::ERROR
        end

        dataset_module do
          def relevant(flag)
            where(flag_id: flag.id).exclude(state: ::Themis::Finals::Constants::FlagPollState::NOT_AVAILABLE)
          end
        end
      end
    end
  end
end
