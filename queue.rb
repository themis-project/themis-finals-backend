require './config'
require './lib/models/init'
require './lib/queue/init'

::Themis::Finals::Models.init
::Themis::Finals::Queue.run
