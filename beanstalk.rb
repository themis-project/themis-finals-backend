require './config'
require './lib/models/init'
require './lib/beanstalk/init'

::Themis::Finals::Models.init
::Themis::Finals::Beanstalk.run
