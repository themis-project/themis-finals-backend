require 'sequel'

module VolgaCTF
  module Final
    module Model
      class NotificationReadItem < ::Sequel::Model
        many_to_one :notification

        dataset_module do
          def for_addr(ip_addr)
            where(addr: ip_addr.to_s)
          end

          def for_notification(notification_id)
            where(notification_id: notification_id)
          end
        end
      end
    end
  end
end
