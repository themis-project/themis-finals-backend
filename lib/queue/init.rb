require './lib/utils/logger'
require 'beaneater'
require './lib/controllers/contest'
require 'json'

module Themis
  module Finals
    module Queue
      @logger = ::Themis::Finals::Utils::Logger.get

      def self.run
        beanstalk = ::Beaneater.new ENV['BEANSTALKD_URI']
        @logger.info 'Connected to beanstalk server'

        tube_namespace = ENV['BEANSTALKD_TUBE_NAMESPACE']

        beanstalk.jobs.register "#{tube_namespace}.main" do |job|
          begin
            case job.body
            when 'push'
              contest_state = ::Themis::Finals::Models::ContestState.last
              if !contest_state.nil? && (contest_state.is_await_start ||
                                         contest_state.is_running)
                if contest_state.is_await_start
                  ::Themis::Finals::Controllers::Contest.start
                end
                ::Themis::Finals::Controllers::Contest.push_flags
              end
            when 'poll'
              contest_state = ::Themis::Finals::Models::ContestState.last
              unless contest_state.nil?
                if contest_state.is_running || contest_state.is_await_complete
                  ::Themis::Finals::Controllers::Contest.poll_flags
                elsif contest_state.is_paused
                  ::Themis::Finals::Controllers::Contest.prolong_flag_lifetimes
                end
              end
            when 'update'
              contest_state = ::Themis::Finals::Models::ContestState.last
              if !contest_state.nil? && (contest_state.is_running ||
                                         contest_state.is_await_complete)
                begin
                  ::Themis::Finals::Controllers::Contest.update_all_scores
                rescue => e
                  @logger.error e.to_s
                end
              end
            else
              @logger.warn "Unknown job #{job.body}"
            end
          rescue => e
            @logger.error e.to_s
          end
        end

        ::Themis::Finals::Models::Service.all.each do |service|
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
                    job_data['adjunct']
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
