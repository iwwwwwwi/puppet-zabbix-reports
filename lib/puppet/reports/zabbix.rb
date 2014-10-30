require 'puppet'
require 'puppet/util/zabbix_sender'
require 'yaml'

Puppet::Reports.register_report(:zabbix) do
  desc "Send reports to a Zabbix server via zabbix trapper."

  def process
    configfile = File.join([File.dirname(Puppet.settings[:config]), "zabbix.yaml"])
    raise Puppet::ParseError, "Zabbix report config file #{configfile} not readable" unless File.exist?(configfile)

    config = YAML.load_file(configfile)
    raise Puppet::ParseError, "Zabbix host was not specified in config file" unless defined? config[:zabbix_host]

    zabbix_sender = Puppet::Util::Zabbix::Sender.new config[:zabbix_host], config.fetch(:zabbix_port, 10051)

    # collect metrics
    self.metrics.each do |metric, data|
      next if metric == 'events' # do not process events at all

      data.values.each do |item|
        next if metric == 'time' and item.first != 'total' # get only total time
        zabbix_sender.add_item "puppet.#{metric}.#{item.first}", item.last
      end
    end

    # send metric to zabbix
    Puppet.debug "sending report for host #{self.host}, to zabbix server at #{zabbix_sender.serv}:#{zabbix_sender.port}"
    result = zabbix_sender.send! self.host

    Puppet.debug result.to_json

    # validate the response
    raise Puppet::Error, "zabbix send failed - #{result['info']}" if result['response'] != 'success'
  end
end
