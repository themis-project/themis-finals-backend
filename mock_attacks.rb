require 'dotenv'
::Dotenv.load

require 'eventmachine'

require './lib/util/logger'
require './lib/model/bootstrap'
require './lib/util/event_emitter'

$total_teams = ::VolgaCTF::Final::Model::Team.count
$total_services = ::VolgaCTF::Final::Model::Service.count

logger = ::VolgaCTF::Final::Util::Logger.get

def fake_state_change(event_name)
  ::Range.new(1, $total_teams).to_a.shuffle.each do |team_id|
    ::Range.new(1, $total_services).to_a.shuffle.each do |service_id|
      ::VolgaCTF::Final::Util::EventEmitter.broadcast(
        event_name,
        team_id: team_id,
        service_id: service_id,
        state: ::Random.rand(::Range.new(1, 4))
      )
    end
  end
end

def fake_attacks
    num_attacks = ::Random.rand(::Range.new($total_teams / 3, $total_teams))

    num_attacks.times do
      actor_id = ::Random.rand(::Range.new(1, $total_teams))
      target_id = actor_id
      while target_id == actor_id do
        target_id = ::Random.rand(::Range.new(1, $total_teams))
      end

      ::VolgaCTF::Final::Util::EventEmitter.broadcast_log(
        4,
        actor_team_id: actor_id,
        target_team_id: target_id,
        target_service_id: ::Random.rand(::Range.new(1, $total_services))
      )
    end
end

::EM.run do
  logger.info('Scheduler started, CTRL+C to stop')

  ::EM.add_periodic_timer 20 do
    fake_state_change('team/service/push-state')
  end

  ::EM.add_periodic_timer 10 do
    fake_state_change('team/service/pull-state')
  end

  ::EM.add_periodic_timer 5 do
    fake_attacks
  end

  ::EM.add_periodic_timer 7 do
    fake_attacks
  end

  ::EM.add_periodic_timer 11 do
    fake_attacks
  end

  ::Signal.trap 'INT' do
    ::EM.stop
  end

  ::Signal.trap 'TERM' do
    ::EM.stop
  end
end
