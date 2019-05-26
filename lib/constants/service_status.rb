require 'ruby-enum'

module Themis
  module Finals
    module Constants
      class ServiceStatus
        include ::Ruby::Enum

        define :NOT_UP, 0
        define :UP, 1
      end
    end
  end
end
