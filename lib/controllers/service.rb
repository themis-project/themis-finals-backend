module Themis
  module Finals
    module Controllers
      class Service
        def initialize
          @logger = ::Themis::Finals::Utils::Logger.get
        end

        def all_services(shuffle = false)
          res = ::Themis::Finals::Models::Service.all
          shuffle ? res.shuffle : res
        end

        def init_services
          ::Themis::Finals::Models::DB.transaction do
            ::Themis::Finals::Configuration.get_services.each { |p| create_service(p) }
          end
        end

        private
        def create_service(opts)
          ::Themis::Finals::Models::Service.create(
            name: opts.name,
            alias: opts.alias,
            hostmask: opts.hostmask,
            checker_endpoint: opts.checker_endpoint
          )
        end
      end
    end
  end
end
