module Themis
  module Finals
    module Configuration
      def self.service(name, &block)
        service_dsl = ServiceDSL.new name
        service_dsl.instance_eval &block
        @_services << service_dsl.service
      end

      def self.get_services
        @_services
      end

      class Service
        attr_accessor :alias, :name, :hostmask, :metadata

        def initialize(service_alias)
          @alias = service_alias
          @name = nil
          @hostmask = nil
          @metadata = {}
        end
      end

      class ServiceDSL
        attr_reader :service

        def initialize(service_alias)
          @service = Service.new service_alias
        end

        def name(name)
          @service.name = name
        end

        def hostmask(hostmask)
          @service.hostmask = hostmask
        end

        def metadata(metadata)
          @service.metadata = metadata
        end
      end

      protected
      @_services = []
    end
  end
end
