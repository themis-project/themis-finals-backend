require './lib/utils/logger'
require 'beaneater'
require './lib/controllers/contest'
require './lib/constants/protocol'
require 'json'
require 'base64'

module Themis
  module Finals
    module Beanstalk
      @logger = ::Themis::Finals::Utils::Logger.get

      def self.run
        beanstalk = ::Beaneater.new ENV['BEANSTALKD_URI']
        @logger.info 'Connected to beanstalk server'

        tube_namespace = ENV['BEANSTALKD_TUBE_NAMESPACE']

        ::Themis::Finals::Models::Service.all.each do |service|
          next unless service.protocol == ::Themis::Finals::Constants::Protocol::BEANSTALK
          channel = "#{tube_namespace}.service.#{service.alias}.report"
          beanstalk.jobs.register channel do |job|
            begin
              job_data = ::JSON.parse job.body
              case job_data['operation']
              when 'push'
                flag = ::Themis::Finals::Models::Flag.first(
                  flag: job_data['flag']
                )
                if flag.nil?
                  @logger.error "Failed to find flag #{job_data['flag']}!"
                else
                  ::Themis::Finals::Controllers::Contest.handle_push(
                    flag,
                    job_data['status'],
                    ::Base64.decode64(job_data['adjunct'])
                  )
                end
              when 'pull'
                poll = ::Themis::Finals::Models::FlagPoll.first(
                  id: job_data['request_id']
                )
                if poll.nil?
                  @logger.error "Failed to find poll #{job_data['request_id']}"
                else
                  ::Themis::Finals::Controllers::Contest.handle_poll(
                    poll,
                    job_data['status']
                  )
                end
              else
                @logger.error "Unknown job #{job.body}"
              end
            rescue => e
              @logger.error e.to_s
            end
          end
        end

        begin
          beanstalk.jobs.process!
        rescue Interrupt
          @logger.info 'Received shutdown signal'
        end
        beanstalk.close
        @logger.info 'Disconnected from beanstalk server'
      end
    end
  end
end
