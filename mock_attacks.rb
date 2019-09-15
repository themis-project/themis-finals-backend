require 'dotenv'
::Dotenv.load

require 'eventmachine'

require './lib/util/logger'
require './lib/model/bootstrap'
require './lib/util/event_emitter'

total_teams = ::VolgaCTF::Final::Model::Team.count
total_services = ::VolgaCTF::Final::Model::Service.count

logger = ::VolgaCTF::Final::Util::Logger.get

::EM.run do
  logger.info('Scheduler started, CTRL+C to stop')

  ::EM.add_periodic_timer 3 do
    num_attacks = ::Random.rand(::Range.new(total_teams / 2, total_teams * 2))

    num_attacks.times do
      actor_id = ::Random.rand(::Range.new(1, total_teams))
      target_id = actor_id
      while target_id == actor_id do
        target_id = ::Random.rand(::Range.new(1, total_teams))
      end

      ::VolgaCTF::Final::Util::EventEmitter.emit_log(
        4,
        actor_team_id: actor_id,
        target_team_id: target_id,
        target_service_id: ::Random.rand(::Range.new(1, total_services))
      )
    end
  end

  ::Signal.trap 'INT' do
    ::EM.stop
  end

  ::Signal.trap 'TERM' do
    ::EM.stop
  end
end
