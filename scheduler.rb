require './lib/models/bootstrap'
require './lib/scheduler/init'

::VolgaCTF::Final::Models.init

scheduler = ::VolgaCTF::Final::Scheduler.new
scheduler.run
