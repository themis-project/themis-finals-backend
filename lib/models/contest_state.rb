require 'sequel'
require './lib/constants/contest_state'

module Themis
  module Finals
    module Models
      class ContestState < ::Sequel::Model
        def is_initial
          state == ::Themis::Finals::Constants::ContestState::INITIAL
        end

        def is_await_start
          state == ::Themis::Finals::Constants::ContestState::AWAIT_START
        end

        def is_running
          state == ::Themis::Finals::Constants::ContestState::RUNNING
        end

        def is_paused
          state == ::Themis::Finals::Constants::ContestState::PAUSED
        end

        def is_await_complete
          state == ::Themis::Finals::Constants::ContestState::AWAIT_COMPLETE
        end

        def is_completed
          state == ::Themis::Finals::Constants::ContestState::COMPLETED
        end
      end
    end
  end
end
