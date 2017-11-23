#!/usr/bin/env ruby

require 'socket'
require 'logger'

STDOUT.sync = true
logger = Logger.new STDOUT
logger.level = Logger::INFO

server = TCPServer.new 2000
logger.info "Listening on #{server.local_address.inspect_sockaddr}"

temperature = 23.5
relays = [false] * 4

loop do
  conn = begin
    server.accept
  rescue
    logger.error $!
    next
  end

  Thread.new(conn) do |conn|
    begin
      remote_addr = conn.remote_address.inspect_sockaddr
      logger.info "#{remote_addr} Connected"
      conn.write "*HELLO*"

      while cmd = conn.read(1)
        logger.debug "#{remote_addr} Received #{cmd.inspect}"
        case cmd
        when 'Z'
          logger.debug "#{remote_addr} Get software ID"
          conn.write 15.chr + 1.chr
        when '['
          logger.debug "#{remote_addr} Get relay states"
          state = 0
          (0...relays.size).each do |i|
            state |= 1 << i if relays[i]
          end
          conn.write state.chr
        when ']'
          logger.debug "#{remote_addr} Get voltage"
          conn.write 50.chr
        when 'a'
          logger.debug "#{remote_addr} Get temperature raw"
          conn.write((temperature / 16.0).to_i.chr + ((temperature * 16.0) % 256.0).to_i.chr)
        when 'b'
          logger.debug "#{remote_addr} Get temperature text"
          conn.write "%.2f\r\n" % [temperature]
        when 'd'
          logger.info "#{remote_addr} Set all relays"
          relays.fill true
        when 'e'..'l'
          i = cmd.ord - 'e'.ord
          logger.info "#{remote_addr} Set relay #{i + 1}"
          relays[i] = true if i < relays.size
        when 'n'
          logger.info "#{remote_addr} Clear all relays"
          relays.fill false
        when 'o'..'v'
          i = cmd.ord - 'o'.ord
          logger.info "#{remote_addr} Clear relay #{i + 1}"
          relays[i] = false if i < relays.size
        else
          logger.warn "#{remote_addr} Ignored unknown command: #{cmd.inspect}"
        end
      end
    rescue
      logger.warn "#{remote_addr} error: #{$!}"
    ensure
      logger.info "#{remote_addr} disconnected"
    end
  end
end
