# coding: utf-8
require 'sinatra'
require 'rest-client'
require 'json'

set server: 'thin'


# ================================================
# variables ======================================
# ================================================
connections = []

# 60 (seconds) * minutes
minutes = 15
offsetTime  = 60 * minutes.to_i

# "puts" and "console.log" statements on/off
trace = true
# ================================================


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

    # callback to remove connection from array
    out.callback{connections.delete(out)}

    if trace 
      puts "========================="
      puts "Connections Count: " + connections.count.to_s
      puts "========================="
      puts
    end

    while !out.closed?

      # rest api call to usgs
      response = getUSGS(offsetTime)

      data = ""

      # check response code
      if (response.code.to_s === "200")  then

        # parse json string
        response = JSON.parse(response)

        # count = number of earthquakes returned
        count = response['metadata']['count'].to_i

        if (trace) then 
          puts "earthquake count: " + count.to_s + "  last: " + minutes.to_s + " minutes" 
          puts ""
        end

        if count > 0 
          # retrieve the first feature (earthquake) from the rest api response
          fetched_earthquake_code = response['features'][0]['properties']['code']

          # check that the latest earthquake we have is not not equal to the latest earthquake
          # returned by usgs; if the codes are equal, then we already have and are displaying
          # the "latest" earthquake... thus do nothing to the map
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

            # ==========================================================================================
            # the string sent from the server to the client must start with "data:" and end with "\n\n"
            # ==========================================================================================
            data = "data: {\"msg\":\"" + title.to_s + "\",\"x\":" + lngX.to_s + ",\"y\":" + latY.to_s + ",\"z\":" + depth.to_s + ",\"utc\":\"" + Time.at(time/1000).to_s + "\"}\n\n"
          else
            # data = "data: {\"msg\":\"0\",\"usgs earthquake count\":" + count.to_s + ",\"in recent minutes\":" + minutes.to_s + "}\n\n"
          end
        else
          # data = "data: {\"msg\":\"0\",\"usgs earthquake count\":" + count.to_s + ",\"in recent minutes\":" + minutes.to_s + "}\n\n"
        end

        if (data === "") then
          data = "data: {\"msg\":\"0\",\"usgs earthquake count\":" + count.to_s + ",\"in recent minutes\":" + minutes.to_s + "}\n\n"
        end

        out << data
        sleep 30

      else
        # most often, server was down (or not responding)
        puts "REST API Call: error"
      end
    end

  end
end
# ================================================

# ================================================
def getUSGS(offsetTime)

  # USGS REST API
  https = 'https://earthquake.usgs.gov/fdsnws/event/1/query'

  response = RestClient.get https, {
    params: {
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

      html, body {
        background-color: gray;
        height: 100%;
        margin:   0;
        padding:  0;
      }

      #map { 
        width: 100%; 
        height: 96%;
        margin:  0;
        padding: 0;
      }

      .vertical-container {
        margin:   0;
        padding:  0;
        /*height:  4%;*/
        display: -webkit-flex;
        display:         flex;
        -webkit-align-items: center;
               align-items: center;
        -webkit-justify-content: center;
               justify-content: center;
      }

      #msg { 
        color: white;
        background-color: gray;
        margin:  0;
        padding: 0;
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

    // =======================================
    // event - message =======================
    // =======================================
    eventSource.addEventListener('message', function(event){

      var divText = "";

      json = JSON.parse(event.data);
      if (json['msg'] != "0") {
        
        if (trace) console.log(json);

        // extract some data from json object
        longitudeX = json['x'];
        latitudeY  = json['y'];
        msg        = json['msg'];
        depth      = json['z'];
        time       = json['utc'];

        // if any, remove current map marker
        if (marker !== undefined) map.removeLayer(marker);

        // add new marker to map
        marker = L.marker([latitudeY, longitudeX]).addTo(map);

        // add marker popup informaiton and open popup window
        marker.bindPopup("<center>" + msg + "<br>Depth: " + depth + " km<br>UTC: " + time + "<center>").openPopup();

        // pan and zoom to new map (earthquake) location
        map.setView(L.latLng(latitudeY, longitudeX), 8);

        // $("#msg").text("");
        divText = "";

        $("#map").effect("shake", "times: 20");

      } else {
        if (trace) console.log(json);

        var count = json["usgs earthquake count"]

        if (count === 0) $("#msg").css('color', 'rgb(165,255,144)')
        else if (count < 6) $("#msg").css('color', 'yellow')
        else $("#msg").css('color', 'rgb(245,107,97)')

        var date = new Date();
        json['msg'] = date;

        divText = date + " === USGS Earthquake Count: " + json["usgs earthquake count"] + " (last " + json["in recent minutes"] + " minutes)"

      }
      $("#msg").text(divText);

    }, false);
    // =======================================


    // =======================================
    // event - error =========================
    // =======================================
    eventSource.addEventListener('error', function(event) {
      // if this event fires it will automatically try and reconnect
      if (trace) {
        console.log("--------------------")
        console.log("error...")
        console.log(event)
        console.log("--------------------")
      }
    }, false);
    // =======================================


    // =======================================
    // event - close =========================
    // =======================================
    eventSource.addEventListener('close', function(event) {
      if (trace) {
        console.log("--------------------")
        console.log("connection closed...")
        console.log(event)
        console.log("--------------------")
      }
    }, false)
    // =======================================


    // =======================================
    // leaflet begin >>>>>>>>>>>>>>>>>>>>>>>>>
    // =======================================

    // initial map settings/view
    var latitude = 35.746512259918504
    var longitude = -96.9873046875
    var zoom = 4

    // kudos
    var attributionOSM = '&copy; <a href="http://osm.org/copyright">OpenStreetMap</a> contributors';

    // var osm = L.tileLayer('https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png', {
    var osm = L.tileLayer('https://{s}.tile.opentopomap.org/{z}/{x}/{y}.png', {  
      attribution: attributionOSM,
      subdomains: ['a', 'b', 'c']
    });

    var map = L.map('map', {
      center: [latitude, longitude],
      zoom: zoom,
      layers: [osm]
    });

    // scalebar
    L.control.scale().addTo(map);

    // =======================================
    // leaflet end <<<<<<<<<<<<<<<<<<<<<<<<<<<
    // =======================================
  });

</script>

<form>
  <div id='map'></div>
  <div class="vertical-container"><div id="msg"></div></div>
</form>