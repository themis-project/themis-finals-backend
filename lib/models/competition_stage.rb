require 'sequel'
require './lib/constants/competition_stage'

module Themis
  module Finals
    module Models
      class CompetitionStage < ::Sequel::Model
        def not_started?
          stage == ::Themis::Finals::Const::CompetitionStage::NOT_STARTED
        end

        def starting?
          stage == ::Themis::Finals::Const::CompetitionStage::STARTING
        end

        def started?
          stage == ::Themis::Finals::Const::CompetitionStage::STARTED
        end

        def pausing?
          stage == ::Themis::Finals::Const::CompetitionStage::PAUSING
        end

        def paused?
          stage == ::Themis::Finals::Const::CompetitionStage::PAUSED
        end

        def finishing?
          stage == ::Themis::Finals::Const::CompetitionStage::FINISHING
        end

        def finished?
          stage == ::Themis::Finals::Const::CompetitionStage::FINISHED
        end
      end
    end
  end
end
