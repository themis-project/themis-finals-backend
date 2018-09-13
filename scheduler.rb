require './lib/models/bootstrap'
require './lib/scheduler/init'

::Themis::Finals::Models.init

scheduler = ::Themis::Finals::Scheduler.new
scheduler.run
