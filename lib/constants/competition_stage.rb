require 'ruby-enum'

module Themis
  module Finals
    module Const
      class CompetitionStage
        include ::Ruby::Enum

        define :NOT_STARTED, 0
        define :STARTING, 1
        define :STARTED, 2
        define :PAUSED, 3
        define :FINISHING, 4
        define :FINISHED, 5
      end
    end
  end
end
