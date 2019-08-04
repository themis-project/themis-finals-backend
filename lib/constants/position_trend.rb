require 'ruby-enum'

module VolgaCTF
  module Final
    module Constants
      class PositionTrend
        include ::Ruby::Enum

        define :DOWN, -1
        define :FLAT, 0
        define :UP, 1
      end
    end
  end
end
