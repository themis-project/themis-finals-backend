require 'ruby-enum'

module VolgaCTF
  module Final
    module Constants
      class SubmitResult
        include ::Ruby::Enum

        define :SUCCESS, 0  # submitted flag has been accepted

        define :ERROR_UNKNOWN, 1  # generic error

        define :ERROR_ACCESS_DENIED, 2  # the attacker does not appear to be a team
        define :ERROR_COMPETITION_NOT_STARTED, 3  # contest has not started yet
        define :ERROR_COMPETITION_PAUSED, 4  # contest is paused
        define :ERROR_COMPETITION_FINISHED, 5  # contest has finished

        define :ERROR_FLAG_INVALID, 6  # submitted data has invalid format

        define :ERROR_RATELIMIT, 7  # attack attempts limit exceeded

        define :ERROR_FLAG_EXPIRED, 8  # submitted flag has expired
        define :ERROR_FLAG_YOUR_OWN, 9  # submitted flag belongs to the attacking team
        define :ERROR_FLAG_SUBMITTED, 10  # submitted flag has been accepted already
        define :ERROR_FLAG_NOT_FOUND, 11  # submitted flag has not been found

        define :ERROR_SERVICE_STATE_INVALID, 12  # the attacking team service is not up
      end
    end
  end
end
