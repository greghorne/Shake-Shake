require 'sinatra'


# gem install sinatra-contrib
require 'sinatra/streaming'

# require 'yahoo_stock'

get '/', provides: 'text/event-stream' do

    stream :keep_open do |out|

        out << "hello\n\n" unless out.closed?
        loop do
            # quote = YahooStock::Quote.new(:stock_symbols => [params[:symbol]])
            my_time = Time.now
            puts "Time: " + my_time.to_s
            if my_time
                # data = my_time(:to_hash).output
                # out << "data:{\"#{data.last_trade_price_only}\",\"time\":\"#{data.last_trade_date}\"}\n\n"
                # out << "Hello there\n\n"
                # data = my_time.to_s + "\n"
                data = Quake::Event.last_hour
                out << data
            else
                out << ": heartbeat\n" unless out.closed?
            end
            sleep 10
        end
    end
end

