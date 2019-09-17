require 'sequel'

module VolgaCTF
  module Final
    module Model
      class ServerSentEvent < ::Sequel::Model
        def serialize_log
          {
            id: id,
            type: data['internal']['type'],
            params: data['internal']['params'],
            created: created.iso8601
          }
        end

        dataset_module do
          def log
            where(name: 'log')
          end

          def log_before(timestamp)
            log.where { created < timestamp }
          end

          def paginate(timestamp, page, page_size)
            log_before(timestamp).order(:id).limit(page_size).offset((page - 1) * page_size)
          end
        end
      end
    end
  end
end
