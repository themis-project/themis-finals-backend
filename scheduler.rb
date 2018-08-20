require './config'
require './lib/models/bootstrap'
require './lib/scheduler/init'

::Themis::Finals::Models.init
::Themis::Finals::Scheduler.run
