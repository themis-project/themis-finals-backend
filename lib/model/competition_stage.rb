require 'sequel'
require './lib/const/competition_stage'

module VolgaCTF
  module Final
    module Model
      class CompetitionStage < ::Sequel::Model
        def not_started?
          stage == ::VolgaCTF::Final::Const::CompetitionStage::NOT_STARTED
        end

        def starting?
          stage == ::VolgaCTF::Final::Const::CompetitionStage::STARTING
        end

        def started?
          stage == ::VolgaCTF::Final::Const::CompetitionStage::STARTED
        end

        def pausing?
          stage == ::VolgaCTF::Final::Const::CompetitionStage::PAUSING
        end

        def paused?
          stage == ::VolgaCTF::Final::Const::CompetitionStage::PAUSED
        end

        def finishing?
          stage == ::VolgaCTF::Final::Const::CompetitionStage::FINISHING
        end

        def finished?
          stage == ::VolgaCTF::Final::Const::CompetitionStage::FINISHED
        end

        def any?(*stages)
          stages.each do |stage|
            method_name = (stage.to_s + '?').to_sym
            return true if send(method_name)
          end

          return false
        end
      end
    end
  end
end
