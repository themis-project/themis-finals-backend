module Rack
  class Request
    def trusted_proxy?(ip)
      ip =~ /^127\.0\.0\.1$/
    end
  end
end
