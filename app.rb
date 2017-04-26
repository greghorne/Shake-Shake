# coding: utf-8
require 'sinatra'
require 'rest-client'
require 'json'

set server: 'thin'
connections = []

# ================================================
get '/' do
  erb :my_receiver
end
# ================================================

# ================================================
get '/streamer', provides: 'text/event-stream' do

  stream :keep_open do |out|

    puts ""
    puts "=========="
    puts "Connections Count: " + connections.count.to_s
    puts "=========="
    puts ""

    connections << out
    out.callback{connections.delete(out)}

    while !out.closed?
      # out << "data: " + Time.now.to_s + "\n\n"
      # lng = -962
      # lat = 36
      # location = "Tulsa, OK"
      # data = "data: {\"lng\": " + lng.to_s + "}\n\n"
      # data = "data: {\"username\": \"bobby\", \"time\": \"02:33:48\"}\n\n"
      data = "data: " + Time.now.to_s + "  " + connections.count.to_s + "\n\n"
      puts data
      out << data
      sleep 10
      
      # out << "data: {}\n\n"
      
      puts ""
      puts "=========="
      puts "Connections Count: " + connections.count.to_s
      puts "=========="
      puts ""

      https = 'https://earthquake.usgs.gov/fdsnws/event/1/query'
      params = {
        :format => 'geojson'
        # :starttime => Time.now.utc - (24 * 60 - 10),
        # :orderby => 'time',
        # :eventtype => 'earthquake'
      }
      response = RestClient.get https, {params: 
                                          {
                                            :format => 'geojson',
                                            :starttime => Time.now.utc - (24 * 60 - 1),
                                            :orderby => 'time',
                                            :eventtype => 'earthquake'
                                          }
                                       }
      puts response

    end
  end
end
# ================================================

__END__

@@ layout
<html>
  <head> 
    <title>Shake-Shake</title> 
    <meta charset="utf-8" />
    <!-- // <script src="http://ajax.googleapis.com/ajax/libs/jquery/1/jquery.min.js"></script>  -->
  </head> 
  <body><%= yield %></body>
</html>



@@ my_receiver
<pre id='my_receiver'></pre>

<script>
  // reading
  console.log("In script...")

  var eventSource = new EventSource('/streamer');

  eventSource.addEventListener('message', function(event){
    // console.log("Receiving data!!!...")
    
    // var data = JSON.parse(event.data);
    // console.log(data.lng);

    console.log(event.data)
    // alert("We be here")
  }, false);

  eventSource.addEventListener('error', function(event) {
    // if this event fires it will automatically try and reconnect
    console.log("--------------------")
    console.log("error...")
    console.log(event)
    console.log("--------------------")
  }, false);

  eventSource.addEventListener('close', function(event) {
    console.log("--------------------")
    console.log("connection closed...")
    console.log(event)
    console.log("--------------------")
  }, false)

</script>

<form>
  Waiting for messages in console...
</form>