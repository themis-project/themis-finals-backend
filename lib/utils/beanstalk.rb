require 'beaneater'

module Themis
  module Finals
    module Utils
      module Beanstalk
        # ::Beaneater.configure do |config|
        #   config.default_put_delay = 0
        #   config.default_put_ttr = ::Themis::Finals::Configuration.get_beanstalk_ttr
        # end

        def self.enqueue(channel, data, opts = {})
          beanstalk = ::Beaneater.new ENV['BEANSTALKD_URI']
          tube = beanstalk.tubes[channel]
          tube.put data, **opts
          beanstalk.close
        end
      end
    end
  end
end
