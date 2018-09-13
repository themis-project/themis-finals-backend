module Themis
  module Finals
    module Domain
      network do
        internal '172.20.0.0/24'  # internal network (for contest organizers)
      end

      settings do
        flag_lifetime 360  # flag lives for 300 seconds
        round_timespan 120  # push new flags every 120 seconds
        poll_timespan 35
        poll_delay 40
      end

      deprecated_settings do
        attack_limits 200, 60  # max 200 attack attempts for the last 60 seconds
      end

      team 'team1' do  # this is an internal alias
        name 'Team #1'  # team displayed name
        network '172.20.1.0/24'  # team network
      end

      team 'team2' do
        name 'Team #2'
        network '172.20.2.0/24'
      end

      team 'team3' do
        name 'Team #3'
        network '172.20.3.0/24'
      end
      # and so on for teams

      service 'service1' do  # this is an internal alias
        name 'Service #1'  # service displayed name
        hostmask '0.0.0.3'
        checker_endpoint 'http://service1.checker.finals.themis-project.com'
      end

      service 'service2' do
        name 'Service #2'  # service displayed name
        hostmask '0.0.0.3'
        checker_endpoint 'http://service2.checker.finals.themis-project.com'
      end

      service 'service3' do
        name 'Service #3'  # service displayed name
        hostmask '0.0.0.3'
        checker_endpoint 'http://service3.checker.finals.themis-project.com'
      end
      # and so on for services
    end
  end
end
