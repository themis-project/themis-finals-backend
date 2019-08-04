require './lib/utils/event_emitter'
require './lib/controllers/round'

module VolgaCTF
  module Final
    module Controllers
      class Service
        def initialize
          @logger = ::VolgaCTF::Final::Utils::Logger.get
          @round_ctrl = ::VolgaCTF::Final::Controllers::Round.new
        end

        def enabled_services(shuffle: false, round: nil)
          res = ::VolgaCTF::Final::Models::Service.enabled(round: round).all
          shuffle ? res.shuffle : res
        end

        def init_services(entries)
          ::VolgaCTF::Final::Models::DB.transaction do
            entries.each { |p| create_service(p) }
          end
        end

        def enable_all
          ::VolgaCTF::Final::Models::DB.transaction do
            ::VolgaCTF::Final::Models::Service.each do |service|
              service.enabled = true
              service.save

              ::VolgaCTF::Final::Utils::EventEmitter.broadcast(
                'service/enable',
                service.serialize
              )

              ::VolgaCTF::Final::Utils::EventEmitter.emit_log(
                41,
                service_name: service.name
              )
            end
          end
        end

        def can_enable?(service, in_round)
          !service.enabled && in_round > @round_ctrl.last_number
        end

        def enqueue_enable(service_alias, in_round)
          service = ::VolgaCTF::Final::Models::Service.named(service_alias)
          raise "Service #{service_alias} does not exist!" if service.nil?

          can_do = can_enable?(service, in_round)
          raise "Service #{service_alias} cannot be enabled in round #{in_round}!" if !can_do

          ::VolgaCTF::Final::Models::DB.transaction do
            service.enable_in = in_round
            service.save

            ::VolgaCTF::Final::Utils::EventEmitter.emit_log(
              43,
              service_name: service.name,
              service_enable_in: service.enable_in
            )
          end
        end

        def can_disable?(service, in_round)
          service.enabled && in_round > @round_ctrl.last_number
        end

        def enqueue_disable(service_alias, in_round)
          service = ::VolgaCTF::Final::Models::Service.named(service_alias)
          raise "Service #{service_alias} does not exist!" if service.nil?

          can_do = can_disable?(service, in_round)
          raise "Service #{service_alias} cannot be disabled in round #{in_round}!" if !can_do

          ::VolgaCTF::Final::Models::DB.transaction do
            service.disable_in = in_round
            service.save

            ::VolgaCTF::Final::Utils::EventEmitter.broadcast(
              'service/modify',
              service.serialize
            )

            ::VolgaCTF::Final::Utils::EventEmitter.emit_log(
              44,
              service_name: service.name,
              service_disable_in: service.disable_in
            )
          end
        end

        def ensure_enable(round)
          ::VolgaCTF::Final::Models::DB.transaction do
            ::VolgaCTF::Final::Models::Service.enabling(round).each do |service|
              service.enabled = true
              service.save

              ::VolgaCTF::Final::Utils::EventEmitter.broadcast(
                'service/enable',
                service.serialize
              )

              ::VolgaCTF::Final::Utils::EventEmitter.emit_log(
                41,
                service_name: service.name
              )
            end
          end
        end

        def ensure_disable(round)
          ::VolgaCTF::Final::Models::DB.transaction do
            ::VolgaCTF::Final::Models::Service.disabling(round).each do |service|
              service.enabled = false
              service.save

              ::VolgaCTF::Final::Utils::EventEmitter.broadcast(
                'service/disable',
                id: service.id
              )

              ::VolgaCTF::Final::Utils::EventEmitter.emit_log(
                42,
                service_name: service.name
              )
            end
          end
        end

        def can_award_defence?(s, r)
          !s.attack_priority ||
          (s.attack_priority && !s.award_defence_after.nil? && r.id > s.award_defence_after)
        end

        private
        def create_service(opts)
          ::VolgaCTF::Final::Models::Service.create(
            name: opts.name,
            alias: opts.alias,
            hostmask: opts.hostmask,
            checker_endpoint: opts.checker_endpoint,
            attack_priority: opts.attack_priority,
            award_defence_after: nil,
            enabled: false,
            enable_in: nil,
            disable_in: nil
          )
        end
      end
    end
  end
end
