require 'beaneater'


module Themis
    module Utils
        module Queue
            def self.enqueue(channel, data, opts = {})
                beanstalk = Beaneater.new ENV['BEANSTALKD_URI']
                tube = beanstalk.tubes[channel]
                tube.put data, **opts
                beanstalk.close
            end
        end
    end
end
