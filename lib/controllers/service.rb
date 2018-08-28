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
      end
    end
  end
end
