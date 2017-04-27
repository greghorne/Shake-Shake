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

    # code that the server currently holds
    current_earthquake_code = ""

    # code that was just retreived from USGS
    fetched_earthquake_code  = ""

    # save connections to array
    connections << out

    out.callback{connections.delete(out)}

    puts "========================="
    puts "Connections Count: " + connections.count.to_s
    puts "========================="
    puts

    while !out.closed?

      # 60 (seconds) * 60 (minutes)
      offsetTime  = 60 * 60 

      # rest api call to usgs
      response    = JSON.parse(getUSGS(offsetTime))

      # retrieve the first feature (earthquake) from the rest response
      fetched_earthquake_code = response['features'][0]['properties']['code']

      if (current_earthquake_code != fetched_earthquake_code)

        current_earthquake_code = fetched_earthquake_code

        # magnitude = response['features'][0]['properties']['mag']
        time      = response['features'][0]['properties']['time']
        # code      = response['features'][0]['properties']['code']
        code      = current_earthquake_code
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
        data = "data: {\"msg\":\"0\"}\n\n"
      end
      # puts "bytes: "+ bytesize(data).to_s
      # puts
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
    
    <link rel="stylesheet" href="https://unpkg.com/leaflet@1.0.3/dist/leaflet.css" integrity="sha512-07I2e+7D8p6he1SIM+1twR5TIrhUQn9+I6yjqD53JQjFiMf8EtC93ty0/5vJTZGF8aAocvHYNEDJajGdNx1IsQ==" crossorigin=""/>
    
    <script src="https://unpkg.com/leaflet@1.0.3/dist/leaflet.js" integrity="sha512-A7vV8IFfih/D732iSSKi20u/ooOfj/AGehOKq0f4vLT1Zr2Y+RX7C+w8A1gaSasGtRUZpF/NZgzSAu4/Gc41Lg==" crossorigin=""></script>
    <script src="https://code.jquery.com/jquery-3.2.1.min.js" integrity="sha256-hwg4gsxgFZhOsEEamdOYGBf13FyQuiTwlAQgxVSNgt4=" crossorigin="anonymous"></script>

    <style>
      #map { width: 100%; 
             height: 100%
           }

    </style>
  </head> 
  <body><%= yield %></body>
</html>



@@ my_receiver
<pre id='my_receiver'></pre>

<script>


  $(document).ready(function() {

    var eventSource = new EventSource('/streamer');

    eventSource.addEventListener('message', function(event){
      // console.log("Receiving data!!!...")
      
      // var data = JSON.parse(event.data);
      // console.log(data.lng);
      console.log(event.data);
      json = JSON.parse(event.data);
      console.log(json);
      if (json['msg'] != "0") {
        longitudeX = json['x'];
        latitudeY  = json['y'];

        map.setView(L.latLng(latitudeY, longitudeX), 10)   // change to 16
      }
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

    // =======================================
    // leaflet begin =========================
    // =======================================
    var latitude = 35.746512259918504
    var longitude = -96.9873046875
    var zoom = 4

    var osm = L.tileLayer('http://{s}.tile.osm.org/{z}/{x}/{y}.png', {
        // attribution: attributionOSM,
        subdomains: ['a', 'b', 'c']
    });

    var map = L.map('map', {
      center: [latitude, longitude],
      zoom: zoom,
      layers: [osm],
      loadingControl: true
    });

    L.control.layers(osm).addTo(map);
    // =======================================
    // leaflet end ===========================
    // =======================================

  });

</script>

<form>
  <div id='map'></div>
</form>