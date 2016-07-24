require './config'
require './lib/models/init'
require './lib/scheduler/init'

::Themis::Finals::Models.init
::Themis::Finals::Scheduler.run
