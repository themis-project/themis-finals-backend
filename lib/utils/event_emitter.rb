require 'date'
require 'json'
require './lib/utils/publisher'
require './lib/utils/logger'

module VolgaCTF
  module Final
    module Utils
      module EventEmitter
        @logger = ::VolgaCTF::Final::Utils::Logger.get

        def self.emit(name, internal_data, teams_data, external_data, team_data={})
          event = nil
          ::VolgaCTF::Final::Models::DB.transaction do
            data = {
              internal: internal_data,
              teams: teams_data,
              team: team_data,
              external: external_data,
            }

            event = ::VolgaCTF::Final::Models::ServerSentEvent.create(
              name: name,
              data: data,
              created: DateTime.now
            )

            ::VolgaCTF::Final::Models::DB.after_commit do
              begin
                publisher = ::VolgaCTF::Final::Utils::Publisher.new
                event_data = {
                  id: event.id,
                  name: name,
                  data: data,
                  created: event.created.iso8601
                }.to_json

                publisher.publish(
                  "#{::ENV['VOLGACTF_FINAL_STREAM_REDIS_CHANNEL_NAMESPACE']}:events",
                  event_data
                )
              rescue => e
                @logger.error("Failed to publish the event. #{e}")
              end
            end
          end
        end

        def self.broadcast(name, data)
          emit(name, data, data, data)
        end

        def self.emit_log(type, params)
          emit('log', { type: type, params: params }, nil, nil)
        end
      end
    end
  end
end
