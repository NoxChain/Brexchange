require 'net/http'
require 'uri'
require 'json'

class CoinRPC

  class JSONRPCError < RuntimeError; end
  class ConnectionRefusedError < StandardError; end

  def initialize(uri)
    @uri = URI.parse(uri)
  end

  def self.[](currency)
    c = Currency.find_by_code(currency.to_s)
    if c && c.rpc
    end
  end

  def method_missing(name, *args)
    handle name, *args
  end

  def handle
    raise "Not implemented"
  end
  class BTC < self
    def handle(name, *args)
      post_body = { 'method' => name, 'params' => args, 'id' => 'jsonrpc' }.to_json
      resp = JSON.parse( http_post_request(post_body) )
      raise JSONRPCError, resp['error'] if resp['error']
      result = resp['result']
      result.symbolize_keys! if result.is_a? Hash
      result
    end
    def http_post_request(post_body)
      http    = Net::HTTP.new(@uri.host, @uri.port)
      request = Net::HTTP::Post.new(@uri.request_uri)
      request.basic_auth @uri.user, @uri.password
      request.content_type = 'application/json'
      request.body = post_body
      http.request(request).body
    rescue Errno::ECONNREFUSED => e
      raise ConnectionRefusedError
    end

    def safe_getbalance
      begin
        getbalance
      rescue
        'N/A'
      end
    end
  end

  class ETH < self
    def handle(name, *args)
      post_body = {"jsonrpc" => "2.0", 'method' => name, 'params' => args, 'id' => '1' }.to_json
      resp = JSON.parse( http_post_request(post_body) )
      raise JSONRPCError, resp['error'] if resp['error']
      result = resp['result']
      result.symbolize_keys! if result.is_a? Hash
      result
    end
    def http_post_request(post_body)
      http    = Net::HTTP.new(@uri.host, @uri.port)
      request = Net::HTTP::Post.new(@uri.request_uri)
      request.basic_auth @uri.user, @uri.password
      request.content_type = 'application/json'
      request.body = post_body
      http.request(request).body
    rescue Errno::ECONNREFUSED => e
      raise ConnectionRefusedError
    end

    def safe_getbalance
      begin
        (open(@uri.host + '/cgi-bin/total.cgi').read.rstrip.to_f)
      rescue
        'N/A'
      end
    end
  end
  class CNT < self
  	def handle(name, *args)
      post_body = {"jsonrpc" => "2.0", 'method' => name, 'params' => args, 'id' => '1' }.to_json
      Rails.logger.info "CNT -> " + post_body
      resp = JSON.parse( http_post_request(post_body) )
      Rails.logger.info "CNT <- " + resp.to_json
      raise JSONRPCError, resp['error'] if resp['error']
      result = resp['result']
      #result.symbolize_keys! if result.is_a? Hash
      result
    end
    def handle_one(name, arg)
      post_body = {"jsonrpc" => "2.0", 'method' => name, 'params' => arg, 'id' => '1' }.to_json
      Rails.logger.info "CNT -> " + post_body
      resp = JSON.parse( http_post_request(post_body) )
      Rails.logger.info "CNT <- " + resp.to_json
      raise JSONRPCError, resp['error'] if resp['error']
      result = resp['result']
      #result.symbolize_keys! if result.is_a? Hash
      result
    end
    def http_post_request(post_body)
      http    = Net::HTTP.new(@uri.host, @uri.port)
      request = Net::HTTP::Post.new(@uri.request_uri)
      #request.basic_auth @uri.user, @uri.password
      request.content_type = 'application/json'
      request.body = post_body
      @reply = http.request(request).body
      return @reply
    rescue Errno::ECONNREFUSED => e
      raise ConnectionRefusedError
    end
    def safe_getbalance
      begin
        getbalance
      rescue => ex
        Rails.logger.info  "[error]: " + ex.message + "\n" + ex.backtrace.join("\n") + "\n"
        'N/A'
      end
    end

    def getbalance
      result = handle("getbalance")
      balance = result['balance'].to_f / 1000000000.0
      return balance
    end

    def gettransaction(txid)
      parameters =
      {
        txid: txid
      }
      transaction = handle_one("get_transfer_by_txid", parameters)
      confirmations = Integer(transaction['transfer']['height'])
      if confirmations > 0
        result = handle("getheight", "")
        confirmations = Integer(result['height']) - confirmations
      end
      result =  {
          confirmations: confirmations,
          time: Time.now.to_i,
          details:[]
        }
      if transaction['transfer']['destinations'] == nil
        return result
      end
      transaction['transfer']['destinations'].each do |destination|
        tx = {
            address: destination['address'],
            amount: destination['amount'].to_f / 1000000000.0,
            category: "receive"
          }
        result[:details].push(tx)
      end
      return result
    end

    def settxfee
    end

    def sendtoaddress(from, address, amount)
      parameters =
      {
        account_index: 0,
        destinations:
        [
          {
            amount: Integer(amount * 1000000000.0),
            address: address
          }
        ],
        get_tx_key: true
      }

      result = handle_one("transfer", parameters)
      return result['tx_hash']
    end

    def getnewaddress(name, digest)
      parameters =
      {
        account_index: 0,
        label: ""
      }.to_json

      result = handle_one("create_address", parameters)
      return result['address']
    end

    def getfee(size)
      return (30000000.0/1000000000.0).to_f
    end

    def validateaddress(address)
    end

    def getblockchaininfo

      result = handle("getheight", "")

      {
        blocks: Integer(result['height']),
        headers: 0,
        mediantime: 0
      }
    end
end
end
