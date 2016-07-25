require 'ruby-enum'

module Themis
  module Finals
    module Constants
      class Protocol
        include ::Ruby::Enum

        define :BEANSTALK, 1
        define :REST_BASIC, 2
        define :REST_JWT, 3
      end
    end
  end
end
