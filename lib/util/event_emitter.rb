require 'date'
require 'json'
require './lib/util/publisher'
require './lib/util/logger'

module VolgaCTF
  module Final
    module Util
      module EventEmitter
        @logger = ::VolgaCTF::Final::Util::Logger.get

        def self.emit(name, internal_data, teams_data, external_data, team_data={})
          event = nil
          ::VolgaCTF::Final::Model::DB.transaction do
            data = {
              internal: internal_data,
              teams: teams_data,
              team: team_data,
              external: external_data,
            }

            event = ::VolgaCTF::Final::Model::ServerSentEvent.create(
              name: name,
              data: data,
              created: DateTime.now
            )

            ::VolgaCTF::Final::Model::DB.after_commit do
              begin
                publisher = ::VolgaCTF::Final::Util::Publisher.new
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
