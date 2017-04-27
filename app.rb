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
    current_earthquake_code = ""
    code = ""

    connections << out
    out.callback{connections.delete(out)}

    puts "========================="
    puts "Connections Count: " + connections.count.to_s
    puts "========================="

    while !out.closed?

      offsetTime  = 60 * 60 # 60 minutes
      response    = JSON.parse(getUSGS(offsetTime))

      code = response['features'][0]['properties']['code']
      # puts code
      if (current_earthquake_code != code)
        current_earthquake_code = code

        magnitude = response['features'][0]['properties']['mag']
        time      = response['features'][0]['properties']['time']
        code      = response['features'][0]['properties']['code']
        title     = response['features'][0]['properties']['title']
        lngX      = response['features'][0]['geometry']['coordinates'][0]
        latY      = response['features'][0]['geometry']['coordinates'][1]
        depth     = response['features'][0]['geometry']['coordinates'][2]

        puts "=========================================="
        puts "title: " + title.to_s
        puts "code:  " + code.to_s
        puts "time:  " + Time.at(time/1000).to_s
        puts "coords:" + lngX.to_s + ", " + latY.to_s
        puts "depth: " + depth.to_s + " km"
        puts "now:   " + Time.now.to_s
        puts "=========================================="
        puts 

        # data = "data: {\"username\": \"bobby\", \"time\": \"02:33:48\"}\n\n"
        # data = "data: {\"title\":\"" + title.to_s + "\", \"lngY\":" + lngY.to_s + ", \"latX\":" + latX.to_s + "}\n\n"
        data = "data: {\"msg\":\"" + title.to_s + "\",\"x\":" + lngX.to_s + ",\"y\":" + latY.to_s + ",\"z\":" + depth.to_s + ",\"utc\":\"" + Time.at(time/1000).to_s + "\"}\n\n"
      else
        data = "data:\n\n"
      end
      puts bytesize(data)
      out << data
      sleep 30

    end
  end
end
# ================================================

# ================================================
def getUSGS(offsetTime)

  https = 'https://earthquake.usgs.gov/fdsnws/event/1/query'
  response = RestClient.get https, {params: 
                                      {
                                        :format => 'geojson',
                                        :starttime => Time.now.utc - offsetTime,
                                        :orderby => 'time',
                                        :eventtype => 'earthquake'
                                      }
                                   }
  return response
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