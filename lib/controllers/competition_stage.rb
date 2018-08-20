require './lib/utils/event_emitter'
require './lib/constants/competition_stage'
require 'json'

module Themis
  module Finals
    module Controllers
      class CompetitionStage
        def current
          val = ::Themis::Finals::Models::CompetitionStage.last
          if val.nil?
            val = ::Themis::Finals::Models::CompetitionStage.new(
              stage: ::Themis::Finals::Const::CompetitionStage::NOT_STARTED,
              created_at: ::DateTime.now
            )
          end

          val
        end

        def init
          change_stage(::Themis::Finals::Const::CompetitionStage::NOT_STARTED)
        end

        def enqueue_start
          change_stage(::Themis::Finals::Const::CompetitionStage::STARTING)
        end

        def start
          change_stage(::Themis::Finals::Const::CompetitionStage::STARTED)
        end

        def resume
          change_stage(::Themis::Finals::Const::CompetitionStage::STARTED)
        end

        def pause
          change_stage(::Themis::Finals::Const::CompetitionStage::PAUSED)
        end

        def enqueue_finish
          change_stage(::Themis::Finals::Const::CompetitionStage::FINISHING)
        end

        def finish
          change_stage(::Themis::Finals::Const::CompetitionStage::FINISHED)
        end

        private
        def change_stage(stage)
          ::Themis::Finals::Models::DB.transaction do
            ::Themis::Finals::Models::CompetitionStage.create(
              stage: stage,
              created_at: ::DateTime.now
            )

            ::Themis::Finals::Utils::EventEmitter.broadcast(
              'competition/stage',
              value: stage
            )
            ::Themis::Finals::Utils::EventEmitter.emit_log(1, value: stage)
          end
        end
      end
    end
  end
end
