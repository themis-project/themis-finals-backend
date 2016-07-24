require './config'
require './lib/models/init'
require './lib/backend/init'

::Themis::Finals::Models.init
::Themis::Finals::Backend.run
