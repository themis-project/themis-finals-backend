require 'ruby-enum'

module VolgaCTF
  module Final
    module Constants
      class FlagPollState
        include ::Ruby::Enum

        define :NOT_AVAILABLE, 0
        define :SUCCESS, 1
        define :ERROR, 2
      end
    end
  end
end
