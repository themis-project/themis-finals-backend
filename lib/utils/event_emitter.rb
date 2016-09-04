require 'date'
require 'json'
require './lib/utils/publisher'
require './lib/utils/logger'

module Themis
  module Finals
    module Utils
      module EventEmitter
        @logger = ::Themis::Finals::Utils::Logger.get

        def self.emit(name, data, internal, team, external)
          event = nil
          ::Themis::Finals::Models::DB.transaction do
            event = ::Themis::Finals::Models::ServerSentEvent.create(
              name: name,
              data: data,
              internal: internal,
              team: team,
              external: external
            )

            ::Themis::Finals::Models::DB.after_commit do
              begin
                publisher = ::Themis::Finals::Utils::Publisher.new
                event_data = {
                  id: event.id,
                  name: name,
                  data: data
                }.to_json

                namespace = ENV['THEMIS_FINALS_STREAM_REDIS_CHANNEL_NAMESPACE']

                if internal
                  publisher.publish "#{namespace}:internal", event_data
                end

                if team
                  publisher.publish "#{namespace}:team", event_data
                end

                if external
                  publisher.publish "#{namespace}:external", event_data
                end
              rescue => e
                @logger.error "Failed to publish the event. #{e}"
              end
            end
          end
        end

        def self.emit_all(name, data)
          emit name, data, true, true, true
        end

        def self.emit_log(type, params)
          emit 'log', { type: type, params: params }, true, false, false
        end
      end
    end
  end
end
