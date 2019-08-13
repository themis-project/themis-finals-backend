require 'ruby-enum'

module VolgaCTF
  module Final
    module Const
      class ServiceStatus
        include ::Ruby::Enum

        define :NOT_UP, 0
        define :UP, 1
      end
    end
  end
end
