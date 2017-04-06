require 'ruby-enum'

module Themis
  module Finals
    module Constants
      class Protocol
        include ::Ruby::Enum

        define :REST_BASIC, 2
      end
    end
  end
end
