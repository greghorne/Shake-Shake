# coding: utf-8
require 'sinatra'
require 'rest-client'
require 'json'

set server: 'thin'
connections = []
trace = true

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

    if trace 
      puts "========================="
      puts "Connections Count: " + connections.count.to_s
      puts "========================="
      puts
    end

    while !out.closed?

      # 60 (seconds) * 120 (minutes)
      offsetTime  = 60 * 15 

      # rest api call to usgs
      response    = JSON.parse(getUSGS(offsetTime))

      count = response['metadata']['count'].to_i
      puts count

      if count > 0 
        # retrieve the first feature (earthquake) from the rest response
        fetched_earthquake_code = response['features'][0]['properties']['code']

        if (current_earthquake_code != fetched_earthquake_code)

          current_earthquake_code = fetched_earthquake_code

          # magnitude = response['features'][0]['properties']['mag']
          time      = response['features'][0]['properties']['time']
          code      = current_earthquake_code
          title     = response['features'][0]['properties']['title']
          lngX      = response['features'][0]['geometry']['coordinates'][0]
          latY      = response['features'][0]['geometry']['coordinates'][1]
          depth     = response['features'][0]['geometry']['coordinates'][2]

          if trace 
            puts "=========================================="
            puts "title: " + title.to_s
            puts "code:  " + code.to_s
            puts "time:  " + Time.at(time/1000).to_s
            puts "coords:" + lngX.to_s + ", " + latY.to_s
            puts "depth: " + depth.to_s + " km"
            puts "now:   " + Time.now.to_s
            puts "=========================================="
            puts 
          end

          data = "data: {\"msg\":\"" + title.to_s + "\",\"x\":" + lngX.to_s + ",\"y\":" + latY.to_s + ",\"z\":" + depth.to_s + ",\"utc\":\"" + Time.at(time/1000).to_s + "\"}\n\n"
        else
          data = "data: {\"msg\":\"0\"}\n\n"
        end
      else
        data = "data: {\"msg\":\"0\"}\n\n"
      end

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
    <link rel="icon" href="earthquakes.ico" type="image/x-icon"/>
    
    <link rel="stylesheet" href="https://unpkg.com/leaflet@1.0.3/dist/leaflet.css" integrity="sha512-07I2e+7D8p6he1SIM+1twR5TIrhUQn9+I6yjqD53JQjFiMf8EtC93ty0/5vJTZGF8aAocvHYNEDJajGdNx1IsQ==" crossorigin=""/>
    <link rel="stylesheet" href="https://code.jquery.com/ui/1.12.1/themes/smoothness/jquery-ui.css">
    
    <script src="https://code.jquery.com/jquery-1.12.4.js"></script>
    <script src="https://unpkg.com/leaflet@1.0.3/dist/leaflet.js" integrity="sha512-A7vV8IFfih/D732iSSKi20u/ooOfj/AGehOKq0f4vLT1Zr2Y+RX7C+w8A1gaSasGtRUZpF/NZgzSAu4/Gc41Lg==" crossorigin=""></script>
    <!-- // <script src="https://code.jquery.com/jquery-3.2.1.min.js" integrity="sha256-hwg4gsxgFZhOsEEamdOYGBf13FyQuiTwlAQgxVSNgt4=" crossorigin="anonymous"></script> -->
    <script src="https://code.jquery.com/ui/1.12.1/jquery-ui.js"></script>

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

  var marker;
  var trace = true; 

  $(document).ready(function() {

    var eventSource = new EventSource('/streamer');

    eventSource.addEventListener('message', function(event){

      if (false) console.log(event.data);
      json = JSON.parse(event.data);
      if (trace) console.log(json);

      if (json['msg'] != "0") {
        longitudeX = json['x'];
        latitudeY  = json['y'];
        msg        = json['msg'];
        depth      = json['z'];
        time       = json['utc'];

        if (marker !== undefined) map.removeLayer(marker);

        marker = L.marker([latitudeY, longitudeX]).addTo(map);
        marker.bindPopup("<center>" + msg + "<br>Depth: " + depth + " km<br>UTC: " + time + "<center>").openPopup();
        map.setView(L.latLng(latitudeY, longitudeX), 8);   // change to 16

        $("#map").effect("shake", "times: 20");
      }
    }, false);

    eventSource.addEventListener('error', function(event) {
      // if this event fires it will automatically try and reconnect
      if (trace) {
        console.log("--------------------")
        console.log("error...")
        console.log(event)
        console.log("--------------------")
      }
    }, false);

    eventSource.addEventListener('close', function(event) {
      if (trace) {
        console.log("--------------------")
        console.log("connection closed...")
        console.log(event)
        console.log("--------------------")
      }
    }, false)


    // =======================================
    // leaflet begin >>>>>>>>>>>>>>>>>>>>>>>>>
    // =======================================
    var latitude = 35.746512259918504
    var longitude = -96.9873046875
    var zoom = 4

    var osm = L.tileLayer('https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png', {
        // attribution: attributionOSM,
        subdomains: ['a', 'b', 'c']
    });

    var map = L.map('map', {
      center: [latitude, longitude],
      zoom: zoom,
      layers: [osm],
      loadingControl: true
    });
    L.control.scale().addTo(map);
    // =======================================
    // leaflet end <<<<<<<<<<<<<<<<<<<<<<<<<<<
    // =======================================


  });

</script>

<form>
  <div id='map'></div>
</form>