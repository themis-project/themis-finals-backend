require 'ruby-enum'

module Themis
  module Finals
    module Const
      class CompetitionStage
        include ::Ruby::Enum

        define :NOT_STARTED, 0
        define :STARTING, 1
        define :STARTED, 2
        define :PAUSING, 3
        define :PAUSED, 4
        define :FINISHING, 5
        define :FINISHED, 6
      end
    end
  end
end
