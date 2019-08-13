require './lib/model/bootstrap'
require './lib/scheduler/init'

::VolgaCTF::Final::Model.init

scheduler = ::VolgaCTF::Final::Scheduler.new
scheduler.run
