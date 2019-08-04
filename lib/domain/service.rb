module VolgaCTF
  module Final
    module Domain
      def self.service(name, &block)
        service_dsl = ServiceDSL.new name
        service_dsl.instance_eval &block
        @_services << service_dsl.service
      end

      def self.get_services
        @_services
      end

      class Service
        attr_accessor :alias, :name, :hostmask, :checker_endpoint, :attack_priority,
                      :enable_in, :disable_in

        def initialize(service_alias)
          @alias = service_alias
          @name = nil
          @hostmask = nil
          @checker_endpoint = nil
          @attack_priority = false
        end
      end

      class ServiceDSL
        attr_reader :service

        def initialize(service_alias)
          @service = Service.new(service_alias)
        end

        def name(name)
          @service.name = name
        end

        def hostmask(hostmask)
          @service.hostmask = hostmask
        end

        def checker_endpoint(checker_endpoint)
          @service.checker_endpoint = checker_endpoint
        end

        def attack_priority(attack_priority)
          @service.attack_priority = attack_priority
        end
      end

      protected
      @_services = []
    end
  end
end
