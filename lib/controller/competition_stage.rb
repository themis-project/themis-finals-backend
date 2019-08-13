require './lib/util/event_emitter'
require './lib/const/competition_stage'
require 'json'

module VolgaCTF
  module Final
    module Controller
      class CompetitionStage
        def current
          val = ::VolgaCTF::Final::Model::CompetitionStage.last
          if val.nil?
            val = ::VolgaCTF::Final::Model::CompetitionStage.new(
              stage: ::VolgaCTF::Final::Const::CompetitionStage::NOT_STARTED,
              created_at: ::DateTime.now
            )
          end

          val
        end

        def init
          change_stage(::VolgaCTF::Final::Const::CompetitionStage::NOT_STARTED)
        end

        def enqueue_start
          change_stage(::VolgaCTF::Final::Const::CompetitionStage::STARTING)
        end

        def start
          change_stage(::VolgaCTF::Final::Const::CompetitionStage::STARTED)
        end

        def enqueue_pause
          change_stage(::VolgaCTF::Final::Const::CompetitionStage::PAUSING)
        end

        def pause
          change_stage(::VolgaCTF::Final::Const::CompetitionStage::PAUSED)
        end

        def enqueue_finish
          change_stage(::VolgaCTF::Final::Const::CompetitionStage::FINISHING)
        end

        def finish
          change_stage(::VolgaCTF::Final::Const::CompetitionStage::FINISHED)
        end

        private
        def change_stage(stage)
          ::VolgaCTF::Final::Model::DB.transaction do
            ::VolgaCTF::Final::Model::CompetitionStage.create(
              stage: stage,
              created_at: ::DateTime.now
            )

            ::VolgaCTF::Final::Util::EventEmitter.broadcast(
              'competition/stage',
              value: stage
            )
            ::VolgaCTF::Final::Util::EventEmitter.emit_log(1, value: stage)
          end
        end
      end
    end
  end
end
